// OverbrightBoost/Engine/DisplayController+Drift.swift — the 2 s drift check while scaled or dimmed, the check 50 ms
// after any app terminated, repairs, adoptions and their budgets. ARCHITECTURE.md §4.3 (drift row), §4.4, §4.5
// invariant 12 (every reapply ramps and journals its cause), §4.8, §5.8 (repair budget), D9. MainActor.
import Foundation
import OverbrightCore
import OverbrightPolicy

extension DisplayController {
    /// Why a target is reapplied (journalled with `drift.reapplied` and `baseline.adopted`).
    enum ReapplyCause: Int, Hashable, Sendable {
        case reset = 1, adoption, appTerminated, reconfiguration, colorProfile, accessibility, foreignWriter,
             unexplainedAdoption
    }

    /// What started a drift check.
    enum DriftTrigger: Hashable, Sendable { case periodic, appTerminated }

    /// The 2 s check while boosted or dimmed (the only periodic work of a steady display, §4.2).
    func startDriftWatch() {
        let stamp = generation
        driftSlot.run { [weak self] in
            while true {
                guard let self, await self.sleep(EngineTiming.watchdogInterval, stamp) else { return }
                await self.driftTick(stamp, trigger: .periodic)
            }
        }
    }

    /// Any app terminated: WindowServer resets every display when a table writer dies, so check after 50 ms; the
    /// trip attributed to that app clears (§4.3, §4.8).
    func appTerminated(processID: Int32) {
        if case .failed(.attributedDrift(let app)) = phase, app.processID == processID {
            clearTrip()
            return
        }
        guard phase == .boosted || phase == .dimmed else { return }
        let stamp = generation
        checkSlot.run { [weak self] in
            guard let self, await self.sleep(EngineTiming.appTerminationCheckDelay, stamp) else { return }
            await self.driftTick(stamp, trigger: .appTerminated)
        }
    }

    /// Screen parameters changed (they also change when H changes): the headroom check, and a retry of a display that
    /// never got headroom when its potential changed (§4.3).
    func headroomEvent() {
        switch phase {
        case .boosted:
            headroomCheck()
        case .failed(.headroomNeverArrived):
            if let reading = takeReading(), let old = potentialAtFailure, abs(reading.potential - old) > 0.01 {
                clearTrip()
            }
        default:
            break
        }
    }

    /// One drift check: hang epoch, read-back classification (§4.8 order), then the headroom check.
    func driftTick(_ stamp: UInt64, trigger: DriftTrigger) async {
        guard isCurrent(stamp), phase == .boosted || phase == .dimmed, !isRebasing else { return }
        if isScaledOrDimmed, epochStamp != deps.ledger.hangEpoch {
            recoverFromHang()
            return
        }
        if mechanism == .table, isScaledOrDimmed, let baseline, let read = try? deps.gamma.read(ref.id) {
            // E″ (a ColorSync profile copy, `vcgt` parse and resample: half the tick on the real port) is computed only
            // when the verdict consults it, and the same fresh value goes to the adoption rules (§4.8 step 1).
            var profile: GammaTable?
            let verdict = DriftCheck.evaluate(read: read, baseline: baseline, factor: appliedFactor, profileBase: {
                let base = deps.gamma.profileBase(of: ref.id, count: baseline.count)
                profile = base
                return base
            })
            switch verdict {
            case .fine, .indistinguishable:
                break
            case .reset:
                await handleReset(stamp, cause: trigger == .appTerminated ? .appTerminated : .reset)
                return
            case .adoptionCandidate:
                // A candidate is only ever found against a computed E″.
                guard let profile else { break }
                await handleAdoptionCandidate(read: read, profile: profile, stamp)
                return
            case .foreign:
                await handleForeignWriter(stamp)
                return
            }
        }
        if phase == .boosted { headroomCheck() }
    }

    /// The system put our baseline back: count a repair, reapply with a ramp after 250 ms.
    func handleReset(_ stamp: UInt64, cause: ReapplyCause) async {
        deps.journal.record("watchdog.reset", display: key, time: deps.time)
        appliedGain = 1
        appliedFactor = 1
        if countRepair() {
            fail(.repairBudgetExceeded)
            return
        }
        guard await sleep(EngineTiming.resetReapplyDelay, stamp) else { return }
        reapply(cause)
    }

    /// The table matches a profile base that changed without an event we saw: a base change only within 2 s of a
    /// ColorSync, reconfiguration or accessibility event and after two identical reads; otherwise a repair and a
    /// non-user reversal, and more than two such in 60 s trip the display as a foreign writer.
    func handleAdoptionCandidate(read: GammaTable, profile: GammaTable, _ stamp: UInt64) async {
        let now = deps.time.now
        let explained = lastBaseEventAt.map { now - $0 <= EngineTiming.adoptionWindow } ?? false
        if explained {
            guard await sleep(EngineTiming.gatePollInterval, stamp), let again = try? deps.gamma.read(ref.id),
                  again.matches(read, tolerance: Self.sameTableTolerance),
                  case .accept = BaselineRules.capture(read, expectedBase: profile, previous: baseline) else { return }
            baseline = read
            expectedBase = profile
            if deps.ledger.isMarked(key) { deps.ledger.markScaled(ref, baseline: read) }
            deps.journal.record("baseline.adopted", display: key, values: ["cause": Double(ReapplyCause.adoption.rawValue)],
                                time: deps.time)
            appliedGain = 1
            appliedFactor = 1
            reapply(.adoption)
            return
        }
        deps.journal.record("adoption.unexplained", display: key, time: deps.time)
        unexplainedAdoptions.append(now)
        unexplainedAdoptions.removeAll { now - $0 > EngineTiming.adoptionBudgetWindow }
        if flicker.recordReversal(at: now) {
            fail(.oscillation)
            return
        }
        if unexplainedAdoptions.count > EngineTiming.adoptionBudget {
            let app = await deps.conflicts.attributeDrift()
            guard isCurrent(stamp) else { return }
            fail(app.map { .attributedDrift($0) } ?? .repairBudgetExceeded)
            return
        }
        if countRepair() {
            fail(.repairBudgetExceeded)
            return
        }
        appliedGain = 1
        appliedFactor = 1
        reapply(.unexplainedAdoption)
    }

    /// Another writer: count a repair and attribute it. An S3 app trips the display at its first drift; the repair
    /// budget trips every other case (even after Continue Anyway); otherwise reapply with a ramp.
    func handleForeignWriter(_ stamp: UInt64) async {
        deps.journal.record("watchdog.drift", display: key, time: deps.time)
        let exceeded = countRepair()
        let app = await deps.conflicts.attributeDrift()
        guard isCurrent(stamp) else { return }
        if let app, app.severity == .conditional {
            fail(.attributedDrift(app))
            return
        }
        if exceeded {
            fail(app.map { .attributedDrift($0) } ?? .repairBudgetExceeded)
            return
        }
        guard await sleep(EngineTiming.resetReapplyDelay, stamp) else { return }
        appliedGain = 1
        appliedFactor = 1
        reapply(.foreignWriter)
    }

    /// Records a repair; true once `repairBudget` repairs fall within `repairWindow`.
    func countRepair() -> Bool {
        let now = deps.time.now
        repairs.append(now)
        repairs.removeAll { now - $0 > EngineTiming.repairWindow }
        return repairs.count >= EngineTiming.repairBudget
    }

    /// Reapplies the current target with a ramp (§4.5 invariant 12) and journals why. While arming or gating only a
    /// leftover dim ramps back to 1 (the gate ramps to the boost); idle, failed and suspended displays have nothing on
    /// screen to reapply.
    func reapply(_ cause: ReapplyCause) {
        deps.journal.record("drift.reapplied", display: key, values: ["cause": Double(cause.rawValue)], time: deps.time)
        switch phase {
        case .arming, .gating:
            if appliedGain < 1 - TableWriter.neutralTolerance {
                startRamp(to: 1, origin: .automatic, finalPhase: nil, setsRampingPhase: false)
            }
            return
        case .idle, .failed, .suspended:
            return
        case .disarming:
            startRamp(to: 1, kind: rampKind, origin: .automatic, finalPhase: .idle, removesWindowsAtEnd: true,
                      setsRampingPhase: false)
            return
        case .ramping, .boosted, .dimmed:
            break
        }
        switch target {
        case .boost(let gain):
            startRamp(to: allowedGain(for: gain) ?? 1, origin: .automatic, finalPhase: .boosted)
        case .dim(let light):
            startRamp(to: light, origin: .automatic, finalPhase: .dimmed, removesWindowsAtEnd: true)
        case .neutral:
            disarm(kind: rampKind)
        }
    }
}
