// OverbrightDesignTests/DesignSeamTests.swift — the Design seam (ARCHITECTURE.md §10.0): every component and copy
// builder keeps its fixed signature, the builders now write words in the app's language, and the components build
// over the preview services.
import OverbrightCore
import OverbrightPolicy
import SwiftUI
import Testing
@testable import OverbrightDesign

@MainActor @Suite struct DesignSeamTests {
    /// The fixed builders answer in the app's language (whatever it is: only presence is checked here; the English
    /// words are checked by each builder's suite).
    @Test func theCopyBuildersWrite() throws {
        let chip = try #require(ChipModel.make(reason: .headroom, phase: .boosted, failedTries: 0))
        #expect(!chip.text.isEmpty && !chip.explanation.isEmpty)
        #expect(!BannerModel.make(.lowPowerMode).sentence.isEmpty)
        #expect(!VerdictText.make(.turnOnHDR, advisories: [.oledCare], lastGrant: nil).sentence.isEmpty)
        let change = LevelChange(sequence: 1, kind: .timerEnded, source: .automation, display: nil)
        #expect(HUDText.make(change, status: .initial)?.reason?.isEmpty == false)
        let values = ReadoutValues(state: .boost, appliedGain: 1.29, requestedGain: nil, nits: nil, preset: .brightRoom,
                                   isEstimate: true, dimPercent: nil)
        #expect(!ValueText.make(values).text.isEmpty)
    }

    @Test func theComponentsBuild() {
        var level = LevelPosition.standard
        let binding = Binding(get: { level }, set: { level = $0 })
        let model = ChipModel(symbol: .hourglass, color: .info, text: "", explanation: "", accessibilityLabel: "")
        _ = BoostSlider(level: binding, top: 1.67, allowedNow: 1.55, presets: [.brightRoom, .max], dimEnabled: true,
                        boostHalf: .active, accessibilityName: "", valueText: { _ in "" }, onCommit: { _ in })
            .spokenValue { _ in "" }
            .extraRange(ValueText.extraRange(allowed: 1.55, peak: 2.6))
            .dimmedLevel(LevelMapping.position(forDimLight: 0.25))
            .dimHalfReason(nil)
            .focusBinding(nil as FocusState<Int?>.Binding?, equals: 0)
        _ = StatusChip(model, actions: [ChipAction(title: "", perform: {})])
        _ = GuardChip(GuardChipModel(symbol: .timer, text: "", accessibilityLabel: ""),
                      menu: [.item(title: "", isChecked: true, perform: {}), .separator, .submenu(title: "", items: [])])
        _ = PausedBanner(BannerModel.make(.focusOff), primary: {}, secondary: nil)
        _ = EDRPreviewSurface(gain: 1.6, divider: .constant(0.5), simulated: true)
        _ = StepWedgeView(patches: [0.95, 1], surround: 0)
        _ = KeyCap("")
        _ = ReadoutText(ReadoutValues(state: .off, appliedGain: 1, requestedGain: nil, nits: nil, preset: nil,
                                      isEstimate: false, dimPercent: nil))
        _ = Text(verbatim: "").overbrightFocusRing().overbrightThemeRoot()
        let settings = SettingsStore(defaults: InMemoryDefaults())
        let showsHUD = settings.binding(GeneralSettings.showsHUD)
        showsHUD.wrappedValue = false
        #expect(settings[GeneralSettings.showsHUD] == false, "the binding writes the setting")
        #expect(!settings.isDefault(GeneralSettings.showsHUD))
    }

    @Test func reduceMotionPlaysNoScaleOrSnap() {
        #expect(OverbrightTheme(reduceMotion: true).animation(.press) == nil)
        #expect(OverbrightTheme(reduceMotion: true).animation(.detentSnap) == nil)
        #expect(OverbrightTheme(reduceMotion: true).animation(.panelIn) != nil, "a cross-fade")
        #expect(OverbrightTheme().animation(.panelIn) != nil)
        #expect(OverbrightTheme(increaseContrast: true).palette == .highContrast)
        #expect(Set(OverbrightSymbol.allCases.map(\.rawValue)).count == OverbrightSymbol.allCases.count)
        #expect(OverbrightDesignModule.name == "OverbrightDesign")
    }

    /// The setting-row conventions: their words, and the dot's size.
    @Test func settingRowConventions() {
        #expect(SettingRowConventions.resetToDefault(in: english) == "Reset to Default")
        #expect(SettingRowConventions.changed(in: english) == "Changed from the default")
        #expect(SettingRowConventions.changedDot == 6 && SettingRowConventions.changedDotGap == 4)
    }

    /// The step wedge lays its 100-pt patches out centred with 16-pt gaps, and fills code values unchanged.
    @Test func theStepWedgeGeometry() throws {
        let frames = StepWedgeView.patchFrames(count: 4, in: CGRect(x: 0, y: 0, width: 600, height: 200))
        #expect(frames.count == 4)
        #expect(frames.allSatisfy { $0.size == CGSize(width: 100, height: 100) })
        #expect(abs(frames[0].minX - (600 - (4 * 100 + 3 * 16)) / 2) < 1e-9)
        #expect(abs(frames[1].minX - frames[0].maxX - 16) < 1e-9)
        let space = try #require(CGColorSpace(name: CGColorSpace.displayP3))
        #expect(CodeValueView.components(0.95, in: space) == [0.95, 0.95, 0.95, 1])
        #expect(StepWedgeView.minimumWidth(count: 4) == CGFloat(4 * 100 + 3 * 16 + 64))
    }

    /// The welcome card's stand-in shows Standard at 1 / gain of the light (sRGB-encoded), white beside it.
    @Test func theWelcomeStandIn() throws {
        #expect(abs(EDRPreviewSurface.standInGrey(gain: 1.29) - FactorMath.encodeSRGB(1 / 1.29)) < 1e-12)
        #expect(abs(EDRPreviewSurface.standInGrey(gain: 1) - 1) < 1e-9)
        var divider = 0.5
        let card = EDRPreviewSurface(gain: 1.6, divider: Binding(get: { divider }, set: { divider = $0 }), simulated: true)
        let pixels = try render(card, size: CGSize(width: 200, height: 100))
        let before = pixels.pixel(x: 8, y: 100), after = pixels.pixel(x: 392, y: 100)
        #expect(after.r > before.r + 0.05, "the brighter side is lighter in the stand-in: \(before.r) vs \(after.r)")
        #expect(EDRPreviewSurface.dividerLabel(in: english) == "Before and after")
    }
}
