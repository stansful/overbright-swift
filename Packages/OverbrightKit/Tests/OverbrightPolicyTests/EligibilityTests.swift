// OverbrightPolicyTests/EligibilityTests.swift — the D8 classifier: every verdict in order, the fixtures of §3.9, the
// OLED override, advisories and class defaults, and identical verdicts under Russian names (no name logic).
// ARCHITECTURE.md D8, §3.2, §5.3, §6.1 steps 1–4, §7.5; DESIGN.md §12.1.
import CoreGraphics
import Foundation
import OverbrightCore
import Testing
@testable import OverbrightPolicy

@Suite struct EligibilityTests {
    private let owner = DisplayFixture.ownerMachine

    private func classify(_ display: FixtureDisplay, preferences: DisplayPreferences = DisplayPreferences(),
                          reading: HeadroomReading?? = nil,
                          machine: MachineIdentity = DisplayFixture.ownerMachine) -> EligibilityResult {
        let defaultReading = display.headroom.hasOwnScreen ? PolicyTestInputs.reading(display, granted: false) : nil
        return EligibilityClassifier.classify(display.facts, preferences: preferences, reading: reading ?? defaultReading,
                                              machine: machine)
    }
    private func external(_ panelClass: PanelClass, pq: Bool?, peak: Double? = 600, frameAverage: Double? = 300,
                          minNits: Double? = nil, capacity: Int = 1024, mirrored: Bool = false) -> FixtureDisplay {
        FixtureDisplay(facts: DisplayFacts(ref: DisplayRef(key: DisplayKey(rawValue: "ext"), id: 8), name: "Ext",
                                           isBuiltIn: false, isMirrored: mirrored, gammaCapacity: capacity,
                                           supportsPQ: pq, panelPeakNits: peak, panelFrameAverageNits: frameAverage,
                                           panelMinNits: minNits, panelClass: panelClass),
                       headroom: HeadroomScript(potential: (peak ?? 100) / 100, grant: 1.5), profileBase: .identity(count: 1024))
    }
    private func gains(_ verdict: DisplayVerdict) -> (safe: Double?, peak: Double)? {
        if case .supported(let safe, let peak) = verdict { (safe, peak) } else { nil }
    }

    /// The verdict of every display fixture (§3.9), and its gains from the default ceilings (§5.3).
    @Test func fixtureVerdicts() throws {
        let builtIn = try #require(gains(classify(PolicyTestInputs.builtIn).verdict))
        #expect(abs((builtIn.safe ?? 0) - 1.667) < 0.0005 && abs(builtIn.peak - 2.587) < 0.0005)
        let pro = try #require(gains(classify(DisplayFixture.proDisplayXDR.displays[0]).verdict))
        #expect(abs((pro.safe ?? 0) - 2.0) < 0.0005 && abs(pro.peak - 3.104) < 0.0005)
        let studio = try #require(gains(classify(DisplayFixture.studioDisplayXDR.displays[0]).verdict))
        #expect(studio.safe == nil && abs(studio.peak - 1.940) < 0.0005)                 // Safe adds nothing
        let msi = try #require(gains(classify(PolicyTestInputs.msi).verdict))
        #expect(abs((msi.safe ?? 0) - 1.3) < 0.0005 && abs(msi.peak - 1.704) < 0.0005)
        #expect(classify(DisplayFixture.builtinXDRPreset600.displays[0]).verdict
                == .presetLimits(presetPeakNits: 600, panelPeakNits: 1600))
        #expect(classify(DisplayFixture.mpg322uxHDROff.displays[0]).verdict == .turnOnHDR)
        #expect(classify(DisplayFixture.lcdOnly.displays[0], machine: DisplayFixture.lcdOnly.machine).verdict == .lcdClass)
        #expect(classify(DisplayFixture.sidecar.displays[1]).verdict == .virtualDisplay)
        #expect(classify(PolicyTestInputs.projector).verdict == .mirrored)
        let neo = DisplayFixture.neoIgnoresWrites
        #expect(gains(classify(neo.displays[0], machine: neo.machine).verdict) != nil)
        #expect(gains(classify(DisplayFixture.calibratedProfile.displays[0]).verdict) != nil)
    }

    /// D8 order: virtual, no table, mirror, no reading or a transient potential, reference, potential ≤ 1, ≤ 2, the
    /// preset below 90 % of the panel peak, panel facts unknown, little gain, supported. ε = 0.01 on every headroom
    /// comparison.
    @Test func theD8Order() {
        let builtIn = PolicyTestInputs.builtIn
        func verdict(_ display: FixtureDisplay = builtIn, potential: Double = 16, reference: Double = 0) -> DisplayVerdict {
            classify(display, reading: PolicyTestInputs.reading(display, potential: potential, reference: reference)).verdict
        }
        #expect(verdict(external(.virtualDisplay, pq: nil, capacity: 0)) == .virtualDisplay)
        #expect(verdict(external(.virtualDisplay, pq: nil, capacity: 1024)) == .virtualDisplay)
        #expect(verdict(external(.hdrExternal, pq: true, capacity: 0)) == .noGammaTable)
        #expect(verdict(external(.hdrExternal, pq: true, mirrored: true)) == .mirrored)
        #expect(classify(builtIn, reading: .some(nil)).verdict == .checking)                       // no reading yet
        #expect(verdict(potential: 0) == .checking && verdict(potential: 0.98) == .checking)        // transient
        #expect(verdict(potential: 0.995) == .switchPreset)                                          // within ε of 1
        #expect(verdict(reference: 10) == .referencePreset)
        #expect(verdict(reference: 0.005) != .referencePreset)
        #expect(verdict(potential: 1.0) == .switchPreset)                                            // built-in XDR, SDR preset
        #expect(verdict(DisplayFixture.proDisplayXDR.displays[0], potential: 1) == .switchPreset)    // Apple XDR external
        #expect(verdict(external(.hdrExternal, pq: true), potential: 1) == .turnOnHDR)
        #expect(verdict(external(.oledExternal, pq: true), potential: 1) == .turnOnHDR)
        #expect(verdict(external(.sdrExternal, pq: false), potential: 1) == .notHDR)
        #expect(verdict(external(.sdrExternal, pq: nil), potential: 1) == .notHDR)
        #expect(verdict(DisplayFixture.lcdOnly.displays[0], potential: 1) == .lcdClass)
        #expect(verdict(potential: 2.0) == .lcdClass && verdict(potential: 2.009) == .lcdClass)
        #expect(verdict(potential: 10) == .presetLimits(presetPeakNits: 1000, panelPeakNits: 1600))
        #expect(gains(verdict(potential: 14.5)) != nil)                                             // 1450 ≥ 0.9 × 1600
        // Peak gain below ×1.1 at full brightness: 0.97 × 420 ÷ 380 = ×1.072; below ×1.05 the half is disabled (×1).
        let little = external(.hdrExternal, pq: true, peak: 420, frameAverage: 380)
        guard case .noGainAtFullBrightness(let peak) = verdict(little, potential: 4.2) else {
            Issue.record("expected little gain"); return
        }
        #expect(abs(peak - 0.97 * 420 / 380) < 1e-9)
        let none = external(.hdrExternal, pq: true, peak: 400, frameAverage: 380)
        #expect(verdict(none, potential: 4) == .noGainAtFullBrightness(peakGain: 1))
        #expect(verdict(external(.hdrExternal, pq: true, peak: 400, frameAverage: 350), potential: 4)
                == .supported(safeGain: nil, peakGain: 0.97 * 400 / 350))                          // ×1.109
        // Unknown panel facts never become a number: the boost half is answered as ×1, and the verdict claims no
        // gain ("little gain" would quote a number nothing measured) and keeps the dim half (`.checking` would hold
        // it), C-PLATFORM-3.
        let unknown = external(.hdrExternal, pq: true, peak: nil, frameAverage: nil)
        #expect(GainCeiling.sliderTop(facts: unknown.facts, capMode: .peak, isOLED: false) == 1)
        #expect(verdict(unknown, potential: 6) == .panelFactsUnknown)
        for display in Self.unbackedTops(builtIn: builtIn) {
            let unbacked = verdict(display, potential: display.headroom.potential)
            #expect(unbacked == .panelFactsUnknown && unbacked.allowsDim && !unbacked.allowsBoost, "\(display.facts.name)")
        }
        #expect(verdict(external(.oledExternal, pq: true, peak: nil, frameAverage: 265), potential: 4.65)
                == .panelFactsUnknown)
        // A known peak still meets the preset rule first; the facts' gap decides only after it.
        #expect(verdict(external(.hdrExternal, pq: true, peak: 1000, frameAverage: nil), potential: 6)
                == .presetLimits(presetPeakNits: 600, panelPeakNits: 1000))
        #expect(verdict(external(.hdrExternal, pq: true, peak: 600, frameAverage: nil), potential: 6) == .panelFactsUnknown)
        // A class that never boosts keeps its own verdict, and known facts keep theirs.
        #expect(verdict(external(.sdrExternal, pq: false, peak: nil, frameAverage: nil), potential: 1) == .notHDR)
        #expect(gains(verdict(DisplayFixture.proDisplayXDR.displays[0])) != nil)
    }

    /// Displays of a boosting class whose panel peak or SDR maximum no source gives (every fallback of §5.1 spent):
    /// an HDR external on an Intel Mac (no `IOMobileFramebufferShim`: the peak is potential × 100, no frame average),
    /// an Apple-silicon HDR external whose EDID has no MaxFrameAverage, the built-in without
    /// `user-accessible-max-nits`, and an Apple XDR external whose product ID `AppleXDRProducts` does not list.
    static func unbackedTops(builtIn: FixtureDisplay) -> [FixtureDisplay] {
        func external(_ name: String, pq: Bool?, peak: Double, potential: Double) -> FixtureDisplay {
            FixtureDisplay(facts: DisplayFacts(ref: DisplayRef(key: DisplayKey(rawValue: name), id: 9), name: name,
                                               isBuiltIn: false, gammaCapacity: 1024, supportsPQ: pq,
                                               panelPeakNits: peak, panelClass: .hdrExternal),
                           headroom: HeadroomScript(potential: potential, grant: 1.5), profileBase: .identity(count: 1024))
        }
        var noSDRMax = builtIn
        noSDRMax.facts.sdrMaxNits = nil                                                            // key missing
        var unlistedXDR = DisplayFixture.proDisplayXDR.displays[0]
        unlistedXDR.facts.productID = 0xAE99
        unlistedXDR.facts.sdrMaxNits = nil                         // what the builder gives an unlisted product
        return [external("Intel HDR external", pq: nil, peak: 465.49, potential: 4.6549),
                external("HDR external without frame average", pq: true, peak: 600, potential: 6),
                noSDRMax, unlistedXDR]
    }

    /// The reducer keeps the dim half of a display without a backed top and stops only its boost half, with the
    /// verdict as the reason (§6.1 row 2; C-PLATFORM-3: `.checking` there took dimming away, and
    /// `noGainAtFullBrightness(peakGain: 1)` claimed a gain nothing measured).
    @Test func anUnbackedTopStillDims() throws {
        for display in Self.unbackedTops(builtIn: PolicyTestInputs.builtIn) {
            let name = display.facts.name
            let key = display.facts.ref.key
            let dim = try #require(BoostPolicy.reduce(PolicyTestInputs.input(
                [PolicyTestInputs.display(display, level: LevelPosition(-0.5))])).displays[key], "\(name)")
            #expect(abs((dim.dimLight ?? 0) - LevelMapping.dimLight(for: LevelPosition(-0.5))) < 1e-12, "\(name)")
            #expect(dim.reasons.isEmpty && dim.eligibility.verdict.allowsDim, "\(name)")
            let boost = try #require(BoostPolicy.reduce(PolicyTestInputs.input(
                [PolicyTestInputs.display(display, boostEnabled: true)])).displays[key], "\(name)")
            #expect(boost.target == .neutral, "\(name)")
            #expect(boost.reasons.first == .notSupported(.panelFactsUnknown), "\(name)")
        }
    }

    /// OLED by IORegistry minimum luminance or the user's override, never by name (D8); defaults per class.
    @Test func oledOverrideAndClassDefaults() {
        let msi = PolicyTestInputs.msi
        #expect(EligibilityClassifier.isOLED(msi.facts, override: .automatic))
        #expect(!EligibilityClassifier.isOLED(msi.facts, override: .notOLED))
        let selfEmissive = external(.hdrExternal, pq: true, minNits: 0.0003)
        #expect(EligibilityClassifier.isOLED(selfEmissive.facts, override: .automatic))
        #expect(!EligibilityClassifier.isOLED(external(.hdrExternal, pq: true, minNits: 0.05).facts, override: .automatic))
        #expect(!EligibilityClassifier.isOLED(PolicyTestInputs.builtIn.facts, override: .automatic))
        #expect(EligibilityClassifier.isOLED(external(.hdrExternal, pq: true).facts, override: .oled))
        // An Apple XDR external's mini-LED black level can read ≤ 0.005 nits: still not an OLED (D8, XDR first).
        var xdrBlack = DisplayFixture.proDisplayXDR.displays[0].facts
        xdrBlack.panelMinNits = 0.0005
        #expect(!EligibilityClassifier.isOLED(xdrBlack, override: .automatic))
        #expect(EligibilityClassifier.isOLED(xdrBlack, override: .oled))
        #expect(classify(FixtureDisplay(facts: xdrBlack, headroom: DisplayFixture.proDisplayXDR.displays[0].headroom,
                                        profileBase: .identity(count: 1024))).defaultBoostEnabled)

        // Built-in XDR and Apple XDR externals are on by default; other HDR and OLED externals are opt-in.
        #expect(classify(PolicyTestInputs.builtIn).defaultBoostEnabled)
        #expect(classify(DisplayFixture.proDisplayXDR.displays[0]).defaultBoostEnabled)
        #expect(!classify(msi).defaultBoostEnabled)
        #expect(!classify(external(.hdrExternal, pq: true)).defaultBoostEnabled)
        #expect(!classify(PolicyTestInputs.builtIn, preferences: DisplayPreferences(oled: .oled)).defaultBoostEnabled)
        // The override changes the gains: the MSI as "Not OLED" gets the HDR-external Safe rule.
        let notOLED = classify(msi, preferences: DisplayPreferences(oled: .notOLED))
        #expect(gains(notOLED.verdict).map { abs(($0.safe ?? 0) - 279.294 / 265.05) < 0.0005 } == true)
        #expect(!notOLED.advisories.contains(.oledCare))
    }

    @Test func advisories() {
        let builtIn = classify(PolicyTestInputs.builtIn)
        #expect(builtIn.advisories == [.autoBrightnessInteracts, .notCalibrated])
        #expect(builtIn.defaultMechanism == .table)
        #expect(classify(PolicyTestInputs.msi).advisories == [.oledCare, .notCalibrated])
        // macOS 25 or earlier: no auto-brightness advisory.
        let older = MachineIdentity(model: "Mac16,5", osBuild: "24A1", osMajor: 15, osMinor: 6, osPatch: 0)
        #expect(!classify(PolicyTestInputs.builtIn, machine: older).advisories.contains(.autoBrightnessInteracts))
        // A Mac that ignores color table changes (§7.5): the table stays the default, and a display that can neither
        // boost nor dim gets no advisory there either.
        let neo = DisplayFixture.neoIgnoresWrites
        #expect(classify(neo.displays[0], machine: neo.machine).defaultMechanism == .table)
        #expect(classify(DisplayFixture.sidecar.displays[1], machine: neo.machine).advisories.isEmpty)
        // Displays that cannot boost get no boost advisories.
        #expect(classify(DisplayFixture.mpg322uxHDROff.displays[0]).advisories.isEmpty)
    }

    /// `notCalibrated` disappears only with a confirmed, still-valid record for the effective mechanism, which is the
    /// table for every preference while Compatibility mode is unavailable; a valid "did not get brighter" record keeps
    /// the table then too (§6.1 step 4, §7.5).
    @Test func calibrationRecords() {
        func advisories(_ record: CalibrationRecord?, mechanism: MechanismPreference = .automatic,
                        potential: Double = 16) -> [Advisory] {
            let display = PolicyTestInputs.builtIn
            return classify(display, preferences: DisplayPreferences(mechanism: mechanism, calibration: record),
                            reading: PolicyTestInputs.reading(display, potential: potential)).advisories
        }
        #expect(!advisories(PolicyTestInputs.record(.encoded)).contains(.notCalibrated))
        #expect(!advisories(PolicyTestInputs.record(.linear)).contains(.notCalibrated))
        #expect(advisories(PolicyTestInputs.record(.inconclusive)).contains(.notCalibrated))
        #expect(advisories(PolicyTestInputs.record(.encoded, build: "26A123")).contains(.notCalibrated))
        #expect(advisories(PolicyTestInputs.record(.encoded), potential: 15.1).contains(.notCalibrated))
        #expect(!advisories(PolicyTestInputs.record(.encoded), potential: 16.7).contains(.notCalibrated))
        // A stored Compatibility-mode preference uses the table: a table record applies, an overlay record does not.
        #expect(!advisories(PolicyTestInputs.record(.encoded), mechanism: .overlay).contains(.notCalibrated))
        #expect(advisories(PolicyTestInputs.record(.encoded, mechanism: .overlay), mechanism: .overlay)
            .contains(.notCalibrated))

        let notBrighter = DisplayPreferences(calibration: PolicyTestInputs.record(.notBrighter))
        #expect(classify(PolicyTestInputs.builtIn, preferences: notBrighter).defaultMechanism == .table)
        let stale = DisplayPreferences(calibration: PolicyTestInputs.record(.notBrighter, build: "26A123"))
        #expect(classify(PolicyTestInputs.builtIn, preferences: stale).defaultMechanism == .table)
        #expect(EligibilityClassifier.effectiveMechanism(.automatic, defaultMechanism: .overlay) == .table)
        #expect(EligibilityClassifier.effectiveMechanism(.table, defaultMechanism: .overlay) == .table)
        #expect(EligibilityClassifier.effectiveMechanism(.overlay, defaultMechanism: .table) == .table)
    }

    /// D8 and §4.5 invariant 10: the Russian-name fixture gives the same verdicts, advisories and defaults as the
    /// English names; so does any other name.
    @Test func namesNeverChangeAVerdict() {
        let russian = DisplayFixture.russianNames.displays
        let english = [PolicyTestInputs.builtIn, PolicyTestInputs.msi]
        #expect(russian.map(\.facts.name) != english.map(\.facts.name))
        for (ru, en) in zip(russian, english) {
            #expect(classify(ru) == classify(en))
            var renamed = en
            renamed.facts.name = "Pro Display XDR (OLED, Sidecar)"
            #expect(classify(renamed) == classify(en))
        }
    }
}
