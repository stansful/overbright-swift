// OverbrightDesignTests/DesignSeamTests.swift — the Design seam (ARCHITECTURE.md §10.0): every component and copy
// builder of the fixed signatures builds, the builders are neutral until WP9 writes the copy, and the theme drops
// motion under Reduce Motion. WP9 adds ContrastAuditTests, SymbolTests, BoostSliderTests and the copy suites.
import OverbrightCore
import OverbrightPolicy
import SwiftUI
import Testing
@testable import OverbrightDesign

@MainActor @Suite struct DesignSeamTests {
    @Test func theCopyBuildersAreNeutral() {
        #expect(ChipModel.make(reason: .headroom, phase: .boosted, failedTries: 0) == nil)
        #expect(BannerModel.make(.lowPowerMode).sentence.isEmpty)
        #expect(VerdictText.make(.turnOnHDR, advisories: [.oledCare], lastGrant: nil).sentence.isEmpty)
        let change = LevelChange(sequence: 1, kind: .level, source: .shortcut, display: nil)
        #expect(HUDText.make(change, status: .initial) == nil)
        let values = ReadoutValues(state: .boost, appliedGain: 1.29, requestedGain: nil, nits: nil, preset: .brightRoom,
                                   isEstimate: true, dimPercent: nil)
        #expect(ValueText.make(values).text.isEmpty)
    }

    @Test func theComponentsBuild() {
        var level = LevelPosition.standard
        let binding = Binding(get: { level }, set: { level = $0 })
        let model = ChipModel(symbol: .hourglass, color: .info, text: "", explanation: "", accessibilityLabel: "")
        _ = BoostSlider(level: binding, top: 1.67, allowedNow: 1.55, presets: [.brightRoom, .max], dimEnabled: true,
                        boostHalf: .active, accessibilityName: "", valueText: { _ in "" }, onCommit: { _ in })
        _ = StatusChip(model, actions: [ChipAction(title: "", perform: {})])
        _ = GuardChip(GuardChipModel(symbol: .timer, text: "", accessibilityLabel: ""),
                      menu: [.item(title: "", isChecked: true, perform: {}), .separator,
                             .submenu(title: "", items: [])])
        _ = PausedBanner(BannerModel.make(.focusOff), primary: {}, secondary: nil)
        _ = EDRPreviewSurface(gain: 1.6, divider: .constant(0.5), simulated: true)
        _ = StepWedgeView(patches: [0.95, 1], surround: 0)
        _ = KeyCap("")
        _ = Text(verbatim: "").overbrightFocusRing().overbrightThemeRoot()
        _ = SettingsStore(defaults: InMemoryDefaults()).binding(GeneralSettings.showsHUD)
    }

    @Test func reduceMotionPlaysNoAnimation() {
        #expect(OverbrightTheme(reduceMotion: true).animation(.panelIn) == nil)
        #expect(OverbrightTheme().animation(.panelIn) != nil)
        #expect(OverbrightTheme(increaseContrast: true).palette == .highContrast)
        #expect(Set(OverbrightSymbol.allCases.map(\.rawValue)).count == OverbrightSymbol.allCases.count)
    }
}
