// OverbrightIntentsTests/StateReportTests.swift — Get Overbright State's dialog and the displays the Shortcuts app
// offers (DESIGN.md §12.8, §1 principle 4: the panel's value text, byte for byte; D8: names for presentation only).
import Foundation
import OverbrightCore
import OverbrightPolicy
import OverbrightTestSupport
import Testing
@testable import OverbrightIntents

@MainActor @Suite struct StateReportTests {
    private let isolate = { (name: String) in "\u{2068}\(name)\u{2069}" }

    private func connected(_ fixture: DisplayFixture) -> (IntentRouter, PreviewBoostControl) {
        let router = IntentRouter(time: ManualTimeSource())
        let boost = PreviewBoostControl(fixture: fixture)
        router.connect(boost: boost, displays: FakeDisplayDirectory(fixture: fixture), signals: FakeSystemSignals())
        return (router, boost)
    }

    @Test func offSaysOnlyThatItIsOff() async throws {
        let (router, _) = connected(.builtinXDRLidOpen)
        var asked = 0
        let report = try await router.stateReport { _ in asked += 1; return "Bright room · ×1.29" }
        #expect(report == StateReport(isOn: false, dialog: "Overbright is off."))
        #expect(asked == 0)
    }

    @Test func onNamesEachDisplayWithThePanelsValueText() async throws {
        let (router, boost) = connected(.russianNames)
        boost.status.isOn = true
        var texts = ["Bright room · ×1.29", "Dimmed · 25 %"]
        let report = try await router.stateReport { _ in texts.removeFirst() }
        let names = DisplayFixture.russianNames.displays.map(\.facts.name)
        #expect(report.isOn)
        #expect(report.dialog == "Overbright is on. \(isolate(names[0])): Bright room · ×1.29. \(isolate(names[1])): Dimmed · 25 %.")
    }

    @Test func theValueTextGetsThePanelsReadoutNumbers() async throws {
        let (router, boost) = connected(.builtinXDRLidOpen)
        boost.status.isOn = true
        var received: [ReadoutValues] = []
        _ = try await router.stateReport { values in received.append(values); return "x" }
        let expected = boost.status.displays.map { Readout.values(for: $0, isMasterOn: true) }
        #expect(received == expected)
    }

    @Test func displaysWithoutACardOrWithoutTextAreLeftOut() async throws {
        let (router, boost) = connected(.sidecar)
        boost.status.isOn = true
        boost.decide(DisplayFixture.Keys.builtIn, verdict: supported)
        boost.decide(DisplayFixture.Keys.sidecar, verdict: .virtualDisplay)
        var asked = 0
        let report = try await router.stateReport { _ in asked += 1; return "Standard" }
        #expect(asked == 1)
        #expect(report.dialog == "Overbright is on. \(isolate("Built-in Retina Display")): Standard.")
        let empty = try await router.stateReport { _ in "" }                      // Design not wired yet
        #expect(empty.dialog == "Overbright is on.")
    }

    @Test func theShortcutsAppOffersDisplaysThatCanBoostOrDim() async throws {
        let (router, boost) = connected(.sidecar)
        #expect(try await router.displayChoices().map(\.key) == [DisplayFixture.Keys.builtIn, DisplayFixture.Keys.sidecar])
        boost.decide(DisplayFixture.Keys.sidecar, verdict: .virtualDisplay)
        #expect(try await router.displayChoices() == [DisplayChoice(key: DisplayFixture.Keys.builtIn, name: "Built-in Retina Display")])
    }

    @Test func aSavedDisplayResolvesEvenWhenItIsNotConnected() async throws {
        let (router, _) = connected(.builtinXDRLidOpen)
        let gone = DisplayKey(rawValue: "0B21E7F1-FFFF-4000-8000-0000000000FF")
        let choices = try await router.displayChoices(for: [gone, DisplayFixture.Keys.builtIn])
        #expect(choices == [DisplayChoice(key: gone, name: nil),
                            DisplayChoice(key: DisplayFixture.Keys.builtIn, name: "Built-in Retina Display")])
    }
}
