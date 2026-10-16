// OverbrightOnboarding/Chrome/WelcomeMetrics.swift — the Welcome window's own measurements (DESIGN.md §8), so no view
// writes a literal size or opacity (ARCHITECTURE.md §9.2 rule 3). The window is an ordinary system window: system text
// styles and colours; spacing comes from Design's `Space`, motion from the theme. Ported from Cranny's WelcomeMetrics
// (the owner's MIT code).
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
    /// A pressed option card (DESIGN.md §3.1 `press`: scale 0.97; none under Reduce Motion).
    static let pressScale: CGFloat = 0.97
    /// The accent wash behind a selected option card.
    static let selectedWash: Double = 0.08
    /// The quiet fill of an option card at rest, and under the pointer.
    static let cardFill: (resting: Double, hovered: Double) = (0.4, 0.7)
}
