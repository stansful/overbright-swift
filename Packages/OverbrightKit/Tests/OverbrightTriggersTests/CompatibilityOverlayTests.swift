// OverbrightTriggersTests/CompatibilityOverlayTests.swift — technique C: a full-screen multiply overlay that requests
// first and boosts second, dims without EDR whatever the request, goes to factor 1 without a display query, and draws
// with a tagged colour (macOS 26+) or a 4 × 4 clear-only Metal frame. ARCHITECTURE.md §3.6 (`OverlayHandle`), §4.2
// (dimmed row), §4.3 (overlay rows), §7.5, §10.5. The presenter only records and the Metal surface is scripted.
import AppKit
import CoreGraphics
import Foundation
import OverbrightCore
import OverbrightTestSupport
import QuartzCore
import Testing
@testable import OverbrightTriggers

@Suite struct CompatibilityOverlayTests {
    nonisolated private static let onTwentySix = ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 26

    private func overlay(_ bed: TriggerTestBed) throws -> CompatibilityOverlay {
        try #require(try bed.factory.makeOverlay(on: TriggerTestBed.builtIn) as? CompatibilityOverlay)
    }

    private func tag(_ layer: CALayer?) -> Double {
        guard #available(macOS 26.0, *) else { return -1 }
        return Double(layer?.backgroundColor?.contentHeadroom ?? -1)
    }

    @Test(.enabled(if: onTwentySix))
    func requestFirstThenBoostOnATaggedColour() throws {
        guard #available(macOS 26.0, *) else { return }
        let bed = TriggerTestBed()
        let overlay = try overlay(bed)
        #expect(overlay.surface == .taggedColor)
        #expect(bed.presenter.orderedIn.isEmpty, "making an overlay opens nothing")
        // Arming: factor 1 with the headroom request for a target of 1.4 (1.4 ÷ 0.97).
        try overlay.setFactor(1, headroomRequest: 1.4 / 0.97)
        let window = try #require(bed.presenter.orderedIn.first)
        let layer = try #require(overlay.layer)
        #expect(window.frame == TriggerTestBed.builtInGeometry.frame)
        #expect(layer.compositingFilter as? String == CompatibilityOverlay.multiplyFilter)
        #expect(layer.preferredDynamicRange == .high)
        #expect(layer.backgroundColor?.components?.first == 1, "requesting changes nothing on screen yet")
        #expect(abs(tag(layer) - 1.4 / 0.97) < 1e-3)
        // The ramp.
        try overlay.setFactor(1.25, headroomRequest: 1.4 / 0.97)
        #expect(layer.backgroundColor?.components?.first == 1.25)
        try overlay.setFactor(1.4, headroomRequest: 1.4 / 0.97)
        #expect(overlay.factor == 1.4)
        #expect(bed.presenter.orderedIn.count == 1, "one window for the whole ramp")
        overlay.remove()
    }

    @Test(.enabled(if: onTwentySix))
    func dimmingAsksForNoExtendedRange() throws {
        guard #available(macOS 26.0, *) else { return }
        let bed = TriggerTestBed()
        let overlay = try overlay(bed)
        try overlay.setFactor(0.6, headroomRequest: 1)
        let layer = try #require(overlay.layer)
        #expect(layer.preferredDynamicRange == .standard)
        #expect(layer.backgroundColor?.contentHeadroom == 0)
        #expect(layer.backgroundColor?.components?.first == 0.6)
        #expect(overlay.headroomRequest == 1)
        overlay.remove()
    }

    @Test(.enabled(if: onTwentySix))
    func aFactorBelowOneNeverAsksForExtendedRangeWhateverTheRequest() throws {
        guard #available(macOS 26.0, *) else { return }
        let bed = TriggerTestBed()
        let overlay = try overlay(bed)
        // The engine may keep the request while it lowers the factor (a ramp from boost to dim, tag policy B).
        try overlay.setFactor(0.6, headroomRequest: 1.5)
        let layer = try #require(overlay.layer)
        #expect(layer.preferredDynamicRange == .standard)
        #expect(layer.backgroundColor?.contentHeadroom == 0)
        #expect(layer.backgroundColor?.components?.first == 0.6)
        #expect(overlay.headroomRequest == 1)
        try overlay.setFactor(1.3, headroomRequest: 1.44)
        #expect(layer.preferredDynamicRange == .high)
        try overlay.setFactor(0.9, headroomRequest: 1.44)
        #expect(layer.preferredDynamicRange == .standard, "the request ends at the first factor below 1")
        #expect(layer.backgroundColor?.contentHeadroom == 0)
        #expect(overlay.headroomRequest == 1)
        try overlay.setFactor(1, headroomRequest: 1.44)
        #expect(layer.preferredDynamicRange == .high, "factor 1 with a request still requests (arming, §7.5)")
        #expect(abs(tag(layer) - 1.44) < 1e-3)
        overlay.remove()
    }

    @Test(.enabled(if: onTwentySix))
    func theRequestNeverFallsBelowTheFactor() throws {
        guard #available(macOS 26.0, *) else { return }
        let bed = TriggerTestBed()
        let overlay = try overlay(bed)
        try overlay.setFactor(2, headroomRequest: 1.5)
        #expect(overlay.headroomRequest == 2)
        #expect(abs(tag(overlay.layer) - 2) < 1e-3)
        try overlay.setFactor(.nan, headroomRequest: .infinity)
        #expect(overlay.factor == 1)
        #expect(overlay.headroomRequest == 1)
        #expect(overlay.layer?.preferredDynamicRange == .standard)
        overlay.remove()
    }

    @Test(.enabled(if: onTwentySix))
    func factorOneAtConfigurationBeginQueriesNoDisplay() throws {
        let bed = TriggerTestBed()
        let overlay = try overlay(bed)
        try overlay.setFactor(1.3, headroomRequest: 1.4)
        let lookups = bed.screens.geometryLookups
        // The begin phase of a reconfiguration: the screens may not be queried (§4.3).
        bed.screens.screens = [:]
        try overlay.setFactor(1, headroomRequest: 1.4)
        #expect(bed.screens.geometryLookups == lookups)
        #expect(overlay.factor == 1)
        #expect(overlay.layer?.backgroundColor?.components?.first == 1)
        overlay.remove()
    }

    @Test func factorOneWithoutARequestOnANeverShownOverlayDoesNothing() throws {
        let bed = TriggerTestBed(overlaySurface: .metal)
        let overlay = try overlay(bed)
        let surface = try #require(bed.surfaces.first)
        let lookups = bed.screens.geometryLookups
        // The begin phase of a reconfiguration reaches an overlay that was never shown: nothing to undo.
        bed.screens.screens = [:]
        try overlay.setFactor(1, headroomRequest: 1)
        try overlay.setFactor(1, headroomRequest: 0.5)
        try overlay.setFactor(.nan, headroomRequest: 1)
        #expect(bed.screens.geometryLookups == lookups, "no screen query")
        #expect(bed.presenter.orderedIn.isEmpty)
        #expect(overlay.layer == nil)
        #expect(surface.presentedValues.isEmpty && surface.wantsEDRCalls.isEmpty)
        #expect(bed.factory.openWindowCount == 0)
        bed.screens.screens[TriggerTestBed.builtIn.id] = TriggerTestBed.builtInGeometry
        try overlay.setFactor(1, headroomRequest: 1.2)
        #expect(bed.presenter.orderedIn.count == 1, "a request shows it")
        #expect(surface.wantsEDRCalls == [true])
        overlay.remove()
    }

    @Test func metalSurfaceClearsItsFourPixelDrawableToTheFactor() throws {
        let bed = TriggerTestBed(overlaySurface: .metal)
        let overlay = try overlay(bed)
        #expect(overlay.surface == .metal)
        let request = try #require(bed.surfaceRequests.first)
        #expect(request.pixels == 4 && request.nearest)
        let surface = try #require(bed.surfaces.first)
        try overlay.setFactor(1, headroomRequest: 1.3)
        #expect(surface.wantsEDRCalls == [true])
        #expect(surface.presentedValues == [1])
        #expect(overlay.layer === surface.layer)
        #expect(surface.layer.compositingFilter as? String == CompatibilityOverlay.multiplyFilter)
        try overlay.setFactor(1.2, headroomRequest: 1.3)
        try overlay.setFactor(0.5, headroomRequest: 1)
        #expect(surface.presentedValues == [1, 1.2, 0.5])
        #expect(surface.wantsEDRCalls == [true, true, false])
        overlay.remove()
        #expect(surface.isReleased)
    }

    @Test func aMetalDimNeverAsksForExtendedRangeWhateverTheRequest() throws {
        let bed = TriggerTestBed(overlaySurface: .metal)
        let overlay = try overlay(bed)
        let surface = try #require(bed.surfaces.first)
        try overlay.setFactor(0.6, headroomRequest: 1.5)
        #expect(surface.wantsEDRCalls == [false])
        #expect(surface.presentedValues == [0.6])
        #expect(overlay.headroomRequest == 1)
        try overlay.setFactor(1.2, headroomRequest: 1.5)
        try overlay.setFactor(0.8, headroomRequest: 1.5)
        #expect(surface.wantsEDRCalls == [false, true, false])
        #expect(surface.presentedValues == [0.6, 1.2, 0.8])
        overlay.remove()
    }

    @Test func aMetalFrameThatFailsIsRetried() async throws {
        let bed = TriggerTestBed(overlaySurface: .metal)
        bed.surfaceFailuresBeforeSuccess = 2
        let overlay = try overlay(bed)
        let surface = try #require(bed.surfaces.first)
        try overlay.setFactor(1.1, headroomRequest: 1.2)
        #expect(surface.presentedValues.isEmpty)
        #expect(await eventually { bed.time.sleeperCount == 1 })
        await bed.time.advance(by: .milliseconds(100))
        #expect(surface.presentedValues == [1.1])
        #expect(surface.attempts == 3)
        overlay.remove()
    }

    @Test func aNewFactorSupersedesAPendingRetry() async throws {
        let bed = TriggerTestBed(overlaySurface: .metal)
        bed.surfaceFailuresBeforeSuccess = 1
        let overlay = try overlay(bed)
        let surface = try #require(bed.surfaces.first)
        try overlay.setFactor(1.5, headroomRequest: 1.5)
        #expect(await eventually { bed.time.sleeperCount == 1 })
        try overlay.setFactor(0.8, headroomRequest: 1)
        await bed.time.advance(by: .seconds(1))
        #expect(surface.presentedValues == [0.8], "the stale 1.5 frame is never shown")
        overlay.remove()
    }

    @Test func removeClosesTheWindowAndLaterFactorsThrow() throws {
        let bed = TriggerTestBed(overlaySurface: .metal)
        let overlay = try overlay(bed)
        try overlay.setFactor(1.2, headroomRequest: 1.3)
        #expect(bed.factory.openWindowCount == 1)
        overlay.remove()
        #expect(bed.factory.openWindowCount == 0)
        #expect(bed.presenter.orderedOut.count == 1)
        #expect(throws: TriggerError.displayGone) { try overlay.setFactor(1, headroomRequest: 1) }
        overlay.remove()
        #expect(bed.presenter.orderedOut.count == 1)
    }

    @Test func representFollowsTheScreenFrame() throws {
        let bed = TriggerTestBed(overlaySurface: .metal)
        let overlay = try overlay(bed)
        let surface = try #require(bed.surfaces.first)
        try overlay.setFactor(1.2, headroomRequest: 1.3)
        var resized = TriggerTestBed.builtInGeometry
        resized.frame = CGRect(x: 0, y: 0, width: 1800, height: 1169)
        bed.screens.screens[TriggerTestBed.builtIn.id] = resized
        overlay.represent()
        #expect(bed.presenter.orderedIn.first?.frame == resized.frame)
        #expect(surface.presentedValues == [1.2, 1.2])
        overlay.remove()
    }

    @Test func screenChangesReachTheEngine() async throws {
        let bed = TriggerTestBed(overlaySurface: .metal)
        let overlay = try overlay(bed)
        var reports: [CGDirectDisplayID?] = []
        overlay.onScreenChange = { reports.append($0) }
        try overlay.setFactor(1, headroomRequest: 1.2)
        let window = try #require(bed.presenter.orderedIn.first)
        bed.screens.windowDisplay = TriggerTestBed.external.id
        NotificationCenter.default.post(name: NSWindow.didChangeScreenNotification, object: window)
        #expect(await eventually { reports == [TriggerTestBed.external.id] })
        overlay.remove()
    }

    @Test func aDisplayWithoutAScreenGetsNoOverlay() {
        let bed = TriggerTestBed()
        bed.screens.screens = [:]
        #expect(throws: TriggerError.displayGone) { _ = try bed.factory.makeOverlay(on: TriggerTestBed.builtIn) }
        let metalBed = TriggerTestBed(overlaySurface: .metal)
        metalBed.hasMetalDevice = false
        #expect(throws: TriggerError.noMetalDevice) { _ = try metalBed.factory.makeOverlay(on: TriggerTestBed.builtIn) }
    }

    @Test func onlyAFactorFromOneUpWithARequestAboveOneAsksForExtendedRange() {
        #expect(!CompatibilityOverlay.wantsEDR(factor: 1, headroomRequest: 1))
        #expect(!CompatibilityOverlay.wantsEDR(factor: 0.5, headroomRequest: 1))
        #expect(!CompatibilityOverlay.wantsEDR(factor: 0.6, headroomRequest: 1.5))
        #expect(!CompatibilityOverlay.wantsEDR(factor: 0.999, headroomRequest: 4))
        #expect(CompatibilityOverlay.wantsEDR(factor: 1, headroomRequest: 1.2))
        #expect(CompatibilityOverlay.wantsEDR(factor: 1.1, headroomRequest: 1))
        #expect(CompatibilityOverlay.effectiveRequest(factor: 0.6, headroomRequest: 1.5) == 1)
        #expect(CompatibilityOverlay.effectiveRequest(factor: 1, headroomRequest: 1.5) == 1.5)
        #expect(CompatibilityOverlay.effectiveRequest(factor: 2, headroomRequest: 1.5) == 2)
        #expect(CompatibilityOverlay.effectiveRequest(factor: 1.2, headroomRequest: .nan) == 1.2)
    }
}
