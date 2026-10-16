// OverbrightAppShell/App/DiagnosticsReport.swift — the read-only diagnostics report behind `--diagnostics <file|->`
// (all builds; `make smoke` reads it) and Advanced ▸ Copy Diagnostics (no bundle facts, with the journal).
// ARCHITECTURE.md §8.4 (the key table), §8.5, D20, D24, D26. Shared shell file (contract owner).
//
// READ-ONLY: it reads transfer tables, profile bases and EDR values, and never writes a table, arms a trigger, opens a
// window or writes a preference (test `diagnosticsNeverWrites`). `gammaWrites` and `triggerWindows` are the ports'
// own counters; smoke asserts both are 0. Each display's table is judged against its profile base by Policy's
// `TableClassifier` (D26); `maxDeviationFromBase` is the raw evidence next to the class. The inputs of a running app
// or of `--diagnostics` come from the shell (`DiagnosticsReport+Shell.swift`).
import AppKit
import CoreGraphics
import Foundation
import OverbrightBoost
import OverbrightCore
import OverbrightPolicy
import os
import Security

private let log = Log.logger(.diagnostics)

/// Builds and writes the diagnostics report.
enum DiagnosticsReport {
    /// Everything the report reads.
    struct Inputs {
        /// The settings (read only).
        var settings: SettingsStore
        /// The Mac and OS build.
        var machine: MachineIdentity
        /// The journal (Copy Diagnostics only).
        var journal: any DiagnosticsJournal
        /// The status item's visibility.
        var iconVisibility: MenuBarIconVisibility
        /// Tables and profile bases (read and counted, never written).
        var gamma: any GammaPort
        /// EDR values.
        var headroom: any HeadroomPort
        /// Open trigger and overlay windows (counted).
        var triggers: any TriggerFactory
        /// The online displays (a read-only snapshot).
        var displays: [DisplayFacts]
        /// The system snapshot (nil: not available, shown as null).
        var signals: (any SystemSignals)?
        /// Running catalogue matches (nil: not available, shown as null).
        var conflicts: (any ConflictProbe)?
        /// Whether a display's ColorSync profile has a `vcgt` tag (nil: unknown).
        var profileHasVCGT: (CGDirectDisplayID) -> Bool?
        /// The strategy cache by "<display UUID>|<OS build>" (the engine's, or the file's for `--diagnostics`).
        var strategyRecords: [String: StrategyRecord] = [:]
        /// The built-in panel's backlight now, in milli-nits (H-N1); nil without one.
        var backlightMilliNits: Double?
        /// The services that start and stop, in start order.
        var services: [String] = []
        /// The `--qa-simulate` fixture, nil for real ports.
        var simulatedFixture: String?
        /// `--diagnostics`: languages, resource bundles, the main menu and a Design string in Russian (smoke).
        var includesBundleFacts: Bool
        /// Copy Diagnostics: the last 500 journal events.
        var includesJournal: Bool
    }

    /// The report as a JSON object.
    static func build(_ inputs: Inputs) -> [String: Any] {
        var report: [String: Any] = [:]
        let info = AppInfo.current()
        report["app"] = ["id": info.bundleIdentifier, "version": info.version, "build": info.build,
                         "signing": signing(), "controls": bundlesControlsExtension()]
        report["machine"] = ["model": inputs.machine.model, "osBuild": inputs.machine.osBuild,
                             "osVersion": "\(inputs.machine.osMajor).\(inputs.machine.osMinor).\(inputs.machine.osPatch)",
                             "compatibilityModeAdvised": CompatibilityModels.tableWritesIgnored(inputs.machine)]
        report["simulatedFixture"] = inputs.simulatedFixture ?? NSNull()
        if inputs.includesBundleFacts {
            report["preferredLanguages"] = Locale.preferredLanguages
            report["mainPreferredLocalizations"] = Bundle.main.preferredLocalizations
            report["resourceBundles"] = resourceBundles()
            report["mainMenu"] = mainMenu()
            report["designString.ru"] = designString(language: "ru")
        }
        report["displays"] = inputs.displays.map { display($0, inputs) }
        report["strategyCache"] = inputs.strategyRecords.keys.sorted().map { key in
            strategyEntry(key: key, record: inputs.strategyRecords[key] ?? StrategyRecord())
        }
        report["services"] = inputs.services
        report["settingsRevision"] = inputs.settings.storedRevision ?? NSNull()
        report["nonDefaultSettings"] = inputs.settings.storedKeyIDs()
        report["conflicts"] = inputs.conflicts.map { probe in
            probe.runningConflicts().map { ["entry": $0.entryID, "severity": $0.severity.rawValue] }
        } ?? NSNull()
        report["signals"] = inputs.signals.map { signals($0.snapshot) } ?? NSNull()
        report["menuBarIcon"] = iconVisibility(inputs.iconVisibility)
        report["boostMarker"] = inputs.settings[EngineRecords.boostMarker] == nil ? "absent" : "present"
        if inputs.includesJournal {
            report["journal"] = inputs.journal.snapshot().map { event in
                ["seconds": event.seconds, "category": event.category, "display": event.display ?? NSNull(),
                 "code": event.code, "values": event.values] as [String: Any]
            }
        }
        report["gammaWrites"] = inputs.gamma.writeCount
        report["triggerWindows"] = inputs.triggers.openWindowCount
        return report
    }

    /// Pretty-printed JSON with sorted keys.
    static func json(_ report: [String: Any]) -> Data? {
        guard JSONSerialization.isValidJSONObject(report) else { return nil }
        return try? JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
    }

    /// Writes `report` to `path` ("-": standard output). Returns false when nothing could be written.
    static func save(_ report: [String: Any], to path: String) -> Bool {
        guard let data = json(report) else {
            log.error("diagnostics: the report is not valid JSON")
            return false
        }
        if path == "-" {
            FileHandle.standardOutput.write(data + Data("\n".utf8))
            return true
        }
        do {
            try data.write(to: URL(fileURLWithPath: path), options: .atomic)
            return true
        } catch {
            log.error("diagnostics: cannot write the report: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    // MARK: Displays

    private static func display(_ facts: DisplayFacts, _ inputs: Inputs) -> [String: Any] {
        let id = facts.ref.id
        var entry: [String: Any] = [
            "key": facts.ref.key.rawValue, "name": facts.name, "builtIn": facts.isBuiltIn,
            "virtual": facts.panelClass == .virtualDisplay, "mirrored": facts.isMirrored,
            "gammaCapacity": facts.gammaCapacity, "panelClass": facts.panelClass.rawValue,
            "supportsPQ": facts.supportsPQ ?? NSNull(), "panelPeakNits": facts.panelPeakNits ?? NSNull(),
            "panelFrameAverageNits": facts.panelFrameAverageNits ?? NSNull(),
            "panelMinNits": facts.panelMinNits ?? NSNull(), "sdrMaxNits": facts.sdrMaxNits ?? NSNull(),
            "backlightMilliNits": (facts.isBuiltIn ? inputs.backlightMilliNits : nil) ?? NSNull(),
            "profileHasVCGT": inputs.profileHasVCGT(id) ?? NSNull(),
        ]
        let cached = inputs.strategyRecords[StrategyCache.key(facts.ref.key, osBuild: inputs.machine.osBuild)]
        entry["cachedRung"] = cached?.rung ?? NSNull()
        entry["lowestReadyHeadroom"] = cached?.lowestReadyHeadroom ?? NSNull()
        entry.merge(table(of: id, capacity: facts.gammaCapacity, gamma: inputs.gamma)) { _, new in new }
        let reading = inputs.headroom.reading(for: facts.ref)
        entry["potential"] = reading?.potential ?? NSNull()
        entry["current"] = reading?.current ?? NSNull()
        entry["reference"] = reading?.reference ?? NSNull()

        let preferences = inputs.settings[DisplaySettings.perDisplay][facts.ref.key] ?? DisplayPreferences()
        let eligibility = EligibilityClassifier.classify(facts, preferences: preferences, reading: reading,
                                                         machine: inputs.machine)
        let mechanism: Mechanism = switch preferences.mechanism {
        case .automatic: eligibility.defaultMechanism
        case .table: .table
        case .overlay: .overlay
        }
        entry["verdict"] = verdict(eligibility.verdict)
        entry["advisories"] = eligibility.advisories.map(\.rawValue)
        entry["boostEnabled"] = preferences.boostEnabled ?? eligibility.defaultBoostEnabled
        entry["mechanism"] = mechanism.rawValue
        entry["effectiveDomain"] = TransferDomainResolver.effectiveDomain(
            preferences.calibration, mechanism: mechanism, machine: inputs.machine, potential: reading?.potential).rawValue
        entry["calibration"] = preferences.calibration.map { record in
            ["outcome": record.outcome.rawValue,
             "valid": EligibilityClassifier.hasValidCalibration(record, mechanism: mechanism, machine: inputs.machine,
                                                                 potential: reading?.potential)] as [String: Any]
        } ?? NSNull()
        return entry
    }

    private static func strategyEntry(key: String, record: StrategyRecord) -> [String: Any] {
        ["key": key, "rung": record.rung ?? NSNull(), "failures": record.failures,
         "lowestReadyHeadroom": record.lowestReadyHeadroom ?? NSNull()]
    }

    /// The table read back and judged against the profile base (read-only).
    private static func table(of id: CGDirectDisplayID, capacity: Int, gamma: any GammaPort) -> [String: Any] {
        guard capacity > 0 else { return ["tableClass": "noTable"] }
        do {
            let table = try gamma.read(id)
            let base = gamma.profileBase(of: id, count: table.count)
            let tableClass = TableClassifier.classify(table, expectedBase: base)
            var entry: [String: Any] = ["tableClass": code(tableClass), "tableEntries": table.count,
                                        "tableMax": Double(table.maximum),
                                        "tableMid": table.count > 0 ? Double(table.green[table.count / 2]) : NSNull(),
                                        "maxDeviationFromBase": maxDeviation(table, base)]
            if case .scaled(let ratio) = tableClass { entry["tableRatio"] = ratio ?? NSNull() }
            return entry
        } catch {
            return ["tableClass": "unreadable", "tableError": String(describing: error)]
        }
    }

    private static func maxDeviation(_ table: GammaTable, _ base: GammaTable) -> Double {
        let pairs = [(table.red, base.red), (table.green, base.green), (table.blue, base.blue)]
        return pairs.flatMap { read, expected in zip(read, expected).map { Double(abs($0 - $1)) } }.max() ?? 0
    }

    // MARK: Codes (machine codes, not UI copy)

    private static func code(_ tableClass: TableClass) -> String {
        switch tableClass {
        case .matchesBase: "matchesBase"
        case .scaled: "scaled"
        case .foreign: "foreign"
        case .invalid: "invalid"
        }
    }

    private static func verdict(_ verdict: DisplayVerdict) -> String {
        switch verdict {
        case .checking: "checking"
        case .supported: "supported"
        case .noGainAtFullBrightness: "noGainAtFullBrightness"
        case .presetLimits: "presetLimits"
        case .turnOnHDR: "turnOnHDR"
        case .switchPreset: "switchPreset"
        case .referencePreset: "referencePreset"
        case .lcdClass: "lcdClass"
        case .mirrored: "mirrored"
        case .virtualDisplay: "virtualDisplay"
        case .noGammaTable: "noGammaTable"
        case .notHDR: "notHDR"
        }
    }

    private static func iconVisibility(_ visibility: MenuBarIconVisibility) -> String {
        switch visibility {
        case .visible: "visible"
        case .hiddenByUser: "hiddenByUser"
        case .notVisible: "notVisible"
        }
    }

    private static func signals(_ s: SystemSnapshot) -> [String: Any] {
        let focus: String = switch s.focus {
        case .leaveAlone: "leaveAlone"
        case .off: "off"
        case .on(let level): "on \(level.value)"
        }
        return ["powerSource": s.power.source.rawValue, "batteryPercent": s.power.batteryPercent ?? NSNull(),
                "lowPowerMode": s.power.isLowPowerMode, "thermal": String(describing: s.thermal),
                "locked": s.isScreenLocked, "screensaver": s.isScreensaverRunning,
                "displaysAsleep": s.areDisplaysAsleep, "systemSleeping": s.isSystemSleeping,
                "onConsole": s.isSessionActive, "frontmostBundleID": s.frontmost?.bundleID ?? NSNull(),
                "isPlaying": s.frontmost?.isPlaying ?? NSNull(), "isGame": s.frontmost?.isGame ?? false,
                "fullScreenDisplays": s.fullScreenDisplays.map(\.rawValue).sorted(),
                "fullScreenVideoDisplays": s.fullScreenVideoDisplays.map(\.rawValue).sorted(),
                "cameraInUse": s.isCameraInUse, "hdrSuppressed": s.isHDRSuppressed, "focus": focus]
    }

    // MARK: Bundle facts

    private static func resourceBundles() -> [String] {
        let resources = Bundle.main.resourcePath ?? ""
        let names = (try? FileManager.default.contentsOfDirectory(atPath: resources)) ?? []
        return names.filter { $0.hasSuffix(".bundle") }.sorted()
    }

    private static func mainMenu() -> [[String: [String]]] {
        NSApp?.mainMenu?.items.map { item in
            [item.title: item.submenu?.items.filter { !$0.keyEquivalent.isEmpty }
                .map { "\($0.title) ⌘\($0.keyEquivalent)" } ?? []]
        } ?? []
    }

    /// A verdict sentence of Design's catalog, looked up in `language` (catalog wiring check).
    private static func designString(language: String) -> String {
        guard let path = Bundle.main.path(forResource: "OverbrightKit_OverbrightDesign", ofType: "bundle"),
              let bundle = Bundle(path: path) else { return "(no bundle)" }
        guard let lproj = bundle.path(forResource: language, ofType: "lproj"),
              let localized = Bundle(path: lproj) else { return "(no \(language) localization)" }
        return localized.localizedString(forKey: "Overbright is reading this display.", value: "(missing)", table: nil)
    }

    private static func bundlesControlsExtension() -> Bool {
        let appex = Bundle.main.bundleURL.appending(path: "Contents/PlugIns/OverbrightControls.appex")
        return FileManager.default.fileExists(atPath: appex.path)
    }

    /// "team <ID>", "adhoc", "signed" or "unsigned" (read from this process's own code signature).
    private static func signing() -> String {
        var code: SecCode?
        guard SecCodeCopySelf([], &code) == errSecSuccess, let code else { return "unknown" }
        var staticCode: SecStaticCode?
        guard SecCodeCopyStaticCode(code, [], &staticCode) == errSecSuccess, let staticCode else { return "unknown" }
        var information: CFDictionary?
        guard SecCodeCopySigningInformation(staticCode, SecCSFlags(rawValue: kSecCSSigningInformation),
                                            &information) == errSecSuccess,
              let info = information as? [String: Any] else { return "unknown" }
        if let team = info[kSecCodeInfoTeamIdentifier as String] as? String { return "team \(team)" }
        if let flags = info[kSecCodeInfoFlags as String] as? UInt32, flags & 0x2 != 0 { return "adhoc" }
        return info[kSecCodeInfoIdentifier as String] == nil ? "unsigned" : "signed"
    }
}
