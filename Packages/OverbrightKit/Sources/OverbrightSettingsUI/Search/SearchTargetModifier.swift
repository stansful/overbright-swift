// OverbrightSettingsUI/Search/SearchTargetModifier.swift — makes a row the scroll target of search results and deep
// links, and washes it with the accent when it is the result (DESIGN.md §7.2: gone after 1 s). The wash holds
// `SettingsMetrics.highlightHold`, then fades with the theme's `colorShift` (a short cross-fade under Reduce Motion, or
// none where the theme gives no animation). Ported from Cranny's SettingRow.swift (the owner's MIT code).
import Foundation
import OverbrightDesign
import SwiftUI

extension View {
    /// Scroll target and search highlight of one row (read-only rows use this alone; rows with a value use
    /// `settingRow`).
    func searchTarget(_ info: SettingsRowInfo) -> some View { modifier(SearchTargetModifier(info: info)) }
}

/// Scroll target and search highlight of one row.
struct SearchTargetModifier: ViewModifier {
    @Environment(SettingsNavigator.self) private var navigator: SettingsNavigator?
    @Environment(\.overbright) private var theme
    @State private var wash = 0.0
    /// Counts the flashes; a new one restarts the hold (`task(id:)` cancels the last).
    @State private var flashes = 0
    let info: SettingsRowInfo

    func body(content: Content) -> some View {
        content
            .id(info.id)
            .background {
                RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
                    .fill(Color.accentColor.opacity(wash))
                    .padding(.horizontal, -Space.s)
                    .padding(.vertical, -Space.xs)
                    .allowsHitTesting(false)
            }
            .onAppear(perform: flashIfRequested)
            .onChange(of: navigator?.highlightSerial) { flashIfRequested() }
            .task(id: flashes) {
                guard flashes > 0 else { return }
                try? await Task.sleep(for: SettingsMetrics.highlightHold)
                guard !Task.isCancelled else { return }
                withAnimation(theme.animation(.colorShift)) { wash = 0 }
            }
    }

    /// Washes the row when a search result or deep link points at it (also when the row appears later).
    private func flashIfRequested() {
        guard let navigator, navigator.highlightedRow == info.id, navigator.isHighlightFresh else { return }
        wash = SettingsMetrics.highlightOpacity
        flashes += 1
    }
}

#Preview("Search highlight") {
    Form {
        Text(verbatim: "Row a search found").searchTarget(SettingsRowInfo(.general, "found", title: "Row a search found"))
        Text(verbatim: "Another row").searchTarget(SettingsRowInfo(.general, "other", title: "Another row"))
    }
    .formStyle(.grouped)
    .environment(SettingsNavigator(target: "general#found"))
    .frame(width: 420, height: 160)
}
