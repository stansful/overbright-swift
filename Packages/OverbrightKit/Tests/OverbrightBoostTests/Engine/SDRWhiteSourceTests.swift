// OverbrightBoostTests/Engine/SDRWhiteSourceTests.swift — which external frame average the engine trusts as SDR
// white (ARCHITECTURE.md §5.1, §5.5): an HDR external's in HDR mode, never an Apple XDR external's, where
// MaxFrameAverage is the full-screen sustained HDR level and trusting it would switch Safe's live bound off (§5.4).
import Foundation
import OverbrightCore
import Testing
@testable import OverbrightBoost

@Suite struct SDRWhiteSourceTests {
    private func estimate(_ display: FixtureDisplay, potential: Double? = nil) -> SDRWhiteEstimate? {
        let script = display.headroom
        let reading = HeadroomReading(display: display.facts.ref.id, current: script.grant,
                                      potential: potential ?? script.potential, reference: script.reference,
                                      time: MonotonicInstant(sinceOrigin: .zero))
        return SDRWhiteSource.estimate(facts: display.facts, preferences: DisplayPreferences(), mechanism: .table,
                                       machine: DisplayFixture.ownerMachine, reading: reading)
    }

    @Test func anHDRExternalsFrameAverageIsItsSDRWhite() {
        let msi = DisplayFixture.mpg322uxHDROn.displays[0]
        #expect(estimate(msi) == SDRWhiteEstimate(nits: 265.05, source: .hdrFrameAverage))
        // Only in HDR mode, and only on an external that supports PQ.
        #expect(estimate(DisplayFixture.mpg322uxHDROff.displays[0]) == nil)
        var noPQ = msi
        noPQ.facts.supportsPQ = nil
        #expect(estimate(noPQ) == nil)
    }

    /// The Pro Display XDR's frame average of 1000 nits (potential 16) is never its SDR white (C-PLATFORM-1); the same
    /// facts on another HDR external class would be, so the class is what decides.
    @Test func anAppleXDRExternalsFrameAverageIsNever() {
        let pro = DisplayFixture.proDisplayXDR.displays[0]
        #expect(pro.facts.panelFrameAverageNits == 1000 && pro.headroom.potential == 16)
        #expect(estimate(pro) == nil)
        var asHDRExternal = pro
        asHDRExternal.facts.panelClass = .hdrExternal
        #expect(estimate(asHDRExternal) == SDRWhiteEstimate(nits: 1000, source: .hdrFrameAverage))
        // A built-in never has one either, whatever its facts carry.
        var builtIn = DisplayFixture.builtinXDRLidOpen.displays[0]
        builtIn.facts.supportsPQ = true
        builtIn.facts.panelFrameAverageNits = 600
        #expect(estimate(builtIn) == nil)
    }
}
