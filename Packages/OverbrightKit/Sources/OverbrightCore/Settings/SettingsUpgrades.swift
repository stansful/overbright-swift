// OverbrightCore/Settings/SettingsUpgrades.swift — one-time upgrades of the settings an earlier version stored, run
// once at launch by the shell (AppDelegate, after `--diagnostics` has had its chance to quit, before the services
// start). Ported from Cranny's SettingsUpgrades.swift (the owner's MIT code). ARCHITECTURE.md §3.8, §8.2.
//
// The store records the settings revision of the install under `overbright.revision` (kept by Reset All, which
// returns to today's defaults, not to an older version's). A fresh install, one with no Overbright key stored yet,
// starts at today's revision and gets today's defaults; an install from before gets every later step once, in order.
//
// Revision 0 is the first release: there is nothing to upgrade yet. Bump `currentRevision` to 1 with the first
// changed default after a release, and add the step to `upgrade(from:)` (a value the user chose is never touched;
// an install that kept the old default gets the old value written explicitly, as Cranny's revision 1 did).
import Foundation
import os

extension SettingsStore {
    /// Where the install's settings revision is kept (not a `SettingKey`: no pane shows it, Reset All keeps it).
    static let revisionKey = keyPrefix + "revision"
    /// Today's settings revision; add a step to `upgrade(from:)` with each bump.
    public static let currentRevision = 0

    /// The settings revision stored by this install, nil before the first upgrade ran (diagnostics `settingsRevision`).
    public var storedRevision: Int? { defaults.object(forKey: Self.revisionKey) as? Int }

    /// Brings settings stored by an earlier version up to today's revision, once (idempotent). Call at launch before
    /// the services start; values change through the store, so anything already reading a key updates.
    public func upgradeStoredSettings() {
        let revision = storedRevision ?? (hasStoredSettings ? 0 : Self.currentRevision)
        if revision < Self.currentRevision { upgrade(from: revision) }
        if storedRevision != Self.currentRevision { defaults.set(Self.currentRevision, forKey: Self.revisionKey) }
    }

    /// An Overbright key is stored (seeded launch arguments do not count: they are not stored).
    private var hasStoredSettings: Bool {
        let arguments = defaults.volatileDomain(forName: UserDefaults.argumentDomain)
        return defaults.dictionaryRepresentation().keys.contains { key in
            key.hasPrefix(Self.keyPrefix) && key != Self.revisionKey && arguments[key] == nil
        }
    }

    /// The steps after `revision`, in order. Revision 0 has none.
    private func upgrade(from revision: Int) {
        Log.logger(.settings).info("settings upgraded from revision \(revision, privacy: .public) to \(Self.currentRevision, privacy: .public)")
    }
}
