// OverbrightBoost/Writer/TableWriter.swift — the interlock: the only code that turns a light gain into a table and
// calls `GammaPort.write`. ARCHITECTURE.md §4.1, §4.5 invariants 1, 3, 9, §4.6, §5.4; D5, D24.
// Seeded by WP0a with the fixed signatures (§10.0); owned by WP4, which writes the body. Until then every write path
// REFUSES (`GammaError.writeRefused`) and the baseline path writes nothing: WP0a can never change a display's table.
import Foundation
import OverbrightCore

/// Writes tables on three paths: `write(_:to:reading:epoch:)` (main: `GainCeiling.liveCap`, a reading of the same
/// display at most 150 ms old, the current hang epoch), `writeCalibrationFactor(_:to:reading:maxFactor:)`, and the
/// nonisolated `writeBaselines(fromLedger:)` of the hang watchdog and the signal queue. Lint test
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

    /// The main path: applies `request` to `display` as far as the interlock allows, with `reading` (same display, at
    /// most `EngineTiming.readingMaxAge` old) and the controller's `epoch` stamp (must equal the ledger's hang epoch).
    /// Throws `GammaError.writeRefused` on a stale epoch or a foreign or stale reading.
    /// WP0a seed: refuses every write (WP4).
    public func write(_ request: Request, to display: DisplayRef, reading: HeadroomReading?,
                      epoch: UInt64) throws -> Outcome {
        _ = (request, display, reading, epoch)
        throw GammaError.writeRefused
    }

    /// Calibration: writes `factor` × the display's ledger baseline, refusing anything above `maxFactor` or the live
    /// interlock. WP0a seed: refuses every write (WP4).
    public func writeCalibrationFactor(_ factor: Double, to display: DisplayRef, reading: HeadroomReading,
                                       maxFactor: Double) throws {
        _ = (factor, display, reading, maxFactor)
        throw GammaError.writeRefused
    }

    /// Writes every baseline of `state` as-is. Call it inside `ledger.withLock { state in … }` (the hang watchdog bumps
    /// the epoch in the same critical section); safe from any thread. Returns the number of displays written.
    /// WP0a seed: writes nothing (nothing is ever scaled before WP4).
    @discardableResult
    public func writeBaselines(fromLedger state: SafetyLedger.State) -> Int {
        _ = state
        return 0
    }
}
