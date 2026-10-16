// OverbrightDesign/Styles/OverbrightFocusRing.swift — the concentric keyboard focus ring. DESIGN.md §5.12, App. A.
// Seam written by WP0a (ARCHITECTURE.md §10.0): `.overbrightFocusRing(cornerRadius:)` is fixed; WP9 shows it only after
// keyboard interaction and disables the system focus effect on the same element so rings never double.
import SwiftUI

/// Draws a 2-pt accent ring `Radius.focusRingOutset` outside the element while it has keyboard focus.
public struct OverbrightFocusRing: ViewModifier {
    @Environment(\.isFocused) private var isFocused
    private let cornerRadius: CGFloat

    /// A ring around an element whose own corner radius is `cornerRadius`.
    public init(cornerRadius: CGFloat) { self.cornerRadius = cornerRadius }

    /// The element with the ring while focused.
    public func body(content: Content) -> some View {
        content.overlay {
            if isFocused {
                RoundedRectangle(cornerRadius: cornerRadius + Radius.focusRingOutset, style: .continuous)
                    .strokeBorder(.tint, lineWidth: StrokeWidth.focusRing)
                    .padding(-Radius.focusRingOutset)
                    .accessibilityHidden(true)
            }
        }
    }
}

public extension View {
    /// The Overbright focus ring (concentric: the element's radius plus the outset).
    func overbrightFocusRing(cornerRadius: CGFloat = Radius.control) -> some View {
        modifier(OverbrightFocusRing(cornerRadius: cornerRadius))
    }
}
