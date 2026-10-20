// OverbrightHotKeysTests/HotKeysTests.swift — the global shortcut center (ARCHITECTURE.md §3.6, §3.7, D17) against a
// recording registrar: no test registers a real combination system-wide. The shipped catalog binds nothing (D17), so
// the behaviour tests run on `SampleShortcuts.catalog`, the catalog with five sample defaults. Ported from Cranny's
// hot-key tests (the owner's MIT code); one test registers a real Carbon hot key on a combination nobody uses.
import Foundation
import Observation
import OverbrightCore
import OverbrightTestSupport
import Testing
@testable import OverbrightHotKeys

/// Registers in memory; `refused` combos fail like a combination another app owns. `press(_:)` simulates Carbon.
@MainActor final class FakeRegistrar: HotKeyRegistrar {
    var onPress: (@MainActor (UInt32) -> Void)?
    var refused: Set<KeyCombo> = []
    private(set) var live: [UInt32: KeyCombo] = [:]
    private(set) var registrations = 0
    private var nextID: UInt32 = 100

    func register(_ combo: KeyCombo) -> UInt32? {
        registrations += 1
        guard !refused.contains(combo) else { return nil }
        nextID += 1
        live[nextID] = combo
        return nextID
    }

    func unregister(_ id: UInt32) { live[id] = nil }

    /// Presses the live hot key with `combo` (false when none is registered, as Carbon would deliver nothing).
    @discardableResult func press(_ combo: KeyCombo) -> Bool {
        guard let id = live.first(where: { $0.value == combo })?.key else { return false }
        onPress?(id)
        return true
    }
}

private let hyper = SampleShortcuts.hyper
private let toggleCombo = SampleShortcuts.toggle                                   // ⌃⌥⌘B
/// ⌃⌥⇧⌘F19: a combination nobody uses.
private let unusedCombo = KeyCombo(keyCode: 80, modifiers: [.control, .option, .shift, .command])

/// A center over `shortcuts` (the sample catalog unless a test checks the shipped one).
@MainActor private func makeCenter(_ registrar: FakeRegistrar = FakeRegistrar(),
                                   settings: SettingsStore = SettingsStore(defaults: InMemoryDefaults()),
                                   shortcuts: [GlobalShortcut] = SampleShortcuts.catalog)
    -> (HotKeyCenter, FakeRegistrar, SettingsStore) {
    let center = HotKeyCenter(settings: settings, shortcuts: shortcuts, registrar: registrar,
                              layout: { .named(KeyCombo.KeyboardLayout.us) })
    return (center, registrar, settings)
}

@MainActor @Suite struct HotKeysTests {
    @Test func bindingsResolveAgainstDefaults() {
        let toggle = GlobalShortcut(id: .toggle, defaultCombo: toggleCombo)
        let max = GlobalShortcut(id: .max, defaultCombo: nil)
        #expect(HotKeyCenter.effectiveCombo(for: toggle, bindings: [:]) == toggleCombo)
        #expect(HotKeyCenter.effectiveCombo(for: toggle, bindings: [.toggle: nil]) == nil)        // explicitly off
        #expect(HotKeyCenter.effectiveCombo(for: toggle, bindings: [.toggle: unusedCombo]) == unusedCombo)
        #expect(HotKeyCenter.effectiveCombo(for: max, bindings: [:]) == nil)                      // off until set
        #expect(CarbonHotKeyRegistrar.carbonModifiers([.control, .option]) == 0x1000 | 0x0800)    // controlKey | optionKey
        #expect(CarbonHotKeyRegistrar.carbonModifiers([.command, .shift]) == 0x0100 | 0x0200)
    }

    /// `constructingServicesTouchesNoHardware`: nothing is registered before `start()`.
    @Test func constructionRegistersNothing() {
        let (center, registrar, _) = makeCenter()
        #expect(registrar.registrations == 0 && registrar.live.isEmpty)
        #expect(center.state(.toggle) == .off && center.displayString(.toggle) == nil)
    }

    /// D17: the shipped catalog binds nothing, so a first launch registers no hot key at all; every shortcut reads off.
    @Test func aFirstLaunchRegistersNoHotKey() async {
        let (center, registrar, _) = makeCenter(shortcuts: ShortcutCatalog.all)
        await center.start()
        #expect(registrar.registrations == 0 && registrar.live.isEmpty)
        #expect(ShortcutCatalog.all.allSatisfy { center.state($0.id) == .off && center.displayString($0.id) == nil })
        #expect(center.set(.standard, SampleShortcuts.standard) == .registered(SampleShortcuts.standard))  // recorded
        #expect(registrar.live.values.contains(SampleShortcuts.standard))
        await center.stop()
    }

    /// A catalog's defaults register (the sample catalog's five); Max and Fill Light have none.
    @Test func startRegistersTheCatalogDefaults() async {
        let (center, registrar, _) = makeCenter()
        await center.start()
        let expected = SampleShortcuts.catalog.compactMap(\.defaultCombo)
        #expect(Set(registrar.live.values) == Set(expected) && registrar.live.count == 5)
        #expect(center.state(.toggle) == .registered(toggleCombo))
        #expect(center.state(.max) == .off && center.state(.fillLight) == .off)
        await center.stop()
        #expect(registrar.live.isEmpty && center.state(.toggle) == .off)
    }

    @Test func aTakenCombinationIsAConflictWithoutKeyCaps() async {
        let registrar = FakeRegistrar()
        registrar.refused = [toggleCombo]
        let (center, _, _) = makeCenter(registrar)
        await center.start()
        #expect(center.state(.toggle) == .conflict(toggleCombo))
        #expect(center.displayString(.toggle) == nil)
        #expect(center.state(.standard) == .registered(KeyCombo(keyCode: 29, modifiers: hyper)))
    }

    /// `set` returns the RESULTING state, stores the binding, and observers of `state` refresh.
    @Test func setReturnsTheResultingStateAndViewsRefresh() async {
        let (center, registrar, settings) = makeCenter()
        await center.start()
        nonisolated final class Flag: @unchecked Sendable { var fired = false }      // written on the main actor only
        let flag = Flag()
        withObservationTracking { _ = center.state(.max) } onChange: { flag.fired = true }
        #expect(center.set(.max, unusedCombo) == .registered(unusedCombo))
        #expect(flag.fired)
        #expect(settings[ShortcutSettings.bindings][.max] == .some(unusedCombo))
        #expect(registrar.live.values.contains(unusedCombo))
        registrar.refused = [unusedCombo]
        #expect(center.set(.fillLight, unusedCombo) == .conflict(unusedCombo))
        #expect(center.set(.toggle, nil) == .off)                                    // cleared
        #expect(settings[ShortcutSettings.bindings][.toggle] == .some(nil))
        #expect(!registrar.live.values.contains(toggleCombo))
    }

    /// Choosing the default combo again removes the override, so the row reads "default" (no changed dot).
    @Test func settingTheDefaultRemovesTheOverride() async {
        let (center, _, settings) = makeCenter()
        await center.start()
        center.set(.toggle, unusedCombo)
        #expect(!settings.isDefault(ShortcutSettings.bindings))
        center.set(.toggle, toggleCombo)
        #expect(settings[ShortcutSettings.bindings][.toggle] == nil && settings.isDefault(ShortcutSettings.bindings))
        #expect(center.state(.toggle) == .registered(toggleCombo))
    }

    /// Reset All, Undo or any other writer changes the bindings: the center follows.
    @Test func bindingChangesFromElsewhereReapply() async {
        let (center, registrar, settings) = makeCenter()
        await center.start()
        settings[ShortcutSettings.bindings] = [.toggle: unusedCombo]
        #expect(await eventually { center.state(.toggle) == .registered(unusedCombo) })
        #expect(registrar.live.values.contains(unusedCombo) && !registrar.live.values.contains(toggleCombo))
        settings.reset(ShortcutSettings.bindings)
        #expect(await eventually { center.state(.toggle) == .registered(toggleCombo) })
    }

    /// The recorder: every hot key is unregistered while it listens, states stay, presses do nothing; afterwards the
    /// bindings of that moment register.
    @Test func recordingPausesEveryHotKeyAndKeepsTheStates() async {
        let (center, registrar, _) = makeCenter()
        var pressed: [ShortcutID] = []
        center.onPress = { pressed.append($0) }
        await center.start()
        let before = center.states
        center.setRecording(true)
        #expect(registrar.live.isEmpty && center.states == before && center.isRecording)
        #expect(!registrar.press(toggleCombo))
        #expect(center.set(.max, unusedCombo) == .off)                               // stored; registered afterwards
        #expect(registrar.live.isEmpty)                                              // still nothing while recording
        center.setRecording(false)
        #expect(center.state(.max) == .registered(unusedCombo))
        #expect(registrar.press(toggleCombo) && pressed == [.toggle])
    }

    @Test func pressesRouteToTheirShortcut() async {
        let (center, registrar, _) = makeCenter()
        var pressed: [ShortcutID] = []
        center.onPress = { pressed.append($0) }
        await center.start()
        registrar.press(KeyCombo(keyCode: 29, modifiers: hyper))                     // ⌃⌥⌘0
        registrar.press(KeyCombo(keyCode: 25, modifiers: hyper))                     // ⌃⌥⌘9
        #expect(pressed == [.standard, .dimToggle])
    }

    /// The real registrar on a combination nobody uses (as Cranny's test did): registers, then unregisters.
    @Test func carbonRegistersAndUnregistersARealHotKey() {
        let registrar = CarbonHotKeyRegistrar()
        let id = registrar.register(unusedCombo)
        #expect(id != nil)
        if let id { registrar.unregister(id) }
        registrar.unregister(9_999_999)                                              // unknown: no-op
    }
}
