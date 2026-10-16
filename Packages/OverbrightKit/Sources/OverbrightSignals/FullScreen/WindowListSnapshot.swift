// OverbrightSignals/FullScreen/WindowListSnapshot.swift — the one window-server read of the full-screen check.
// ARCHITECTURE.md §7.1 ("Full screen": `@concurrent` snapshot ≈ 2 ms → main), §7.3, §8.1 rule 3.
// Thread: any; `read()` runs off the main actor. `CGWindowListCopyWindowInfo` is thread-safe and needs no permission for
// bounds, layer, owner PID and alpha (window names and sharing state are withheld without Screen Recording; we never
// read them). Status items, menus, the Dock and the rest are skipped by their layer before anything else is read. The
// menu-bar window's owner is identified as the WindowServer by its executable path (libproc), never by a name.
import CoreGraphics
import Darwin
import Foundation

/// On-screen windows of layer 0 and of the menu-bar layer, front to back, plus the WindowServer's PID.
nonisolated struct WindowListSnapshot: Hashable, Sendable {
    /// Layer-0 and menu-bar-layer windows, front to back.
    var windows: [FullScreenDetector.Window]
    /// The PID that owns the menu-bar windows (the WindowServer), when it could be identified.
    var windowServerPID: Int32?

    /// A snapshot (tests build them directly).
    init(windows: [FullScreenDetector.Window], windowServerPID: Int32?) {
        self.windows = windows; self.windowServerPID = windowServerPID
    }

    /// Reads the window list off the main actor (≈ 2 ms).
    @concurrent static func read() async -> WindowListSnapshot { capture() }

    /// Reads the window list on the calling thread.
    static func capture() -> WindowListSnapshot {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let list = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as NSArray? else {
            return WindowListSnapshot(windows: [], windowServerPID: nil)
        }
        var windows: [FullScreenDetector.Window] = []
        for case let info as NSDictionary in list {
            guard let layer = info[kCGWindowLayer as String] as? Int,
                  layer == 0 || layer == FullScreenDetector.menuBarLayer,
                  let window = window(from: info, layer: layer) else { continue }
            windows.append(window)
        }
        let menuBarOwners = Set(windows.filter { $0.layer == FullScreenDetector.menuBarLayer }.map(\.ownerPID))
        return WindowListSnapshot(windows: windows, windowServerPID: menuBarOwners.sorted().first(where: isWindowServer))
    }

    /// One window-server entry of `layer`: bounds, owner PID and alpha.
    static func window(from info: NSDictionary, layer: Int) -> FullScreenDetector.Window? {
        guard let pid = info[kCGWindowOwnerPID as String] as? Int, let ownerPID = Int32(exactly: pid),
              let boundsDictionary = info[kCGWindowBounds as String] as? NSDictionary,
              let bounds = CGRect(dictionaryRepresentation: boundsDictionary as CFDictionary) else { return nil }
        let alpha = info[kCGWindowAlpha as String] as? Double ?? 1
        return FullScreenDetector.Window(layer: layer, bounds: bounds, ownerPID: ownerPID, alpha: alpha)
    }

    /// Whether `pid` runs the WindowServer executable (its path, not a localized name).
    static func isWindowServer(_ pid: Int32) -> Bool {
        executablePath(of: pid).map(isWindowServerPath) ?? false
    }

    /// Whether an executable path is the WindowServer's (".../SkyLight.framework/Resources/WindowServer").
    static func isWindowServerPath(_ path: String) -> Bool {
        (path as NSString).lastPathComponent == "WindowServer"
    }

    /// `proc_pidpath` of `pid`, nil when it cannot be read.
    static func executablePath(of pid: Int32) -> String? {
        var buffer = [CChar](repeating: 0, count: 4 * Int(MAXPATHLEN))
        let length = proc_pidpath(pid, &buffer, UInt32(buffer.count))
        guard length > 0 else { return nil }
        return String(decoding: buffer.prefix(Int(length)).map { UInt8(bitPattern: $0) }, as: UTF8.self)
    }
}
