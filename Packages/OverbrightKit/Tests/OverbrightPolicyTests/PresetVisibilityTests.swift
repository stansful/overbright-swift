// OverbrightPolicyTests/PresetVisibilityTests.swift — which preset ticks a display shows. ARCHITECTURE.md §5.3
// ("Presets per class"), D0 review note #54 (merging walks down from Max).
import Foundation
import OverbrightCore
import Testing
@testable import OverbrightPolicy

@Suite struct PresetVisibilityTests {
    private let all: [LevelPreset] = [.indoor, .brightRoom, .sunlight, .max]
    private func top(_ facts: DisplayFacts, _ mode: CapMode, oled: Bool = false) -> Double {
        GainCeiling.sliderTop(facts: facts, capMode: mode, isOLED: oled)
    }
    private func gains(_ top: Double) -> [Double] {
        all.map { LevelMapping.requestedGain(for: $0.position, top: top) }
    }

    /// §5.3 "Presets per class": the shown presets and their gains at full brightness (to 2 decimals as printed).
    @Test func presetsPerClass() {
        let builtIn = DisplayFixture.builtinXDRLidOpen.displays[0].facts
        let pro = DisplayFixture.proDisplayXDR.displays[0].facts
        let studio = DisplayFixture.studioDisplayXDR.displays[0].facts
        let msi = DisplayFixture.mpg322uxHDROn.displays[0].facts
        let hdr600 = DisplayFacts(ref: DisplayRef(key: DisplayKey(rawValue: "hdr600"), id: 7), name: "", isBuiltIn: false,
                                  gammaCapacity: 1024, supportsPQ: true, panelPeakNits: 600, sdrMaxNits: 300,
                                  panelClass: .hdrExternal)
        let rows: [(name: String, top: Double, shown: [LevelPreset], gains: [Double])] = [
            ("M4 Max Safe", top(builtIn, .safe), all, [1.14, 1.29, 1.47, 1.67]),
            ("M4 Max Peak", top(builtIn, .peak), all, [1.27, 1.61, 2.04, 2.59]),
            ("Pro Display XDR Safe", top(pro, .safe), all, [1.19, 1.41, 1.68, 2.00]),
            ("Pro Display XDR Peak", top(pro, .peak), all, [1.33, 1.76, 2.34, 3.10]),
            ("Studio Display XDR Peak", top(studio, .peak), all, [1.18, 1.39, 1.64, 1.94]),
            ("MSI OLED Safe", top(msi, .safe, oled: true), [.brightRoom, .max], [1.07, 1.14, 1.22, 1.30]),
            ("MSI OLED Peak", top(msi, .peak, oled: true), all, [1.14, 1.31, 1.49, 1.70]),
            ("DisplayHDR 600 at SDR 300 Safe", top(hdr600, .safe), [.max], [1.05, 1.10, 1.15, 1.20]),
        ]
        for row in rows {
            #expect(PresetVisibility.visiblePresets(top: row.top) == row.shown, "\(row.name)")
            for (gain, expected) in zip(gains(row.top), row.gains) {
                #expect(abs(gain - expected) < 0.005, "\(row.name): \(gain) vs \(expected)")
            }
        }
        // Studio Display XDR in Safe: no boost half, so only Max (at ×1) is listed and the half is disabled.
        #expect(top(studio, .safe) == 1 && PresetVisibility.visiblePresets(top: 1) == [.max])
        // "small gain on this display" applies below ×1.3: the OLED's Safe Max is exactly at it, HDR 600 below.
        #expect(top(hdr600, .safe) < 1.3)
    }

    /// The walk keeps a preset only if it is ≥ ×1.1 and ≥ 0.1 stop below the last kept one; Max is always kept.
    @Test func mergingRules() {
        for top in stride(from: 1.0, through: 16, by: 0.01) {
            let shown = PresetVisibility.visiblePresets(top: top)
            #expect(shown.last == .max)
            let shownGains = shown.map { LevelMapping.requestedGain(for: $0.position, top: top) }
            for (index, gain) in shownGains.enumerated().dropLast() {
                #expect(gain >= PresetVisibility.minimumGain - 1e-12)
                #expect(log2(shownGains[index + 1] / gain) >= PresetVisibility.minimumSpacingStops - 1e-12)
            }
            #expect(shown == shown.sorted { $0.position < $1.position })
        }
        #expect(PresetVisibility.visiblePresets(top: 1.3) == [.brightRoom, .max])
        #expect(PresetVisibility.visiblePresets(top: 1.2) == [.max])
        #expect(PresetVisibility.visiblePresets(top: 0.5) == [.max])
    }
}
