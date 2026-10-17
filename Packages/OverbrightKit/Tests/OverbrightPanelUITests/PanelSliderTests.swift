// OverbrightPanelUITests/PanelSliderTests.swift — the Fill Light card's sliders (DESIGN.md §5.3, §15, §17): drawn in
// shapes at the small control size, the thumb's centre a radius in from either end, a press or drag setting the value
// under it (mirrored right to left), VoiceOver adjusting by the card's keyboard step within the range; and no panel
// source draws a system slider or switch, whose Liquid Glass knob renders with in-process Metal on every showing.
import Foundation
import SwiftUI
import Testing
@testable import OverbrightPanelUI

@MainActor @Suite struct PanelSliderTests {
    private let range = FillLightCard.brightnessRange
    private let width: CGFloat = 162.5

    @Test func theThumbTravelsTheTrackARadiusInFromEitherEnd() {
        let radius = PanelSlider.thumbSize / 2
        #expect(PanelSlider.x(of: 0, width: width) == radius)
        #expect(PanelSlider.x(of: 1, width: width) == width - radius)
        #expect(PanelSlider.fraction(of: range.lowerBound, in: range) == 0)
        #expect(PanelSlider.fraction(of: range.upperBound, in: range) == 1)
        #expect(abs(PanelSlider.fraction(of: 0.6, in: range) - 0.5) < 1e-9)
        #expect(PanelSlider.fraction(of: 5, in: range) == 1 && PanelSlider.fraction(of: -5, in: range) == 0)
        #expect(PanelSlider.height == 14)
    }

    @Test func aPressSetsTheValueUnderItMirroredRightToLeft() {
        for value in stride(from: range.lowerBound, through: range.upperBound, by: 0.05) {
            let x = PanelSlider.x(of: PanelSlider.fraction(of: value, in: range), width: width)
            let back = PanelSlider.value(atPhysicalX: x, width: width, in: range, direction: .leftToRight)
            #expect(abs(back - value) < 1e-9, "\(value)")
            let mirrored = PanelSlider.value(atPhysicalX: width - x, width: width, in: range, direction: .rightToLeft)
            #expect(abs(mirrored - value) < 1e-9, "\(value) right to left")
        }
        #expect(PanelSlider.value(atPhysicalX: -20, width: width, in: range, direction: .leftToRight) == range.lowerBound)
        #expect(PanelSlider.value(atPhysicalX: width + 20, width: width, in: range, direction: .leftToRight)
                == range.upperBound)
    }

    @Test func voiceOverAdjustsByTheKeyboardStepWithinTheRange() throws {
        let step = FillLightCard.brightnessStep
        let up = try #require(PanelSlider.adjusted(0.5, by: .increment, in: range, step: step))
        let down = try #require(PanelSlider.adjusted(0.5, by: .decrement, in: range, step: step))
        #expect(abs(up - 0.55) < 1e-9 && abs(down - 0.45) < 1e-9)
        #expect(PanelSlider.adjusted(1, by: .increment, in: range, step: step) == 1)
        #expect(PanelSlider.adjusted(0.2, by: .decrement, in: range, step: step) == 0.2)
    }

    /// The panel's own sources build no system `Slider` and no `.switch` toggle (the master switch has its own style,
    /// the sliders are `BoostSlider` and `PanelSlider`), so opening the panel costs no Metal (DESIGN.md §17).
    @Test func noPanelSourceDrawsASystemSliderOrSwitch() throws {
        let sources = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().appending(path: "Sources/OverbrightPanelUI")
        let files = try #require(FileManager.default.enumerator(at: sources, includingPropertiesForKeys: nil))
            .compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" }
        #expect(files.count > 20)
        let systemSlider = /(^|[^A-Za-z])Slider\s*\(/
        for file in files {
            let text = try String(contentsOf: file, encoding: .utf8)
            for (number, line) in text.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
                let code = line.split(separator: "//", maxSplits: 1, omittingEmptySubsequences: false).first ?? ""
                #expect(code.firstMatch(of: systemSlider) == nil, "\(file.lastPathComponent):\(number + 1)")
                #expect(!code.contains(".toggleStyle(.switch)"), "\(file.lastPathComponent):\(number + 1)")
            }
        }
    }
}
