// OverbrightBoost/Engine/DisplayController+Events.swift — shields, suspension and resume, occlusion, window moves,
// reconfiguration, re-basing, display removal, Back to Standard and the hang recovery. ARCHITECTURE.md §4.3 (event
// rows), §4.5 invariants 2, 6, 11, §4.6, §4.8 (event-driven re-base), D9, D27. MainActor.
import CoreGraphics
import Foundation
import OverbrightCore
import OverbrightPolicy

extension DisplayController {
    // MARK: Shields (synchronous, §4.5 invariant 6)

    /// Lock, screensaver, sleep, screens asleep, session resigned: the baseline is written before this returns; the
    /// trigger is kept for `triggerLinger` (removed at once off the console).
    func shield(_ cause: SuspendCause) {
        if cause == .notOnConsole { isOffConsole = true }
        switch phase {
        case .idle, .failed:
            if cause == .notOnConsole { removeWindows() }
            return
        default:
            break
        }
        generation += 1
        cancelAllTasks()
        writeBaselineNow()
        if cause == .notOnConsole { removeWindows() }
        phase = .suspended(cause)
        if trigger != nil || overlay != nil { startLinger() }
    }

    /// Removes the kept trigger after `triggerLinger` while still suspended.
    func startLinger() {
        lingerSlot.run { [weak self] in
            guard let self else { return }
            do { try await self.deps.time.sleep(for: EngineTiming.triggerLinger) } catch { return }
            guard case .suspended = self.phase else { return }
            let windows = (self.trigger, self.overlay)
            self.trigger = nil
            self.overlay = nil
            windows.0?.remove()
            windows.1?.remove()
            self.notify()
        }
    }

    /// Wake or unlock ended a shield: the next resume uses the backoff rule; failures for the next 60 s do not count
    /// against the cached rung; a display that never got headroom tries again (§4.3).
    func noteResume(_ kind: ResumeKind) {
        pendingResume = kind
        quarantineUntil = deps.time.now + EngineTiming.escalationQuarantine
        if case .failed(.headroomNeverArrived) = phase { clearTrip() }
    }

    /// The session is on the console again: writes are allowed (D27).
    func noteSessionActive() {
        isOffConsole = false
        noteResume(.unlock)
    }

    /// A suspended display and a new decision: stay while the shield holds, otherwise resume or go idle.
    func resumeIfPossible(_ cause: SuspendCause, requested: Bool) {
        let shielded = decision?.reasons.contains(.shielded) ?? false
        switch cause {
        case .shielded, .displayAsleep, .notOnConsole, .policy:
            if shielded { return }
        case .occluded:
            let hidden = trigger?.isOccluded == true || overlay?.isOccluded == true
            if hidden, targetGain != nil { return }
        case .reconfiguring, .hungMainThread:
            if case .neutral = target { break }
            return
        }
        resume()
    }

    /// Leaves `suspended`: neutral → idle; dim → ramp to it; boost → re-gate (wake settles 1 s first).
    func resume() {
        lingerSlot.cancel()
        let kind = pendingResume
        pendingResume = nil
        switch target {
        case .neutral:
            generation += 1
            cancelAllTasks()
            writeBaselineNow()
            removeWindows()
            phase = .idle
            settled()
        case .dim(let light):
            generation += 1
            cancelAllTasks()
            removeWindows()
            if mechanism == .table, baseline == nil { guard captureBaseline() else { return } }
            startRamp(to: light, origin: .automatic, finalPhase: .dimmed)
        case .boost:
            guard kind == .wake else {
                regate(backoff: kind)
                return
            }
            generation += 1
            let stamp = generation
            checkSlot.run { [weak self] in
                guard let self, await self.sleep(EngineTiming.wakeSettle, stamp) else { return }
                self.regate(backoff: .wake)
            }
        }
    }

    // MARK: Windows

    /// The trigger or overlay became hidden (the lock shield) or visible again.
    func windowOcclusionChanged(_ occluded: Bool, isCurrentWindow: Bool) {
        guard isCurrentWindow else { return }
        if occluded {
            switch phase {
            case .arming, .gating, .ramping, .boosted:
                generation += 1
                cancelAllTasks()
                writeBaselineNow()
                phase = .suspended(.occluded)
            default:
                break
            }
        } else if case .suspended(.occluded) = phase {
            trigger?.represent()
            overlay?.represent()
            resume()
        }
    }

    /// AppKit moved the trigger or overlay to another screen: un-scale, remove that window at once, wait for the
    /// reconfiguration pass (§4.3, §4.7), so it never requests EDR on another display.
    func windowMoved(to displayID: CGDirectDisplayID?, isCurrentWindow: Bool) {
        guard isCurrentWindow, displayID != ref.id else { return }
        deps.journal.record("trigger.movedScreen", display: key, time: deps.time, category: .trigger)
        switch phase {
        case .suspended:
            removeWindows()
        default:
            generation += 1
            cancelAllTasks()
            writeBaselineNow()
            removeWindows()
            phase = .suspended(.reconfiguring)
        }
    }

    // MARK: Reconfiguration and re-basing (§4.8)

    /// New facts without a reconfiguration pass (the directory changed).
    func updateFacts(_ newFacts: DisplayFacts) {
        facts = newFacts
        ref = newFacts.ref
    }

    /// The debounced after-phase pass: re-place windows, retry `headroomNeverArrived`, recheck a foreign table, resume
    /// a display whose window moved, and re-base a scaled or dimmed one.
    func reconfigured(_ newFacts: DisplayFacts) {
        updateFacts(newFacts)
        lastBaseEventAt = deps.time.now
        trigger?.represent()
        overlay?.represent()
        switch phase {
        case .failed(.headroomNeverArrived):
            clearTrip()
        case .failed(.foreignTableAtLaunch), .failed(.attributedDrift):
            if case .failed(.foreignTableAtLaunch) = phase, tableMatchesBase() { clearTrip() }
        case .suspended(.reconfiguring):
            resume()
        case .boosted, .dimmed, .ramping:
            rebase(cause: .reconfiguration)
        default:
            break
        }
    }

    /// A ColorSync profile change or a change of the accessibility display options (the same re-base, §4.8).
    func baseEventOccurred(_ cause: ReapplyCause) {
        lastBaseEventAt = deps.time.now
        switch phase {
        case .boosted, .dimmed, .ramping:
            rebase(cause: cause)
        case .failed(.foreignTableAtLaunch):
            if tableMatchesBase() { clearTrip() }
        default:
            break
        }
    }

    /// Whether the live table matches the display's profile base now.
    func tableMatchesBase() -> Bool {
        guard let read = try? deps.gamma.read(ref.id) else { return false }
        let expected = deps.gamma.profileBase(of: ref.id, count: read.count)
        return read.matches(expected, tolerance: EngineTiming.driftTolerance)
    }

    /// Recomputes the expected base, waits until WindowServer applied the new table (at most 1 s), adopts it after two
    /// identical reads (or the new profile base when WindowServer kept our table), updates the ledger in the same step
    /// and reapplies the target with a ramp.
    func rebase(cause: ReapplyCause) {
        guard mechanism == .table, let old = baseline else {
            if mechanism == .overlay { reapply(cause) }
            return
        }
        let stamp = generation
        rampSerial &+= 1
        rampSlot.cancel()
        let ourLast = old.scaled(by: appliedFactor)
        rebaseSlot.run { [weak self] in await self?.runRebase(old: old, ourLast: ourLast, cause: cause, stamp: stamp) }
    }

    /// Two tables this close are the same write (read-back noise).
    static let sameTableTolerance = 1e-4

    func runRebase(old: GammaTable, ourLast: GammaTable, cause: ReapplyCause, stamp: UInt64) async {
        let expected = deps.gamma.profileBase(of: ref.id, count: old.count)
        var waited = Duration.zero
        var first = try? deps.gamma.read(ref.id)
        while let read = first, read.matches(ourLast, tolerance: Self.sameTableTolerance),
              waited < EngineTiming.reapplyWaitLimit {
            guard await sleep(EngineTiming.gatePollInterval, stamp) else { return }
            waited += EngineTiming.gatePollInterval
            first = try? deps.gamma.read(ref.id)
        }
        guard let first, await sleep(EngineTiming.gatePollInterval, stamp),
              let second = try? deps.gamma.read(ref.id) else { return }
        let keptOurs = first.matches(ourLast, tolerance: Self.sameTableTolerance)
        var adopted: GammaTable?
        if !keptOurs, first.matches(second, tolerance: Self.sameTableTolerance),
           first.matches(expected, tolerance: EngineTiming.driftTolerance),
           case .accept = BaselineRules.capture(first, expectedBase: expected, previous: old) {
            adopted = first
        } else if keptOurs, !expected.matches(old, tolerance: EngineTiming.driftTolerance),
                  case .accept = BaselineRules.capture(expected, expectedBase: expected, previous: old) {
            adopted = expected
        }
        if let adopted {
            baseline = adopted
            if deps.ledger.isMarked(key) { deps.ledger.markScaled(ref, baseline: adopted) }
            deps.journal.record("baseline.adopted", display: key, values: ["cause": Double(cause.rawValue)],
                                time: deps.time)
        }
        if !keptOurs {
            appliedGain = 1
            appliedFactor = 1
        }
        reapply(cause)
    }

    // MARK: Removal, Back to Standard, stop

    /// `kCGDisplayRemoveFlag`: order the windows out first; no table write (the table went with the display); forget
    /// the ledger entry.
    func removeNow() {
        generation += 1
        cancelAllTasks()
        removeWindows()
        deps.ledger.unmark(key)
        appliedGain = 1
        appliedFactor = 1
        if !phase.isFailed { phase = .idle }
    }

    /// Back to Standard: ramp to 1 in 120 ms, baseline, windows removed. A step without a fresh reading lands on the
    /// baseline at once, so it never depends on one.
    func rampBackToStandard() {
        generation += 1
        armSlot.cancel(); burstSlot.cancel(); driftSlot.cancel(); rebaseSlot.cancel(); checkSlot.cancel()
        lingerSlot.cancel()
        target = .neutral
        if phase.isFailed { return }
        guard isScaledOrDimmed else {
            rampSlot.cancel()
            removeWindows()
            phase = .idle
            settled()
            return
        }
        phase = .disarming
        startRamp(to: 1, kind: .backToStandard, origin: .user, finalPhase: .idle, removesWindowsAtEnd: true,
                  setsRampingPhase: false, rateLimited: false)
    }

    /// `ServiceLifecycle.stop()`: the ramped stop; await `waitUntilSettled()`.
    func beginStop(kind: RampPlanner.Kind) {
        target = .neutral
        pendingResume = nil
        disarm(kind: kind, rateLimited: false)
    }

    /// Waits for the running ramp (the ramped stop).
    func waitUntilSettled() async {
        await rampSlot.wait()
    }

    /// `stopNow()`: baseline at once, windows removed, no tasks.
    func stopNow() {
        generation += 1
        cancelAllTasks()
        writeBaselineNow()
        removeWindows()
        if !phase.isFailed { phase = .idle }
    }

    // MARK: Hang recovery (§4.6)

    /// The hang watchdog wrote every ledger baseline and bumped the epoch: queued scaled writes are refused; journal
    /// `hang.restored` and re-gate (which re-stamps the epoch).
    func recoverFromHang() {
        deps.journal.record("hang.restored", display: key, time: deps.time)
        generation += 1
        cancelAllTasks()
        appliedGain = 1
        appliedFactor = 1
        appliedLimit = nil
        phase = .suspended(.hungMainThread)
        switch target {
        case .neutral:
            removeWindows()
            phase = .idle
            settled()
        case .dim(let light):
            epochStamp = deps.ledger.hangEpoch
            startRamp(to: light, origin: .automatic, finalPhase: .dimmed)
        case .boost:
            regate(backoff: nil)
        }
    }
}
