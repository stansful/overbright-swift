// OverbrightSettingsUI/Components/SettingsForm.swift — the body of every pane: `Form { … }.formStyle(.grouped)`
// (DESIGN.md §7.2) inside a `ScrollViewReader`, so a search result or deep link scrolls its row into view. Ported from
// Cranny's SettingsForm (the owner's MIT code).
import Foundation
import OverbrightDesign
import SwiftUI

/// A pane's grouped form.
struct SettingsForm<Content: View>: View {
    @Environment(SettingsNavigator.self) private var navigator: SettingsNavigator?
    @Environment(\.overbright) private var theme
    private let pane: SettingsPaneID
    private let content: Content

    /// `pane` is the pane these rows belong to: only its rows are scrolled to.
    init(_ pane: SettingsPaneID, @ViewBuilder content: () -> Content) {
        self.pane = pane
        self.content = content()
    }

    var body: some View {
        ScrollViewReader { proxy in
            Form { content }
                .formStyle(.grouped)
                .onAppear { scrollToPendingRow(proxy) }
                .onChange(of: navigator?.highlightSerial) { scrollToPendingRow(proxy) }
        }
    }

    /// Waits one layout pass (the rows of a pane that just appeared do not exist yet), then centres the row with the
    /// theme's `contentSwap` (at once under Reduce Motion).
    private func scrollToPendingRow(_ proxy: ScrollViewProxy) {
        guard let navigator, let row = navigator.takePendingRow(in: pane) else { return }
        let animation = theme.animation(.contentSwap)
        Task { @MainActor in
            await Task.yield()
            withAnimation(animation) { proxy.scrollTo(row, anchor: .center) }
        }
    }
}

#Preview("Settings form") {
    SettingsForm(.general) {
        Section { Text(verbatim: "Row") }
    }
    .frame(width: 500, height: 200)
}
