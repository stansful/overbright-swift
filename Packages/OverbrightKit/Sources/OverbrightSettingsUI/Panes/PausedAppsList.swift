// OverbrightSettingsUI/Panes/PausedAppsList.swift — the edits of Automations ▸ Pause for these apps (DESIGN.md §7.5;
// ARCHITECTURE.md §3.4 `PausedAppRule`, §6.5): add (from the running apps, an Open panel or the suggestions), remove,
// and change an app's mode, on the list stored in `automations.pausedApps`. Bundle IDs are matched exactly and
// case-insensitively, as Policy matches them; names are never compared (D8). Pure (tested).
import Foundation
import OverbrightCore

/// Edits of the per-app pause list.
enum PausedAppsList {
    /// Video apps that are not on the default list but are worth suggesting: Prime Video, Infuse Enterprise,
    /// GeForce NOW, Moonlight (DESIGN.md §7.5). Bundle IDs only; the menu shows Finder's names, and only of apps that
    /// are installed. [U] The identifiers are the publishers' public ones; WP16 checks them on the owner's Mac.
    static let extraSuggestions: [PausedAppRule] = [
        PausedAppRule(bundleID: "com.amazon.aiv.AIVApp", mode: .whilePlaying),
        PausedAppRule(bundleID: "com.firecore.infuse.enterprise", mode: .whilePlaying),
        PausedAppRule(bundleID: "com.nvidia.gfnpc.mall", mode: .whileFrontmost),
        PausedAppRule(bundleID: "com.moonlight-stream.Moonlight", mode: .whileFrontmost),
    ]

    /// `rules` with `bundleIDs` added at the end (each once; an app already listed keeps its rule). A new app takes
    /// its suggested mode, else "While in front".
    static func adding(_ bundleIDs: [String], to rules: [PausedAppRule]) -> [PausedAppRule] {
        var result = rules
        for id in bundleIDs where !id.isEmpty && !contains(id, in: result) {
            result.append(PausedAppRule(bundleID: id, mode: suggestedMode(for: id)))
        }
        return result
    }

    /// `rules` without `bundleID`.
    static func removing(_ bundleID: String, from rules: [PausedAppRule]) -> [PausedAppRule] {
        rules.filter { !same($0.bundleID, bundleID) }
    }

    /// `rules` with `bundleID`'s mode set to `mode`.
    static func setting(_ mode: PausedAppRule.Mode, for bundleID: String, in rules: [PausedAppRule]) -> [PausedAppRule] {
        rules.map { rule in
            guard same(rule.bundleID, bundleID) else { return rule }
            var changed = rule
            changed.mode = mode
            return changed
        }
    }

    /// The suggestions not on the list yet (the default list's apps first, then the extra video apps), of which
    /// `isInstalled` keeps the installed ones.
    static func suggestions(for rules: [PausedAppRule], isInstalled: (String) -> Bool) -> [PausedAppRule] {
        (PausedAppDefaults.rules + extraSuggestions).filter { !contains($0.bundleID, in: rules) && isInstalled($0.bundleID) }
    }

    /// The mode an app gets when added: its suggested one, else "While in front".
    static func suggestedMode(for bundleID: String) -> PausedAppRule.Mode {
        (PausedAppDefaults.rules + extraSuggestions).first { same($0.bundleID, bundleID) }?.mode ?? .whileFrontmost
    }

    /// `bundleID` has a rule in `rules`.
    static func contains(_ bundleID: String, in rules: [PausedAppRule]) -> Bool {
        rules.contains { same($0.bundleID, bundleID) }
    }

    private static func same(_ a: String, _ b: String) -> Bool { a.caseInsensitiveCompare(b) == .orderedSame }
}
