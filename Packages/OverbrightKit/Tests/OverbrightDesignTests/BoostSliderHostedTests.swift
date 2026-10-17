// OverbrightDesignTests/BoostSliderHostedTests.swift — the level slider in a real view hierarchy: an NSHostingView in a
// window that is never ordered in; events are made and handed to that window, never posted. The slider is the 240-pt
// track alone (the card's slider row draws the end glyphs, DESIGN.md §5.4); with the pointer on it its scroll anchor
// sits in that window and drives the level through the slider's own handler (DESIGN.md §5.5, §15), mirrored right to
// left; without the pointer there is no anchor and nothing listens; and a host that binds the slider's focus moves
// the level with the arrow keys of that one focusable element, where a focusable wrapper around it would take the
// focus without the keys (DESIGN.md §5.12). Every wait is `eventually` on the condition asserted (ARCHITECTURE.md
// §9.1), never a fixed delay.
import AppKit
import Observation
import OverbrightCore
import OverbrightPolicy
import OverbrightTestSupport
import SwiftUI
import Testing
@testable import OverbrightDesign

@MainActor @Suite struct BoostSliderHostedTests {
    /// A level, the commits the slider made, and the host's focus as it last changed. Observable, so the slider draws
    /// again when its level changes, as it does over the app's own state.
    @Observable final class Record {
        var level: LevelPosition
        var commits: [LevelPosition] = []
        var focus: Int?
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

    private func anchor(in view: NSView) -> ScrollWheelAnchor.AnchorView? {
        if let anchor = view as? ScrollWheelAnchor.AnchorView { return anchor }
        for subview in view.subviews {
            if let found = anchor(in: subview) { return found }
        }
        return nil
    }

    /// The slider's scroll anchor once it is in `hosted`'s window with its listener running; nil if that never comes.
    private func listeningAnchor(in hosted: HostedView) async -> ScrollWheelAnchor.AnchorView? {
        var found: ScrollWheelAnchor.AnchorView?
        _ = await eventually {
            found = anchor(in: hosted.host)
            return found?.steps?.isListening == true
        }
        return found
    }

    /// The slider is the track: the 14-pt sun glyphs and their gaps belong to the card's slider row, so the slider
    /// fits the card's 240-pt frame exactly.
    @Test func theSliderIsTheTrackAlone() {
        let hosted = HostedView(slider(Record(.standard)))
        defer { hosted.close() }
        #expect(hosted.host.fittingSize.width == BoostSliderTrack.width)
        #expect(hosted.host.fittingSize.height == HitTarget.sliderThumb)
    }

    /// With the pointer on the slider its anchor is in the slider's window, the listener runs with the slider's own
    /// handler, and a notch over the slider steps and commits the level.
    @Test func theScrollAnchorAttachesAndStepsTheLevel() async throws {
        let record = Record(LevelPosition(0.3))
        let hosted = HostedView(slider(record).underPointer())
        defer { hosted.close() }
        let anchor = try #require(await listeningAnchor(in: hosted), "the anchor is in place while the pointer is over")
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
    @Test func horizontalScrollingIsMirroredRightToLeft() async throws {
        var raised: [LayoutDirection: Bool] = [:]
        for direction in [LayoutDirection.leftToRight, .rightToLeft] {
            let record = Record(LevelPosition(0.3))
            let hosted = HostedView(slider(record).underPointer(), direction: direction)
            defer { hosted.close() }
            let anchor = try #require(await listeningAnchor(in: hosted))
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
        let hosted = HostedView(slider(Record(.standard)))
        defer { hosted.close() }
        #expect(anchor(in: hosted.host) == nil)
    }

    /// A host's focus state binds the slider's own focusable element: when the host focuses it, → and Home reach
    /// the slider's key handler (one element, one Tab stop; no wrapper that takes focus without the keys).
    @Test func theHostsFocusBindingReachesTheSlidersKeys() async throws {
        let record = Record(LevelPosition(0.3))
        let hosted = HostedView(FocusHost(slider: slider(record), record: record))
        defer { hosted.close() }
        hosted.window.makeKey()
        #expect(await eventually { record.focus == 1 && hosted.hostIsFirstResponder }, "the host focused the slider")
        try hosted.press(.rightArrow)
        #expect(await eventually { record.level.value > 0.3 }, "→ stepped the level")
        try hosted.press(.home)
        #expect(await eventually { record.level == .standard }, "Home is Standard")
    }

    /// Why a host never wraps the slider in a focusable element of its own (as a generic "make this a Tab stop"
    /// modifier does): the host's focus lands on the wrapper, which has no key handler, and → never reaches the
    /// slider inside it.
    /// The key reaches the window's focused element while the event is handed over (`sendEvent` dispatches it at
    /// once), so once the wrapper holds the focus a → that would have stepped the slider has already been ignored.
    @Test func aFocusableWrapperTakesTheFocusButNotTheKeys() async throws {
        let record = Record(LevelPosition(0.3))
        let hosted = HostedView(WrappingHost(slider: slider(record), record: record))
        defer { hosted.close() }
        hosted.window.makeKey()
        #expect(await eventually { record.focus == 1 && hosted.hostIsFirstResponder }, "the wrapper took the focus")
        try hosted.press(.rightArrow)
        #expect(record.level == LevelPosition(0.3))
    }
}

/// A host with its own focus state that focuses the slider as soon as it appears, and reports its focus.
private struct FocusHost: View {
    let slider: BoostSlider
    let record: BoostSliderHostedTests.Record
    @FocusState private var focus: Int?

    var body: some View {
        slider.focusBinding($focus, equals: 1)
            .onAppear { focus = 1 }
            .onChange(of: focus) { _, value in record.focus = value }
    }
}

/// A host that makes the slider a Tab stop with its own focusable wrapper (the pattern `focusBinding` replaces).
private struct WrappingHost: View {
    let slider: BoostSlider
    let record: BoostSliderHostedTests.Record
    @FocusState private var focus: Int?

    var body: some View {
        slider
            .focusable()
            .focusEffectDisabled()
            .focused($focus, equals: 1)
            .onAppear { focus = 1 }
            .onChange(of: focus) { _, value in record.focus = value }
    }
}
