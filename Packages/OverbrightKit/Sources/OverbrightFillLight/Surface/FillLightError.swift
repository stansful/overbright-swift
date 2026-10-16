// OverbrightFillLight/Surface/FillLightError.swift — why a frame surface could not be made. ARCHITECTURE.md §10.9.
import CoreGraphics

/// Why a Fill Light surface could not be made.
public nonisolated enum FillLightError: Error, Hashable, Sendable {
    /// No `NSScreen` shows this display (a hardware-mirror member, or it just went away).
    case noScreen(CGDirectDisplayID)
    /// A test or stand-in factory refused the display.
    case unavailable(CGDirectDisplayID)
}
