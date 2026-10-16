// OverbrightDesign/Components/KeyCap.swift — shortcut key caps. DESIGN.md §16, App. A.
// Seam written by WP0a (ARCHITECTURE.md §10.0): the initializer is fixed. Key caps are never literal: the text comes
// from `ShortcutCenter.displayString(_:)` (the live binding in the current keyboard layout). System colours only; a
// full-strength hairline under Increase Contrast.
import SwiftUI

/// Renders the key caps it is given ("⌃⌥⌘B") in system colours.
public struct KeyCap: View {
    private let text: String
    @Environment(\.overbright) private var theme

    /// Key caps for `text`.
    public init(_ text: String) { self.text = text }

    /// The caps on a rounded key.
    public var body: some View {
        let shape = RoundedRectangle(cornerRadius: Radius.keycap, style: .continuous)
        Text(verbatim: text)
            .font(.system(.callout, design: .rounded).monospacedDigit())
            .foregroundStyle(.primary)
            .padding(.horizontal, Space.s)
            .padding(.vertical, Space.xxs)
            .background(Color(nsColor: .controlBackgroundColor), in: shape)
            .overlay(shape.strokeBorder(theme.color(.cardStroke), lineWidth: StrokeWidth.regular))
            .fixedSize()
            .accessibilityLabel(Text(verbatim: text))
    }
}

#Preview("Key caps") {
    HStack { KeyCap("⌃⌥⌘B"); KeyCap("⌃⌥⌘0") }
        .padding()
        .overbrightThemeRoot()
}
