// OverbrightAppShellTests/StatusItemClickRoutingTests.swift — DESIGN.md §4.2's click table for both settings of
// "Clicking the icon": click, right-click or ⌃-click, ⌥-click; a press without a mouse event (VoiceOver, keyboard)
// is a plain click and gives the panel keyboard focus (§5.1); a toggle from the icon is announced (§4.2, §12.9).
import AppKit
import OverbrightCore
import Testing
@testable import OverbrightAppShell

@MainActor @Suite struct ClickRoutingTests {
    @Test func opensThePanelByDefault() {
        let setting = StatusClickAction.openPanel
        #expect(ClickRouting.action(for: .left, modifiers: [], setting: setting) == .togglePanel)
        #expect(ClickRouting.action(for: .right, modifiers: [], setting: setting) == .showMenu)
        #expect(ClickRouting.action(for: .left, modifiers: .control, setting: setting) == .showMenu)
        #expect(ClickRouting.action(for: .left, modifiers: .option, setting: setting) == .toggleMaster)
    }

    @Test func toggleModeSwapsClickAndOptionClick() {
        let setting = StatusClickAction.toggle
        #expect(ClickRouting.action(for: .left, modifiers: [], setting: setting) == .toggleMaster)
        #expect(ClickRouting.action(for: .right, modifiers: [], setting: setting) == .showMenu)
        #expect(ClickRouting.action(for: .left, modifiers: .control, setting: setting) == .showMenu)
        #expect(ClickRouting.action(for: .left, modifiers: .option, setting: setting) == .togglePanel)
        #expect(ClickRouting.action(for: .right, modifiers: .option, setting: setting) == .showMenu)   // the menu wins
    }

    @Test func eventsRouteByButtonAndModifiers() throws {
        func mouse(_ type: NSEvent.EventType, _ flags: NSEvent.ModifierFlags = []) throws -> NSEvent {
            try #require(NSEvent.mouseEvent(with: type, location: .zero, modifierFlags: flags, timestamp: 0,
                                            windowNumber: 0, context: nil, eventNumber: 0, clickCount: 1, pressure: 1))
        }
        #expect(ClickRouting.action(for: try mouse(.leftMouseUp), setting: .openPanel) == .togglePanel)
        #expect(ClickRouting.action(for: try mouse(.rightMouseUp), setting: .openPanel) == .showMenu)
        #expect(ClickRouting.action(for: try mouse(.leftMouseUp, [.control, .capsLock]), setting: .openPanel) == .showMenu)
        #expect(ClickRouting.action(for: try mouse(.leftMouseUp, .option), setting: .toggle) == .togglePanel)
        #expect(ClickRouting.action(for: nil, setting: .toggle) == .toggleMaster)                   // VoiceOver's press
        #expect(!ClickRouting.isKeyboardOrAccessibility(try mouse(.leftMouseUp)))
        #expect(ClickRouting.isKeyboardOrAccessibility(nil))
    }

    @Test func aToggleFromTheIconIsAnnouncedAndTheClickRoutes() throws {
        var posted: [String] = []
        let services = OverbrightServices(
            settings: SettingsStore(defaults: InMemoryDefaults()), paths: .temporary(), machine: DisplayFixture.ownerMachine,
            time: ManualTimeSource(), journal: RingBufferJournal(), announcer: Announcer(post: { posted.append($0) }, now: { 0 }),
            ownEDRSurfaces: OwnEDRSurfaces(), displays: FakeDisplayDirectory(fixture: .builtinXDRLidOpen),
            signals: FakeSystemSignals(), boost: PreviewBoostControl(fixture: .builtinXDRLidOpen),
            fillLight: PreviewFillLightControl(), shortcuts: PreviewShortcutCenter(), updates: PreviewUpdateChecking())
        let controller = StatusItemController(services: services)
        var panelToggles = 0
        controller.onClick = { panelToggles += 1 }
        controller.perform(.toggleMaster)
        controller.perform(.toggleMaster)
        controller.perform(.togglePanel)
        let boost = try #require(services.boost as? PreviewBoostControl)
        #expect(boost.calls == ["toggle(statusItem)", "toggle(statusItem)"])
        #expect(posted == ["Overbright on", "Overbright off"])
        #expect(panelToggles == 1)
        controller.perform(.showMenu)                                   // not installed: nothing opens, nothing breaks
    }
}
