// OverbrightChannel/PreferencesChannelStore.swift — the channel store in an application's preferences domain.
// ARCHITECTURE.md §7.7, §8.2 ("Controls snapshot and token"); D25.
// The app writes its own domain (the standard one; no suite: `noCodeCreatesAPreferencesSuite`); the sandboxed
// extension reads the same domain through `com.apple.security.temporary-exception.shared-preference.read-only`.
// CFPreferences is thread-safe, so the store is usable from any thread.
import Foundation

/// A `ChannelStore` over CFPreferences of one application domain.
public nonisolated struct PreferencesChannelStore: ChannelStore {
    /// The domain (the app's bundle identifier).
    public let applicationID: String

    /// A store in `applicationID`'s preferences domain.
    public init(applicationID: String) { self.applicationID = applicationID }

    /// Overbright's own domain: the app writes it, the extension reads it.
    public static let app = PreferencesChannelStore(applicationID: BoostChannel.appBundleID)

    /// The string under `key`, nil when absent or not a string.
    public func string(forKey key: String) -> String? {
        CFPreferencesCopyAppValue(key as CFString, applicationID as CFString) as? String
    }

    /// Writes (or removes) `key` and synchronizes the domain, so the extension's next read sees it.
    public func set(_ value: String?, forKey key: String) {
        CFPreferencesSetAppValue(key as CFString, value as CFString?, applicationID as CFString)
        CFPreferencesAppSynchronize(applicationID as CFString)
    }
}
