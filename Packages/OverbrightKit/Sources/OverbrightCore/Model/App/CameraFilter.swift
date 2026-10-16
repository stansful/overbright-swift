// OverbrightCore/Model/App/CameraFilter.swift — which cameras turn Fill Light on. ARCHITECTURE.md §3.8, D12.

/// Which cameras count for "Fill Light on while a camera is in use".
public nonisolated enum CameraFilter: String, Codable, Sendable {
    /// Any camera, virtual ones included.
    case anyCamera
    /// Only the built-in and USB cameras.
    case builtInAndUSB
}
