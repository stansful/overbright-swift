// OverbrightDesign/Tokens/OverbrightMotion.swift — interface motion kinds and their Reduce Motion variants.
// DESIGN.md §3.1–§3.2. Seam written by WP0a (ARCHITECTURE.md §10.0); WP9 owns the values. Brightness ramps are not
// SwiftUI animations: the engine owns them (DESIGN.md §3.3). Every animation is interruptible, nothing queues, nothing
// overshoots when it shrinks, and nothing loops.
import SwiftUI

/// Interface motion. Views ask the theme (`theme.animation(.panelIn)`), never build animations themselves.
public nonisolated enum OverbrightMotion {
    /// A curve with its duration.
    public enum Curve: Hashable, Sendable {
        /// Ease out over `duration` seconds.
        case easeOut(Double)
        /// Ease in.
        case easeIn(Double)
        /// Ease in and out.
        case easeInOut(Double)
        /// SwiftUI's smooth curve.
        case smooth(Double)
        /// A spring of `duration` seconds and `bounce` (0 never overshoots).
        case spring(duration: Double, bounce: Double)

        /// The duration in seconds.
        public var duration: Double {
            switch self {
            case let .easeOut(d), let .easeIn(d), let .easeInOut(d), let .smooth(d): d
            case let .spring(duration, _): duration
            }
        }

        /// The overshoot (0 for every curve but a bouncing spring).
        public var bounce: Double {
            if case let .spring(_, bounce) = self { return bounce }
            return 0
        }

        /// The SwiftUI animation.
        public var animation: Animation {
            switch self {
            case let .easeOut(d): .easeOut(duration: d)
            case let .easeIn(d): .easeIn(duration: d)
            case let .easeInOut(d): .easeInOut(duration: d)
            case let .smooth(d): .smooth(duration: d)
            case let .spring(d, b): .spring(duration: d, bounce: b)
            }
        }
    }

    /// Every animation the interface uses (DESIGN.md §3.1).
    public enum Kind: String, CaseIterable, Sendable {
        /// The panel appears: opacity 0 → 1 and a 4-pt downward settle.
        case panelIn
        /// The panel fades out.
        case panelOut
        /// Card content changes (state, chip), the Welcome verdict cross-fade.
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
        /// The HUD appears (scale 0.96 → 1 and fade).
        case hudIn
        /// The HUD fades out.
        case hudOut
        /// A banner slides in 6 pt and fades in.
        case bannerIn
        /// A banner leaves.
        case bannerOut

        /// The curve and duration of DESIGN.md §3.1.
        public var spec: Curve {
            switch self {
            case .panelIn: .easeOut(0.18)
            case .panelOut: .easeIn(0.12)
            case .contentSwap: .smooth(0.25)
            case .expand: .spring(duration: 0.30, bounce: 0)
            case .hover: .easeOut(0.12)
            case .press: .spring(duration: 0.18, bounce: 0.2)
            case .detentSnap: .spring(duration: 0.20, bounce: 0)
            case .colorShift: .easeInOut(0.40)
            case .hudIn: .easeOut(0.18)
            case .hudOut: .easeIn(0.25)
            case .bannerIn: .easeOut(0.22)
            case .bannerOut: .easeIn(0.22)
            }
        }

        /// Reduce Motion (DESIGN.md §3.2): cross-fades only, at most 0.2 s, no springs; nil where the change is
        /// immediate (the press scale, the detent and preset snaps).
        public var reducedSpec: Curve? {
            switch self {
            case .panelIn, .hudIn, .bannerIn: .easeOut(0.15)
            case .panelOut: .easeIn(0.12)
            case .hudOut, .bannerOut: .easeIn(0.15)
            case .contentSwap, .expand, .colorShift: .easeInOut(0.2)
            case .hover: .easeOut(0.12)
            case .press, .detentSnap: nil
            }
        }

        /// The animation of DESIGN.md §3.1.
        public var animation: Animation { spec.animation }

        /// The animation to play: the Reduce Motion variant when `reduceMotion`, nil when nothing may move.
        public func animation(reduceMotion: Bool) -> Animation? {
            reduceMotion ? reducedSpec?.animation : spec.animation
        }
    }

    /// The panel's downward settle while it appears.
    public static let panelSettle: CGFloat = 4
    /// The HUD's starting scale.
    public static let hudScale: CGFloat = 0.96
    /// The banner's slide.
    public static let bannerSlide: CGFloat = 6
    /// The press scale of buttons and chips.
    public static let pressScale: CGFloat = 0.97
    /// The HUD stays this long after the last change …
    public static let hudDwell: Duration = .milliseconds(1500)
    /// … and this long for automation reasons (DESIGN.md §6).
    public static let hudAutomationDwell: Duration = .seconds(3)

    /// A banner's insertion and removal: a 6-pt slide plus fade, or a fade under Reduce Motion.
    public static func bannerTransition(reduceMotion: Bool) -> AnyTransition {
        let insertion = Kind.bannerIn.animation(reduceMotion: reduceMotion)
        let removal = Kind.bannerOut.animation(reduceMotion: reduceMotion)
        let move: AnyTransition = reduceMotion ? .opacity : .offset(y: -bannerSlide).combined(with: .opacity)
        return .asymmetric(insertion: move.animation(insertion), removal: move.animation(removal))
    }

    /// The HUD's content: scale 0.96 → 1 and fade in, fade out; a fade only under Reduce Motion.
    public static func hudTransition(reduceMotion: Bool) -> AnyTransition {
        let insertion: AnyTransition = reduceMotion ? .opacity : .scale(scale: hudScale).combined(with: .opacity)
        return .asymmetric(insertion: insertion.animation(Kind.hudIn.animation(reduceMotion: reduceMotion)),
                           removal: AnyTransition.opacity.animation(Kind.hudOut.animation(reduceMotion: reduceMotion)))
    }
}
