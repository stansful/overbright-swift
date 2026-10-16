// OverbrightCore/Model/Displays/TransferDomain.swift — how the transfer table maps to light. ARCHITECTURE.md §3.2, §5.2, D5.

/// How the transfer table maps to light (ARCHITECTURE.md §5.2). Only calibration with a positive linear
/// confirmation can select `.linear`; everything else, and any stale record, is `.encoded`.
public nonisolated enum TransferDomain: String, Hashable, Codable, Sendable {
    /// Display-encoded values: the sRGB curve at and below white (dimming); above white the conservative pure
    /// 2.4 power (`F = G^(1/2.4)`), so `F^k ≤ G` for every exponent k ≤ 2.4 and nothing clips under either model.
    case encoded
    /// Linear light: light gain = table factor.
    case linear
}
