// OverbrightBoost/Writer/TableWriter.swift — the interlock: the only code that turns a light gain into a table and
// calls `GammaPort.write`. ARCHITECTURE.md §4.1, §4.5 invariants 1, 3, 9, §4.6, §5.4; D5, D24.
// Seeded by WP0a with the fixed signatures (§10.0); body by WP4.
// Thread: nonisolated and `Sendable`. The main actor writes through `write(_:to:reading:epoch:)` and
// `writeBaseline(_:to:)`; the hang watchdog's queue and the signal queue call only `writeBaselines(fromLedger:)`. Every
// write holds the ledger lock across the WindowServer call, so writes land in lock order and the hang epoch is checked
// in the same critical section as the write it guards (§4.6).
import Foundation
import OverbrightCore
import OverbrightPolicy

/// Writes tables on three paths: `write(_:to:reading:epoch:)` (main: `GainCeiling.liveCap`, a reading of the same
/// display at most 150 ms old, the current hang epoch), `writeCalibrationFactor(_:of:to:reading:maxFactor:epoch:)`
/// (the session's bound, a fresh reading, the hang epoch), and the nonisolated `writeBaselines(fromLedger:)` of the hang
/// watchdog and the signal queue. Lint test
/// `onlyTableWriterAndRescueWrite` keeps every other caller away from `GammaPort.write`.
public nonisolated final class TableWriter: Sendable {
    /// What one scaled or dimmed write asks for: the light gain and the inputs of `GainCeiling.liveCap`.
    public struct Request: Hashable, Sendable {
        /// The light gain wanted (> 1 boosts, < 1 dims, 1 is the baseline).
        public var gain: Double
        /// The effective transfer domain (`TransferDomainResolver`).
        public var domain: TransferDomain
        /// The captured baseline the factor multiplies; recorded in the ledger before the write.
        public var baseline: GammaTable
        /// The display's facts (Safe bound, panel peak).
        public var facts: DisplayFacts
        /// Safe or Peak.
        public var capMode: CapMode
        /// OLED (by minimum luminance or the user's override).
        public var isOLED: Bool
        /// A trusted SDR white, if any.
        public var sdrWhite: SDRWhiteEstimate?
        /// "Add extra brightness only near full brightness".
        public var taper: Bool
        /// The lowest ready headroom seen (the taper's reference), if known.
        public var fullBrightnessHeadroom: Double?

        /// A request.
        public init(gain: Double, domain: TransferDomain, baseline: GammaTable, facts: DisplayFacts, capMode: CapMode,
                    isOLED: Bool, sdrWhite: SDRWhiteEstimate?, taper: Bool, fullBrightnessHeadroom: Double?) {
            self.gain = gain; self.domain = domain; self.baseline = baseline; self.facts = facts
            self.capMode = capMode; self.isOLED = isOLED; self.sdrWhite = sdrWhite; self.taper = taper
            self.fullBrightnessHeadroom = fullBrightnessHeadroom
        }
    }

    /// What a write applied.
    public struct Outcome: Hashable, Sendable {
        /// The light gain on screen after the write (≤ the request, clamped by the interlock).
        public var appliedGain: Double
        /// The table factor written.
        public var factor: Double
        /// The live term that bound (`nearFullBrightnessOnly`, `safeLimit` or `headroom`), if any.
        public var limit: LimitReason?
        /// An outcome.
        public init(appliedGain: Double, factor: Double, limit: LimitReason?) {
            self.appliedGain = appliedGain; self.factor = factor; self.limit = limit
        }
    }

    /// A light gain this close to 1 is the baseline (no write of a scaled table).
    public static let neutralTolerance = 1e-6
    /// A boost whose clamped gain stays below this writes the baseline instead (a no-op boost, §5.4 step 3) …
    public static let minimumBoostGain = 1.005
    /// … and so does any boost while the reading's headroom is below this.
    public static let minimumBoostHeadroom = 1.03

    /// The only port that writes tables.
    public let gamma: any GammaPort
    /// Baselines and the hang epoch, locked across every write.
    public let ledger: SafetyLedger
    /// Reading ages are measured with it.
    public let time: any TimeSource
    /// `interlock.clamped`, `interlock.refusedStaleEpoch`, …
    public let journal: any DiagnosticsJournal

    /// A writer over `gamma`, recording baselines in `ledger`.
    public init(gamma: any GammaPort, ledger: SafetyLedger, time: any TimeSource, journal: any DiagnosticsJournal) {
        self.gamma = gamma; self.ledger = ledger; self.time = time; self.journal = journal
    }

    // MARK: The main path

    /// The main path: applies `request` to `display` as far as the interlock allows, with `reading` (same display, at
    /// most `EngineTiming.readingMaxAge` old) and the controller's `epoch` stamp (must equal the ledger's hang epoch).
    /// Throws `GammaError.writeRefused` on a stale epoch or a foreign or stale reading. A gain of 1 writes the baseline;
    /// a dim (gain < 1) needs no reading but respects the epoch.
    @discardableResult
    public func write(_ request: Request, to display: DisplayRef, reading: HeadroomReading?,
                      epoch: UInt64) throws -> Outcome {
        let gain = request.gain.isFinite ? max(request.gain, LevelMapping.minimumDimLight) : 1
        if abs(gain - 1) < Self.neutralTolerance {
            try writeBaseline(request.baseline, to: display)
            return Outcome(appliedGain: 1, factor: 1, limit: nil)
        }
        if gain < 1 {
            let factor = FactorMath.tableFactor(forLightGain: gain, domain: request.domain)
            try writeScaled(request.baseline, factor: factor, to: display, epoch: epoch)
            return Outcome(appliedGain: gain, factor: factor, limit: nil)
        }
        let cap = try interlock(request, to: display, reading: reading)
        if cap.appliedGain < Self.minimumBoostGain || cap.headroom < Self.minimumBoostHeadroom {
            try writeBaseline(request.baseline, to: display)
            return Outcome(appliedGain: 1, factor: 1, limit: cap.limit ?? .headroom)
        }
        let factor = FactorMath.tableFactor(forLightGain: cap.appliedGain, domain: request.domain)
        try writeScaled(request.baseline, factor: factor, to: display, epoch: epoch)
        return Outcome(appliedGain: cap.appliedGain, factor: factor, limit: cap.limit)
    }

    /// The gain the interlock allows for `request` with `reading`, without writing (the Compatibility-mode overlay
    /// applies the same ceiling to its factor, and the engine uses it to plan a ramp's end). Throws
    /// `GammaError.writeRefused` for a missing, foreign or stale reading.
    public func allowedGain(for request: Request, on display: DisplayRef, reading: HeadroomReading?) throws -> Outcome {
        guard request.gain > 1 else {
            return Outcome(appliedGain: max(request.gain, 0), factor: request.gain, limit: nil)
        }
        let cap = try interlock(request, to: display, reading: reading, journals: false)
        let applied = cap.appliedGain < Self.minimumBoostGain || cap.headroom < Self.minimumBoostHeadroom
            ? 1 : cap.appliedGain
        return Outcome(appliedGain: applied, factor: FactorMath.tableFactor(forLightGain: applied, domain: request.domain),
                       limit: cap.limit ?? (applied < request.gain - Self.neutralTolerance ? .headroom : nil))
    }

    /// Writes `baseline` as-is and forgets the display in the ledger once the write returned (§4.5 invariant 9). The
    /// un-scaling path of every stop, suspend and shield; never refused by the epoch (an un-scale is always safe).
    public func writeBaseline(_ baseline: GammaTable, to display: DisplayRef) throws {
        try ledger.withLock { state in
            try gamma.write(baseline, to: display.id)
            state.entries[display.key] = nil
        }
    }

    // MARK: Calibration and the safety queues

    /// Calibration: writes `factor` × `baseline`, refusing a factor above `maxFactor` or the calibration ceiling of the
    /// reading (or above 1 without extra range), a reading that is not a fresh one of the same display, and a stale hang
    /// epoch. The sweep is meant to pass `0.97 × H`: it looks for where the 0.95 patch clips (at 1.15 × the linear
    /// prediction it reaches about 1.29 × H; an encoded table clips far below, and the display clips the light at H
    /// either way), so the boost interlock's `0.97 × H` does not apply here (§5.2). `maxFactor` is the session's bound for the step, set from a fresh reading
    /// (the sweep's cap, the comparison's ×1.3, the confirmation frame's `0.97 × H`); the ceiling bounds any session by
    /// the reading itself (`CalibrationMath.writeCeiling`). The display is recorded in the ledger before the scaled
    /// write and the epoch is checked in the same critical section (§4.5 invariants 1(b) and 9, §4.6), so a step queued
    /// behind a hang never re-scales a restored display. A factor of 1 writes the baseline and forgets the display (an
    /// un-scale is always allowed).
    public func writeCalibrationFactor(_ factor: Double, of baseline: GammaTable, to display: DisplayRef,
                                       reading: HeadroomReading, maxFactor: Double, epoch: UInt64) throws {
        try checkCalibrationFactor(factor, on: display, reading: reading, maxFactor: maxFactor)
        if abs(factor - 1) < Self.neutralTolerance {
            try writeBaseline(baseline, to: display)
            return
        }
        try writeScaled(baseline, factor: factor, to: display, epoch: epoch)
    }

    /// The checks of a calibration factor without a write (the Compatibility-mode overlay calibrates with the same
    /// bound): finite and positive, at most `maxFactor`, a reading of `display` at most 150 ms old, and above 1 only
    /// with extra range granted (`minimumBoostHeadroom`) and at most the calibration ceiling of that reading's headroom.
    public func checkCalibrationFactor(_ factor: Double, on display: DisplayRef, reading: HeadroomReading,
                                       maxFactor: Double) throws {
        guard factor.isFinite, factor > 0, factor <= maxFactor + Self.neutralTolerance else {
            refuse("interlock.refusedCalibration", display: display, values: ["factor": factor, "maxFactor": maxFactor])
            throw GammaError.writeRefused
        }
        try checkReading(reading, for: display)
        let ceiling = CalibrationMath.writeCeiling(headroom: reading.current)
        if factor > 1 + Self.neutralTolerance,
           factor > ceiling + Self.neutralTolerance || reading.current < Self.minimumBoostHeadroom {
            refuse("interlock.refusedCalibration", display: display,
                   values: ["factor": factor, "headroom": reading.current, "ceiling": ceiling])
            throw GammaError.writeRefused
        }
    }

    /// Writes every baseline of `state` as-is. Call it inside `ledger.withLock { state in … }` (the hang watchdog bumps
    /// the epoch in the same critical section); safe from any thread. Returns the number of displays written.
    @discardableResult
    public func writeBaselines(fromLedger state: SafetyLedger.State) -> Int {
        var written = 0
        for entry in state.entries.values.sorted(by: { $0.display.key < $1.display.key }) {
            do {
                try gamma.write(entry.baseline, to: entry.display.id)
                written += 1
            } catch {
                journal.record("ledger.baselineFailed", display: entry.display.key, time: time, category: .gamma)
            }
        }
        return written
    }

    // MARK: Internals

    private struct Cap {
        var appliedGain: Double
        var headroom: Double
        var limit: LimitReason?
    }

    /// Checks the reading and applies `GainCeiling.liveCap` (taper, live Safe bound, 0.97 × H), journalling a clamp.
    private func interlock(_ request: Request, to display: DisplayRef, reading: HeadroomReading?,
                           journals: Bool = true) throws -> Cap {
        guard let reading else {
            if journals { refuse("interlock.refusedNoReading", display: display) }
            throw GammaError.writeRefused
        }
        try checkReading(reading, for: display, journals: journals)
        let cap = GainCeiling.liveCap(staticGain: request.gain, reading: reading, facts: request.facts,
                                      capMode: request.capMode, isOLED: request.isOLED, sdrWhite: request.sdrWhite,
                                      taper: request.taper, fullBrightnessHeadroom: request.fullBrightnessHeadroom)
        let applied = min(request.gain, cap.gain)
        let binds = cap.gain < request.gain - Self.neutralTolerance
        if binds, journals {
            journal.record("interlock.clamped", display: display.key,
                           values: ["requested": request.gain, "applied": applied, "headroom": reading.current],
                           time: time, category: .gamma)
        }
        return Cap(appliedGain: applied, headroom: reading.current, limit: binds ? cap.reason : nil)
    }

    /// The reading must be of `display` and at most `EngineTiming.readingMaxAge` old (never from the future).
    private func checkReading(_ reading: HeadroomReading, for display: DisplayRef, journals: Bool = true) throws {
        guard reading.display == display.id else {
            if journals { refuse("interlock.refusedForeignReading", display: display) }
            throw GammaError.writeRefused
        }
        let age = time.now - reading.time
        guard age >= .zero, age <= EngineTiming.readingMaxAge else {
            if journals { refuse("interlock.refusedStaleReading", display: display, values: ["age": age.timeInterval]) }
            throw GammaError.writeRefused
        }
    }

    /// `baseline × factor`, with the ledger marked first and the epoch checked, all under the ledger lock.
    private func writeScaled(_ baseline: GammaTable, factor: Double, to display: DisplayRef, epoch: UInt64) throws {
        let stale: UInt64? = try ledger.withLock { state in
            guard state.hangEpoch == epoch else { return state.hangEpoch }
            state.entries[display.key] = SafetyLedger.Entry(display: display, baseline: baseline)
            try gamma.write(baseline.scaled(by: factor), to: display.id)
            return nil
        }
        if let stale {
            refuse("interlock.refusedStaleEpoch", display: display,
                   values: ["epoch": Double(epoch), "hangEpoch": Double(stale)])
            throw GammaError.writeRefused
        }
    }

    private func refuse(_ code: String, display: DisplayRef, values: [String: Double] = [:]) {
        journal.record(code, display: display.key, values: values, time: time, category: .gamma)
    }
}

