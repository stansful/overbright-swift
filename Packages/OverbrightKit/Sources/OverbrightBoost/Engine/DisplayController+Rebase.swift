// OverbrightBoost/Engine/DisplayController+Rebase.swift — reconfiguration passes, ColorSync and accessibility events: the
// expected base recomputed, WindowServer's table awaited and adopted, the ledger updated, the target reapplied, in every
// phase, idle and failed included. ARCHITECTURE.md §4.3 (reconfiguration rows: "whether or not the display is scaled"),
// §4.8 (event-driven re-base: "scaled, dimmed or idle alike"), §4.5 invariants 5 and 6, D26, D27. MainActor.
import CoreGraphics
import Foundation
import OverbrightCore
import OverbrightPolicy

extension DisplayController {
    // MARK: Reconfiguration and re-basing (§4.8)

    /// New facts without a reconfiguration pass (the directory changed).
    func updateFacts(_ newFacts: DisplayFacts) {
        facts = newFacts
        ref = newFacts.ref
    }

    /// The debounced after-phase pass: re-place windows, re-base every display (at rest too), resume a display whose
    /// window moved, retry `headroomNeverArrived` and recheck a foreign table.
    func reconfigured(_ newFacts: DisplayFacts) {
        updateFacts(newFacts)
        trigger?.represent()
        overlay?.represent()
        noteBaseEvent(.reconfiguration)
        switch phase {
        case .suspended(.reconfiguring):
            resume()                                                      // which restarts the re-base where it lands
        case .failed(.headroomNeverArrived):
            clearTrip()
        case .failed(.foreignTableAtLaunch):
            if tableMatchesBase() { clearTrip() }
        default:
            break
        }
    }

    /// A ColorSync profile change or a change of the accessibility display options (the same re-base, §4.8).
    func baseEventOccurred(_ cause: ReapplyCause) {
        noteBaseEvent(cause)
        if case .failed(.foreignTableAtLaunch) = phase, tableMatchesBase() { clearTrip() }
    }

    /// A base event, in every phase (§4.8: "scaled, dimmed or idle alike"). An active display re-bases (suspended,
    /// arming, gating and disarming included) and the event stays pending (`pendingRebase`) until that re-base has
    /// judged the table; a display at rest (idle or failed) is judged at once, because WindowServer may keep our last
    /// baseline write over the old curve, which the next arm or calibration would otherwise capture.
    func noteBaseEvent(_ cause: ReapplyCause) {
        lastBaseEventAt = deps.time.now
        pendingRebase = cause
        if isActive {
            rebase(cause: cause)
        } else {
            settlePendingRebase()
        }
    }

    /// A pending base event whose re-base a shield, a hang recovery or a resume cut short starts again (no-op while one
    /// runs).
    func restartPendingRebase() {
        guard let cause = pendingRebase, !isRebasing, isActive else { return }
        rebase(cause: cause)
    }

    /// Whether the live table matches the display's profile base now.
    func tableMatchesBase() -> Bool {
        guard let read = try? deps.gamma.read(ref.id) else { return false }
        let expected = deps.gamma.profileBase(of: ref.id, count: read.count)
        return read.matches(expected, tolerance: EngineTiming.driftTolerance)
    }

    /// Whether the profile base moved since the baseline was captured or adopted: only then does a re-base that finds
    /// our own table still on screen replace the baseline with the new profile base. A foreign baseline (a continued S2
    /// app's curve, an S3 tool, a calibration loader) differs from the profile base on every reconfiguration and must
    /// stay (§4.8). Without a recorded expected base (a baseline from before WP14's fix), the old rule applies.
    func profileChanged(_ expected: GammaTable, old: GammaTable) -> Bool {
        !expected.matches(expectedBase ?? old, tolerance: EngineTiming.driftTolerance)
    }

    /// Recomputes the expected base, waits until WindowServer applied the new table (at most 1 s), adopts it after two
    /// identical reads (or the new profile base when WindowServer kept our table and the profile changed), updates the
    /// ledger in the same step and reapplies the target with a ramp. It runs across target changes (its reapply uses
    /// the latest target) and compares every read with our latest write, so our own ramps and safety drops are never
    /// mistaken for WindowServer's table; shields, removal and stops cancel it (a pending event then restarts or settles
    /// it). A base that cannot be written now (off the console, D27, or a refused write) keeps the event pending.
    func rebase(cause: ReapplyCause) {
        guard mechanism == .table, let old = baseline else {
            pendingRebase = nil
            if mechanism == .overlay { reapply(cause) }
            return
        }
        isRebasing = true
        rebaseSlot.run { [weak self] in await self?.runRebase(old: old, cause: cause) }
    }

    /// Two tables this close are the same write (read-back noise).
    static let sameTableTolerance = 1e-4

    func runRebase(old: GammaTable, cause: ReapplyCause) async {
        let expected = deps.gamma.profileBase(of: ref.id, count: old.count)
        var waited = Duration.zero
        var read = try? deps.gamma.read(ref.id)
        while let current = read, isOurs(current), waited < EngineTiming.reapplyWaitLimit {
            guard await rebaseSleep() else { return }
            waited += EngineTiming.gatePollInterval
            read = try? deps.gamma.read(ref.id)
        }
        // A cancelled sleep means a newer re-base (a second event in the same pass), a shield or a stop took over: it
        // owns `isRebasing` now. Only an unreadable table ends this one here.
        guard let first = read else {
            isRebasing = false
            return
        }
        guard await rebaseSleep() else { return }
        guard let second = try? deps.gamma.read(ref.id) else {
            isRebasing = false
            return
        }
        let keptOurs = isOurs(second)
        var adopted: GammaTable?
        if !keptOurs, first.matches(second, tolerance: Self.sameTableTolerance),
           second.matches(expected, tolerance: EngineTiming.driftTolerance),
           case .accept = BaselineRules.capture(second, expectedBase: expected, previous: old) {
            adopted = second
        } else if keptOurs, profileChanged(expected, old: old),
                  case .accept = BaselineRules.capture(expected, expectedBase: expected, previous: old) {
            adopted = expected
        }
        pendingRebase = nil
        if let adopted { adopt(adopted, expected: expected, cause: cause) }
        if !keptOurs {
            forgetOwnWrite()
        } else if isScaledOrDimmed, !phase.isSuspended {
            // WindowServer kept our table over the old curve: the same light on the new base is one write (the level
            // does not change, only the curve under it).
            if adopted != nil { _ = writeGain(appliedGain) }
        } else if lastWrite != nil, adopted != nil || !lastWriteIsBaseline, let baseline {
            // A shielded display is neutral (§4.2, §4.5 invariant 6), even when its shield write failed and our scaled
            // table is still on screen: the new base, never a scaled table (the linger retries it). At rest, our old
            // baseline is still on screen (or a base adopted earlier could not be written yet).
            if !writeAdoptedBase(baseline) { pendingRebase = cause }
        }
        isRebasing = false
        reapply(cause)
    }

    /// A base event at rest (idle or failed), judged at once in one read: a fresh event, or one whose re-base a disarm,
    /// Back to Standard, a stop or a trip cut short. Idle does no work (§4.2), so nothing waits for WindowServer: a
    /// table it applies later replaces ours anyway and is captured at the next arm. Only a display we wrote can show
    /// our own table. When it still does (WindowServer kept our write over the old curve) and the profile changed, the
    /// new profile base is adopted and written once, on the console only (D27); this also lands a failed landing. A
    /// foreign baseline over an unchanged profile stays (`profileChanged`). WindowServer's table is adopted as it is
    /// when it matches the new base; any table that is not ours means no write of ours is on screen any more
    /// (`forgetOwnWrite`: another writer restoring our old table is never taken for our stale write, and the ledger
    /// entry a failed landing left goes with it). A write that cannot happen now keeps the event pending for the next
    /// reduction (`retryLandingAtRest`), and no capture takes our old table meanwhile (`isOwnStaleWrite`). Without
    /// this, "off" would leave the old curve after a profile, preset or HDR change, and the next arm or calibration
    /// would multiply it (§4.8).
    func settlePendingRebase() {
        guard let cause = pendingRebase else { return }
        pendingRebase = nil
        stopRebase()
        guard mechanism == .table, lastWrite != nil, let old = baseline, let read = try? deps.gamma.read(ref.id) else {
            return
        }
        let expected = deps.gamma.profileBase(of: ref.id, count: old.count)
        if isOurs(read) {
            if profileChanged(expected, old: old),
               case .accept = BaselineRules.capture(expected, expectedBase: expected, previous: old) {
                adopt(expected, expected: expected, cause: cause)
            }
            if !lastWriteIsBaseline, let baseline, !writeAdoptedBase(baseline) { pendingRebase = cause }
        } else {
            if read.matches(expected, tolerance: EngineTiming.driftTolerance),
               case .accept = BaselineRules.capture(read, expectedBase: expected, previous: old) {
                adopt(read, expected: expected, cause: cause)
            }
            forgetOwnWrite()
        }
    }

    /// WindowServer's table replaced ours: what is on screen is not our scaling and no write of ours (a later table
    /// equal to our old write is another writer's, never our stale one). The display leaves the safety ledger in the
    /// same step: no baseline write follows to empty its entry (`writeBaselineNow` has nothing to restore), and a
    /// stale entry would keep the hang watchdog pinging and the boost marker set while nothing is scaled (D7, DESIGN.md
    /// §17). A boost or dim that reapplies marks it again with its first scaled write, under the ledger lock.
    func forgetOwnWrite() {
        let changed = isScaledOrDimmed || deps.ledger.isMarked(key)
        resetApplied()
        lastWrite = nil
        deps.ledger.unmark(key)
        if changed { notify() }                                           // the marker and boost sources follow
    }

    /// `table` becomes the baseline, and the ledger's baseline in the same step (the hang watchdog never restores the
    /// old curve); `expected` is the profile base it was judged against (`profileChanged`).
    func adopt(_ table: GammaTable, expected: GammaTable, cause: ReapplyCause) {
        baseline = table
        expectedBase = expected
        if deps.ledger.isMarked(key) { deps.ledger.markScaled(ref, baseline: table) }
        deps.journal.record("baseline.adopted", display: key, values: ["cause": Double(cause.rawValue)],
                            time: deps.time)
    }

    /// Writes the adopted base over our own write still on screen (one baseline write; only after we wrote this
    /// display, and never off the console, D27). The table is at its baseline afterwards; false when nothing was
    /// written.
    @discardableResult
    func writeAdoptedBase(_ table: GammaTable) -> Bool {
        guard lastWrite != nil, !isOffConsole, parameters.isSessionActive else { return false }
        do {
            try deps.writer.writeBaseline(table, to: ref)
        } catch {
            deps.journal.record("baseline.writeFailed", display: key, time: deps.time, category: .gamma)
            return false
        }
        lastWrite = (table, 1)
        resetApplied()
        return true
    }

    /// Whether `read` is our latest write (or the baseline when we never wrote), under either read-back model: the
    /// table as written, or clamped at 1.0 (D26).
    func isOurs(_ read: GammaTable) -> Bool {
        guard let lastWrite else { return baseline.map { read.matches($0, tolerance: Self.sameTableTolerance) } ?? false }
        let written = abs(lastWrite.factor - 1) < TableWriter.neutralTolerance
            ? lastWrite.baseline : lastWrite.baseline.scaled(by: lastWrite.factor)
        return read.matches(written, tolerance: Self.sameTableTolerance)
            || read.matches(written.clampedAtOne, tolerance: Self.sameTableTolerance)
    }

    /// Our latest table write is the baseline we hold now (true when we never wrote this display): nothing of ours
    /// but the baseline can be on screen.
    var lastWriteIsBaseline: Bool {
        guard let lastWrite else { return true }
        guard let baseline, !lastWriteIsScaled else { return false }
        return lastWrite.baseline.matches(baseline, tolerance: Self.sameTableTolerance)
    }

    /// `read` is our own latest write and not the baseline we hold: a failed landing, or the old curve whose
    /// replacement a re-base adopted but could not write yet. It never becomes a baseline (§4.5 invariant 5).
    func isOwnStaleWrite(_ read: GammaTable) -> Bool {
        baseline != nil && !lastWriteIsBaseline && isOurs(read)
    }

    /// The re-base's poll; false once a shield, removal or stop cancelled it.
    func rebaseSleep() async -> Bool {
        do { try await deps.time.sleep(for: EngineTiming.gatePollInterval) } catch { return false }
        return isRebasing
    }
}
