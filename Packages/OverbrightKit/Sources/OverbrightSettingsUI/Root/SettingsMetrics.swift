// OverbrightSettingsUI/Root/SettingsMetrics.swift — the few sizes and durations DESIGN.md §7 fixes for the Settings
// window, and the control widths its components share, so no view writes a literal size (ARCHITECTURE.md §9.2 rule 3).
// Settings is an ordinary window with system colours and text styles; spacing comes from Design's `Space`, motion from
// the theme. Ported from Cranny's SettingsMetrics (the owner's MIT code).
import CoreGraphics

/// Layout constants of the Settings window (DESIGN.md §7.1, §7.2).
nonisolated enum SettingsMetrics {
    /// Default window content size.
    static let windowSize = CGSize(width: 860, height: 620)
    /// Minimum window content size.
    static let minimumWindowSize = CGSize(width: 780, height: 560)
    /// Sidebar width range and default.
    static let sidebarWidth: (min: CGFloat, ideal: CGFloat, max: CGFloat) = (190, 210, 260)
    /// The sidebar icon: a 20 × 20 rounded square, radius 5, continuous.
    static let sidebarIcon: CGFloat = 20
    /// The sidebar icon's corner radius.
    static let sidebarIconRadius: CGFloat = 5
    /// The sidebar glyph's point size.
    static let sidebarGlyph: CGFloat = 11
    /// Search highlight (DESIGN.md §7.2: gone after 1 s): the accent wash holds this long, then fades with the theme's
    /// `colorShift` (0.4 s; a short cross-fade under Reduce Motion).
    static let highlightHold: Duration = .milliseconds(600)
    /// The wash's starting opacity.
    static let highlightOpacity: Double = 0.22
    /// The gap between a search hit's row label and its pane name in the sidebar.
    static let searchHitLineGap: CGFloat = 1
    /// The "All settings were reset." banner shows for 10 s (Undo stays until the window closes).
    static let undoBannerTime: Duration = .seconds(10)
    /// The banner's distance from the window's bottom edge (above the pane footer).
    static let bannerInset: CGFloat = 60
    /// App icons in rows (paused apps, other apps).
    static let rowIcon: CGFloat = 20
    /// The About header's icon.
    static let aboutIcon: CGFloat = 112
    /// The Acknowledgments sheet.
    static let acknowledgmentsSize = CGSize(width: 520, height: 460)
    /// A shortcut recorder's button: wide enough that "Record Shortcut" and key caps keep one size.
    static let recorderMinWidth: CGFloat = 96
    /// A slider row's track: minimum, ideal and maximum width.
    static let sliderWidth: (min: CGFloat, ideal: CGFloat, max: CGFloat) = (140, 200, 220)
    /// A slider row's value with its unit ("5,100 K"), trailing-aligned so the track does not jump.
    static let sliderValueMinWidth: CGFloat = 52
}
