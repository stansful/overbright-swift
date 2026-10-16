// OverbrightBoost/Engine/DisplayController+Rebase.swift — reconfiguration passes, ColorSync and accessibility events: the
// expected base recomputed, WindowServer's table awaited and adopted, the ledger updated, the target reapplied, in every
// phase that holds a baseline. ARCHITECTURE.md §4.3 (reconfiguration rows: "whether or not the display is scaled"),
// §4.8 (event-driven re-base), D26. MainActor.
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

    /// The debounced after-phase pass: re-place windows, retry `headroomNeverArrived`, recheck a foreign table, resume
    /// a display whose window moved, and re-base every display that holds a baseline.
    func reconfigured(_ newFacts: DisplayFacts) {
        updateFacts(newFacts)
        trigger?.represent()
        overlay?.represent()
        switch phase {
        case .failed(.headroomNeverArrived):
            lastBaseEventAt = deps.time.now
            clearTrip()
        case .failed(.foreignTableAtLaunch), .failed(.attributedDrift):
            lastBaseEventAt = deps.time.now
            if case .failed(.foreignTableAtLaunch) = phase, tableMatchesBase() { clearTrip() }
        case .suspended(.reconfiguring):
            noteBaseEvent(.reconfiguration)
            resume()                                                      // which restarts the re-base where it lands
        default:
            noteBaseEvent(.reconfiguration)
        }
    }

    /// A ColorSync profile change or a change of the accessibility display options (the same re-base, §4.8).
    func baseEventOccurred(_ cause: ReapplyCause) {
        switch phase {
        case .failed(.foreignTableAtLaunch):
            lastBaseEventAt = deps.time.now
            if tableMatchesBase() { clearTrip() }
        default:
            noteBaseEvent(cause)
        }
    }

    /// A base event: every phase that holds a baseline (all but idle and failed, which capture afresh at the next
    /// arm) re-bases, suspended, arming, gating and disarming included. Until a re-base has judged the table, the
    /// event stays pending (`pendingRebase`).
    func noteBaseEvent(_ cause: ReapplyCause) {
        lastBaseEventAt = deps.time.now
        guard isActive else { return }
        pendingRebase = cause
        rebase(cause: cause)
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

    /// Recomputes the expected base, waits until WindowServer applied the new table (at most 1 s), adopts it after two
    /// identical reads (or the new profile base when WindowServer kept our table), updates the ledger in the same step
    /// and reapplies the target with a ramp. It runs across target changes (its reapply uses the latest target) and
    /// compares every read with our latest write, so our own ramps and safety drops are never mistaken for
    /// WindowServer's table; shields, removal and stops cancel it (a pending event then restarts or settles it).
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
        } else if keptOurs, !expected.matches(old, tolerance: EngineTiming.driftTolerance),
                  case .accept = BaselineRules.capture(expected, expectedBase: expected, previous: old) {
            adopted = expected
        }
        pendingRebase = nil
        if let adopted { adopt(adopted, cause: cause) }
        if !keptOurs {
            // What is on screen now is WindowServer's table, not our scaling.
            resetApplied()
        } else if let adopted {
            if isScaledOrDimmed {
                // WindowServer kept our table over the old curve: the same light on the new base is one write (the
                // level does not change, only the curve under it).
                _ = writeGain(appliedGain)
            } else {
                writeAdoptedBase(adopted)                                 // our old baseline is still on screen
            }
        }
        isRebasing = false
        reapply(cause)
    }

    /// The display reached idle or failed while a base event was unjudged (the end of a disarm, Back to Standard, a
    /// stop or a trip cut its re-base short; the last write may have been the old baseline): judge it now in one read.
    /// Our own baseline write still on screen is replaced by the new profile base; WindowServer's table is adopted as
    /// it is. Without this, "off" would leave the old curve after a profile, preset or HDR change (§4.8).
    func settlePendingRebase() {
        guard let cause = pendingRebase else { return }
        pendingRebase = nil
        stopRebase()
        guard mechanism == .table, let old = baseline, let read = try? deps.gamma.read(ref.id) else { return }
        let expected = deps.gamma.profileBase(of: ref.id, count: old.count)
        if isOurs(read) {
            guard !lastWriteIsScaled, !isScaledOrDimmed, !expected.matches(old, tolerance: EngineTiming.driftTolerance),
                  case .accept = BaselineRules.capture(expected, expectedBase: expected, previous: old) else { return }
            adopt(expected, cause: cause)
            writeAdoptedBase(expected)
        } else if read.matches(expected, tolerance: EngineTiming.driftTolerance),
                  case .accept = BaselineRules.capture(read, expectedBase: expected, previous: old) {
            adopt(read, cause: cause)
        }
    }

    /// `table` becomes the baseline, and the ledger's baseline in the same step (the hang watchdog never restores the
    /// old curve).
    func adopt(_ table: GammaTable, cause: ReapplyCause) {
        baseline = table
        if deps.ledger.isMarked(key) { deps.ledger.markScaled(ref, baseline: table) }
        deps.journal.record("baseline.adopted", display: key, values: ["cause": Double(cause.rawValue)],
                            time: deps.time)
    }

    /// Writes the adopted base over our own old baseline write (one baseline write; only after we wrote this display,
    /// and never off the console, D27).
    func writeAdoptedBase(_ table: GammaTable) {
        guard lastWrite != nil, !isOffConsole, parameters.isSessionActive else { return }
        do {
            try deps.writer.writeBaseline(table, to: ref)
            lastWrite = (table, 1)
        } catch {
            deps.journal.record("baseline.writeFailed", display: key, time: deps.time, category: .gamma)
        }
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

    /// The re-base's poll; false once a shield, removal or stop cancelled it.
    func rebaseSleep() async -> Bool {
        do { try await deps.time.sleep(for: EngineTiming.gatePollInterval) } catch { return false }
        return isRebasing
    }
}
