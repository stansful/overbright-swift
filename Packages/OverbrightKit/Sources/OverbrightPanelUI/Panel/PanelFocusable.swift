// OverbrightPanelUI/Panel/PanelFocusable.swift — binds one element to the panel's `@FocusState` (DESIGN.md §5.12) and
// draws the concentric focus ring after keyboard use (`.overbrightFocusRing`). The wrapper takes the focus, so the
// keys reach it and never the control inside: every element therefore says what its keys do. A button, chip, menu or
// pop-up runs its action on Space and Return; a slider moves on ← and → (mirrored right to left, like a system
// slider). Other keys travel on to the panel (Tab, ↑ / ↓). Outside the panel (the Welcome card) there is no binding and
// the element keeps the system's focus behaviour.
import OverbrightDesign
import SwiftUI

/// The panel's focus binding for one element.
struct PanelFocusable: ViewModifier {
    /// What the element's keys do.
    enum Keys {
        /// Space and Return run it (a button, a chip's popover, a menu, a pop-up).
        case activate(@MainActor () -> Void)
        /// ← and → step a slider; the argument is "toward the end of the track".
        case step(@MainActor (_ towardEnd: Bool) -> Void)
    }

    let focus: FocusState<PanelFocus?>.Binding?
    let value: PanelFocus
    let cornerRadius: CGFloat
    let keys: Keys
    @Environment(\.layoutDirection) private var direction

    func body(content: Content) -> some View {
        if let focus {
            content
                .focusable()
                .focusEffectDisabled()
                .focused(focus, equals: value)
                .overbrightFocusRing(cornerRadius: cornerRadius)
                .onKeyPress(keys: [.space, .return, .leftArrow, .rightArrow], phases: [.down, .repeat]) { press in
                    Self.handle(press.key, modifiers: press.modifiers, isRepeat: press.phase == .repeat, keys: keys,
                                direction: direction)
                }
        } else {
            content
        }
    }

    /// What `key` does to an element whose keys are `keys`: handled when it ran the element, ignored (so the panel or
    /// the system sees it) otherwise. A held Space or Return runs it once; a held arrow keeps stepping.
    static func handle(_ key: KeyEquivalent, modifiers: EventModifiers, isRepeat: Bool, keys: Keys,
                       direction: LayoutDirection) -> KeyPress.Result {
        guard modifiers.isEmpty else { return .ignored }
        switch keys {
        case .activate(let activate):
            guard key == .space || key == .return, !isRepeat else { return .ignored }
            activate()
            return .handled
        case .step(let step):
            guard key == .leftArrow || key == .rightArrow else { return .ignored }
            step((key == .rightArrow) == (direction == .leftToRight))
            return .handled
        }
    }
}

extension View {
    /// Makes the element `value` of the panel's Tab order (nothing without a binding); `activate` runs on Space and
    /// Return while it has focus.
    func panelFocus(_ focus: FocusState<PanelFocus?>.Binding?, _ value: PanelFocus,
                    cornerRadius: CGFloat = Radius.control, activate: @escaping @MainActor () -> Void) -> some View {
        modifier(PanelFocusable(focus: focus, value: value, cornerRadius: cornerRadius, keys: .activate(activate)))
    }

    /// Makes the slider `value` of the panel's Tab order; `step` moves it one step on ← or → while it has focus.
    func panelFocus(_ focus: FocusState<PanelFocus?>.Binding?, _ value: PanelFocus,
                    cornerRadius: CGFloat = Radius.control,
                    step: @escaping @MainActor (_ towardEnd: Bool) -> Void) -> some View {
        modifier(PanelFocusable(focus: focus, value: value, cornerRadius: cornerRadius, keys: .step(step)))
    }
}
