// OverbrightDesignTests/ScrollWheelStepsTests.swift — the slider's scroll-wheel listener takes only scrolls aimed at the
// slider (DESIGN.md §5.5, §15): a scroll in another window (Settings after the panel closed under the pointer) or
// beside the slider passes through and leaves the level alone, and the listener stops when its window resigns key,
// closes or is hidden. Over the slider a trackpad's part of a notch is taken while the level can still move that way
// (the card list behind does not scroll between steps, DESIGN.md §5.1), a notch follows the hand with natural
// scrolling on or off, horizontal scrolling is mirrored right to left, and a listener that goes away removes its event
// monitor and its window observers. The windows are built, never ordered in; the events are made, never posted (a made
// event is never direction-inverted, so the inverted cases are checked on the deltas).
import AppKit
import CoreGraphics
import OverbrightCore
import SwiftUI
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

    /// The rules of a slider with a Safe top of ×1.667.
    private let model = BoostSliderModel(top: 1.667, allowedNow: nil, presets: [.indoor, .brightRoom, .sunlight, .max],
                                         dimEnabled: true, boostHalf: .active)

    /// What the slider gives the listener: steps of `level` the way the slider takes them.
    private func target(_ level: Box, direction: LayoutDirection = .leftToRight) -> ScrollWheelSteps.Target {
        let model = model
        return ScrollWheelSteps.Target(direction: direction,
                                       canMove: { model.step(from: level.value, by: $0) != level.value },
                                       step: { notches in
                                           let next = model.step(from: level.value, by: notches)
                                           guard next != level.value else { return false }
                                           level.value = next
                                           return true
                                       })
    }

    /// A listener over `scene`'s slider that steps `level` like the slider does.
    private func listener(_ scene: Scene, level: Box, direction: LayoutDirection = .leftToRight,
                          registrations: ScrollWheelRegistrations = ScrollWheelRegistrations()) -> ScrollWheelSteps {
        let steps = ScrollWheelSteps(registrations: registrations)
        steps.attach(scene.slider)
        steps.start(target(level, direction: direction))
        return steps
    }

    @Test func aScrollAimedAtAnotherWindowPassesThroughAndLeavesTheLevel() throws {
        let scene = scene()
        let level = Box(LevelPosition(0.3))
        let steps = listener(scene, level: level)
        defer { steps.stop() }
        let event = try ScrollEvents.notch()
        #expect(steps.handle(event, in: scene.settings, at: scene.insideSlider) === event, "passed through")
        #expect(steps.handle(event, in: nil, at: scene.insideSlider) === event, "no window")
        #expect(level.value == LevelPosition(0.3))
    }

    @Test func aScrollBesideTheSliderPassesThrough() throws {
        let scene = scene()
        let level = Box(LevelPosition(0.3))
        let steps = listener(scene, level: level)
        defer { steps.stop() }
        let event = try ScrollEvents.notch()
        #expect(steps.handle(event, in: scene.panel, at: NSPoint(x: 20, y: 94)) === event, "left of the slider")
        #expect(steps.handle(event, in: scene.panel, at: NSPoint(x: 60, y: 150)) === event, "above the slider")
        #expect(level.value == LevelPosition(0.3))
    }

    @Test func aScrollOverTheSliderStepsTheLevelAndIsConsumed() throws {
        let scene = scene()
        let level = Box(LevelPosition(0.3))
        let steps = listener(scene, level: level)
        defer { steps.stop() }
        #expect(steps.handle(try ScrollEvents.notch(), in: scene.panel, at: scene.insideSlider) == nil, "consumed")
        #expect(level.value.value > 0.3)
    }

    /// A trackpad's small deltas add up to notches; until one is whole they are still the slider's, so the card list
    /// behind does not scroll between two steps. At the end of the slider they pass through to the list.
    @Test func partOfANotchIsTakenWhileTheLevelCanStillMove() throws {
        let scene = scene()
        let level = Box(LevelPosition(0.3))
        let steps = listener(scene, level: level)
        defer { steps.stop() }
        let small = try ScrollEvents.precise(dy: 5)
        #expect(small.hasPreciseScrollingDeltas)
        #expect(steps.handle(small, in: scene.panel, at: scene.insideSlider) == nil, "5 pt: taken, no step yet")
        #expect(level.value == LevelPosition(0.3))
        #expect(steps.handle(small, in: scene.panel, at: scene.insideSlider) == nil, "10 pt: taken, no step yet")
        #expect(level.value == LevelPosition(0.3))
        #expect(steps.handle(small, in: scene.panel, at: scene.insideSlider) == nil, "15 pt: one notch")
        #expect(level.value.value > 0.3)
        // At Max a scroll further up is the list's, part of a notch or not; down is still the slider's.
        level.value = model.clamped(LevelPreset.max.position)
        #expect(steps.handle(small, in: scene.panel, at: scene.insideSlider) === small, "at Max: passes through")
        #expect(steps.handle(try ScrollEvents.precise(dy: 30), in: scene.panel, at: scene.insideSlider) != nil)
        #expect(steps.handle(try ScrollEvents.precise(dy: -5), in: scene.panel, at: scene.insideSlider) == nil)
    }

    /// A turn the other way starts a fresh notch instead of paying back what was left of the last one.
    @Test func aTurnTheOtherWayStartsAFreshNotch() {
        let steps = ScrollWheelSteps()
        #expect(steps.notches(adding: 10) == 0)
        #expect(steps.notches(adding: -11) == 0, "the 10 pt up are dropped, not netted against")
        #expect(steps.notches(adding: -2) == -1)
        #expect(steps.notches(adding: 25) == 2)
    }

    /// Right to left the boost end is on the left: a swipe to the right lowers the level, a swipe to the left raises
    /// it; vertical scrolling is the same in both directions (DESIGN.md §5.5 "Right to left").
    @Test(arguments: [LayoutDirection.leftToRight, .rightToLeft])
    func horizontalScrollingFollowsTheLayout(direction: LayoutDirection) throws {
        let scene = scene()
        let level = Box(LevelPosition(0.3))
        let steps = listener(scene, level: level, direction: direction)
        defer { steps.stop() }
        let sideways = try ScrollEvents.precise(dx: 24)
        #expect(abs(sideways.scrollingDeltaX) > abs(sideways.scrollingDeltaY))
        // AppKit's positive x is a scroll to the left unless natural scrolling inverted it.
        let handMovedRight = sideways.isDirectionInvertedFromDevice == (sideways.scrollingDeltaX > 0)
        #expect(steps.handle(sideways, in: scene.panel, at: scene.insideSlider) == nil)
        let raised = level.value.value > 0.3
        #expect(raised == (handMovedRight == (direction == .leftToRight)), "\(direction): \(level.value)")
        level.value = LevelPosition(0.3)
        #expect(steps.handle(try ScrollEvents.precise(dy: 24), in: scene.panel, at: scene.insideSlider) == nil)
        #expect(level.value.value > 0.3, "\(direction): up raises the level")
    }

    @Test func nothingIsTakenAfterStopOrWithoutAWindow() throws {
        let scene = scene()
        let level = Box(LevelPosition(0.3))
        let steps = listener(scene, level: level)
        steps.stop()
        let event = try ScrollEvents.notch()
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

    /// Neither the event monitor nor the window observers keep a listener alive, so one that goes away while it listens
    /// is released, and its `isolated deinit` removes the monitor and all three window observers.
    @Test func aListenerThatGoesAwayWhileListeningIsReleased() {
        let scene = scene()
        let registrations = ScrollWheelRegistrations()
        weak var released: ScrollWheelSteps?
        do {
            let steps = listener(scene, level: Box(.standard), registrations: registrations)
            #expect(steps.isListening)
            #expect(registrations.monitors == 1 && registrations.observers == 3, "listening over its window")
            released = steps
        }
        #expect(released == nil)
        #expect(registrations.monitors == 0, "the event monitor went with the listener")
        #expect(registrations.observers == 0, "and so did its window observers")
        // Its window's notifications reach nobody now.
        NotificationCenter.default.post(name: NSWindow.didResignKeyNotification, object: scene.panel)
    }

    /// Restarting, stopping and moving between windows never leave a second monitor or stale observers behind.
    @Test func registrationsStayBalanced() {
        let scene = scene()
        let registrations = ScrollWheelRegistrations()
        let steps = listener(scene, level: Box(.standard), registrations: registrations)
        steps.start(target(Box(.standard)))
        #expect(registrations.monitors == 1, "a second start keeps the one monitor")
        steps.attach(scene.slider)
        #expect(registrations.observers == 3, "attaching again replaces the observers")
        steps.stop()
        #expect(registrations.monitors == 0 && registrations.observers == 3, "stopped, still attached")
        steps.attach(nil)
        #expect(registrations.monitors == 0 && registrations.observers == 0, "out of its window")
    }

    /// A notch follows the hand whatever the scroll direction setting: with natural scrolling (the macOS default)
    /// the deltas are inverted, so pushing two fingers up or rolling the wheel away gives a negative `scrollingDeltaY`
    /// and must still raise the level; the same goes for a swipe to the right, mirrored right to left.
    @Test(arguments: [false, true])
    func aNotchFollowsTheHand(naturalScrolling inverted: Bool) {
        func delta(dx: CGFloat = 0, dy: CGFloat = 0, _ direction: LayoutDirection = .leftToRight) -> CGFloat {
            ScrollWheelSteps.delta(dx: dx, dy: dy, invertedFromDevice: inverted, direction: direction)
        }
        // What AppKit reports for the hand moving up and to the right.
        let up: CGFloat = inverted ? -12 : 12
        let right: CGFloat = inverted ? 12 : -12
        #expect(delta(dy: up) > 0, "up raises")
        #expect(delta(dy: -up) < 0, "down lowers")
        #expect(delta(dx: right) > 0, "right raises left to right")
        #expect(delta(dx: right, .rightToLeft) < 0, "right lowers right to left")
        #expect(delta(dx: -right, .rightToLeft) > 0, "left raises right to left")
        #expect(delta(dx: right / 2, dy: up) == 12, "the larger axis wins")
    }
}

/// Scroll events made with CoreGraphics, never posted.
enum ScrollEvents {
    /// One notch of a line-based wheel, up.
    static func notch() throws -> NSEvent {
        let cgEvent = try #require(CGEvent(scrollWheelEvent2Source: nil, units: .line, wheelCount: 1, wheel1: 1, wheel2: 0,
                                           wheel3: 0))
        return try #require(NSEvent(cgEvent: cgEvent))
    }

    /// Precise (trackpad) scrolling of `dy` points up and `dx` points along the horizontal axis.
    static func precise(dy: Int32 = 0, dx: Int32 = 0) throws -> NSEvent {
        let cgEvent = try #require(CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 2, wheel1: dy,
                                           wheel2: dx, wheel3: 0))
        return try #require(NSEvent(cgEvent: cgEvent))
    }
}

/// A level the listener's target can change.
@MainActor final class Box {
    var value: LevelPosition
    init(_ value: LevelPosition) { self.value = value }
}
