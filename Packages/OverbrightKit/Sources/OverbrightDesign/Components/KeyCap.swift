// OverbrightDesign/Components/KeyCap.swift — shortcut key caps. DESIGN.md §16, App. A.
// Seam written by WP0a (ARCHITECTURE.md §10.0): the initializer is fixed; WP9 owns the styling. Key caps are never
// literal: the text comes from `ShortcutCenter.displayString(_:)` (the live binding in the current keyboard layout).
import SwiftUI

/// Renders the key caps it is given ("⌃⌥⌘B") in system colours.
public struct KeyCap: View {
    private let text: String

    /// Key caps for `text`.
    public init(_ text: String) { self.text = text }

    /// The caps on a rounded key.
    public var body: some View {
        Text(verbatim: text)
            .font(.system(.callout, design: .rounded).monospacedDigit())
            .padding(.horizontal, Space.s)
            .padding(.vertical, Space.xxs)
            .background(Color(nsColor: .quaternarySystemFill), in: RoundedRectangle(cornerRadius: Radius.keycap,
                                                                                   style: .continuous))
    }
}
