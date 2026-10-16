// swift-tools-version: 6.2
// OverbrightKit — ALL Overbright code except the app target's @main, its App Intents adapters (D18) and the
// dormant Controls extension. The Xcode project (Overbright.xcodeproj) links only the static product
// OverbrightAppShell (and, with CONTROLS=1, the extension links only the static OverbrightControlsKit).
//
// Layering (enforced by the dependency lists below — never add an edge that is not here):
//   L0  OverbrightCore       contracts (ports + value types), settings keys, platform utils, fakes      nonisolated
//       OverbrightPolicy     pure decisions: factor math, level mapping, eligibility, guard reducer,
//                            table classifier, conflict matcher (Core only)                             nonisolated
//       OverbrightChannel    Foundation-only state channel for the dormant control (D25): pack/unpack,
//                            notify name, CFPreferences snapshot, token, URL route parser (no Core)     nonisolated
//   L1  Design, Displays, Triggers, Boost, Signals, FillLight, HotKeys, Updates, Intents
//                            depend on L0 ONLY (Intents also on Channel), never on each other
//   L2  PanelUI, SettingsUI, Onboarding      L0 + Design (Onboarding may also use PanelUI)
//   L3  OverbrightAppShell   composition root, status item, windows (depends on everything)
//   --  OverbrightTestSupport  test helpers; test targets only, never linked into the app
//
// This file is owned by Work Package 0a (WP13 in phase C). Other packages never edit it.
import PackageDescription

let common: [SwiftSetting] = [
    .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
    .enableUpcomingFeature("InferIsolatedConformances"),
    .enableUpcomingFeature("MemberImportVisibility"),
    .enableUpcomingFeature("ExistentialAny"),
]
let mainActorByDefault: [SwiftSetting] = common + [.defaultIsolation(MainActor.self)]
let nonisolatedByDefault: [SwiftSetting] = common + [.defaultIsolation(nil)]

let core: Target.Dependency = "OverbrightCore"
let policy: Target.Dependency = "OverbrightPolicy"
let channel: Target.Dependency = "OverbrightChannel"

/// A layer-1 module: MainActor by default, depends on L0 only, owns a String Catalog.
func layer1(_ name: String) -> Target {
    let deps: [Target.Dependency] = name == "OverbrightIntents" ? [core, policy, channel] : [core, policy]
    return .target(name: name, dependencies: deps, resources: [.process("Resources")], swiftSettings: mainActorByDefault)
}
/// A layer-2/3 module.
func upperLayer(_ name: String, _ dependencies: [Target.Dependency]) -> Target {
    .target(name: name, dependencies: dependencies, resources: [.process("Resources")], swiftSettings: mainActorByDefault)
}
/// Every library target except TestSupport has exactly one test target, declared up front so nobody edits this file.
func tests(_ module: String, isolation: [SwiftSetting] = mainActorByDefault) -> Target {
    var deps: [Target.Dependency] = [.target(name: module), "OverbrightTestSupport"]
    if module == "OverbrightChannel" { return .testTarget(name: module + "Tests", dependencies: deps, swiftSettings: isolation) }
    if module != "OverbrightCore" { deps.append(core) }
    if module != "OverbrightCore" && module != "OverbrightPolicy" { deps.append(policy) }
    return .testTarget(name: module + "Tests", dependencies: deps, swiftSettings: isolation)
}

let layer1Modules = [
    "OverbrightDesign", "OverbrightDisplays", "OverbrightTriggers", "OverbrightBoost", "OverbrightSignals",
    "OverbrightFillLight", "OverbrightHotKeys", "OverbrightUpdates", "OverbrightIntents",
]
let ui: [Target.Dependency] = [core, policy, "OverbrightDesign"]

let package = Package(
    name: "OverbrightKit",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [
        // The app links only this product (static). It pulls in the whole graph. Never add a .dynamic product
        // to the app (a hardened ad-hoc Release dies with "different Team IDs").
        .library(name: "OverbrightAppShell", type: .static, targets: ["OverbrightAppShell"]),
        // The dormant Controls extension (D18) links only this: the Foundation-only state channel (D25).
        .library(name: "OverbrightControlsKit", type: .static, targets: ["OverbrightChannel"]),
    ],
    targets: [
        // L0
        .target(name: "OverbrightCore", resources: [.process("Resources")], swiftSettings: nonisolatedByDefault),
        .target(name: "OverbrightPolicy", dependencies: [core], swiftSettings: nonisolatedByDefault),   // no strings
        .target(name: "OverbrightChannel", swiftSettings: nonisolatedByDefault),                         // no strings
        // L1
    ] + layer1Modules.map(layer1) + [
        // L2
        upperLayer("OverbrightPanelUI", ui),
        upperLayer("OverbrightSettingsUI", ui),
        upperLayer("OverbrightOnboarding", ui + ["OverbrightPanelUI"]),
        // L3
        upperLayer("OverbrightAppShell", ui + ["OverbrightPanelUI", "OverbrightSettingsUI", "OverbrightOnboarding", channel]
                   + layer1Modules.filter { $0 != "OverbrightDesign" }.map { .target(name: $0) }),
        // Test helpers (no Resources folder: smoke counts Sources/*/Resources against the app's bundles)
        .target(name: "OverbrightTestSupport", dependencies: [core, policy], swiftSettings: mainActorByDefault),
        // Tests
        tests("OverbrightCore", isolation: nonisolatedByDefault),
        tests("OverbrightPolicy", isolation: nonisolatedByDefault),
        tests("OverbrightChannel", isolation: nonisolatedByDefault),
    ] + (layer1Modules + ["OverbrightPanelUI", "OverbrightSettingsUI", "OverbrightOnboarding", "OverbrightAppShell"])
        .map { tests($0) }
)
