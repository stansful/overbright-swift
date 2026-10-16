// OverbrightTriggersTests/WindowRecipeTests.swift — the trigger and overlay panel as AppKit configures it (never
// shown), and `TriggerHost`'s wiring: layer hosting, soft light, occlusion and screen-change callbacks, re-placement
// and teardown. ARCHITECTURE.md §4.3 ("onScreenChange" row), §4.7, §7.6, §10.5. No window is ordered in: the host's
// presenter only records.
import AppKit
import CoreGraphics
import OverbrightCore
import OverbrightTestSupport
import QuartzCore
import Testing
@testable import OverbrightTriggers

@Suite struct WindowRecipeTests {
    private func host(_ screens: FixedScreens, _ presenter: RecordingPresenter,
                      shape: TriggerHost.Shape = .trigger(placement: .topRightCorner, edgePoints: 1)) -> TriggerHost {
        TriggerHost(display: TriggerTestBed.builtIn, shape: shape, screens: screens, presenter: presenter)
    }

    private func screens() -> FixedScreens {
        FixedScreens([TriggerTestBed.builtIn.id: TriggerTestBed.builtInGeometry,
                      TriggerTestBed.external.id: TriggerTestBed.externalGeometry])
    }

    @Test func panelIsConfiguredButNeverShown() {
        let panel = WindowRecipes.makePanel(frame: NSRect(x: 10, y: 20, width: 1, height: 1))
        defer { panel.close() }
        #expect(panel.level == .screenSaver)
        #expect(panel.collectionBehavior.rawValue == 0x40151)
        for behavior: NSWindow.CollectionBehavior in [.canJoinAllSpaces, .stationary, .ignoresCycle,
                                                      .fullScreenAuxiliary, .canJoinAllApplications] {
            #expect(panel.collectionBehavior.contains(behavior))
        }
        #expect(panel.styleMask.contains(.nonactivatingPanel))
        #expect(!panel.styleMask.contains(.titled))
        #expect(panel.sharingType == .none)
        #expect(panel.ignoresMouseEvents)
        #expect(!panel.isOpaque)
        #expect(panel.backgroundColor == .clear)
        #expect(!panel.hasShadow)
        #expect(!panel.hidesOnDeactivate)
        #expect(!panel.canHide)
        #expect(panel.isExcludedFromWindowsMenu)
        #expect(panel.animationBehavior == .none)
        #expect(!panel.isReleasedWhenClosed)
        #expect(!panel.isMovable)
        #expect(!panel.isAccessibilityElement())
        #expect(!panel.canBecomeKey && !panel.canBecomeMain)
        #expect(panel.frame == NSRect(x: 10, y: 20, width: 1, height: 1))
        #expect(!panel.isVisible)
    }

    @Test func preparedWindowHostsTheLayerAtTheTriggerFrameWithoutOrderingIn() throws {
        let presenter = RecordingPresenter()
        let host = host(screens(), presenter)
        let layer = CALayer()
        try host.prepare(layer: layer, blend: .normal)
        let window = try #require(host.window)
        let view = try #require(window.contentView)
        #expect(view.layer === layer, "layer-hosting view: our layer is the view's layer")
        #expect(view.wantsLayer)
        #expect(layer.frame == view.bounds)
        #expect(layer.compositingFilter == nil)
        #expect(window.frame == CGRect(x: 1511, y: 981, width: 1, height: 1))
        #expect(presenter.orderedIn.isEmpty)
        #expect(!host.isOrderedIn)
        #expect(!window.isVisible)
        host.tearDown()
    }

    @Test func softLightBlendIsTheCompositingFilter() throws {
        let host = host(screens(), RecordingPresenter())
        let layer = CALayer()
        try host.prepare(layer: layer, blend: .softLight)
        #expect(layer.compositingFilter as? String == "softLightBlendMode")
        host.tearDown()
    }

    @Test func overlayShapeCoversTheWholeScreen() throws {
        let host = host(screens(), RecordingPresenter(), shape: .fullScreen)
        try host.prepare(layer: CALayer(), blend: .normal)
        #expect(host.window?.frame == TriggerTestBed.builtInGeometry.frame)
        host.tearDown()
    }

    @Test func aDisplayWithoutAScreenThrowsDisplayGone() {
        let screens = screens()
        screens.screens[TriggerTestBed.builtIn.id] = nil
        let host = host(screens, RecordingPresenter())
        #expect(throws: TriggerError.displayGone) { try host.prepare(layer: CALayer(), blend: .normal) }
        #expect(!host.hasWindow)
    }

    @Test func showOrdersInThroughThePresenterOnly() throws {
        let presenter = RecordingPresenter()
        let host = host(screens(), presenter)
        try host.show(layer: CALayer(), blend: .normal)
        let window = try #require(host.window)
        #expect(presenter.orderedIn.count == 1)
        #expect(presenter.orderedIn.first === window)
        #expect(host.isOrderedIn)
        #expect(!window.isVisible, "the recording presenter never puts it on screen")
        host.tearDown()
        #expect(presenter.orderedOut.first === window)
        #expect(!host.hasWindow && !host.isOrderedIn)
    }

    @Test func screenChangeReportsTheDisplayAppKitMovedTheWindowTo() async throws {
        let screens = screens()
        let host = host(screens, RecordingPresenter())
        var reports: [CGDirectDisplayID?] = []
        host.onScreenChange = { reports.append($0) }
        try host.prepare(layer: CALayer(), blend: .normal)
        let window = try #require(host.window)
        screens.windowDisplay = TriggerTestBed.external.id
        NotificationCenter.default.post(name: NSWindow.didChangeScreenNotification, object: window)
        #expect(await eventually { reports.count == 1 })
        #expect(reports == [TriggerTestBed.external.id])
        screens.windowDisplay = nil
        NotificationCenter.default.post(name: NSWindow.didChangeScreenNotification, object: window)
        #expect(await eventually { reports.count == 2 })
        #expect(reports.last == .some(nil))
        // Another window's notification is not ours.
        let other = WindowRecipes.makePanel(frame: .init(x: 0, y: 0, width: 1, height: 1))
        NotificationCenter.default.post(name: NSWindow.didChangeScreenNotification, object: other)
        other.close()
        // After teardown the observer is gone.
        host.tearDown()
        NotificationCenter.default.post(name: NSWindow.didChangeScreenNotification, object: window)
        await Task.yield()
        #expect(reports.count == 2)
    }

    @Test func occlusionChangesAreReportedOnce() async throws {
        let host = host(screens(), RecordingPresenter())
        var reports: [Bool] = []
        host.onOcclusionChange = { reports.append($0) }
        try host.prepare(layer: CALayer(), blend: .normal)
        let window = try #require(host.window)
        #expect(!host.isOccluded)
        // A window that is not on screen is not visible: AppKit's state says occluded.
        #expect(!window.occlusionState.contains(.visible))
        NotificationCenter.default.post(name: NSWindow.didChangeOcclusionStateNotification, object: window)
        #expect(await eventually { reports.count == 1 })
        #expect(reports == [true])
        #expect(host.isOccluded)
        NotificationCenter.default.post(name: NSWindow.didChangeOcclusionStateNotification, object: window)
        await Task.yield()
        #expect(reports == [true], "an unchanged state is not reported again")
        host.tearDown()
        #expect(!host.isOccluded)
    }

    @Test func repositionFollowsTheScreenAndLeavesAGoneDisplayAlone() throws {
        let screens = screens()
        let host = host(screens, RecordingPresenter())
        let layer = CALayer()
        try host.prepare(layer: layer, blend: .normal)
        var moved = TriggerTestBed.builtInGeometry
        moved.frame = CGRect(x: 0, y: 0, width: 1800, height: 1169)
        screens.screens[TriggerTestBed.builtIn.id] = moved
        host.reposition()
        #expect(host.window?.frame == CGRect(x: 1799, y: 1168, width: 1, height: 1))
        screens.screens[TriggerTestBed.builtIn.id] = nil
        host.reposition()
        #expect(host.window?.frame == CGRect(x: 1799, y: 1168, width: 1, height: 1))
        host.tearDown()
    }

    @Test func overlayRepositionResizesTheHostedLayer() throws {
        let screens = screens()
        let host = host(screens, RecordingPresenter(), shape: .fullScreen)
        let layer = CALayer()
        try host.prepare(layer: layer, blend: .normal)
        var resized = TriggerTestBed.builtInGeometry
        resized.frame = CGRect(x: 0, y: 0, width: 1800, height: 1169)
        screens.screens[TriggerTestBed.builtIn.id] = resized
        host.reposition()
        #expect(host.window?.frame == resized.frame)
        #expect(layer.frame.size == CGSize(width: 1800, height: 1169))
        host.tearDown()
    }

    @Test func aDroppedHostOrdersItsWindowOut() throws {
        let presenter = RecordingPresenter()
        var host: TriggerHost? = host(screens(), presenter)
        try host?.show(layer: CALayer(), blend: .normal)
        let window = try #require(host?.window)
        host = nil
        #expect(presenter.orderedOut.contains { $0 === window })
    }
}
