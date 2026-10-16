// OverbrightCore/Model/App/BoostMarker.swift — the diagnostic "a display is scaled" record. ARCHITECTURE.md §3.8, §7.4, D7.
import Foundation

/// Written while any display is scaled or dimmed (`EngineRecords.boostMarker`). At launch, present + every table
/// `matchesBase` means "we died and WindowServer restored"; present + a `scaled` table means "run the rescue".
public nonisolated struct BoostMarker: Hashable, Codable, Sendable {
    /// When the first display was scaled or dimmed.
    public var since: Date
    /// The displays scaled or dimmed.
    public var displays: [DisplayKey]
    /// The largest table factor written.
    public var maxFactor: Double
    /// A marker.
    public init(since: Date, displays: [DisplayKey], maxFactor: Double) {
        self.since = since; self.displays = displays; self.maxFactor = maxFactor
    }
}
