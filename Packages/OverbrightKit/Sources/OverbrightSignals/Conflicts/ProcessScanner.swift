// OverbrightSignals/Conflicts/ProcessScanner.swift — the on-demand libproc scan behind drift attribution.
// ARCHITECTURE.md §3.6 (`ConflictProbe.attributeDrift`), §7.2 ("Drift attribution"), §8.1 rule 3.
// `LibProc` (`proc_listallpids` + `proc_pidpath`) lists every process with its executable path (≈ 920 PIDs in
// ≈ 14 ms, no permission [VERIFIED]). It runs only when an unexplained drift needs a culprit, never periodically, and
// off the main actor. For executables inside an app bundle the bundle ID is read from that bundle's Info.plist (once
// per bundle; system bundles under /System are skipped: they are never catalogued).
// Thread: any; `scan()` runs off the main actor.
import Foundation

/// Lists running processes by executable path.
nonisolated enum ProcessScanner {
    /// One running process.
    struct Process: Hashable, Sendable {
        /// The process ID.
        var processID: Int32
        /// The executable's file name.
        var executableName: String
        /// The enclosing app bundle, when the executable is an app's main executable.
        var bundlePath: String?
        /// That bundle's identifier.
        var bundleID: String?
    }

    /// Scans every process off the main actor.
    @concurrent static func scan() async -> [Process] { capture() }

    /// Scans every process on the calling thread.
    static func capture() -> [Process] {
        var bundleIDs: [String: String?] = [:]
        var processes: [Process] = []
        for pid in LibProc.allProcessIDs() {
            guard let path = LibProc.executablePath(of: pid) else { continue }
            let bundle = bundlePath(forExecutable: path)
            var bundleID: String?
            if let bundle, !bundle.hasPrefix("/System/") {
                if let cached = bundleIDs[bundle] {
                    bundleID = cached
                } else {
                    bundleID = bundleIdentifier(ofBundleAt: bundle)
                    bundleIDs[bundle] = bundleID
                }
            }
            processes.append(Process(processID: pid, executableName: (path as NSString).lastPathComponent,
                                     bundlePath: bundle, bundleID: bundleID))
        }
        return processes
    }

    /// The app bundle whose main executable `path` is (".../Name.app/Contents/MacOS/Name" → ".../Name.app"; the
    /// innermost bundle for helpers nested in another app); nil for executables outside a bundle.
    static func bundlePath(forExecutable path: String) -> String? {
        guard let range = path.range(of: ".app/Contents/MacOS/", options: .backwards) else { return nil }
        return String(path[..<range.lowerBound]) + ".app"
    }

    /// `CFBundleIdentifier` from the bundle's Info.plist.
    static func bundleIdentifier(ofBundleAt path: String) -> String? {
        let plist = URL(fileURLWithPath: path).appending(path: "Contents/Info.plist", directoryHint: .notDirectory)
        guard let data = try? Data(contentsOf: plist),
              let info = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        else { return nil }
        return info["CFBundleIdentifier"] as? String
    }
}
