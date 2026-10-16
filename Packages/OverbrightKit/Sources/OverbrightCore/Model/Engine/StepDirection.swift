// OverbrightCore/Model/Engine/StepDirection.swift — Brighter / Less Bright. ARCHITECTURE.md §3.5, §5.3.

/// Brighter / Less Bright: one step in STOPS of light (`StepSize`), never crossing Standard in one press (§5.3).
public nonisolated enum StepDirection: Sendable {
    /// One step up.
    case brighter
    /// One step down.
    case lessBright
}
