// OverbrightBoost/Engine/DisplayController+Rebase.swift — reconfiguration passes, ColorSync and accessibility events: the
// expected base recomputed, WindowServer's table awaited and adopted, the ledger updated, the target reapplied.
// ARCHITECTURE.md §4.3 (reconfiguration rows), §4.8 (event-driven re-base), D26. MainActor.
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
    /// and reapplies the target with a ramp. It runs across target changes (its reapply uses the latest target) and
    /// compares every read with our latest write, so our own ramps and safety drops are never mistaken for
    /// WindowServer's table; only shields, removal and stops cancel it.
    func rebase(cause: ReapplyCause) {
        guard mechanism == .table, let old = baseline else {
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
        guard let first = read, await rebaseSleep(), let second = try? deps.gamma.read(ref.id) else {
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
        if let adopted {
            baseline = adopted
            if deps.ledger.isMarked(key) { deps.ledger.markScaled(ref, baseline: adopted) }
            deps.journal.record("baseline.adopted", display: key, values: ["cause": Double(cause.rawValue)],
                                time: deps.time)
        }
        if !keptOurs {
            // What is on screen now is WindowServer's table, not our scaling.
            appliedGain = 1
            appliedFactor = 1
        } else if adopted != nil, isScaledOrDimmed {
            // WindowServer kept our table over the old curve: the same light on the new base is one write (the level
            // does not change, only the curve under it).
            _ = writeGain(appliedGain)
        }
        isRebasing = false
        reapply(cause)
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
