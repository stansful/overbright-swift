// OverbrightDesign/Styles/OverbrightFocusRing.swift — the concentric keyboard focus ring. DESIGN.md §5.12, §15, App. A.
// Seam written by WP0a (ARCHITECTURE.md §10.0): `.overbrightFocusRing(cornerRadius:)` is fixed; WP9 shows it only
// after keyboard interaction and disables the system focus effect on the same element so rings never double.
// A 2-pt accent ring, concentric (the element's radius + 3, outset 3).
import SwiftUI

/// Draws a 2-pt accent ring `Radius.focusRingOutset` outside the element while it has keyboard focus and the last
/// interaction was with the keyboard.
public struct OverbrightFocusRing: ViewModifier {
    @Environment(\.isFocused) private var isFocused
    @State private var keyboard = KeyboardInteraction.shared
    private let cornerRadius: CGFloat

    /// A ring around an element whose own corner radius is `cornerRadius`.
    public init(cornerRadius: CGFloat) { self.cornerRadius = cornerRadius }

    /// The element with the ring while focused by the keyboard.
    public func body(content: Content) -> some View {
        content
            .focusEffectDisabled()
            .overlay {
                if isFocused && keyboard.isActive {
                    RoundedRectangle(cornerRadius: Self.ringRadius(for: cornerRadius), style: .continuous)
                        .strokeBorder(.tint, lineWidth: StrokeWidth.focusRing)
                        .padding(-Radius.focusRingOutset)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
            .onAppear { keyboard.startObserving() }
    }

    /// The ring's corner radius: concentric with an element of `cornerRadius` (inner + outset).
    public static func ringRadius(for cornerRadius: CGFloat) -> CGFloat { cornerRadius + Radius.focusRingOutset }
}

public extension View {
    /// The Overbright focus ring (concentric: the element's radius plus the outset).
    func overbrightFocusRing(cornerRadius: CGFloat = Radius.control) -> some View {
        modifier(OverbrightFocusRing(cornerRadius: cornerRadius))
    }
}
