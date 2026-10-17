// OverbrightPanelUITests/FillLightCardTests.swift — the panel's Fill Light card (DESIGN.md §5.3, §7.7): warmth in
// kelvin (6,500 K cool … 3,000 K warm, never converted to the locale's temperature unit), Settings' ranges, Turn off
// through the Fill Light control, the card shows only while Fill Light is on, and its controls fill the card (measured
// in a window that is never ordered in).
import AppKit
import OverbrightCore
import OverbrightDesign
import OverbrightTestSupport
import SwiftUI
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

    /// The controls take the rest of the 280-pt inner width (C-PANEL-15): the pop-up and both sliders start at one x,
    /// the pop-up ends no later than the sliders, both sliders end at one x, right before the value column, which ends
    /// at the card's inner edge, so each slider is the inner width less the label column, the value column and the
    /// two gaps.
    @Test func theSlidersTakeTheRestOfTheCard() async throws {
        let services = try #require(ScriptedStatuses.services(named: "fill-light-card"))
        let frames = ReportedFrames<FillLightCard.LayoutPart>()
        let card = FillLightCard(services: services).reportingLayout { frames.parts[$0] = $1 }
        let host = NSHostingView(rootView: card.overbrightThemeRoot().fixedSize())
        host.frame = CGRect(origin: .zero, size: host.fittingSize)
        let window = NSWindow(contentRect: host.frame, styleMask: [.borderless], backing: .buffered, defer: true)
        window.contentView = host
        defer { window.contentView = nil }
        #expect(await eventually {
            host.layoutSubtreeIfNeeded()
            return frames.parts.count == 5
        }, "reported: \(frames.parts.keys)")
        let display = try #require(frames.parts[.display])
        let brightness = try #require(frames.parts[.brightness])
        let warmth = try #require(frames.parts[.warmth])
        let values = try [#require(frames.parts[.brightnessValue]), #require(frames.parts[.warmthValue])]
        let inner = PanelLayout.cardInnerWidth
        let labelColumn = [PanelText.display, PanelText.brightness, PanelText.warmth]
            .map { FitMeasure.textWidth($0, .callout) }.max() ?? 0
        let valueColumn = FillLightCard.widestValues.map { FitMeasure.textWidth($0, .callout.monospacedDigit()) }.max() ?? 0
        func near(_ a: CGFloat, _ b: CGFloat) -> Bool { abs(a - b) <= 0.5 }
        #expect(near(brightness.minX, warmth.minX) && near(brightness.minX, display.minX),
                "starts: pop-up \(display.minX), sliders \(brightness.minX) and \(warmth.minX) pt")
        #expect(display.maxX <= brightness.maxX + 0.5, "the pop-up ends at \(display.maxX) pt, past the sliders")
        #expect(near(brightness.maxX, warmth.maxX), "ends: \(brightness.maxX) and \(warmth.maxX) pt")
        for value in values {
            #expect(near(value.maxX, inner), "the value column ends at \(value.maxX) pt of \(inner)")
            #expect(near(value.minX - brightness.maxX, Space.s), "slider to value: \(value.minX - brightness.maxX) pt")
        }
        for slider in [brightness, warmth] {
            #expect(slider.width >= inner - labelColumn - valueColumn - 2 * Space.s - 0.5,
                    "a slider is \(slider.width) pt of \(inner) less \(labelColumn) + \(valueColumn) + gaps")
        }
    }
}

/// The frames a view reported, by part.
@MainActor final class ReportedFrames<Part: Hashable> {
    var parts: [Part: CGRect] = [:]
}
