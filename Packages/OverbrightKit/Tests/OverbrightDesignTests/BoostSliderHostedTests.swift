// OverbrightDesignTests/BoostSliderHostedTests.swift — the level slider in a real view hierarchy: an NSHostingView in a
// window that is never ordered in; events are made and handed to that window, never posted. The slider is the 240-pt
// track alone (the card's slider row draws the end glyphs, DESIGN.md §5.4); with the pointer on it its scroll anchor
// sits in that window and drives the level through the slider's own handler (DESIGN.md §5.5, §15), mirrored right to
// left; without the pointer there is no anchor and nothing listens; and a host that binds the slider's focus moves
// the level with the arrow keys of that one focusable element, where a focusable wrapper around it would take the
// focus without the keys (DESIGN.md §5.12).
import AppKit
import OverbrightCore
import OverbrightPolicy
import SwiftUI
import Testing
@testable import OverbrightDesign

@MainActor @Suite struct BoostSliderHostedTests {
    private struct Hosted {
        let window: NSWindow
        let host: NSView
    }

    /// A level and the commits the slider made.
    private final class Record {
        var level: LevelPosition
        var commits: [LevelPosition] = []
        init(_ level: LevelPosition) { self.level = level }
        var binding: Binding<LevelPosition> { Binding(get: { self.level }, set: { self.level = $0 }) }
    }

    private static let top = 1.667
    private static let presets: [LevelPreset] = [.indoor, .brightRoom, .sunlight, .max]

    private func slider(_ record: Record) -> BoostSlider {
        BoostSlider(level: record.binding, top: Self.top, allowedNow: nil, presets: Self.presets, dimEnabled: true,
                    boostHalf: .active, accessibilityName: "Built-in Display",
                    valueText: { ValueText.forLevel($0, top: Self.top, presets: Self.presets, isEstimate: true).text },
                    onCommit: { record.commits.append($0) })
    }

    /// `view` in an off-screen window that is never ordered in, laid out.
    private func host(_ view: some View, direction: LayoutDirection = .leftToRight) -> Hosted {
        _ = NSApplication.shared
        let host = NSHostingView(rootView: view.environment(\.layoutDirection, direction).overbrightThemeRoot())
        let window = KeyableWindow(contentRect: NSRect(x: -30_000, y: -30_000, width: 320, height: 80),
                                   styleMask: .borderless, backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = host
        settle(host)
        return Hosted(window: window, host: host)
    }

    private func settle(_ view: NSView) {
        view.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        view.layoutSubtreeIfNeeded()
    }

    private func close(_ hosted: Hosted) {
        hosted.window.contentView = nil
        hosted.window.close()
    }

    private func anchor(in view: NSView) -> ScrollWheelAnchor.AnchorView? {
        if let anchor = view as? ScrollWheelAnchor.AnchorView { return anchor }
        for subview in view.subviews {
            if let found = anchor(in: subview) { return found }
        }
        return nil
    }

    /// The slider is the track: the 14-pt sun glyphs and their gaps belong to the card's slider row, so the slider
    /// fits the card's 240-pt frame exactly.
    @Test func theSliderIsTheTrackAlone() {
        let hosted = host(slider(Record(.standard)))
        defer { close(hosted) }
        #expect(hosted.host.fittingSize.width == BoostSliderTrack.width)
        #expect(hosted.host.fittingSize.height == HitTarget.sliderThumb)
    }

    /// With the pointer on the slider its anchor is in the slider's window, the listener runs with the slider's own
    /// handler, and a notch over the slider steps and commits the level.
    @Test func theScrollAnchorAttachesAndStepsTheLevel() throws {
        let record = Record(LevelPosition(0.3))
        let hosted = host(slider(record).underPointer())
        defer { close(hosted) }
        let anchor = try #require(anchor(in: hosted.host), "the anchor is in place while the pointer is over")
        let steps = try #require(anchor.steps)
        defer { steps.stop() }
        #expect(anchor.window === hosted.window)
        #expect(steps.anchor === anchor)
        #expect(steps.isListening)
        #expect(anchor.frame.width >= BoostSliderTrack.width, "it covers the slider")
        let center = anchor.convert(NSPoint(x: anchor.bounds.midX, y: anchor.bounds.midY), to: nil)
        #expect(steps.handle(try ScrollEvents.notch(), in: hosted.window, at: center) == nil, "taken")
        #expect(record.level.value > 0.3)
        #expect(record.commits == [record.level])
        // A little trackpad travel is the slider's too while it can still move.
        #expect(steps.handle(try ScrollEvents.precise(dy: 3), in: hosted.window, at: center) == nil)
        // Beside the slider nothing is taken.
        let outside = anchor.convert(NSPoint(x: anchor.bounds.maxX + 20, y: anchor.bounds.midY), to: nil)
        let notch = try ScrollEvents.notch()
        #expect(steps.handle(notch, in: hosted.window, at: outside) === notch)
    }

    /// Right to left the boost end is on the left, so a horizontal scroll moves the thumb the way the fingers go.
    @Test func horizontalScrollingIsMirroredRightToLeft() throws {
        var raised: [LayoutDirection: Bool] = [:]
        for direction in [LayoutDirection.leftToRight, .rightToLeft] {
            let record = Record(LevelPosition(0.3))
            let hosted = host(slider(record).underPointer(), direction: direction)
            defer { close(hosted) }
            let anchor = try #require(anchor(in: hosted.host))
            let steps = try #require(anchor.steps)
            defer { steps.stop() }
            let center = anchor.convert(NSPoint(x: anchor.bounds.midX, y: anchor.bounds.midY), to: nil)
            #expect(steps.handle(try ScrollEvents.precise(dx: 24), in: hosted.window, at: center) == nil)
            #expect(record.level != LevelPosition(0.3))
            raised[direction] = record.level.value > 0.3
        }
        #expect(raised[.leftToRight] != raised[.rightToLeft])
    }

    /// Without the pointer there is no platform view (an ImageRenderer would draw a placeholder for it) and nothing
    /// listens.
    @Test func withoutThePointerNothingListens() {
        let hosted = host(slider(Record(.standard)))
        defer { close(hosted) }
        #expect(anchor(in: hosted.host) == nil)
    }

    /// A host's focus state binds the slider's own focusable element: when the host focuses it, → and Home reach
    /// the slider's key handler (one element, one Tab stop; no wrapper that takes focus without the keys).
    @Test func theHostsFocusBindingReachesTheSlidersKeys() throws {
        let record = Record(LevelPosition(0.3))
        let hosted = host(FocusHost(slider: slider(record)))
        defer { close(hosted) }
        hosted.window.makeKey()
        settle(hosted.host)
        try hosted.window.sendEvent(Self.key(.rightArrow, in: hosted.window))
        settle(hosted.host)
        #expect(record.level.value > 0.3, "→ stepped the level")
        try hosted.window.sendEvent(Self.key(.home, in: hosted.window))
        settle(hosted.host)
        #expect(record.level == .standard, "Home is Standard")
    }

    /// Why a host never wraps the slider in a focusable element of its own (as a generic "make this a Tab stop"
    /// modifier does): the host's focus lands on the wrapper, which has no key handler, and → never reaches the
    /// slider inside it.
    @Test func aFocusableWrapperTakesTheFocusButNotTheKeys() throws {
        let record = Record(LevelPosition(0.3))
        let hosted = host(WrappingHost(slider: slider(record)))
        defer { close(hosted) }
        hosted.window.makeKey()
        settle(hosted.host)
        try hosted.window.sendEvent(Self.key(.rightArrow, in: hosted.window))
        settle(hosted.host)
        #expect(record.level == LevelPosition(0.3))
    }

    /// A key-down of → or Home for `window` (the function-key character and the virtual key code AppKit gives).
    private static func key(_ key: KeyEquivalent, in window: NSWindow) throws -> NSEvent {
        let (function, code): (Int, UInt16) = key == .home ? (NSHomeFunctionKey, 115) : (NSRightArrowFunctionKey, 124)
        let characters = String(Character(try #require(UnicodeScalar(UInt32(function)))))
        return try #require(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [.function, .numericPad],
                                             timestamp: ProcessInfo.processInfo.systemUptime,
                                             windowNumber: window.windowNumber, context: nil, characters: characters,
                                             charactersIgnoringModifiers: characters, isARepeat: false, keyCode: code))
    }
}

/// A host with its own focus state that focuses the slider as soon as it appears.
private struct FocusHost: View {
    let slider: BoostSlider
    @FocusState private var focus: Int?

    var body: some View {
        slider.focusBinding($focus, equals: 1)
            .onAppear { focus = 1 }
    }
}

/// A host that makes the slider a Tab stop with its own focusable wrapper (the pattern `focusBinding` replaces).
private struct WrappingHost: View {
    let slider: BoostSlider
    @FocusState private var focus: Int?

    var body: some View {
        slider
            .focusable()
            .focusEffectDisabled()
            .focused($focus, equals: 1)
            .onAppear { focus = 1 }
    }
}

/// A borderless window that may become key while it stays off screen.
private final class KeyableWindow: NSWindow {
    override var canBecomeKey: Bool { true }
}
