// OverbrightDesign/Styles/OverbrightFocusRing.swift — the concentric keyboard focus ring. DESIGN.md §5.12, §15, App. A.
// Seam written by WP0a (ARCHITECTURE.md §10.0): `.overbrightFocusRing(cornerRadius:)` is fixed; WP9 shows it only
// after keyboard interaction and disables the system focus effect on the same element so rings never double.
// A 2-pt accent ring, concentric (the element's radius + 3, outset 3).
//
// `@Environment(\.isFocused)` describes the nearest focusable ancestor, so the environment form belongs inside the
// focusable element (a button style's body, a menu's label); a view that owns its focus (`@FocusState`, the slider)
// passes it with `isFocused:`.
import SwiftUI

/// Draws a 2-pt accent ring `Radius.focusRingOutset` outside the element while it has keyboard focus and the last
/// interaction was with the keyboard.
public struct OverbrightFocusRing: ViewModifier {
    /// The outline the ring follows.
    public enum Outline: Hashable, Sendable {
        /// A rounded rectangle of this corner radius.
        case rounded(CGFloat)
        /// A capsule (chips).
        case capsule
    }

    @Environment(\.isFocused) private var environmentFocus
    @State private var keyboard = KeyboardInteraction.shared
    private let outline: Outline
    private let explicitFocus: Bool?

    /// A ring around an element whose own corner radius is `cornerRadius`, focused per the environment.
    public init(cornerRadius: CGFloat) { self.init(outline: .rounded(cornerRadius), isFocused: nil) }

    /// A ring around `outline`; `isFocused` overrides the environment when the element tracks its own focus.
    public init(outline: Outline, isFocused: Bool?) {
        self.outline = outline; explicitFocus = isFocused
    }

    /// The element with the ring while focused by the keyboard.
    public func body(content: Content) -> some View {
        content
            .focusEffectDisabled()
            .overlay {
                if Self.showsRing(isFocused: explicitFocus ?? environmentFocus, keyboardActive: keyboard.isActive) {
                    ring
                        .padding(-Radius.focusRingOutset)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
            .onAppear { keyboard.startObserving() }
    }

    @ViewBuilder private var ring: some View {
        switch outline {
        case let .rounded(radius):
            RoundedRectangle(cornerRadius: Self.ringRadius(for: radius), style: .continuous)
                .strokeBorder(.tint, lineWidth: StrokeWidth.focusRing)
        case .capsule:
            Capsule(style: .continuous).strokeBorder(.tint, lineWidth: StrokeWidth.focusRing)
        }
    }

    /// The ring shows only while the element has focus and the last interaction was with the keyboard.
    public static func showsRing(isFocused: Bool, keyboardActive: Bool) -> Bool { isFocused && keyboardActive }

    /// The ring's corner radius: concentric with an element of `cornerRadius` (inner + outset).
    public static func ringRadius(for cornerRadius: CGFloat) -> CGFloat { cornerRadius + Radius.focusRingOutset }
}

public extension View {
    /// The Overbright focus ring (concentric: the element's radius plus the outset), focused per the environment: use
    /// it inside the focusable element.
    func overbrightFocusRing(cornerRadius: CGFloat = Radius.control) -> some View {
        modifier(OverbrightFocusRing(cornerRadius: cornerRadius))
    }

    /// The ring for an element that tracks its own focus (`@FocusState`).
    func overbrightFocusRing(cornerRadius: CGFloat, isFocused: Bool) -> some View {
        modifier(OverbrightFocusRing(outline: .rounded(cornerRadius), isFocused: isFocused))
    }

    /// The capsule ring of chips, focused per the environment.
    func overbrightCapsuleFocusRing() -> some View {
        modifier(OverbrightFocusRing(outline: .capsule, isFocused: nil))
    }
}
