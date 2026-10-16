// OverbrightBoost/Engine/DisplayController+Arming.swift — capture, idle headroom, the pre-held test, the ladder and
// the gate loop. ARCHITECTURE.md §4.3 (idle → arming/gating, arming and gating rows, wake backoff), §4.7 (ladder, make
// before break, cache), §4.8 (capture), D6. MainActor.
import Foundation
import OverbrightCore
import OverbrightPolicy

extension DisplayController {
    /// Potential at or below `1 + this` means "no EDR at all": stop escalating (§4.3).
    static let potentialEpsilon = 0.01
    /// Gate samples kept (≥ the stability window at 10 Hz).
    static let maximumSamples = 64

    // MARK: Starting an arm

    /// idle or dimmed → boost: capture the baseline (from idle), read H0, decide the path, show the first rung, gate.
    func beginArm() {
        generation += 1
        let stamp = generation
        armSlot.cancel(); burstSlot.cancel(); driftSlot.cancel(); lingerSlot.cancel(); rebaseSlot.cancel()
        if phase == .idle, mechanism == .table {
            guard captureBaseline() else { return }
        }
        if appliedGain < 1 - TableWriter.neutralTolerance {
            // The dim factor ramps back to 1 while arming (§4.3 dimmed → boost).
            startRamp(to: 1, origin: .automatic, finalPhase: nil, setsRampingPhase: false)
        } else {
            rampSlot.cancel()
        }
        backoff = nil
        rungs = plannedRungs(backoff: false)
        currentRung = nil
        phase = .arming(rung: rungs.first?.number ?? 0)
        armSlot.run { [weak self] in await self?.runArm(stamp) }
    }

    /// H0 (three reads 100 ms apart, the maximum), the pre-held test, the first rung, then the gate.
    func runArm(_ stamp: UInt64) async {
        var reads: [Double] = []
        for index in 0..<EngineTiming.baselineReads {
            if index > 0 { guard await sleep(EngineTiming.baselineReadInterval, stamp) else { return } }
            guard isCurrent(stamp) else { return }
            reads.append(takeReading()?.current ?? 1)
        }
        idleHeadroom = reads.max() ?? 1
        if let potential = lastReading?.potential, potential <= 1 + Self.potentialEpsilon {
            fail(.headroomNeverArrived)
            return
        }
        armedPreHeld = GateEvaluator.isPreHeld(idleReads: reads, gain: targetGain ?? 1,
                                               ownSurface: deps.ownEDRSurfaces.isHeld(key))
        preHeldHeadroom = armedPreHeld ? idleHeadroom : nil
        gatePath = armedPreHeld ? .preHeld : .normal
        cachedRungFailedThisArm = false
        belowNeededSince = nil
        deps.journal.record(armedPreHeld ? "gate.preHeld" : "arm.start", display: key,
                            values: ["h0": idleHeadroom], time: deps.time)
        if mechanism == .overlay {
            guard showOverlay(stamp) else { return }
        } else {
            guard await presentRung(from: 0, stamp) else { return }
        }
        await gateLoop(stamp)
    }

    /// The rungs of this arm (§4.7): from the cached rung, the override, OLED black only, the backoff's single rung.
    func plannedRungs(backoff: Bool) -> [LadderRung] {
        let cached = deps.cache.record(for: key, osBuild: deps.machine.osBuild)?.rung
        let available = Set(TriggerStrategy.allCases.filter { deps.triggers.isAvailable($0) })
        return LadderPlanner.rungs(for: facts, isOLED: parameters.isOLED, os: deps.machine.osMajor, cache: cached,
                                   override: parameters.triggerOverride, backoff: backoff, available: available)
    }

    // MARK: Capture (§4.8)

    /// Reads the table and keeps it as the baseline when `BaselineRules` allows it. A scaled or invalid read does not
    /// arm: with `failsOnReject` the display fails as `foreignTableAtLaunch` (or `attributedDrift` once the conflict
    /// probe names an app).
    @discardableResult
    func captureBaseline(failsOnReject: Bool = true) -> Bool {
        let read: GammaTable
        do {
            read = try deps.gamma.read(ref.id)
        } catch {
            deps.journal.record("baseline.readFailed", display: key, time: deps.time, category: .gamma)
            return false
        }
        let expected = deps.gamma.profileBase(of: ref.id, count: read.count)
        switch BaselineRules.capture(read, expectedBase: expected, previous: baseline) {
        case .accept(let foreign):
            baseline = read
            if foreign { deps.journal.record("baseline.foreign", display: key, time: deps.time) }
            return true
        case .reject(let tableClass):
            var values: [String: Double] = [:]
            if case .scaled(let ratio?) = tableClass { values["ratio"] = ratio }
            deps.journal.record("baseline.rejected", display: key, values: values, time: deps.time)
            if failsOnReject { failForForeignTable() }
            return false
        }
    }

    /// `failed(foreignTableAtLaunch)` now; `failed(attributedDrift(app))` if the conflict probe names a writer.
    func failForForeignTable() {
        fail(.foreignTableAtLaunch)
        let stamp = generation
        checkSlot.run { [weak self] in
            guard let self, let app = await self.deps.conflicts.attributeDrift(), self.isCurrent(stamp),
                  self.trip == .foreignTableAtLaunch else { return }
            self.trip = .attributedDrift(app)
            self.phase = .failed(.attributedDrift(app))
            self.notify(needsReduction: true)
        }
    }

    // MARK: Rungs (§4.7)

    /// Shows the first rung from `position` that presents (make before break); in a wake or unlock backoff the same
    /// rung is retried after each backoff step instead of escalating. False (and failed) when nothing presents.
    func presentRung(from position: Int, _ stamp: UInt64) async -> Bool {
        var position = position
        while position < rungs.count {
            let rung = rungs[position]
            if await present(rung, stamp) {
                rungPosition = position
                currentRung = rung
                if position > 0 {
                    deps.journal.record("rung.escalated", display: key, values: ["rung": Double(rung.number)],
                                        time: deps.time, category: .trigger)
                }
                restartGate()
                return true
            }
            guard isCurrent(stamp) else { return false }
            deps.journal.record("rung.presentFailed", display: key, values: ["rung": Double(rung.number)],
                                time: deps.time, category: .trigger)
            noteRungFailure(rung)
            if let current = backoff {
                guard current.step < EngineTiming.wakeBackoff.count else { break }
                backoff = (current.kind, current.step + 1)
                guard await sleep(EngineTiming.wakeBackoff[current.step], stamp) else { return false }
                continue
            }
            position += 1
        }
        guard isCurrent(stamp) else { return false }
        fail(.headroomNeverArrived)
        return false
    }

    /// Makes and presents one rung; on success it replaces the previous trigger, which is removed only now.
    func present(_ rung: LadderRung, _ stamp: UInt64) async -> Bool {
        let request = LadderPlanner.request(for: rung, facts: facts, potential: lastReading?.potential ?? 1)
        let handle: any TriggerHandle
        do {
            handle = try deps.triggers.makeTrigger(request, on: ref)
        } catch {
            return false
        }
        handle.onOcclusionChange = { [weak self, weak handle] occluded in
            guard let self, let handle else { return }
            self.windowOcclusionChanged(occluded, isCurrentWindow: handle === self.trigger)
        }
        handle.onScreenChange = { [weak self, weak handle] displayID in
            guard let self, let handle else { return }
            self.windowMoved(to: displayID, isCurrentWindow: handle === self.trigger)
        }
        let presented = await handle.present(rung.pixel)
        guard presented, isCurrent(stamp) else {
            handle.remove()
            return false
        }
        let previous = trigger
        trigger = handle
        previous?.remove()
        return true
    }

    /// Compatibility mode: the overlay is its own EDR request (shown at factor 1 with `G ÷ 0.97`, §7.5).
    func showOverlay(_ stamp: UInt64) -> Bool {
        do {
            let handle = try overlay ?? deps.triggers.makeOverlay(on: ref)
            handle.onOcclusionChange = { [weak self, weak handle] occluded in
                guard let self, let handle else { return }
                self.windowOcclusionChanged(occluded, isCurrentWindow: handle === self.overlay)
            }
            handle.onScreenChange = { [weak self, weak handle] displayID in
                guard let self, let handle else { return }
                self.windowMoved(to: displayID, isCurrentWindow: handle === self.overlay)
            }
            try handle.setFactor(max(appliedFactor, 1), headroomRequest: overlayRequest)
            overlay = handle
            currentRung = nil
            restartGate()
            return true
        } catch {
            deps.journal.record("overlay.failed", display: key, time: deps.time, category: .trigger)
            if isCurrent(stamp) { fail(.headroomNeverArrived) }
            return false
        }
    }

    /// The headroom the overlay asks for: the target gain ÷ 0.97 while boosting, else none.
    var overlayRequest: Double { targetGain.map { $0 / FactorMath.headroomMargin } ?? 1 }

    /// A fresh gate on the current rung: the rung timeout restarts, samples are dropped.
    func restartGate() {
        let now = deps.time.now
        presentedAt = now
        movedAt = gatePath == .preHeld ? now : nil
        samples = []
        let number = currentRung?.number ?? 0
        phase = gatePath == .preHeld ? .gating(rung: number) : .arming(rung: number)
    }

    /// Counts a failure of the cached rung once per normal arm, outside the wake/unlock quarantine (§4.7).
    func noteRungFailure(_ rung: LadderRung) {
        guard !armedPreHeld, !cachedRungFailedThisArm else { return }
        let quarantined = quarantineUntil.map { deps.time.now < $0 } ?? false
        guard deps.cache.record(for: key, osBuild: deps.machine.osBuild)?.rung == rung.number else { return }
        cachedRungFailedThisArm = true
        deps.cache.recordFailure(rung: rung.number, for: key, osBuild: deps.machine.osBuild, quarantined: quarantined)
    }

    // MARK: The gate (D6)

    /// Polls headroom at 10 Hz until the gate is ready (→ ramp), escalating on rung and gate timeouts.
    func gateLoop(_ stamp: UInt64) async {
        while isCurrent(stamp) {
            guard await sleep(EngineTiming.gatePollInterval, stamp) else { return }
            let now = deps.time.now
            let reading = takeReading()
            let headroom = reading?.current ?? 1
            if let potential = reading?.potential, potential <= 1 + Self.potentialEpsilon {
                fail(.headroomNeverArrived)
                return
            }
            samples.append(GateEvaluator.Sample(time: now, headroom: headroom))
            if samples.count > Self.maximumSamples { samples.removeFirst(samples.count - Self.maximumSamples) }
            flicker.noteHeadroom(headroom)
            if appliedGain > 1, appliedGain > FactorMath.lowerThreshold * headroom { lowerForSafety() }
            if parameters.isHDRSuppressed {
                // Keep the rung and stop escalating: the timeouts pause (§4.3).
                presentedAt = presentedAt.map { $0 + EngineTiming.gatePollInterval }
                movedAt = movedAt.map { $0 + EngineTiming.gatePollInterval }
            }
            guard let presentedAt else { continue }
            switch GateEvaluator.evaluate(path: gatePath, samples: samples, idle: idleHeadroom,
                                          presentedAt: presentedAt, movedAt: movedAt, now: now) {
            case .waiting:
                continue
            case .moved:
                movedAt = now
                phase = .gating(rung: currentRung?.number ?? 0)
                deps.journal.record("gate.moved", display: key, values: ["headroom": headroom], time: deps.time)
            case .ready(let ready):
                becomeReady(at: ready)
                return
            case .rungTimedOut, .gateTimedOut:
                guard await rungFailed(stamp) else { return }
            }
        }
    }

    /// A rung or gate timeout: in a backoff, wait and retry the same rung; otherwise escalate (make before break).
    func rungFailed(_ stamp: UInt64) async -> Bool {
        deps.journal.record("rung.timedOut", display: key, values: ["rung": Double(currentRung?.number ?? 0)],
                            time: deps.time, category: .trigger)
        if let rung = currentRung { noteRungFailure(rung) }
        if let current = backoff {
            guard current.step < EngineTiming.wakeBackoff.count else {
                fail(.headroomNeverArrived)
                return false
            }
            backoff = (current.kind, current.step + 1)
            guard await sleep(EngineTiming.wakeBackoff[current.step], stamp) else { return false }
            trigger?.represent()
            overlay?.represent()
            restartGate()
            return true
        }
        guard mechanism == .table else {
            fail(.headroomNeverArrived)
            return false
        }
        return await presentRung(from: rungPosition + 1, stamp)
    }

    /// Ready: cache the rung (normal path only), learn the lowest ready headroom, stamp the epoch, ramp to liveCap.
    func becomeReady(at headroom: Double) {
        deps.journal.record("gate.ready", display: key,
                            values: ["headroom": headroom, "rung": Double(currentRung?.number ?? 0)], time: deps.time)
        if !armedPreHeld, let rung = currentRung {
            deps.cache.recordWin(rung: rung.number, for: key, osBuild: deps.machine.osBuild)
        }
        deps.cache.learnReadyHeadroom(headroom, for: key, osBuild: deps.machine.osBuild)
        backoff = nil
        epochStamp = deps.ledger.hangEpoch
        guard let gain = targetGain else { return }
        startRamp(to: allowedGain(for: gain) ?? 1, origin: .automatic, finalPhase: .boosted)
    }

    // MARK: Re-gating

    /// Re-gates from the cached rung (§4.3 suspended → gating/arming): the kept trigger is re-presented, else the
    /// cached rung is armed; wake and unlock retry that rung only, with backoff.
    func regate(backoff kind: ResumeKind?) {
        generation += 1
        let stamp = generation
        armSlot.cancel(); burstSlot.cancel(); driftSlot.cancel(); lingerSlot.cancel(); rebaseSlot.cancel()
        backoff = kind.map { ($0, 0) }
        if kind != nil { quarantineUntil = deps.time.now + EngineTiming.escalationQuarantine }
        armedPreHeld = false
        preHeldHeadroom = nil
        gatePath = .normal
        cachedRungFailedThisArm = false
        if mechanism == .overlay {
            overlay?.represent()
            armSlot.run { [weak self] in
                guard let self, self.showOverlay(stamp) else { return }
                await self.gateLoop(stamp)
            }
            return
        }
        if trigger != nil, let rung = currentRung {
            trigger?.represent()
            rungs = backoff != nil ? [rung] : [rung] + plannedRungs(backoff: false).filter { $0.number > rung.number }
            rungPosition = 0
            restartGate()
            armSlot.run { [weak self] in await self?.gateLoop(stamp) }
        } else {
            rungs = plannedRungs(backoff: backoff != nil)
            phase = .arming(rung: rungs.first?.number ?? 0)
            armSlot.run { [weak self] in
                guard let self, await self.presentRung(from: 0, stamp) else { return }
                await self.gateLoop(stamp)
            }
        }
    }

    /// Boosted on a pre-held arm, and the other source left: escalate from the current rung with H0 := H (§4.3).
    func escalateAfterHeldSourceLeft(headroom: Double) {
        generation += 1
        let stamp = generation
        burstSlot.cancel(); driftSlot.cancel()
        deps.journal.record("gate.heldSourceLeft", display: key, values: ["headroom": headroom], time: deps.time)
        idleHeadroom = headroom
        armedPreHeld = false
        preHeldHeadroom = nil
        gatePath = .normal
        belowNeededSince = nil
        let next = rungPosition + 1
        guard next < rungs.count, mechanism == .table else {
            fail(.headroomNeverArrived)
            return
        }
        phase = .arming(rung: rungs[next].number)
        armSlot.run { [weak self] in
            guard let self, await self.presentRung(from: next, stamp) else { return }
            await self.gateLoop(stamp)
        }
    }
}
