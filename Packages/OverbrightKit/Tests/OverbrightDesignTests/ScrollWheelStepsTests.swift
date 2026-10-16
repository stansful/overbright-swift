// OverbrightDesignTests/ScrollWheelStepsTests.swift — the slider's scroll-wheel listener takes only scrolls aimed at the
// slider (DESIGN.md §5.5, §15): a scroll in another window (Settings after the panel closed under the pointer) or
// beside the slider passes through and leaves the level alone, and the listener stops when its window resigns key,
// closes or is hidden. The windows are built, never ordered in; the events are made, never posted.
import AppKit
import CoreGraphics
import OverbrightCore
import Testing
@testable import OverbrightDesign

@MainActor @Suite struct ScrollWheelStepsTests {
    /// The panel with a slider 40 pt in from its left, and a Settings window beside it.
    private struct Scene {
        let panel: NSWindow
        let settings: NSWindow
        let slider: NSView
        /// A point inside the slider, in window coordinates.
        let insideSlider = NSPoint(x: 60, y: 94)
    }

    private func scene() -> Scene {
        _ = NSApplication.shared
        func window() -> NSWindow {
            let window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 320, height: 200), styleMask: .borderless,
                                  backing: .buffered, defer: true)
            window.isReleasedWhenClosed = false
            return window
        }
        let panel = window(), settings = window()
        let slider = NSView(frame: CGRect(x: 40, y: 80, width: 280, height: 28))
        panel.contentView?.addSubview(slider)
        return Scene(panel: panel, settings: settings, slider: slider)
    }

    /// One notch of a line-based wheel, up.
    private func notch() throws -> NSEvent {
        let cgEvent = try #require(CGEvent(scrollWheelEvent2Source: nil, units: .line, wheelCount: 1, wheel1: 1, wheel2: 0,
                                           wheel3: 0))
        return try #require(NSEvent(cgEvent: cgEvent))
    }

    /// A listener over `scene`'s slider that steps `level` like the slider does.
    private func listener(_ scene: Scene, level: Box) -> ScrollWheelSteps {
        let model = BoostSliderModel(top: 1.667, allowedNow: nil, presets: [.indoor, .brightRoom, .sunlight, .max],
                                     dimEnabled: true, boostHalf: .active)
        let steps = ScrollWheelSteps()
        steps.attach(scene.slider)
        steps.start { notches in
            let next = model.step(from: level.value, by: notches)
            guard next != level.value else { return false }
            level.value = next
            return true
        }
        return steps
    }

    @Test func aScrollAimedAtAnotherWindowPassesThroughAndLeavesTheLevel() throws {
        let scene = scene()
        let level = Box(LevelPosition(0.3))
        let steps = listener(scene, level: level)
        defer { steps.stop() }
        let event = try notch()
        #expect(steps.handle(event, in: scene.settings, at: scene.insideSlider) === event, "passed through")
        #expect(steps.handle(event, in: nil, at: scene.insideSlider) === event, "no window")
        #expect(level.value == LevelPosition(0.3))
    }

    @Test func aScrollBesideTheSliderPassesThrough() throws {
        let scene = scene()
        let level = Box(LevelPosition(0.3))
        let steps = listener(scene, level: level)
        defer { steps.stop() }
        let event = try notch()
        #expect(steps.handle(event, in: scene.panel, at: NSPoint(x: 20, y: 94)) === event, "left of the slider")
        #expect(steps.handle(event, in: scene.panel, at: NSPoint(x: 60, y: 150)) === event, "above the slider")
        #expect(level.value == LevelPosition(0.3))
    }

    @Test func aScrollOverTheSliderStepsTheLevelAndIsConsumed() throws {
        let scene = scene()
        let level = Box(LevelPosition(0.3))
        let steps = listener(scene, level: level)
        defer { steps.stop() }
        #expect(steps.handle(try notch(), in: scene.panel, at: scene.insideSlider) == nil, "consumed")
        #expect(level.value.value > 0.3)
    }

    @Test func nothingIsTakenAfterStopOrWithoutAWindow() throws {
        let scene = scene()
        let level = Box(LevelPosition(0.3))
        let steps = listener(scene, level: level)
        steps.stop()
        let event = try notch()
        #expect(!steps.isListening)
        #expect(steps.handle(event, in: scene.panel, at: scene.insideSlider) === event)
        let detached = listener(scene, level: level)
        detached.attach(nil)
        #expect(!detached.isListening, "a control that leaves its window stops listening")
        #expect(detached.handle(event, in: scene.panel, at: scene.insideSlider) === event)
        #expect(level.value == LevelPosition(0.3))
    }

    /// The panel resigns key (Esc, ⌘, opens Settings), closes, or is hidden: the listener stops with it.
    @Test(arguments: [NSWindow.didResignKeyNotification, NSWindow.willCloseNotification,
                      NSWindow.didChangeOcclusionStateNotification])
    func theListenerStopsWithItsWindow(_ name: Notification.Name) {
        let scene = scene()
        let steps = listener(scene, level: Box(.standard))
        defer { steps.stop() }
        #expect(steps.isListening)
        NotificationCenter.default.post(name: name, object: scene.settings)
        #expect(steps.isListening, "another window's notification changes nothing")
        // The panel was never ordered in, so its occlusion state is not visible.
        NotificationCenter.default.post(name: name, object: scene.panel)
        #expect(!steps.isListening)
    }
}

/// A level the listener's handler can change.
@MainActor private final class Box {
    var value: LevelPosition
    init(_ value: LevelPosition) { self.value = value }
}
