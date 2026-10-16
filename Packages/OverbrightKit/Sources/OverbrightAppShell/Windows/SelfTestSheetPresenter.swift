// OverbrightAppShell/Windows/SelfTestSheetPresenter.swift — the self-test outside Settings, and its Save Log… panel.
// ARCHITECTURE.md §8.4, §10.13; DESIGN.md §10. Seam written by WP0a (§10.0): `init(services:)` and `present(over:)`
// are fixed; WP11 wrote the body. Settings ▸ Advanced presents SettingsUI's `SelfTestSheet` as a SwiftUI sheet itself;
// `present(over:)` shows the same sheet over any window, or in its own small window. `saveLog(_:)` is what
// `AppControl.saveSelfTestLog` does: a Save panel for a JSON file, then the report written off the main actor (only
// the user's choice of place ever receives a log; the archive of the last ten is SettingsUI's).
import AppKit
import OverbrightCore
import OverbrightSettingsUI
import os
import SwiftUI
import UniformTypeIdentifiers

private let log = Log.logger(.selfTest)

/// Presents the self-test sheet over a window (Settings), or as its own window, and saves logs.
final class SelfTestSheetPresenter: NSObject, NSWindowDelegate {
    private let services: OverbrightServices
    /// Only while the sheet is up.
    private(set) var window: NSWindow?

    /// A presenter for the app's services.
    init(services: OverbrightServices) {
        self.services = services
        super.init()
    }

    /// Presents the sheet over `window` (nil: its own window), or brings the one that is up forward.
    func present(over parent: NSWindow?) {
        if let window {
            (window.sheetParent ?? window).makeKeyAndOrderFront(nil)
            return
        }
        let window = preparedWindow()
        NSApp.activate()
        if let parent {
            parent.beginSheet(window)
        } else {
            window.center()
            window.makeKeyAndOrderFront(nil)
        }
    }

    /// The sheet's window, not yet shown (tests call this alone).
    func preparedWindow() -> NSWindow {
        let host = NSHostingController(rootView: SelfTestSheet(services: services) { [weak self] in self?.dismiss() })
        host.sizingOptions = [.preferredContentSize]
        let window = NSWindow(contentViewController: host)
        window.styleMask = [.titled, .closable]
        window.title = String(localized: "Self-Test", table: "Calibration", bundle: .module,
                              comment: "Self-test: title of its window (VoiceOver and the Window menu)")
        window.isReleasedWhenClosed = false
        window.delegate = self
        self.window = window
        return window
    }

    /// Done or Cancel: the sheet goes away.
    func dismiss() {
        guard let window else { return }
        if let parent = window.sheetParent { parent.endSheet(window) }
        window.close()
    }

    func windowWillClose(_ notification: Notification) {
        window = nil
    }

    /// Save Log…: a Save panel for a JSON file, then the report written there.
    func saveLog(_ report: SelfTestReport) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = Self.suggestedName(for: report)
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            Task {
                do {
                    try await SelfTestLog.write(report, to: url)
                    log.info("self-test log saved")
                } catch {
                    let failure = error as NSError
                    log.error("self-test log not saved: \(failure.domain, privacy: .public) \(failure.code, privacy: .public) (\(failure.localizedDescription, privacy: .private))")
                }
            }
        }
    }

    /// "Overbright Self-Test 2026-10-16T142005Z.json".
    static func suggestedName(for report: SelfTestReport) -> String {
        let stamp = SelfTestLog.fileName(startedAt: report.startedAt)
        return String(localized: "Overbright Self-Test \(stamp)", table: "Calibration", bundle: .module,
                      comment: "Self-test: the suggested file name of a saved log; the argument is its date and time with “.json”")
    }
}
