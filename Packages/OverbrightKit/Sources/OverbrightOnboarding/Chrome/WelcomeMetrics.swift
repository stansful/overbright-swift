// OverbrightOnboarding/Chrome/WelcomeMetrics.swift — the Welcome window's own measurements (DESIGN.md §8). The window
// is an ordinary system window: system text styles and colours; spacing comes from Design's `Space`. Ported from
// Cranny's WelcomeMetrics (the owner's MIT code).
import CoreGraphics
import OverbrightDesign

/// Sizes of the Welcome window.
nonisolated enum WelcomeMetrics {
    /// 640 × 480, not resizable (DESIGN.md §8).
    static let window = CGSize(width: 640, height: 480)
    /// The stage on top (the before/after card or an illustration); the rest holds copy, controls and the footer.
    static let stageHeight: CGFloat = 200
    /// Side inset of the lower half.
    static let inset = Space.huge
    /// Corner radius of option and display cards in the window.
    static let cardRadius = Radius.card
    /// The size of a step's check badge.
    static let badge = Space.xl
}
