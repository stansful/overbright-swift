// OverbrightCore/Model/Displays/TriggerStrategy.swift — the rungs of the trigger ladder. ARCHITECTURE.md §3.2, §4.7, D4.

/// Trigger strategies of the escalation ladder (D4, ARCHITECTURE.md §4.7). Raw values are persisted.
public nonisolated enum TriggerStrategy: String, Codable, Sendable, CaseIterable {
    /// T1: CALayer, preferredDynamicRange .high, headroom-tagged CGColor (macOS 26+).
    case taggedLayer
    /// T2: CAMetalLayer rgba16Float, one clear-only frame, re-presented on events.
    case metalOneShot
    /// T3: T2 plus a keep-alive frame every 0.2 s.
    case metalKeepAlive
    /// T4-alt: AVSampleBufferDisplayLayer with one in-memory HLG frame.
    case hlgSampleBuffer
    /// T4: our own generated HLG still in a paused AVPlayerLayer.
    case hlgStill
}
