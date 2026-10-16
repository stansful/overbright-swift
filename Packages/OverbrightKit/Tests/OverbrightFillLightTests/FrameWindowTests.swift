// OverbrightFillLightTests/FrameWindowTests.swift — the real window's recipe and layers, built but never ordered in
// (ARCHITECTURE.md §10.9 acceptance: never ordered in during tests; the window ignores mouse events and is excluded from
// the full-screen detector; capture exclusion; §7.6 EDR colour with headroom; §4.7 colours from CGColor).
import AppKit
import CoreGraphics
import OverbrightCore
import QuartzCore
import Testing
@testable import OverbrightFillLight

@MainActor @Suite struct FrameWindowTests {
    @Test func recipeIsClickThroughCaptureExcludedAndNotLayerZero() {
        let panel = FillLightWindowRecipe.makePanel(frame: NSRect(x: 0, y: 0, width: 1_728, height: 1_117))
        defer { panel.close() }
        #expect(panel.ignoresMouseEvents)                                  // click-through
        #expect(panel.sharingType == .none)                                // left out of captures where honoured
        // The full-screen detector (Signals, §7.3) considers layer-0 windows of other apps only; the frame sits at the
        // screen-saver level, so it can never be taken for a full-screen window even if the PID filter failed.
        #expect(panel.level == .screenSaver)
        #expect(panel.level.rawValue != 0)
        #expect(panel.collectionBehavior.isSuperset(of: [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary,
                                                         .ignoresCycle]))
        #expect(panel.styleMask.contains(.nonactivatingPanel) && panel.styleMask.contains(.borderless))
        #expect(!panel.isOpaque && !panel.hasShadow && !panel.canHide && !panel.hidesOnDeactivate)
        #expect(panel.isExcludedFromWindowsMenu)
        #expect(!panel.isAccessibilityElement())                          // decorative (DESIGN.md §11)
        #expect(!panel.isVisible)                                          // never ordered in by building it
        #expect(panel.frame == NSRect(x: 0, y: 0, width: 1_728, height: 1_117))
    }

    @Test func liveFactoryRefusesADisplayWithoutAScreenAndOpensNothing() {
        let factory = SystemFillLightSurfaces(mode: .live, time: ManualTimeSource())
        let ghost = DisplayRef(key: DisplayKey(rawValue: "0B21E7F1-0000-4000-8000-0000000000EE"), id: 0x7FFF_FFEE)
        #expect(throws: FillLightError.noScreen(0x7FFF_FFEE)) { _ = try factory.makeSurface(on: ghost) }
        #expect(factory.openWindowCount == 0)
    }

    @Test func standInCountsTheMainScreenAsItsSimulatedDisplay() throws {
        // `--qa-simulate`: a simulated display without a real screen shows on the main screen, whose ID is not its
        // own; a screen change must not remove the stand-in as "left its display".
        guard NSScreen.main != nil else { return }   // no screen to stand in on (a headless runner)
        let factory = SystemFillLightSurfaces(mode: .sdrStandIn, time: ManualTimeSource())
        let simulated = DisplayRef(key: DisplayKey(rawValue: "0B21E7F1-0000-4000-8000-0000000000ED"), id: 0x7FFF_FFED)
        let window = try #require(try factory.makeSurface(on: simulated) as? FillLightWindow)
        defer { window.remove() }
        let reports = ScreenReports()
        window.onScreenChange = { reports.ids.append($0) }
        window.screenChanged()
        #expect(reports.ids == [0x7FFF_FFED])
        #expect(window.rendering == .sdr)
        #expect(factory.openWindowCount == 0)                              // built, never ordered in
    }

    @Test func preferredRenderingFollowsTheOS() {
        if #available(macOS 26.0, *) {
            #expect(SystemFillLightSurfaces.preferredRendering == .taggedLayer)
        } else {
            #expect(SystemFillLightSurfaces.preferredRendering == .metalClear)
        }
    }

    // MARK: Layers

    private let geometry = FrameGeometry(displaySize: CGSize(width: 1_728, height: 1_117), menuBarHeight: 37,
                                         safeAreaTop: 32, width: 48, reachesTop: false)

    private func edrStyle(value: Double = 1.6, request: Double? = 1.65) -> FillLightStyle {
        FillLightStyle(width: 48, color: .white, value: value, headroomRequest: request, reachesTop: false)
    }

    private func rgba(_ color: CGColor?) -> [Double] { (color?.components ?? []).map { Double($0) } }

    @Test func layersMaskTheColourWithTheEvenOddFrame() {
        let layers = FillLightLayers(rendering: .sdr, display: 0)
        layers.apply(edrStyle(value: 0.8, request: nil), geometry: geometry, scale: 2)
        #expect(layers.content.mask === layers.mask)
        #expect(layers.mask.fillRule == .evenOdd)
        #expect(layers.mask.path == geometry.path)
        #expect(layers.root.frame == geometry.bounds && layers.content.frame == geometry.bounds)
        #expect(layers.mask.frame == geometry.bounds && layers.mask.contentsScale == 2)
        #expect(layers.root.sublayers?.first === layers.content)
    }

    @Test func taggedLayerCarriesTheHeadroomAndComponentsAboveWhite() throws {
        guard #available(macOS 26.0, *) else { return }
        let layers = FillLightLayers(rendering: .taggedLayer, display: 0)
        #expect(layers.rendering == .taggedLayer)
        let warm = ColorTemperature.linearSRGB(kelvin: 3_000)
        layers.apply(FillLightStyle(width: 48, color: warm, value: 1.6, headroomRequest: 1.65, reachesTop: false),
                     geometry: geometry, scale: 2)
        let color = try #require(layers.content.backgroundColor)
        #expect(abs(Double(color.contentHeadroom) - 1.65) < 2e-3)        // the tag asks for EDR
        #expect(layers.content.preferredDynamicRange == .high)
        let expected = [warm.red * 1.6, warm.green * 1.6, warm.blue * 1.6, 1]
        // Extended components survive (an 8-bit NSColor path would wrap 1.6 to 0.596, §4.7).
        for (actual, wanted) in zip(rgba(color), expected) { #expect(abs(actual - wanted) < 1e-4) }
        #expect(color.colorSpace?.name == CGColorSpace.extendedLinearSRGB)
    }

    @Test func taggedLayerWithoutARequestIsPlainSDR() throws {
        guard #available(macOS 26.0, *) else { return }
        let layers = FillLightLayers(rendering: .taggedLayer, display: 0)
        layers.apply(edrStyle(value: 0.8, request: nil), geometry: geometry, scale: 2)
        let color = try #require(layers.content.backgroundColor)
        #expect(color.contentHeadroom == 0)
        #expect(layers.content.preferredDynamicRange == .standard)
        #expect(rgba(color).allSatisfy { $0 <= 1 })
    }

    @Test func sdrRenderingNeverTagsTheColour() throws {
        let layers = FillLightLayers(rendering: .sdr, display: 0)
        layers.apply(edrStyle(value: 0.9, request: 1.5), geometry: geometry, scale: 2)
        let color = try #require(layers.content.backgroundColor)
        if #available(macOS 26.0, *) {
            #expect(color.contentHeadroom == 0)
            #expect(layers.content.preferredDynamicRange == .standard)
        }
        #expect(abs((rgba(color).first ?? 0) - 0.9) < 1e-6)
    }

    @Test func aColourLayerIsSetEvenWhenTheDrawableWaits() throws {
        // `presentsDrawable: false` (hidden, or not ordered in yet) only keeps the Metal path from presenting.
        let layers = FillLightLayers(rendering: .sdr, display: 0)
        #expect(layers.apply(edrStyle(value: 0.7, request: nil), geometry: geometry, scale: 2, presentsDrawable: false))
        let color = try #require(layers.content.backgroundColor)
        #expect(abs((rgba(color).first ?? 0) - 0.7) < 1e-6)
        #expect(layers.showColor(presentsDrawable: false))
    }

    @Test func changingTheStyleRecoloursInPlace() throws {
        guard #available(macOS 26.0, *) else { return }
        let layers = FillLightLayers(rendering: .taggedLayer, display: 0)
        layers.apply(edrStyle(value: 1.2, request: 1.3), geometry: geometry, scale: 2)
        let content = layers.content
        layers.apply(edrStyle(value: 1.9, request: 2.0), geometry: geometry, scale: 2)
        #expect(layers.content === content)
        let color = try #require(layers.content.backgroundColor)
        #expect(abs((rgba(color).first ?? 0) - 1.9) < 1e-4)
        #expect(abs(Double(color.contentHeadroom) - 2.0) < 2e-3)
    }
}

/// The display IDs a window reported as its new screen.
@MainActor private final class ScreenReports {
    var ids: [CGDirectDisplayID?] = []
}
