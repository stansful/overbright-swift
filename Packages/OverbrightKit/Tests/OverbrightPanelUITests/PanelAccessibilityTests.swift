// OverbrightPanelUITests/PanelAccessibilityTests.swift — every control of the panel has a VoiceOver label (DESIGN.md
// §12.7, §15; ARCHITECTURE.md §9.1 UI row: "accessibilityLabel non-empty"). SwiftUI vends its accessibility tree only
// to an accessibility client, so the test walks the models instead: for every element of the panel's Tab order in each
// key state, the words the view gives it as its label (an explicit label for icon-only controls: the switch, "⋯", the
// slider, the chips; the title for a button), in the app's language and in every shipped one for the panel's own
// words. A control whose model has no words fails here before VoiceOver reads "button".
import Foundation
import OverbrightCore
@testable import OverbrightDesign
import Testing
@testable import OverbrightPanelUI

@MainActor @Suite struct PanelAccessibilityTests {
    /// The label of `focus` in the panel of `services`, from the builders its view uses.
    private func label(of focus: PanelFocus, _ services: OverbrightServices) -> String? {
        let status = services.boost.status
        let view = PanelView(services: services)
        let content = view.content
        let titles = CardTitles.titles(for: status.displays)
        func card(_ key: DisplayKey) -> DisplayCardModel? {
            status.displays.first { $0.key == key }.map { DisplayCardModel(status: $0, isMasterOn: status.isOn,
                                                                          services: services) }
        }
        let chips = FooterChips.chips(settings: services.settings, hasBattery: content.showsBatteryChip,
                                      autoOffAt: status.autoOffAt, now: services.time.wallClock, editApps: {})
        func footer(_ kind: FooterChip.Kind) -> String? { chips.first { $0.kind == kind }?.model.accessibilityLabel }
        switch focus {
        case .masterSwitch: return "Overbright"
        case .slider(let key): return titles[key].map { BoostSlider.label($0) }
        case .chip(let key): return card(key).flatMap { CardChip.model(for: $0, isMasterOn: status.isOn) }?.accessibilityLabel
        case .turnOn: return CardAction.turnOnExtraBrightness.title
        case .why: return PanelText.why
        case .fix(let key):
            let verdict = status.displays.first { $0.key == key }?.decision?.eligibility.verdict ?? .checking
            return VerdictText.make(verdict, advisories: [], lastGrant: nil).fixTitle ?? CardAction.openDisplaySettings.title
        case .learnMore: return PanelText.learnMore
        case .bannerPrimary, .bannerSecondary:
            return status.banner.flatMap { BannerModel.make($0, displayNames: titles, in: .app).primaryTitle }
        case .tipCalibrate: return PanelText.calibrate
        case .tipNotNow: return PanelText.notNow
        case .footerBattery: return footer(.battery)
        case .footerAutoPause: return footer(.autoPause)
        case .footerTimer: return footer(.timer)
        case .fillLightDisplay: return PanelText.display
        case .fillLightBrightness: return PanelText.brightness
        case .fillLightWarmth: return PanelText.warmth
        case .fillLightTurnOff: return PanelText.turnOff
        case .overflow: return PanelText.overflowLabel
        }
    }

    @Test(arguments: ["boosting", "extra-brightness-off", "banner-low-power", "banner-paused", "why-expanded",
                      "fill-light-card", "calibration-tip", "no-extra-range", "conflict-booster", "four-displays"])
    func everyControlHasALabel(_ name: String) throws {
        let services = try #require(ScriptedStatuses.services(named: name))
        services.settings[OnboardingSettings.calibrationTipShown] = name != "calibration-tip"
        let view = PanelView(services: services, expandsWhy: true)
        let order = view.focusOrder(view.content, status: services.boost.status).order
        #expect(order.count >= 5, "\(name)")
        let unlabelled = order.filter { (label(of: $0, services) ?? "").trimmingCharacters(in: .whitespaces).isEmpty }
        #expect(unlabelled.isEmpty, "\(name): no label for \(unlabelled)")
        let footer = [PanelFocus.footerBattery, .footerAutoPause, .footerTimer].compactMap { label(of: $0, services) }
        #expect(Set(footer).count == footer.count, "\(name): footer chips share a label")
    }

    /// The panel's own words for its icon-only and button controls exist in every shipped language.
    @Test(arguments: ShippedLanguages.codes)
    func thePanelsControlWordsExistInEveryLanguage(_ code: String) throws {
        let bundle = try #require(ShippedLanguages.panel(code), "\(code): no PanelUI table")
        let locale = Locale(identifier: code)
        for key in ["More", "Why?", "Learn more", "Not now", "Calibrate…", "Display", "Brightness", "Warmth", "Turn off",
                    "Turn on", "Battery limit", "Auto-pause", "Timer", "Cool", "Warm"] {
            let text = String(localized: String.LocalizationValue(key), bundle: bundle, locale: locale)
            #expect(!text.trimmingCharacters(in: .whitespaces).isEmpty, "\(code): «\(key)»")
        }
    }
}
