// OverbrightIntents/Control/SystemControlOutlet.swift — the real outputs of the control's publish point.
// ARCHITECTURE.md §7.7, §8.2; D25. Main actor (the publisher's); `ControlCenter` exists from macOS 26, the control's
// own minimum, so the reloads are no-ops before it.
import Foundation
import OverbrightChannel
import WidgetKit

/// Posts the notifyd word, writes the snapshot and the token to the app's own preferences domain, and reloads the
/// control through WidgetKit's `ControlCenter`.
@MainActor public final class SystemControlOutlet: ControlStateOutlet {
    private let bundle: Bundle
    private let store: any ChannelStore
    private let word: NotifyStateWord

    /// The outlet of the app in `bundle`, writing `store` and posting `BoostChannel.notifyName`.
    public init(bundle: Bundle = .main, store: any ChannelStore = PreferencesChannelStore.app,
                word: NotifyStateWord = NotifyStateWord()) {
        self.bundle = bundle; self.store = store; self.word = word
    }

    /// Whether the extension is in the bundle's `PlugIns` folder (`scripts/build.sh` removes it unless `CONTROLS=1`).
    public var isControlInstalled: Bool {
        guard let plugIns = bundle.builtInPlugInsURL else { return false }
        return FileManager.default.fileExists(atPath: plugIns.appending(path: BoostChannel.extensionBundleName).path)
    }

    /// Makes the token when there is none.
    public func ensureToken() { BoostChannel.ensureToken(in: store) }

    /// Sets and posts the notify word.
    public func post(_ word: UInt64) { self.word.post(word) }

    /// Writes the snapshot.
    public func writeSnapshot(_ state: BoostChannel.State) { BoostChannel.writeSnapshot(state, to: store) }

    /// Reloads the toggle (macOS 26+).
    public func reloadControl() {
        if #available(macOS 26.0, *) { ControlCenter.shared.reloadControls(ofKind: BoostChannel.controlKind) }
    }

    /// Reloads every control of the app (macOS 26+).
    public func reloadAllControls() {
        if #available(macOS 26.0, *) { ControlCenter.shared.reloadAllControls() }
    }
}
