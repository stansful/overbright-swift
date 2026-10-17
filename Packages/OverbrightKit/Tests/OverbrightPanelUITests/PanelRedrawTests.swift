// OverbrightPanelUITests/PanelRedrawTests.swift — the panel redraws on change only (DESIGN.md §17): a pass reads the
// settings once for all its cards and builds each card's model once; a panel card is `Equatable` on the model, guard
// words, title and master switch it was given and reads nothing observable itself; the header keeps only the symbol,
// the switch and the dimmed state, and the footer compares its chips by what they show and offer. So a status change
// that moves nothing a part draws (a reading, another display's gain) leaves that part alone.
import Foundation
import Observation
import OverbrightCore
import OverbrightDesign
import SwiftUI
import Testing
@testable import OverbrightPanelUI

@MainActor @Suite struct PanelRedrawTests {
    private func services(_ name: String = "boosting") throws -> OverbrightServices {
        try #require(ScriptedStatuses.services(named: name))
    }

    /// The pass's inputs give every card the model a card reading the settings itself would build, Dimmed's light
    /// included, and two builds over the same inputs are equal.
    @Test func thePassInputsBuildTheSameModelAsTheServices() throws {
        let services = try services("boosting")                              // two displays
        services.settings[DisplaySettings.lastDimLight] = 0.4
        let status = services.boost.status
        let inputs = DisplayCardModel.Inputs(services: services, status: status)
        #expect(status.displays.count >= 2)
        for display in status.displays {
            let pass = DisplayCardModel(status: display, isMasterOn: status.isOn, services: services, inputs: inputs)
            let own = DisplayCardModel(status: display, isMasterOn: status.isOn, services: services)
            #expect(pass == own, "\(display.name)")
            #expect(pass.lastDimLight == 0.4)
            #expect(pass == DisplayCardModel(status: display, isMasterOn: status.isOn, services: services,
                                             inputs: inputs))
        }
        services.settings[DisplaySettings.lastDimLight] = 0.3                 // a changed setting changes the model
        let display = try #require(status.displays.first)
        #expect(DisplayCardModel(status: display, isMasterOn: status.isOn, services: services, inputs: inputs)
                != DisplayCardModel(status: display, isMasterOn: status.isOn, services: services))
    }

    /// A panel card compares equal when the panel gave it the same model, guard words, title and master switch, and
    /// unequal when any of them moved; a card that derives its model (Welcome's seam) never compares equal.
    @Test func aPanelCardIsEqualOnWhatItWasGiven() throws {
        let services = try services()
        let status = services.boost.status
        let display = try #require(status.displays.first)
        let commands = PanelCommands(services: services, source: .panel)
        let model = DisplayCardModel(status: display, isMasterOn: status.isOn, services: services)
        func card(_ model: DisplayCardModel, guardText: String? = nil, title: String? = "A",
                  isMasterOn: Bool = true) -> DisplayCardView {
            DisplayCardView(model: model, guardText: guardText, status: display, isMasterOn: isMasterOn,
                            services: services, title: title, focus: nil, commands: commands)
        }
        #expect(card(model) == card(model))
        var moved = model
        moved.displayedLevel = LevelPosition(0.2)                            // the thumb moved
        #expect(card(model) != card(moved))
        #expect(card(model) != card(model, guardText: "Paused: Low Power Mode"))
        #expect(card(model) != card(model, title: "B"))
        #expect(card(model) != card(model, isMasterOn: false))
        let seam = DisplayCardView(status: display, isMasterOn: true, services: services)
        #expect(seam != seam)
    }

    /// A card given its model reads no setting while it builds what it draws (`model`), so a setting change alone
    /// does not invalidate it; the panel, which built the model, is the one that observes.
    @Test func aCardGivenItsModelObservesNoSetting() throws {
        let services = try services()
        let status = services.boost.status
        let display = try #require(status.displays.first)
        let model = DisplayCardModel(status: display, isMasterOn: status.isOn, services: services)
        let card = DisplayCardView(model: model, guardText: nil, status: display, isMasterOn: status.isOn,
                                   services: services, title: nil, focus: nil,
                                   commands: PanelCommands(services: services, source: .panel))
        let given = Flag()
        withObservationTracking { _ = card.model } onChange: { given.set() }
        let seam = DisplayCardView(status: display, isMasterOn: status.isOn, services: services)
        let derived = Flag()
        withObservationTracking { _ = seam.model } onChange: { derived.set() }
        services.settings[DisplaySettings.lastDimLight] = 0.35
        services.settings[DisplaySettings.linkLevels] = !services.settings[DisplaySettings.linkLevels]
        #expect(!given.isSet, "the given card's model read the settings")
        #expect(derived.isSet, "the seam's card should still follow the settings it reads")
    }

    /// The header keeps the symbol, the switch and whether every display is dimmed: a status whose gains and readings
    /// moved draws the same header; turning off does not.
    @Test func theHeaderIgnoresWhatItDoesNotDraw() throws {
        let services = try services()
        var status = services.boost.status
        let commands = PanelCommands(services: services, source: .panel)
        let symbol: (StatusSymbolState) -> Image = { _ in Image(symbol: .sunMax) }
        @FocusState var focus: PanelFocus?
        func header(_ status: BoostStatus, fillLightOn: Bool = false) -> PanelHeader {
            PanelHeader(status: status, fillLightOn: fillLightOn, symbol: symbol, commands: commands, focus: $focus)
        }
        let before = header(status)
        status.displays = status.displays.map { display in
            var display = display
            display.appliedGain *= 1.01                                       // a ramp step
            return display
        }
        #expect(header(status) == before)
        #expect(header(status, fillLightOn: true) != before)
        status.isOn = false
        #expect(header(status) != before)
    }

    /// The footer compares chips by what they show and offer: the same settings draw an equal footer whatever the
    /// clock says while no timer runs; a changed setting does not.
    @Test func theFooterIsEqualWhileItsChipsAre() throws {
        let services = try services()
        let settings = services.settings
        let now = Date(timeIntervalSinceReferenceDate: 800_000_000)
        func footer(at time: Date) -> PanelFooter {
            PanelFooter(chips: FooterChips.chips(settings: settings, hasBattery: true, autoOffAt: nil, now: time,
                                                 editApps: {}), focus: nil)
        }
        #expect(footer(at: now) == footer(at: now.addingTimeInterval(61)))
        let before = footer(at: now)
        settings[AutomationSettings.batteryThreshold] = settings[AutomationSettings.batteryThreshold] == 20 ? 30 : 20
        #expect(footer(at: now) != before)
    }
}

/// A flag an observation's change handler sets (it may run on any thread).
private nonisolated final class Flag: @unchecked Sendable {
    private let lock = NSLock()
    private var value = false
    func set() { lock.withLock { value = true } }
    var isSet: Bool { lock.withLock { value } }
}
