// OverbrightAppShell/App/QAHooks+Snapshot.swift — DEBUG-only: `--qa-snapshot <dir>` draws every visible window into
// `<dir>/panel-<number>.png` (the panel) or `<dir>/window-<number>.png`, and `-OverbrightQAAppearance light|dark` pins
// the app's appearance. ARCHITECTURE.md §8.5, §9.1. Compiled out of Release.
//
// The capture is in-process (`cacheDisplay`: no Screen Recording access, works while the displays sleep; menus cannot
// be drawn). `cacheDisplay` cannot draw vibrancy or glass: over the panel's and the HUD's material, text came out black
// on a dark card, separators bright, template symbols in the other appearance's colour, and Settings' sidebar blank.
// So a window that hosts SwiftUI is drawn the way the snapshot suites draw a view (`PanelSnapshotTests`): its SwiftUI
// root again, in an opaque host over `windowBackgroundColor`, in the window's appearance made non-vibrant, never
// ordered in. Only a window without a SwiftUI host is drawn from its own views. One limit stays: a material SwiftUI
// itself puts inside the root (Settings' sidebar column) still draws its vibrant labels dark in Dark (the sidebar's
// rows are drawn, the selected one black); judge that sidebar in Light, on screen, or in `SettingsChromeSnapshotTests`.
//
// The pinned appearance goes on `NSApp`, so the panel, the HUD, Welcome, Help, the calibration window and Settings all
// follow it (it used to pin Settings alone).
#if DEBUG
import AppKit
import Foundation
import OverbrightCore
import os
import SwiftUI

private let log = Log.logger(.app)

/// A view hosting a SwiftUI root that the snapshot can draw again (every `NSHostingView`, also a hosting controller's).
protocol QASnapshotHost: NSView {
    /// The hosted root.
    var qaRoot: AnyView { get }
}

extension NSHostingView: QASnapshotHost {
    var qaRoot: AnyView { AnyView(rootView) }
}

extension QAHooks {
    /// The defaults key of the pinned appearance (`-OverbrightQAAppearance light|dark`).
    static let appearanceKey = "OverbrightQAAppearance"

    /// The appearance `-OverbrightQAAppearance` pins: Aqua for "light", Dark Aqua for "dark", nil otherwise.
    static func pinnedAppearance(_ defaults: UserDefaults) -> NSAppearance? {
        switch defaults.string(forKey: appearanceKey) {
        case "light": NSAppearance(named: .aqua)
        case "dark": NSAppearance(named: .darkAqua)
        default: nil
        }
    }

    /// Pins the app's appearance when `-OverbrightQAAppearance` asks for one (every window follows `NSApp`'s).
    static func applyAppearance(_ defaults: UserDefaults, to application: NSApplication = NSApp) {
        guard let appearance = pinnedAppearance(defaults) else { return }
        application.appearance = appearance
        log.info("QA: appearance pinned to \(appearance.name.rawValue, privacy: .public)")
    }

    /// Draws each visible window into `<directory>/<kind>-<number>.png`.
    static func capture(into directory: URL) {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        } catch {
            log.error("QA: snapshot folder: \(error.localizedDescription, privacy: .public)")
            return
        }
        let visible = NSApp.windows.filter(\.isVisible)
        log.info("QA: snapshot of \(visible.count, privacy: .public) visible windows (panel open: \(visible.contains { $0 is OverbrightPanel }, privacy: .public))")
        for window in visible {
            guard let rep = picture(of: window), let data = rep.representation(using: .png, properties: [:]) else {
                continue
            }
            let kind = window is OverbrightPanel ? "panel" : "window"
            let url = directory.appending(path: "\(kind)-\(window.windowNumber).png")
            do {
                try data.write(to: url)
                log.info("QA: snapshot \(url.lastPathComponent, privacy: .public)")
            } catch {
                log.error("QA: snapshot failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    /// `window`'s picture: its SwiftUI root drawn again in an opaque, non-vibrant host at the hosting view's size and
    /// in the window's appearance; a window without a SwiftUI host is drawn from its own views.
    static func picture(of window: NSWindow) -> NSBitmapImageRep? {
        guard let content = window.contentView else { return nil }
        if let host = snapshotHost(in: content), host.bounds.width > 0, host.bounds.height > 0 {
            return render(host.qaRoot, size: host.bounds.size, appearance: opaque(window.effectiveAppearance))
        }
        guard let rep = content.bitmapImageRepForCachingDisplay(in: content.bounds) else { return nil }
        content.cacheDisplay(in: content.bounds, to: rep)
        return rep
    }

    /// The first SwiftUI host under `view` (breadth first: the outermost one).
    static func snapshotHost(in view: NSView) -> (any QASnapshotHost)? {
        var queue = [view]
        while !queue.isEmpty {
            let next = queue.removeFirst()
            if let host = next as? any QASnapshotHost { return host }
            queue += next.subviews
        }
        return nil
    }

    /// `appearance` without vibrancy (vibrant light and dark become Aqua and Dark Aqua; high contrast stays).
    static func opaque(_ appearance: NSAppearance) -> NSAppearance? {
        let names: [NSAppearance.Name] = [.aqua, .darkAqua, .accessibilityHighContrastAqua,
                                          .accessibilityHighContrastDarkAqua]
        return appearance.bestMatch(from: names).flatMap(NSAppearance.init(named:))
    }

    /// `root` over `windowBackgroundColor` in `appearance`, `size` points, in a borderless window never ordered in.
    static func render(_ root: AnyView, size: CGSize, appearance: NSAppearance?) -> NSBitmapImageRep? {
        let host = NSHostingView(rootView: root.background(Color(nsColor: .windowBackgroundColor)))
        host.sizingOptions = []
        host.appearance = appearance
        host.frame = CGRect(origin: .zero, size: size)
        let window = NSWindow(contentRect: host.frame, styleMask: [.borderless], backing: .buffered, defer: true)
        window.appearance = appearance
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        defer { window.contentView = nil }
        guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { return nil }
        host.cacheDisplay(in: host.bounds, to: rep)
        return rep
    }
}
#endif
