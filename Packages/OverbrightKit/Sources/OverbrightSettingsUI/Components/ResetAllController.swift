// OverbrightSettingsUI/Components/ResetAllController.swift — "Reset All Settings…" with Undo (DESIGN.md §7.8, §12.4):
// afterwards an Undo Reset button stays in Advanced until the Settings window closes, ⌘Z works too, and a banner
// "All settings were reset." [Undo] shows for 10 s. Ported from Cranny's ResetAllController (the owner's MIT code):
// the offer now outlives the banner, and the reset goes through `AppControl` (`resetAllSettings` /
// `undoResetAllSettings`), which keeps the snapshot. Records are not settings (ARCHITECTURE.md §3.8, `EngineRecords`):
// the boost marker survives both the reset and the undo. One sleep to the banner's deadline, no polling.
import Foundation
import Observation
import OverbrightCore

/// The Reset All offer of one Settings session.
@Observable final class ResetAllController {
    /// True while Undo is offered: from the reset until the window closes (the Undo Reset button, ⌘Z).
    private(set) var canUndo = false
    /// True while the banner shows (10 s after the reset, or until dismissed).
    private(set) var showsBanner = false
    @ObservationIgnored private var localSnapshot: SettingsStore.Snapshot?
    @ObservationIgnored private var expiry: Task<Void, Never>?
    /// The current offer was announced to VoiceOver (`takeAnnouncement()`).
    @ObservationIgnored private var isAnnounced = false
    @ObservationIgnored private let services: OverbrightServices
    @ObservationIgnored private let bannerTime: Duration
    @ObservationIgnored private let sleep: @Sendable (Duration) async throws -> Void

    /// `sleep` is injectable so tests can end the banner without waiting.
    init(services: OverbrightServices, bannerTime: Duration = SettingsMetrics.undoBannerTime,
         sleep: @escaping @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) }) {
        self.services = services; self.bannerTime = bannerTime; self.sleep = sleep
    }

    /// Resets every setting (through the app, which keeps the snapshot and re-applies what follows the settings) and
    /// offers Undo until the window closes.
    func resetAll() {
        let records = Records(services.settings)
        if let app = services.app {
            app.resetAllSettings()
        } else {
            localSnapshot = services.settings.snapshot()
            services.settings.resetAll()
        }
        records.restore(into: services.settings)
        canUndo = true
        showsBanner = true
        isAnnounced = false
        expiry?.cancel()
        expiry = Task { [weak self, bannerTime, sleep] in
            try? await sleep(bannerTime)
            guard !Task.isCancelled else { return }
            self?.dismissBanner()
        }
    }

    /// Restores every setting from before the reset.
    func undo() {
        guard canUndo else { return }
        let records = Records(services.settings)
        if let app = services.app {
            app.undoResetAllSettings()
        } else if let localSnapshot {
            services.settings.restore(localSnapshot)
        }
        records.restore(into: services.settings)
        endOffer()
    }

    /// True the first time the banner asks for the current offer: it is announced once, also when the banner appears
    /// again in a rebuilt Settings window.
    func takeAnnouncement() -> Bool {
        defer { isAnnounced = true }
        return !isAnnounced
    }

    /// Hides the banner (its close button, or the 10 s are over); Undo stays offered.
    func dismissBanner() {
        expiry?.cancel()
        expiry = nil
        if showsBanner { showsBanner = false }
    }

    /// The Settings window closed: the offer ends (DESIGN.md §7.8).
    func windowDidClose() { endOffer() }

    private func endOffer() {
        dismissBanner()
        localSnapshot = nil
        if canUndo { canUndo = false }
    }

    /// The records that live among the settings but are not settings: written back after a reset or an undo, in the
    /// same main-actor turn, so observers never see them change.
    private struct Records {
        let boostMarker: BoostMarker?

        init(_ settings: SettingsStore) { boostMarker = settings[EngineRecords.boostMarker] }

        func restore(into settings: SettingsStore) {
            if settings[EngineRecords.boostMarker] != boostMarker { settings[EngineRecords.boostMarker] = boostMarker }
        }
    }
}
