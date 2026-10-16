// OverbrightHotKeys/HotKeyCenter.swift — Overbright's global shortcuts. ARCHITECTURE.md §3.6 (`ShortcutCenter`), §3.7,
// §7.4 (lifecycle order), D17; DESIGN.md §7.6, §16. Ported from Cranny's HotKeyCenter (the owner's MIT code):
// `ModuleRegistry` became an explicit shortcut list plus the settings store, the states carry their combo, and
// `displayString` renders key caps through the current keyboard layout.
//
// The center registers every shortcut of `ShortcutCatalog` with its effective binding (`ShortcutSettings.bindings`: a
// combo, an explicit nil = cleared, no entry = the default) once started, and again whenever the bindings change
// (Reset All, Undo, any writer); `set(_:_:)` writes the binding and re-applies at once so it can return the resulting
// state. `states` is observed: the recorder, the menu and Welcome re-render when a shortcut turns `.conflict` or `.off`.
// While the Settings recorder listens (`setRecording(true)`) every hot key is unregistered so its keys reach the
// recorder; the states keep their values and everything re-registers afterwards. Key caps follow the keyboard layout:
// a layout switch (`kTISNotifySelectedKeyboardInputSourceChanged`, distributed, delivered on main) bumps an observed
// generation so every surface that shows them redraws.
import Carbon
import Foundation
import Observation
import OverbrightCore
import os

private let log = Log.logger(.hotKeys)

/// Registers Overbright's global shortcuts and reports their state (`services.shortcuts`).
@MainActor @Observable public final class HotKeyCenter: ShortcutCenter, ServiceLifecycle {
    /// What a press does, by shortcut. Set by the composition root (the engine's calls); nil = presses are ignored.
    @ObservationIgnored public var onPress: (@MainActor (ShortcutID) -> Void)?

    /// The state of every shortcut after the last `apply` (empty before `start()` and after `stop()`).
    public private(set) var states: [ShortcutID: ShortcutState] = [:]
    /// Bumped when the keyboard layout changes, so views reading `displayString` redraw.
    private var layoutGeneration = 0

    @ObservationIgnored private let settings: SettingsStore
    @ObservationIgnored private let shortcuts: [GlobalShortcut]
    @ObservationIgnored private let registrar: any HotKeyRegistrar
    @ObservationIgnored private let layout: @MainActor () -> KeyCombo.KeyboardLayout?
    @ObservationIgnored private var registered: [ShortcutID: UInt32] = [:]
    @ObservationIgnored private var routes: [UInt32: ShortcutID] = [:]
    /// The bindings of the last `apply`, so the settings observer skips a change `set` already applied.
    @ObservationIgnored private var applied: [ShortcutID: KeyCombo?]?
    @ObservationIgnored private var bindingsToken: ObservationToken?
    @ObservationIgnored private var layoutObserver: (any NSObjectProtocol)?
    @ObservationIgnored private var isStarted = false
    /// The recorder listens: nothing is registered.
    @ObservationIgnored public private(set) var isRecording = false

    /// A center for `shortcuts` (the catalog by default) whose bindings live in `settings`. Construction registers
    /// nothing and observes nothing (`constructingServicesTouchesNoHardware`); `start()` does. `layout` renders key caps
    /// (the current keyboard layout; tests pass a fixed one).
    public init(settings: SettingsStore, shortcuts: [GlobalShortcut] = ShortcutCatalog.all,
                registrar: any HotKeyRegistrar = CarbonHotKeyRegistrar(),
                layout: @escaping @MainActor () -> KeyCombo.KeyboardLayout? = { .forDisplay() }) {
        self.settings = settings
        self.shortcuts = shortcuts
        self.registrar = registrar
        self.layout = layout
        registrar.onPress = { [weak self] id in self?.pressed(id) }
    }

    // MARK: ServiceLifecycle

    /// "HotKeys".
    public var serviceName: String { "HotKeys" }

    /// Registers every shortcut and follows the bindings and the keyboard layout from now on.
    public func start() async {
        guard !isStarted else { return }
        isStarted = true
        reapply()
        bindingsToken = observe({ [settings] in settings[ShortcutSettings.bindings] }) { [weak self] bindings in
            guard let self, self.applied != bindings else { return }
            self.apply(bindings)
        }
        let name = Notification.Name(kTISNotifySelectedKeyboardInputSourceChanged as String)
        layoutObserver = DistributedNotificationCenter.default().addObserver(forName: name, object: nil,
                                                                             queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.layoutGeneration += 1 }                 // queue: .main
        }
    }

    /// Unregisters everything and stops following the settings.
    public func stop() async { stopNow() }

    /// Unregisters everything at once (`applicationWillTerminate`).
    public func stopNow() {
        bindingsToken?.cancel()
        bindingsToken = nil
        if let layoutObserver { DistributedNotificationCenter.default().removeObserver(layoutObserver) }
        layoutObserver = nil
        unregisterAll()
        applied = nil
        isRecording = false
        isStarted = false
        if !states.isEmpty { states = [:] }
    }

    // MARK: ShortcutCenter

    /// The live state of one shortcut (`.off` before `start()`).
    public func state(_ id: ShortcutID) -> ShortcutState { states[id] ?? .off }

    /// Stores `combo` for `id` (nil clears the shortcut; the default combo removes the override) and re-registers at
    /// once; returns the resulting state.
    @discardableResult public func set(_ id: ShortcutID, _ combo: KeyCombo?) -> ShortcutState {
        var bindings = settings[ShortcutSettings.bindings]
        let defaultCombo = shortcuts.first { $0.id == id }?.defaultCombo
        if combo == defaultCombo { bindings[id] = nil } else { bindings[id] = .some(combo) }
        settings[ShortcutSettings.bindings] = bindings
        if isStarted { apply(bindings) }
        return state(id)
    }

    /// While the recorder listens every hot key is unregistered, so a combination that is already bound records
    /// instead of running; the states keep their values (the rows do not flash "Off") and everything re-registers
    /// with the bindings of that moment afterwards.
    public func setRecording(_ recording: Bool) {
        guard isRecording != recording else { return }
        isRecording = recording
        if recording { unregisterAll() } else if isStarted { reapply() }
    }

    /// The key caps of a registered shortcut in the current keyboard layout ("⌃⌥⌘B"); nil when cleared, refused or not
    /// started.
    public func displayString(_ id: ShortcutID) -> String? {
        _ = layoutGeneration                                  // redraw on a layout switch
        guard case .registered(let combo) = state(id) else { return nil }
        return combo.keyCaps(in: layout(), spaceName: Self.spaceName)
    }

    // MARK: Applying

    /// Re-registers every shortcut with the stored bindings; returns the states.
    @discardableResult public func reapply() -> [ShortcutID: ShortcutState] {
        apply(settings[ShortcutSettings.bindings])
    }

    /// (Re-)registers every shortcut with its effective combination; returns the resulting states.
    @discardableResult func apply(_ bindings: [ShortcutID: KeyCombo?]) -> [ShortcutID: ShortcutState] {
        unregisterAll()
        // Recording: nothing is registered now; the end of recording re-applies the bindings of that moment.
        guard !isRecording else { applied = nil; return states }
        applied = bindings
        var next: [ShortcutID: ShortcutState] = [:]
        for shortcut in shortcuts {
            guard let combo = Self.effectiveCombo(for: shortcut, bindings: bindings) else {
                next[shortcut.id] = .off
                continue
            }
            if let id = registrar.register(combo) {
                registered[shortcut.id] = id
                routes[id] = shortcut.id
                next[shortcut.id] = .registered(combo)
            } else {
                log.info("hot key \(shortcut.id.rawValue, privacy: .public) is taken")
                next[shortcut.id] = .conflict(combo)
            }
        }
        if states != next { states = next }                   // one observable change per apply
        return next
    }

    // MARK: Pure helpers (unit-tested)

    /// The user's binding wins; an explicit nil binding means "off"; no entry means the default.
    public nonisolated static func effectiveCombo(for shortcut: GlobalShortcut,
                                                  bindings: [ShortcutID: KeyCombo?]) -> KeyCombo? {
        if let binding = bindings[shortcut.id] { return binding }
        return shortcut.defaultCombo
    }

    // MARK: Private

    /// The space bar's name in key caps.
    private static var spaceName: String {
        String(localized: "Space", bundle: .module,
               comment: "Settings ▸ Shortcuts: name of the space bar in a shortcut’s key caps (also the menu and Welcome)")
    }

    private func pressed(_ id: UInt32) {
        guard !isRecording, let shortcut = routes[id] else { return }
        log.info("shortcut \(shortcut.rawValue, privacy: .public)")
        onPress?(shortcut)
    }

    private func unregisterAll() {
        for id in registered.values { registrar.unregister(id) }
        registered.removeAll()
        routes.removeAll()
    }
}
