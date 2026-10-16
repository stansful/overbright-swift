// OverbrightSignals/Apps/RunningAppInfo.swift — a running app as Signals needs it. ARCHITECTURE.md §6.5, §7.2, §7.3.
// Thread: any (a value type). The live platform builds it from `NSRunningApplication` on the main actor; tests write it.
import Foundation

/// One running application. Identity is the process ID and the bundle ID; `localizedName` is for the UI only (D8: no
/// code compares names).
nonisolated struct RunningAppInfo: Hashable, Sendable {
    /// `NSRunningApplication.bundleIdentifier` (nil for bundle-less command-line tools).
    var bundleID: String?
    /// The process ID.
    var processID: Int32
    /// The executable's file name (matches bundle-less tools in the conflict catalogue).
    var executableName: String?
    /// The bundle on disk (team ID, `LSApplicationCategoryType`).
    var bundleURL: URL?
    /// `NSRunningApplication.localizedName` (shown at runtime, never matched).
    var localizedName: String
    /// `activationPolicy == .regular` (a Dock app). Accessory and agent apps (overlay shades, other apps' overlays)
    /// never count as full screen unless they are frontmost (§7.3).
    var isRegular: Bool

    /// A running app.
    init(bundleID: String?, processID: Int32, executableName: String? = nil, bundleURL: URL? = nil,
         localizedName: String = "", isRegular: Bool = true) {
        self.bundleID = bundleID; self.processID = processID; self.executableName = executableName
        self.bundleURL = bundleURL; self.localizedName = localizedName; self.isRegular = isRegular
    }
}
