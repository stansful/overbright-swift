// OverbrightCore/Model/System/ConflictSeverity.swift — severity classes of conflicting apps. ARCHITECTURE.md §3.3, §7.2.

/// Severity classes of apps that also change display colours or brightness.
public nonisolated enum ConflictSeverity: String, Codable, Sendable, CaseIterable {
    /// S1: suspend every display; never continued (§7.2).
    case booster
    /// S2: suspend before starting; Continue Anyway allowed (the repair budget stays authoritative).
    case gammaWriter
    /// S3: info chip; suspend a display at the first attributed drift.
    case conditional
    /// S4: diagnostics only.
    case benign
}
