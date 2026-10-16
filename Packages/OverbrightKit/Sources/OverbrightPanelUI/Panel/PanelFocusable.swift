// OverbrightPanelUI/Panel/PanelFocusable.swift — binds one element to the panel's `@FocusState` (DESIGN.md §5.12) and
// draws the concentric focus ring after keyboard use (`.overbrightFocusRing`). A focused button runs on Space and
// Return. Outside the panel (the Welcome card) there is no binding and the element keeps the system's focus behaviour.
import OverbrightDesign
import SwiftUI

/// The panel's focus binding for one element.
struct PanelFocusable: ViewModifier {
    let focus: FocusState<PanelFocus?>.Binding?
    let value: PanelFocus
    let cornerRadius: CGFloat
    let activate: (@MainActor () -> Void)?

    func body(content: Content) -> some View {
        if let focus {
            content
                .focusable()
                .focusEffectDisabled()
                .focused(focus, equals: value)
                .overbrightFocusRing(cornerRadius: cornerRadius)
                .onKeyPress(keys: [.space, .return], phases: .down) { press in
                    guard let activate, press.modifiers.isEmpty else { return .ignored }
                    activate()
                    return .handled
                }
        } else {
            content
        }
    }
}

extension View {
    /// Makes the element `value` of the panel's Tab order (nothing without a binding); `activate` runs on Space and
    /// Return while it has focus.
    func panelFocus(_ focus: FocusState<PanelFocus?>.Binding?, _ value: PanelFocus,
                    cornerRadius: CGFloat = Radius.control, activate: (@MainActor () -> Void)? = nil) -> some View {
        modifier(PanelFocusable(focus: focus, value: value, cornerRadius: cornerRadius, activate: activate))
    }
}
