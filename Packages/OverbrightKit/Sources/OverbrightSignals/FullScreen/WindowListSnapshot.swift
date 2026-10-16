// OverbrightSignals/FullScreen/WindowListSnapshot.swift — the one window-server read of the full-screen check.
// ARCHITECTURE.md §7.1 ("Full screen": `@concurrent` snapshot ≈ 2 ms → main), §7.3, §8.1 rule 3.
// Thread: any; `read(windowServerPID:)` runs off the main actor. `CGWindowListCopyWindowInfo` is thread-safe and needs
// no permission for bounds, layer, owner PID and alpha (window names and sharing state are withheld without Screen
// Recording; we never read them). Status items, menus, the Dock and the rest are skipped by their layer before anything
// else is read.
// The WindowServer's PID (the owner of the menu-bar windows) must be known even when no menu bar is on screen: in a
// full-screen Space every menu-bar window is off screen [VERIFIED 2026-10-16 on the owner's Mac: Chrome full screen on
// the MSI, all three WindowServer layer-24 windows off screen], and the below-band and Split View rules need exactly
// that absence. So the PID comes, in order, from the caller (the tracker keeps it for the session), from an on-screen
// menu-bar window whose owner runs the WindowServer executable, or from one libproc scan (`WindowServerProcess`).
import CoreGraphics
import Foundation

/// On-screen windows of layer 0 and of the menu-bar layer, front to back, plus the WindowServer's PID.
nonisolated struct WindowListSnapshot: Hashable, Sendable {
    /// Layer-0 and menu-bar-layer windows, front to back.
    var windows: [FullScreenDetector.Window]
    /// The WindowServer's PID (it owns the menu-bar windows); nil only when libproc could not tell.
    var windowServerPID: Int32?

    /// A snapshot (tests build them directly).
    init(windows: [FullScreenDetector.Window], windowServerPID: Int32?) {
        self.windows = windows; self.windowServerPID = windowServerPID
    }

    /// Reads the window list off the main actor (≈ 2 ms, plus one ≈ 5 ms libproc scan when the WindowServer is not
    /// known yet and no menu bar is on screen). `windowServerPID`: the PID an earlier snapshot found, if any.
    @concurrent static func read(windowServerPID: Int32?) async -> WindowListSnapshot {
        capture(windowServerPID: windowServerPID)
    }

    /// Reads the window list on the calling thread.
    static func capture(windowServerPID: Int32?) -> WindowListSnapshot {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        let list = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as NSArray?
        let entries = list.map { $0.compactMap { $0 as? NSDictionary } } ?? []
        return make(entries, windowServerPID: windowServerPID, isWindowServer: WindowServerProcess.isWindowServer,
                    locate: WindowServerProcess.locate)
    }

    /// A snapshot from window-server entries (front to back, as `CGWindowListCopyWindowInfo` returns them). The
    /// WindowServer's PID is `windowServerPID` when given; else the lowest on-screen menu-bar owner that
    /// `isWindowServer`; else `locate()`.
    static func make(_ entries: [NSDictionary], windowServerPID known: Int32?, isWindowServer: (Int32) -> Bool,
                     locate: () -> Int32?) -> WindowListSnapshot {
        var windows: [FullScreenDetector.Window] = []
        for info in entries {
            guard let layer = info[kCGWindowLayer as String] as? Int,
                  layer == 0 || layer == FullScreenDetector.menuBarLayer,
                  let window = window(from: info, layer: layer) else { continue }
            windows.append(window)
        }
        if let known { return WindowListSnapshot(windows: windows, windowServerPID: known) }
        let menuBarOwners = Set(windows.filter { $0.layer == FullScreenDetector.menuBarLayer }.map(\.ownerPID))
        let pid = menuBarOwners.sorted().first(where: isWindowServer) ?? locate()
        return WindowListSnapshot(windows: windows, windowServerPID: pid)
    }

    /// One window-server entry of `layer`: bounds, owner PID and alpha.
    static func window(from info: NSDictionary, layer: Int) -> FullScreenDetector.Window? {
        guard let pid = info[kCGWindowOwnerPID as String] as? Int, let ownerPID = Int32(exactly: pid),
              let boundsDictionary = info[kCGWindowBounds as String] as? NSDictionary,
              let bounds = CGRect(dictionaryRepresentation: boundsDictionary as CFDictionary) else { return nil }
        let alpha = info[kCGWindowAlpha as String] as? Double ?? 1
        return FullScreenDetector.Window(layer: layer, bounds: bounds, ownerPID: ownerPID, alpha: alpha)
    }
}
