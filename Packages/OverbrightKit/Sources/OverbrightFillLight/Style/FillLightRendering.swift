// OverbrightFillLight/Style/FillLightRendering.swift — how a frame window makes its colour. ARCHITECTURE.md §7.6,
// §10.9 ("tagged CALayer 26+, clear-only CAMetalLayer 14–25, SDR fallback"); DESIGN.md §11.

/// How a Fill Light surface makes its colour, and so whether it can show light above SDR white.
public nonisolated enum FillLightRendering: String, Hashable, Sendable, CaseIterable {
    /// macOS 26+: a plain layer whose background is a headroom-tagged `CGColor`, `preferredDynamicRange = .high`.
    case taggedLayer
    /// macOS 14–25: a 4 × 4 px `CAMetalLayer` (`rgba16Float`, extended linear sRGB) cleared once to the colour.
    case metalClear
    /// An ordinary colour, at most SDR white: no EDR on this path (and the `--qa-simulate` stand-in).
    case sdr

    /// Whether this path can show values above 1.0.
    public var showsEDR: Bool { self != .sdr }

    /// A stable number for the journal (codes and numbers only, §8.3).
    public var journalCode: Double {
        switch self {
        case .taggedLayer: 1
        case .metalClear: 2
        case .sdr: 0
        }
    }
}
