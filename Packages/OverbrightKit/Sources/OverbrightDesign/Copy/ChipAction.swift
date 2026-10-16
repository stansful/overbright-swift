// OverbrightDesign/Copy/ChipAction.swift — one action in a chip's popover. DESIGN.md §5.7, §12.2.
// Seam written by WP0a (ARCHITECTURE.md §10.0); WP9 owns it.

/// An action offered in a chip's popover ("Try again", "Choose Peak…"), also a VoiceOver action on the card.
public struct ChipAction: Identifiable {
    /// The button title, already localized (sentence case, DESIGN.md §12).
    public let title: String
    /// What the button does.
    public let perform: @MainActor () -> Void

    /// An action titled `title`.
    public init(title: String, perform: @escaping @MainActor () -> Void) {
        self.title = title; self.perform = perform
    }

    /// The title identifies the action within one popover.
    public var id: String { title }
}
