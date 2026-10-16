// OverbrightPanelUI/Help/HelpView.swift — the local Help window's content. DESIGN.md §12.6.
// Seam written by WP0a (ARCHITECTURE.md §10.0): the initializer is fixed (the shell's Help window hosts it); WP10
// writes the entries and scrolls to `anchor`. The WP0a body is empty.
import SwiftUI

/// Every Help entry, scrolled to `anchor` ("no-extra-range", "control-center", …) when given.
public struct HelpView: View {
    private let anchor: String?

    /// Help, optionally at `anchor`.
    public init(anchor: String?) { self.anchor = anchor }

    /// WP0a placeholder: an empty scroll view.
    public var body: some View {
        ScrollView { EmptyView() }
            .frame(minWidth: 480, minHeight: 360)
    }
}
