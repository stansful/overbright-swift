// OverbrightAppShell/LoginItem/LoginItemController.swift — opening at login (`AppControl.loginItem`). ARCHITECTURE.md
// §3.6, §3.8 (`GeneralSettings.launchBehavior`), §7.6, D15; DESIGN.md §7.3, §8 (Skip registers the default). Ported
// from Cranny's LoginItemController (the owner's MIT code); `LaunchBehavior` decides register or unregister, and the
// "why unavailable" lives beside the state because Core's `LoginItemState.unavailable` carries no message.
//
// `SMAppService.mainApp` only. The status (an XPC round trip) is read on first use, not at launch: only Settings and
// Welcome show it. After that it is read again whenever the app becomes active (Settings and Welcome activate it),
// never cached as a Bool: the user can change it in System Settings at any time. `.requiresApproval` leaves the user
// to finish in Login Items (Settings shows the footnote and an Open System Settings button, `openSystemSettings()`);
// nothing opens System Settings on its own. A translocated copy (run from Downloads) cannot register at all.
import AppKit
import Foundation
import Observation
import OverbrightCore
import os
import ServiceManagement

private let log = Log.logger(.app)

/// The app's login item.
@Observable final class LoginItemController {
    /// Why the login item cannot be used (`LoginItemState.unavailable`).
    enum Unavailable: Equatable {
        /// A translocated copy (App Translocation runs a quarantined app from a random read-only path).
        case translocated
        /// macOS refused the registration.
        case refused
    }

    /// `AppControl.loginItem`. The first read asks `SMAppService` (so whoever shows it first, Settings ▸ General or
    /// Welcome, sees the real status); later reads return what the last refresh found.
    var state: LoginItemState {
        if !hasRead { refresh() }
        return current
    }

    /// Why `state` is `.unavailable` (nil otherwise): Settings words its footnote after it.
    var unavailable: Unavailable? {
        if !hasRead { refresh() }
        return reason
    }

    /// The status as last read or set (observed: views reading `state` follow it).
    private var current: LoginItemState = .disabled
    private var reason: Unavailable?
    /// Whether the status was read (or set) at least once; until then nothing shows it.
    @ObservationIgnored private var hasRead = false
    @ObservationIgnored private let service: any LoginItemService
    @ObservationIgnored private let bundleURL: URL
    @ObservationIgnored private var observer: (any NSObjectProtocol)?

    /// A controller for `service` (the app's `SMAppService.mainApp` by default) of the bundle at `bundleURL`. Makes no
    /// XPC call until something reads `state`.
    init(service: any LoginItemService = MainAppLoginItem(), bundleURL: URL = Bundle.main.bundleURL) {
        self.service = service
        self.bundleURL = bundleURL
    }

    /// Reads the status again every time Overbright becomes active, once something has read it (the first read is
    /// lazy: a launch at login, which shows neither Settings nor Welcome, makes no XPC call for it).
    func start() {
        guard observer == nil else { return }
        observer = NotificationCenter.default.addObserver(forName: NSApplication.didBecomeActiveNotification,
                                                          object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { if let self, self.hasRead { self.refresh() } }      // queue: .main
        }
    }

    /// Stops following activations.
    func stop() {
        if let observer { NotificationCenter.default.removeObserver(observer) }
        observer = nil
    }

    /// Reads the status now.
    func refresh() {
        hasRead = true
        if Self.isTranslocated(bundleURL) {
            set(.unavailable, reason: .translocated)
        } else if reason == .refused, Self.state(for: service.status) == .disabled {
            set(.unavailable, reason: .refused)                                   // still refused: keep explaining
        } else {
            set(Self.state(for: service.status), reason: nil)
        }
    }

    /// Applies a launch behaviour (Settings ▸ General ▸ When you log in, Welcome's Done and Skip): both "Open
    /// Overbright" choices register the app, "Don't open Overbright" removes it. Whether it turns on at login is
    /// the engine's business (`GeneralSettings.launchBehavior`), not the login item's.
    func apply(_ behavior: LaunchBehavior) {
        setEnabled(behavior != .dontLaunch)
    }

    /// Registers (true) or unregisters (false) the app; `state` reports the outcome.
    func setEnabled(_ enabled: Bool) {
        hasRead = true
        guard !Self.isTranslocated(bundleURL) else { set(.unavailable, reason: .translocated); return }
        let status = Self.state(for: service.status)
        if enabled {
            guard status != .enabled, status != .requiresApproval else { set(status, reason: nil); return }
            do {
                try service.register()
                log.info("login item registered")
            } catch {
                log.error("login item not registered: \(error.localizedDescription, privacy: .public)")
            }
            let after = Self.state(for: service.status)
            if after == .disabled || after == .unavailable { set(.unavailable, reason: .refused) } else { set(after, reason: nil) }
        } else {
            guard status != .disabled else { set(.disabled, reason: nil); return }
            do {
                try service.unregister()
                log.info("login item unregistered")
            } catch {
                log.error("login item not unregistered: \(error.localizedDescription, privacy: .public)")
            }
            set(Self.state(for: service.status), reason: nil)
        }
    }

    /// Opens Login Items in System Settings (the Open System Settings button of the approval footnote).
    func openSystemSettings() { service.openSystemSettingsLoginItems() }

    // MARK: Pure helpers (unit-tested)

    /// `.notRegistered` and `.notFound` (an app macOS has never seen as a login item) are both "off".
    nonisolated static func state(for status: SMAppService.Status) -> LoginItemState {
        switch status {
        case .enabled: .enabled
        case .requiresApproval: .requiresApproval
        case .notRegistered, .notFound: .disabled
        @unknown default: .disabled
        }
    }

    /// App Translocation runs a quarantined app from a random read-only path, which breaks login items.
    nonisolated static func isTranslocated(_ url: URL) -> Bool {
        url.standardizedFileURL.path(percentEncoded: false).contains("/AppTranslocation/")
    }

    // MARK: Private

    private func set(_ state: LoginItemState, reason: Unavailable?) {
        if current != state { current = state }
        if self.reason != reason { self.reason = reason }
    }
}
