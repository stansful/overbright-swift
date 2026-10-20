// OverbrightAppShell/Windows/SettingsWindowController.swift — the Settings window. ARCHITECTURE.md §7.6, §10.2; D15;
// DESIGN.md §7.1. Seam written by WP0a (§10.0): `init(services:)` and `show(pane:)` are fixed; WP0b ported Cranny's
// controller (the owner's MIT code) and WP11 fills the panes.
//
// An AppKit-managed `NSWindow` hosting `SettingsRootView`, so any pane (or row: "displays#cap") can be opened from an
// agent app, a chip, a banner, the menu, Help or an intent (no SwiftUI `Settings` scene: `OverbrightScenes` keeps an
// empty one and routes ⌘, here). 860 × 620 by default, 780 × 560 minimum; the frame is autosaved (not in a Debug QA run
// with its own defaults suite) and the last pane is restored (`ShellDefaults`). SwiftUI drives the toolbar and title
// (`sceneBridgingOptions`), so the sidebar and toolbar get the system's Liquid Glass on macOS 26+ and Overbright adds
// none. While Settings is open, opening a pane navigates its `SettingsSession`, so the search and the Undo offer
// survive. Closing releases the window, its hosting controller, the SwiftUI tree and the session (energy E3, DESIGN.md
// §17) and ends the Undo offer of Reset All (DESIGN.md §7.8); the next open builds them again at the pane shown last,
// with the search text of before, at the frame the window had.
// ⌘Q quits Overbright (the app menu's Quit, while Settings is key); ⌘Z undoes Reset All (Edit ▸ Undo, through the
// window's undo manager).
import AppKit
import OverbrightCore
import OverbrightSettingsUI
import os
import SwiftUI

private let log = Log.logger(.app)

/// Owns the Settings window.
final class SettingsWindowController: NSObject, NSWindowDelegate {
    /// Not an Overbright setting (Reset All keeps it): the pane shown last, restored when Settings opens without one.
    static let lastPaneKey = "OverbrightSettingsLastPane"
    /// AppKit's frame autosave name (the frame is stored under "NSWindow Frame OverbrightSettings").
    private static let frameAutosaveName = "OverbrightSettings"

    private let services: OverbrightServices
    private let defaults: UserDefaults
    /// False in a QA run with its own suite: AppKit's frame autosave would write the standard domain.
    private let autosavesFrame: Bool
    /// Only while Settings is open: released on close.
    private(set) var window: NSWindow?
    /// The open window's state (nil while no window exists); `show(pane:)` navigates it.
    private(set) var session: SettingsSession?
    /// The search text of the last window that closed, for the next one.
    private var closedQuery: String?
    /// Whether a window was built this run (the Debug QA hooks act on the first one only).
    private var hasOpened = false
    /// The app that was frontmost before Settings opened gets activation back on close.
    private var previousApp: NSRunningApplication?
    /// Without frame autosave (a QA run with its own suite): where the window was when it closed, so the next one
    /// opens there for the rest of the run, as the autosave would.
    private var closedFrame: CGRect?

    /// A controller for the app's services, keeping its own state in the defaults this launch chose (`ShellDefaults`).
    convenience init(services: OverbrightServices) {
        self.init(services: services, defaults: .forLaunch())
    }

    /// `defaults` is the app's `ShellDefaults` (tests pass an in-memory one).
    init(services: OverbrightServices, defaults: ShellDefaults) {
        self.services = services
        self.defaults = defaults.defaults
        autosavesFrame = defaults.autosavesWindowFrames
        super.init()
        #if DEBUG
        scheduleQASettingsMenuItem()
        #endif
    }

    /// Opens (or brings forward) Settings at `pane` ("pane" or "pane#row"), or at the pane shown last when nil. Call
    /// in response to a user action (cooperative activation).
    func show(pane: String?) {
        let front = NSWorkspace.shared.frontmostApplication
        if front?.processIdentifier != ProcessInfo.processInfo.processIdentifier { previousApp = front }
        let window = preparedWindow(at: pane)
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
        log.info("settings shown at \(pane ?? "-", privacy: .public) (pane \(self.session?.currentPane.rawValue ?? "-", privacy: .public), window \(window.windowNumber, privacy: .public))")
    }

    /// The Settings window at `pane` (nil keeps the open window's pane, else restores the one shown last), not yet
    /// ordered in: the open window navigated, never rebuilt, or a new one built around a new session that carries
    /// the search text of the last window. `show(pane:)` brings it forward; tests call this alone.
    func preparedWindow(at pane: String?) -> NSWindow {
        if let window, let session {
            session.open(pane)
            return window
        }
        let session = SettingsSession(services: services, initialPane: pane ?? lastPane)
        if let closedQuery { session.query = closedQuery }
        self.session = session
        #if DEBUG
        if !hasOpened {
            scheduleQASnapshot()
            scheduleQAClose()
        }
        #endif
        hasOpened = true
        let window = makeWindow(session: session)
        self.window = window
        return window
    }

    /// A new window hosting `session`, where the last one was (the frame autosave; a QA run's `closedFrame`).
    private func makeWindow(session: SettingsSession) -> NSWindow {
        let host = NSHostingController(rootView: SettingsRootView(session: session) { [weak self] shown in
            self?.rememberLastPane(shown)
        })
        host.sizingOptions = []
        host.sceneBridgingOptions = [.title, .toolbars]
        let size = CGSize(width: 860, height: 620)
        let window = NSWindow(contentRect: CGRect(origin: .zero, size: size),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                              backing: .buffered, defer: false)
        window.contentViewController = host
        window.contentMinSize = CGSize(width: 780, height: 560)
        window.setContentSize(size)
        window.isReleasedWhenClosed = false
        window.toolbarStyle = .unified
        window.titlebarSeparatorStyle = .automatic
        window.tabbingMode = .disallowed
        window.collectionBehavior.insert(.fullScreenNone)
        window.delegate = self
        window.center()
        if autosavesFrame {
            window.setFrameAutosaveName(Self.frameAutosaveName)
        } else if let closedFrame {
            window.setFrame(closedFrame, display: false)
        }
        return window
    }

    func windowWillClose(_ notification: Notification) {
        // Cooperative activation hand-back.
        if let previousApp, !previousApp.isTerminated { previousApp.activate() }
        previousApp = nil
        // Release the window (AppKit lets go of it once the close is done), the hosting controller and the SwiftUI
        // tree now, and the session; keep the search text. The frame is already saved: giving up the autosave name
        // keeps it saved and lets the next window take the name even if this one is still alive then (a name is unique
        // per live window). Without the autosave, the controller keeps the frame for the next window.
        if autosavesFrame { window?.setFrameAutosaveName("") } else { closedFrame = window?.frame }
        window?.contentViewController = nil
        window?.delegate = nil
        window = nil
        closedQuery = session?.query
        session?.windowDidClose()
        session = nil
        log.info("settings closed")
    }

    #if DEBUG
    // `-OverbrightQAAppearance light|dark` pins the whole app's appearance, this window's too (QAHooks+Snapshot.swift).

    /// Visual QA (Debug only): `-OverbrightQASnapshot <file.png>` renders the window's own view hierarchy to a PNG after
    /// `-OverbrightQASnapshotDelay` seconds (default 3). Unlike `screencapture`, it works while the displays sleep.
    private func scheduleQASnapshot() {
        guard let snapshot = defaults.string(forKey: "OverbrightQASnapshot") else { return }
        let delay = defaults.double(forKey: "OverbrightQASnapshotDelay")
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay > 0 ? delay : 3))
            self?.writeSnapshot(to: URL(fileURLWithPath: snapshot))
        }
    }

    /// Visual QA (Debug only): `-OverbrightQASettingsMenuItem <s>` performs the app menu's ⌘, item that many seconds
    /// after launch, as pressing ⌘, would (shape question 1 of ARCHITECTURE.md §10.2: ⌘, reaches this window). No input
    /// is synthesized: the item is found by its key equivalent and its own action runs (`performActionForItem(at:)`).
    /// The log names the item; `show(pane:)` then logs the window it opened, and `-OverbrightQASnapshot` draws it.
    private func scheduleQASettingsMenuItem() {
        let delay = defaults.double(forKey: "OverbrightQASettingsMenuItem")
        guard delay > 0 else { return }
        Task {
            try? await Task.sleep(for: .seconds(delay))
            Self.performSettingsMenuItem()
        }
    }

    /// The app menu's ⌘, item, performed; false when the menu has none.
    @discardableResult
    static func performSettingsMenuItem(in mainMenu: NSMenu? = NSApp.mainMenu) -> Bool {
        guard let appMenu = mainMenu?.items.first?.submenu,
              let index = appMenu.items.firstIndex(where: isSettingsItem) else {
            log.error("QA: the app menu has no ⌘, item")
            return false
        }
        log.info("QA: performing the app menu's \(appMenu.items[index].title, privacy: .public) (⌘,)")
        appMenu.performActionForItem(at: index)
        return true
    }

    /// ⌘, with no other modifier.
    static func isSettingsItem(_ item: NSMenuItem) -> Bool {
        item.keyEquivalent == "," && item.keyEquivalentModifierMask.intersection(.deviceIndependentFlagsMask) == .command
    }

    /// Visual QA (Debug only): `-OverbrightQACloseAfter <s>` closes the first Settings window of the run after that
    /// many seconds, as its close button would (checks that the agent app survives closing Settings, §10.2).
    private func scheduleQAClose() {
        let delay = defaults.double(forKey: "OverbrightQACloseAfter")
        guard delay > 0 else { return }
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            self?.window?.performClose(nil)
        }
    }

    private func writeSnapshot(to url: URL) {
        guard let view = window?.contentView?.superview ?? window?.contentView,
              let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
        view.cacheDisplay(in: view.bounds, to: rep)
        do {
            try rep.representation(using: .png, properties: [:])?.write(to: url)
        } catch {
            let failure = error as NSError
            log.error("QA: settings snapshot failed: \(failure.domain, privacy: .public) \(failure.code, privacy: .public) (\(failure.localizedDescription, privacy: .private))")
        }
    }
    #endif

    private var lastPane: String? {
        defaults.string(forKey: Self.lastPaneKey)
    }

    /// Restored when Settings opens without a pane (kept in the app's `ShellDefaults`).
    func rememberLastPane(_ pane: SettingsPaneID) {
        defaults.set(pane.rawValue, forKey: Self.lastPaneKey)
    }
}
