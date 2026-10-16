// OverbrightHotKeys/CarbonHotKeyRegistrar.swift — system-wide shortcuts with Carbon `RegisterEventHotKey` on the
// application event target: no Accessibility permission (verified on macOS 27 in Cranny). Ported from Cranny's
// HotKeyCenter (the owner's MIT code), signature 'OVBR' instead of 'CRNY'. ARCHITECTURE.md §3.7, D17.
//
// Thread: Carbon calls the event handler on the main thread (application event target). The handler is a C function
// without context, so presses are routed by hot-key id through a static table; it still hops explicitly with
// `DispatchQueue.main.async` before touching anything main-actor isolated (§8.1 rule 2).
import Carbon
import Foundation
import OverbrightCore
import os

private let log = Log.logger(.hotKeys)

/// The real registrar: one Carbon hot key per registered combo.
@MainActor public final class CarbonHotKeyRegistrar: HotKeyRegistrar {
    /// Delivers presses of this registrar's hot keys.
    public var onPress: (@MainActor (UInt32) -> Void)?

    /// Carbon delivers hot keys through a C callback without context: every live hot key's registrar, by id.
    private static var routes: [UInt32: Route] = [:]
    private static var handlerInstalled = false
    private static var nextID: UInt32 = 1
    /// Carbon's `EventHotKeyID.signature`: 'OVBR'.
    static let signature = OSType(0x4F56_4252)

    private var refs: [UInt32: EventHotKeyRef] = [:]

    /// A registrar with nothing registered (the Carbon handler is installed on the first registration).
    public init() {}

    /// Registers `combo`; nil when Carbon refuses it.
    public func register(_ combo: KeyCombo) -> UInt32? {
        guard Self.installHandler() else { return nil }
        let id = Self.nextID
        Self.nextID &+= 1
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(UInt32(combo.keyCode), Self.carbonModifiers(combo.modifiers),
                                         EventHotKeyID(signature: Self.signature, id: id),
                                         GetApplicationEventTarget(), 0, &ref)
        guard status == noErr, let ref else {
            log.info("hot key not registered (\(status, privacy: .public))")
            return nil
        }
        refs[id] = ref
        Self.routes[id] = Route(self)
        return id
    }

    /// Unregisters the hot key `id`.
    public func unregister(_ id: UInt32) {
        guard let ref = refs.removeValue(forKey: id) else { return }
        UnregisterEventHotKey(ref)
        Self.routes[id] = nil
    }

    isolated deinit {
        for (id, ref) in refs {
            UnregisterEventHotKey(ref)
            Self.routes[id] = nil
        }
    }

    // MARK: Pure helpers (unit-tested)

    /// `KeyCombo.Modifiers` → Carbon's modifier bits (`cmdKey`, `optionKey`, `controlKey`, `shiftKey`).
    public nonisolated static func carbonModifiers(_ modifiers: KeyCombo.Modifiers) -> UInt32 {
        var carbon: UInt32 = 0
        if modifiers.contains(.command) { carbon |= UInt32(cmdKey) }
        if modifiers.contains(.option) { carbon |= UInt32(optionKey) }
        if modifiers.contains(.control) { carbon |= UInt32(controlKey) }
        if modifiers.contains(.shift) { carbon |= UInt32(shiftKey) }
        return carbon
    }

    // MARK: Private

    /// A weak reference to the registrar that owns a hot key.
    private final class Route {
        weak var registrar: CarbonHotKeyRegistrar?
        init(_ registrar: CarbonHotKeyRegistrar) { self.registrar = registrar }
    }

    /// Delivers a press to the registrar that owns `id`.
    private static func deliver(_ id: UInt32) {
        guard let registrar = routes[id]?.registrar else { return }
        registrar.onPress?(id)
    }

    private static func installHandler() -> Bool {
        guard !handlerInstalled else { return true }
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let status = InstallEventHandler(GetApplicationEventTarget(), { _, event, _ in
            var hotKey = EventHotKeyID()
            let status = GetEventParameter(event, EventParamName(kEventParamDirectObject),
                                           EventParamType(typeEventHotKeyID), nil,
                                           MemoryLayout<EventHotKeyID>.size, nil, &hotKey)
            guard status == noErr, hotKey.signature == CarbonHotKeyRegistrar.signature else { return status }
            let id = hotKey.id
            // Carbon dispatches application-target events on the main thread; hop explicitly anyway.
            DispatchQueue.main.async { MainActor.assumeIsolated { CarbonHotKeyRegistrar.deliver(id) } }
            return noErr
        }, 1, &spec, nil, nil)
        handlerInstalled = status == noErr
        if !handlerInstalled { log.error("InstallEventHandler failed (\(status, privacy: .public))") }
        return handlerInstalled
    }
}
