// OverbrightDesign/Components/BoostHalfState.swift — how the slider draws its boost half. DESIGN.md §5.4, §5.5.
// Seam written by WP0a (ARCHITECTURE.md §10.0); WP9 owns it.

/// The state of the slider's boost half (right of the Standard detent).
public nonisolated enum BoostHalfState: Hashable, Sendable {
    /// Extra light is on screen: the fill is `BoostColor.warm`.
    case active
    /// Overbright is off or paused: the fill is the inactive hatch; moving the thumb turns Overbright on (or ends a
    /// pause the user set).
    case inactive
    /// Extra brightness is off for this display: hatched; moving past the detent turns it on (an OLED shows its
    /// notice first).
    case switchedOff
    /// Boosting is impossible (verdict, or a Safe top below ×1.05): hatched, the thumb stops at the detent and the
    /// half's help tag is `reason` (already localized).
    case unavailable(reason: String)
}
