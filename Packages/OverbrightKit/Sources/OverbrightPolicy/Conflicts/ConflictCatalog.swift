// OverbrightPolicy/Conflicts/ConflictCatalog.swift — apps that also change display colours or brightness.
// ARCHITECTURE.md §7.2, D3. This is the one source file the D3 clean-room scan allowlists by path, and only for
// string literals shaped like a bundle ID or an executable name: it holds identifiers, never product names, and
// neither its comments nor its entry IDs name a product. The UI shows `NSRunningApplication.localizedName` at runtime.
//
// Every identifier comes from a public primary source: a Homebrew cask's uninstall or zap stanza, the app's own
// project file or Info.plist, Apple's App Store lookup API, or a code signature anyone can read with `codesign -dv`.
// Identifiers guessed by other projects are not shipped. Entry IDs are persisted (`advanced.alwaysContinue`) and shown
// in diagnostics: never rename or reuse one; append new entries at the end of their severity group.
import OverbrightCore

/// The conflict catalogue (§7.2), most severe first, so `ConflictMatcher.match` reports the strongest class.
public nonisolated enum ConflictCatalog {
    /// Every entry: S1 boosters (12), S2 continuous gamma writers (4), S3 conditional writers (4), S4 benign (3).
    public static let entries: [ConflictCatalogEntry] = boosters + gammaWriters + conditional + benign

    /// The entry with `id`, if any.
    public static func entry(id: String) -> ConflictCatalogEntry? { entries.first { $0.id == id } }

    /// S1: another EDR trigger plus its own table or overlay boost. Suspends every display; nothing continues next to
    /// one (§7.2).
    static let boosters: [ConflictCatalogEntry] = [
        // Table booster with Mac App Store, direct and Setapp builds: the IDs vary, so prefixes confirmed by the
        // team ID of the store and direct builds (local Info.plist, App Store lookup id6443470555, code signature).
        ConflictCatalogEntry(id: "booster-01", severity: .booster,
                             bundleIDs: ["com.lumen-digital.Vivid-MacAppStore", "com.goodsnooze.vivid"],
                             bundlePrefixes: ["com.lumen-digital.Vivid", "com.goodsnooze.vivid"],
                             teamIDs: ["793V7A9UA3"]),
        // Trigger pixel plus table or overlay; one ID for the store and direct builds (project file; lookup
        // id6452471855). Its widget extension is not a conflict.
        ConflictCatalogEntry(id: "booster-02", severity: .booster, bundleIDs: ["de.brightintosh.app"]),
        // EDR boost plus dimming below the minimum (App Store lookup id6776136831).
        ConflictCatalogEntry(id: "booster-03", severity: .booster, bundleIDs: ["com.equinox.lumel"]),
        // XDR boost to the panel peak (App Store lookup id6758426477).
        ConflictCatalogEntry(id: "booster-04", severity: .booster, bundleIDs: ["com.ramster.LumiMax"]),
        // EDR boost (App Store lookup id6764316131).
        ConflictCatalogEntry(id: "booster-05", severity: .booster, bundleIDs: ["com.billypaulmason.luxa"]),
        // EDR boost with a video-player mode; no reverse-DNS prefix (App Store lookup id6787140590).
        ConflictCatalogEntry(id: "booster-06", severity: .booster, bundleIDs: ["Grimsbekken-AS.MaxBrightness"]),
        // Built-in XDR peak unlock (App Store lookup id6786285526).
        ConflictCatalogEntry(id: "booster-07", severity: .booster, bundleIDs: ["com.sajdak.brightlight"]),
        // Boost beyond the default limits (App Store lookup id6761735613).
        ConflictCatalogEntry(id: "booster-08", severity: .booster, bundleIDs: ["com.mrgnhnt.brightness-plus"]),
        // Metal overlay with multiply blending (project file).
        ConflictCatalogEntry(id: "booster-09", severity: .booster, bundleIDs: ["com.starkdmi.BrightXDR"]),
        // Bundle-less command-line overlay booster: matched by its executable name (Makefile).
        ConflictCatalogEntry(id: "booster-10", severity: .booster, bundleIDs: [], executableNames: ["xdr-boost"]),
        // Transfer-table booster (the app's Info.plist).
        ConflictCatalogEntry(id: "booster-11", severity: .booster, bundleIDs: ["com.openclawfarm.xdrlight"]),
        // 1 × 1 EDR trigger window plus table, built-in only (the app's Info.plist).
        ConflictCatalogEntry(id: "booster-12", severity: .booster, bundleIDs: ["com.ptlghost.BrightBoi"]),
    ]

    /// S2: colour-temperature and dimming tools that re-assert tables. Suspends before boosting; Continue Anyway.
    static let gammaWriters: [ConflictCatalogEntry] = [
        // Colour-temperature tables, re-asserted during transitions (Homebrew cask uninstall stanza).
        ConflictCatalogEntry(id: "gamma-writer-01", severity: .gammaWriter, bundleIDs: ["org.herf.Flux"]),
        // Blue-light filter and brightness reduction (Homebrew cask uninstall stanza).
        ConflictCatalogEntry(id: "gamma-writer-02", severity: .gammaWriter, bundleIDs: ["co.iristech.Iris"]),
        // Gamma, brightness and contrast per display; the major version is part of the ID (App Store lookup
        // id1250521285; Homebrew cask zap stanza).
        ConflictCatalogEntry(id: "gamma-writer-03", severity: .gammaWriter, bundleIDs: ["ca.michelf.GammaControl.6"],
                             bundlePrefixes: ["ca.michelf.GammaControl"]),
        // Dims through the gamma formula, or an overlay where it cannot (App Store lookup id1635180752).
        ConflictCatalogEntry(id: "gamma-writer-04", severity: .gammaWriter, bundleIDs: ["com.lowtechguys.GammaDimmer"]),
    ]

    /// S3: write tables or boost only in some modes. An info chip; a display suspends at its first attributed drift.
    static let conditional: [ConflictCatalogEntry] = [
        // DDC sync, dimming below the minimum and an XDR table mode; the current and the v2–v3 IDs (Homebrew cask,
        // project file at HEAD and at two release tags).
        ConflictCatalogEntry(id: "conditional-01", severity: .conditional,
                             bundleIDs: ["fyi.lunar.Lunar", "site.lunarapp.Lunar"]),
        // Virtual displays and resolutions, software dimming, XDR upscaling; the current and the earlier
        // open-source ID (Homebrew cask; project file at a release tag).
        ConflictCatalogEntry(id: "conditional-02", severity: .conditional,
                             bundleIDs: ["pro.betterdisplay.BetterDisplay", "me.waydabber.BetterDummy"]),
        // DDC with software dimming through the table where DDC is missing; the current, earlier and store IDs
        // (project files at six release tags; App Store lookup id1595464182). Its login helpers are not conflicts.
        ConflictCatalogEntry(id: "conditional-03", severity: .conditional,
                             bundleIDs: ["app.monitorcontrol.MonitorControl", "me.guillaumeb.MonitorControl",
                                         "app.monitorcontrol.MonitorControlLite"]),
        // DDC, resolutions and presets, plus a mode that reaches the panel peak (Homebrew cask zap stanza).
        ConflictCatalogEntry(id: "conditional-04", severity: .conditional, bundleIDs: ["com.sids.DisplayBuddy"]),
    ]

    /// S4: overlay shades, resolution and preset managers. Diagnostics only.
    static let benign: [ConflictCatalogEntry] = [
        // Software shade (an overlay window) (App Store lookup id931571202).
        ConflictCatalogEntry(id: "benign-01", severity: .benign, bundleIDs: ["jp.questbeat.Shade"]),
        // Display modes and sets that switch profiles and presets; the UI app and its daemon (Homebrew cask).
        ConflictCatalogEntry(id: "benign-02", severity: .benign,
                             bundleIDs: ["fr.madrau.switchresx.app", "fr.madrau.switchresx.daemon"]),
        // Dims the windows behind the front one with an overlay (Homebrew cask uninstall stanza).
        ConflictCatalogEntry(id: "benign-03", severity: .benign, bundleIDs: ["com.pointum.hazeover"]),
    ]
}
