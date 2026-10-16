// OverbrightDesign/Tokens/OverbrightMotion.swift — interface motion kinds. DESIGN.md §3.1–§3.2.
// Seam written by WP0a (ARCHITECTURE.md §10.0); WP9 owns the values and the Reduce Motion variants. Brightness ramps
// are not SwiftUI animations: the engine owns them (DESIGN.md §3.3).
import SwiftUI

/// Interface motion. Views ask the theme (`theme.animation(.panelIn)`), never build animations themselves.
public nonisolated enum OverbrightMotion {
    /// Every animation the interface uses (DESIGN.md §3.1).
    public enum Kind: String, CaseIterable, Sendable {
        /// The panel appears.
        case panelIn
        /// The panel fades out.
        case panelOut
        /// Card content changes (state, chip).
        case contentSwap
        /// "Why?" expands, a banner is inserted.
        case expand
        /// Hover highlights.
        case hover
        /// A press (scale 0.97).
        case press
        /// The thumb settles into Standard or a preset.
        case detentSnap
        /// A fill changes colour (dim ↔ boost, warm ↔ hatch).
        case colorShift
        /// The HUD appears.
        case hudIn
        /// The HUD fades out.
        case hudOut
        /// A banner slides in.
        case bannerIn
        /// A banner leaves.
        case bannerOut

        /// The curve and duration of DESIGN.md §3.1.
        public var animation: Animation {
            switch self {
            case .panelIn: .easeOut(duration: 0.18)
            case .panelOut: .easeIn(duration: 0.12)
            case .contentSwap: .smooth(duration: 0.25)
            case .expand: .spring(duration: 0.30, bounce: 0)
            case .hover: .easeOut(duration: 0.12)
            case .press: .spring(duration: 0.18, bounce: 0.2)
            case .detentSnap: .spring(duration: 0.20, bounce: 0)
            case .colorShift: .easeInOut(duration: 0.40)
            case .hudIn: .easeOut(duration: 0.18)
            case .hudOut: .easeIn(duration: 0.25)
            case .bannerIn: .easeOut(duration: 0.22)
            case .bannerOut: .easeIn(duration: 0.22)
            }
        }
    }
}
