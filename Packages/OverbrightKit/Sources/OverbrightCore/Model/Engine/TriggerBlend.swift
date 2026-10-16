// OverbrightCore/Model/Engine/TriggerBlend.swift — how a trigger pixel is composited. ARCHITECTURE.md §3.5, §4.7.

/// How a non-black trigger pixel is composited.
public nonisolated enum TriggerBlend: String, Codable, Sendable {
    /// Plain source-over.
    case normal
    /// Soft light: a bright pixel nearly vanishes on pure black and pure white.
    case softLight
}
