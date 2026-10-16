// OverbrightAppShell/Windows/CalibrationWindowController.swift — the calibration window on the display under test.
// ARCHITECTURE.md §7.6, §10.13; DESIGN.md §9. Seam written by WP0a (§10.0): `init(services:)` and `show(display:)` are
// fixed; WP11 wrote the body.
//
// `show(display:)` asks the engine for a session (`BoostControl.beginCalibration`, which returns every display to
// Standard and holds Overbright off until the session ends) and shows SettingsUI's `CalibrationView` in a borderless
// window that covers that display: level `.screenSaver − 1`, our colour space set to the screen's
// (`NSScreen.colorSpace`) so the squares' code values reach the framebuffer unchanged, a black surround. Esc always ends
// the session at once and closes the window; covering the window ends the session too (occlusion), as do the engine's
// own reasons (lock, headroom drop, the minute's limit). While the window is on screen it is one of Overbright's own
// EDR surfaces (`OwnEDRSurfaces`), so the engine never mistakes it for idle headroom. One calibration at a time: asking
// for another display while one runs brings the running one forward. A display without an `NSScreen` of its own (a
// simulated one under `--qa-simulate`) gets an ordinary titled window on the main screen instead.
import AppKit
import OverbrightBoost
import OverbrightCore
import OverbrightSettingsUI
import os
import SwiftUI

private let log = Log.logger(.app)

/// Owns the calibration window.
final class CalibrationWindowController: NSObject, NSWindowDelegate {
    private let services: OverbrightServices
    /// Only while a calibration runs.
    private(set) var window: CalibrationWindow?
    /// The steps of the running calibration.
    private(set) var model: CalibrationModel?
    /// Holds the display as one of Overbright's own EDR surfaces while the window is on screen.
    private var surface: ObservationToken?
    private var occlusion: (any NSObjectProtocol)?

    /// The window's level: just below the screen saver, above every app and the menu bar.
    static let level = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue - 1)
    /// The window of a display without its own screen (simulated).
    static let fallbackSize = CGSize(width: 960, height: 640)

    /// A controller for the app's services.
    init(services: OverbrightServices) {
        self.services = services
        super.init()
    }

    /// Starts a calibration of `display` and shows its window (or brings the running one forward).
    func show(display: DisplayKey) {
        if let window {
            if model?.display != display { log.info("calibration already runs on another display; brought forward") }
            NSApp.activate()
            window.makeKeyAndOrderFront(nil)
            return
        }
        let window = preparedWindow(for: display)
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
        surface = services.ownEDRSurfaces.hold(display)
        log.info("calibration window shown (session \(self.model?.session != nil, privacy: .public))")
    }

    /// The window for `display`, with its model and session, not yet ordered in. `show(display:)` brings it forward;
    /// tests call this alone (a test never orders a window in).
    func preparedWindow(for display: DisplayKey) -> CalibrationWindow {
        let facts = services.displays.facts(for: display)
        let name = facts?.name ?? ""
        let model = CalibrationModel(display: display, name: name, services: services)
        model.onClose = { [weak self] in self?.window?.close() }
        let screen = facts.flatMap(Self.screen(for:))
        let window = CalibrationWindow(contentRect: CGRect(origin: .zero, size: screen?.frame.size ?? Self.fallbackSize),
                                       styleMask: screen == nil ? [.titled, .closable] : [.borderless],
                                       backing: .buffered, defer: true)
        window.isReleasedWhenClosed = false
        window.backgroundColor = .black
        window.isOpaque = true
        window.title = String(localized: "Calibrate \(name)", table: "Calibration", bundle: .module,
                              comment: "Calibration: window title (VoiceOver and the Window menu); the argument is the display’s name")
        window.contentView = NSHostingView(rootView: CalibrationView(model: model))
        window.onCancel = { [weak model] in model?.cancel() }
        window.delegate = self
        if let screen {
            window.level = Self.level
            window.colorSpace = screen.colorSpace
            window.hasShadow = false
            window.collectionBehavior = [.fullScreenAuxiliary, .ignoresCycle]
            window.setFrame(screen.frame, display: false)
            occlusion = NotificationCenter.default.addObserver(forName: NSWindow.didChangeOcclusionStateNotification,
                                                               object: window, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.occlusionChanged() }                  // queue: .main
            }
        } else {
            window.center()
        }
        self.window = window
        self.model = model
        return window
    }

    /// The `NSScreen` of `facts`' display, nil when it has none (a mirror member, a simulated display).
    static func screen(for facts: DisplayFacts) -> NSScreen? {
        NSScreen.screens.first { screen in
            (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value == facts.ref.id
        }
    }

    func windowWillClose(_ notification: Notification) {
        if let occlusion { NotificationCenter.default.removeObserver(occlusion) }
        occlusion = nil
        let model = self.model
        self.model = nil
        window = nil
        model?.onClose = nil
        model?.cancel()                          // the session ends (Standard at once) unless it already did
        surface?.cancel()
        surface = nil
        log.info("calibration window closed")
    }

    /// Covering the calibration window ends the session (DESIGN.md §9).
    private func occlusionChanged() {
        guard let window, window.isVisible, !window.occlusionState.contains(.visible),
              let session = model?.session else { return }
        if let controller = session as? OverbrightBoost.CalibrationController {
            controller.setOccluded(true)
        } else {
            session.cancel()
        }
    }
}
