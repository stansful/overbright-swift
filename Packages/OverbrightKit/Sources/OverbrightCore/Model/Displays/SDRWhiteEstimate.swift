// OverbrightCore/Model/Displays/SDRWhiteEstimate.swift — a trusted SDR white in nits. ARCHITECTURE.md §3.2, §5.5.

/// Estimated SDR white in nits and where it came from; nil hides nits (DESIGN.md §5.6).
public nonisolated struct SDRWhiteEstimate: Hashable, Sendable {
    /// Where a trusted SDR white comes from (§5.5).
    public enum Source: String, Codable, Sendable {
        /// Typed from a colorimeter in the calibration sheet.
        case colorimeter
        /// An external's HDR-mode frame-average luminance.
        case hdrFrameAverage
    }
    /// SDR white in nits.
    public var nits: Double
    /// Where the value came from.
    public var source: Source
    /// An estimate of `nits` from `source`.
    public init(nits: Double, source: Source) { self.nits = nits; self.source = source }
}
