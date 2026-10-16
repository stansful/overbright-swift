// OverbrightSettingsUI/Search/SearchTargetModifier.swift — makes a row the scroll target of search results and deep
// links, and washes it with the accent when it is the result (DESIGN.md §7.2: fading over 1 s). Ported from Cranny's
// SettingRow.swift (the owner's MIT code); the wash starts at once under Reduce Motion.
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var wash = 0.0
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
    }

    /// Washes the row when a search result or deep link points at it (also when the row appears later).
    private func flashIfRequested() {
        guard let navigator, navigator.highlightedRow == info.id, navigator.isHighlightFresh else { return }
        wash = SettingsMetrics.highlightOpacity
        withAnimation(.easeOut(duration: SettingsMetrics.highlightFade).delay(reduceMotion ? 0 : 0.25)) { wash = 0 }
    }
}
