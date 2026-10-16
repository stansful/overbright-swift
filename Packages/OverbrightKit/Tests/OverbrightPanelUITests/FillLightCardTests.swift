// OverbrightPanelUITests/FillLightCardTests.swift — the panel's Fill Light card (DESIGN.md §5.3, §7.7): warmth in
// kelvin (6,500 K cool … 3,000 K warm, never converted to the locale's temperature unit), Settings' ranges, Turn off
// through the Fill Light control, and the card shows only while Fill Light is on.
import OverbrightCore
import Testing
@testable import OverbrightPanelUI

@MainActor @Suite struct FillLightCardTests {
    @Test func warmthIsShownInKelvin() {
        #expect(FillLightCard.kelvin(warmth: 0) == 6500)
        #expect(FillLightCard.kelvin(warmth: 1) == 3000)
        #expect(FillLightCard.kelvin(warmth: 0.4) == 5100)                    // the default, ≈ 5,100 K
        #expect(FillLightCard.kelvin(warmth: 2) == 3000)                      // clamped
        let text = FillLightCard.kelvinText(warmth: 0.4)
        #expect(text.contains("K") && !text.contains("°"))
        #expect(text.filter(\.isNumber) == "5100")
    }

    @Test func theRangesAreSettings() {
        #expect(FillLightCard.brightnessRange == 0.2...1)
        #expect(FillLightCard.warmthRange == 0...1)
    }

    @Test func theCardShowsOnlyWhileFillLightIsOn() throws {
        let on = try #require(ScriptedStatuses.services(named: "fill-light-card"))
        let off = try #require(ScriptedStatuses.services(named: "boosting"))
        #expect(PanelView(services: on).content.showsFillLightCard)
        #expect(!PanelView(services: off).content.showsFillLightCard)
        let fill = try #require(on.fillLight as? PreviewFillLightControl)
        fill.setOn(false, source: .panel)
        #expect(!PanelView(services: on).content.showsFillLightCard)
    }
}
