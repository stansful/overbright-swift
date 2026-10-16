// OverbrightIntentsTests/ControlStatePublisherTests.swift — the control's one publish point (ARCHITECTURE.md §7.7,
// D25): nothing at all without the extension; with it, word → snapshot → reload on every change the control shows,
// every control reloaded at start and stop, "not valid" at stop, a new generation per publish, and no publish for
// status changes the control does not show (energy). Recorded outlet: no notifyd, preferences or Control Center.
import Foundation
import OverbrightChannel
import OverbrightCore
import OverbrightTestSupport
import Testing
@testable import OverbrightIntents

/// Records the publisher's outputs in order.
@MainActor private final class RecordingOutlet: ControlStateOutlet {
    let isControlInstalled: Bool
    private(set) var calls: [String] = []
    private(set) var words: [UInt64] = []
    init(installed: Bool) { isControlInstalled = installed }
    func ensureToken() { calls.append("token") }
    func post(_ word: UInt64) {
        words.append(word)
        let state = BoostChannel.unpack(word)
        calls.append(state.isValid ? "word(\(state.isOn ? "on" : "off"),\(state.levelPermille),#\(state.generation))" : "word(invalid)")
    }
    func writeSnapshot(_ state: BoostChannel.State) {
        calls.append(state.isValid ? "snapshot(#\(state.generation))" : "snapshot(invalid)")
    }
    func reloadControl() { calls.append("reload") }
    func reloadAllControls() { calls.append("reloadAll") }
}

@MainActor @Suite struct ControlStatePublisherTests {
    private let boost = PreviewBoostControl(fixture: .builtinXDRLidOpen)

    @Test func withoutTheControlNothingHappens() async {
        let outlet = RecordingOutlet(installed: false)
        let publisher = ControlStatePublisher(boost: boost, outlet: outlet)
        publisher.start()
        boost.setOn(true, source: .panel)
        for _ in 0..<20 { await Task.yield() }
        publisher.stop()
        #expect(!publisher.isPublishing)
        #expect(outlet.calls.isEmpty)
    }

    @Test func startPublishesTheStateAndReloadsEveryControl() {
        let outlet = RecordingOutlet(installed: true)
        let publisher = ControlStatePublisher(boost: boost, outlet: outlet)
        publisher.start()
        publisher.start()                                       // once
        #expect(publisher.isPublishing)
        #expect(outlet.calls == ["token", "word(off,0,#1)", "snapshot(#1)", "reloadAll"])
    }

    @Test func aChangeWritesTheWordThenTheSnapshotThenReloads() async {
        let outlet = RecordingOutlet(installed: true)
        let publisher = ControlStatePublisher(boost: boost, outlet: outlet)
        publisher.start()
        boost.setOn(true, source: .panel)
        #expect(await eventually { outlet.calls.count == 7 })
        #expect(Array(outlet.calls.suffix(3)) == ["word(on,0,#2)", "snapshot(#2)", "reload"])
        boost.setOn(false, source: .menu)
        #expect(await eventually { outlet.calls.count == 10 })
        #expect(Array(outlet.calls.suffix(3)) == ["word(off,0,#3)", "snapshot(#3)", "reload"])
        publisher.stop()
    }

    @Test func changesTheControlDoesNotShowPublishNothing() async {
        let outlet = RecordingOutlet(installed: true)
        let publisher = ControlStatePublisher(boost: boost, outlet: outlet)
        publisher.start()
        boost.status.lastChange = LevelChange(sequence: 9, kind: .preparing, source: .intent, display: nil)
        boost.status.displays[0].appliedGain = 1.4                 // a ramp step
        boost.status.symbol = .preparing
        boost.setOn(true, source: .panel)                           // the one change that shows
        #expect(await eventually { outlet.calls.count == 7 })
        for _ in 0..<20 { await Task.yield() }
        #expect(outlet.calls.count == 7)
        #expect(outlet.words.map { BoostChannel.unpack($0).generation } == [1, 2])
        publisher.stop()
    }

    @Test func stopLeavesTheControlOff() async {
        let outlet = RecordingOutlet(installed: true)
        let publisher = ControlStatePublisher(boost: boost, outlet: outlet)
        publisher.start()
        publisher.stop()
        #expect(Array(outlet.calls.suffix(3)) == ["word(invalid)", "snapshot(invalid)", "reloadAll"])
        #expect(outlet.words.last == 0)
        let count = outlet.calls.count
        boost.setOn(true, source: .panel)
        for _ in 0..<20 { await Task.yield() }
        #expect(outlet.calls.count == count)
        publisher.stop()
        #expect(outlet.calls.count == count)
    }

    @Test func theLevelIsTheHighestBoostTargetInStops() {
        var status = PreviewBoostControl(fixture: .mpg322uxHDROn).status
        status.displays = PreviewBoostControl(fixture: .builtinXDRLidOpen).status.displays + status.displays
        status.isOn = true
        func level(_ first: BoostTarget, _ second: BoostTarget) -> Int {
            status.displays[0].decision = decision(DisplayFixture.Keys.builtIn, verdict: supported, target: first)
            status.displays[1].decision = decision(DisplayFixture.Keys.mpg322ux, verdict: supported, target: second)
            return ControlStatePublisher.levelPermille(of: status)
        }
        #expect(level(.boost(gain: 2), .boost(gain: 4)) == 500)          // 2 of 4 stops
        #expect(level(.boost(gain: 2), .neutral) == 250)
        #expect(level(.boost(gain: 16), .dim(light: 0.5)) == 1000)
        #expect(level(.boost(gain: 40), .neutral) == 1000)                // clamped
        #expect(level(.dim(light: 0.25), .neutral) == 0)
        #expect(level(.boost(gain: .infinity), .neutral) == 0)
        status.isOn = false
        #expect(ControlStatePublisher.levelPermille(of: status) == 0)
        #expect(ControlStatePublisher.content(of: status) == BoostChannel.State(isValid: true, isOn: false,
                                                                                 levelPermille: 0, generation: 0))
    }
}
