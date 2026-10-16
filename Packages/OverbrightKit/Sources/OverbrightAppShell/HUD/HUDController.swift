// OverbrightAppShell/HUD/HUDController.swift — the on-screen level indicator. ARCHITECTURE.md §4.9 (`status.lastChange`
// by its increasing `sequence`), §7.6; DESIGN.md §6 (when, where, how long; never two), §12.9; D19. Seam written by
// WP0a (§10.0): `init(services:)`, `start()` and `stop()` are fixed. The words are Design's (`HUDText.make`); the rules
// are `HUDPolicy`'s; the place is shared with the Keep-this-level prompt (`HUDSlot`). Its timer is one
// `TimeSource.sleep` per showing (no repeating timer, DESIGN.md §17).
import AppKit
import OverbrightCore
import OverbrightDesign
import os
import SwiftUI

private let log = Log.logger(.panel)

/// Shows the HUD for level changes from shortcuts, intents, Focus and Back to Standard, "Preparing…" and automation
/// stops.
final class HUDController {
    private let services: OverbrightServices
    private let slot: HUDSlot
    private let makeText: (LevelChange, BoostStatus) -> HUDText?
    private var observation: ObservationToken?
    private var window: HUDWindow?
    private var hideTask: Task<Void, Never>?

    /// Tests turn windows off: the controller then decides and records, but orders nothing in.
    var presentsWindows = true
    /// The sequence of the last change shown.
    private(set) var lastShown: UInt64?
    /// What the HUD shows now (nil while hidden).
    private(set) var visible: HUDText?
    /// Number of showings (a new change while visible updates it and counts again).
    private(set) var showCount = 0

    /// A controller for the app's services.
    convenience init(services: OverbrightServices) {
        self.init(services: services, slot: .shared, text: { HUDText.make($0, status: $1) })
    }

    /// A controller with its own slot and words (tests).
    init(services: OverbrightServices, slot: HUDSlot, text: @escaping (LevelChange, BoostStatus) -> HUDText?) {
        self.services = services
        self.slot = slot
        makeText = text
    }

    /// Starts observing the engine's `lastChange` (a change already published, e.g. by `--qa-state`, shows at once).
    func start() {
        guard observation == nil else { return }
        let boost = services.boost
        if let change = boost.status.lastChange { handle(change) }
        observation = OverbrightCore.observe({ boost.status.lastChange }) { [weak self] change in
            if let change { self?.handle(change) }
        }
    }

    /// Stops observing and closes the HUD.
    func stop() {
        observation?.cancel()
        observation = nil
        hide()
    }

    /// Shows `change` if the rules allow it: one HUD, updated in place, gone `duration` after the last change.
    func handle(_ change: LevelChange) {
        let status = services.boost.status
        guard let presentation = HUDPolicy.presentation(for: change, lastShown: lastShown,
                                                        showsHUD: services.settings[GeneralSettings.showsHUD]) else {
            return
        }
        lastShown = change.sequence
        guard let text = makeText(change, status), slot.claim(.hud, onEvicted: { [weak self] in self?.hide() }) else {
            return
        }
        visible = text
        showCount += 1
        services.announcer.announce(text.announcement, kind: presentation.announcement)
        let display = change.display ?? status.displays.first?.key
        present(text, display: display, status: status)
        hideTask?.cancel()
        let time = services.time
        hideTask = Task { [weak self] in
            do { try await time.sleep(for: presentation.duration) } catch { return }
            self?.hide()
        }
    }

    /// Closes the HUD now.
    func hide() {
        hideTask?.cancel()
        hideTask = nil
        visible = nil
        slot.leave(.hud)
        guard let window, window.isVisible else { return }
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.25                                      // hudOut (DESIGN.md §3.1)
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            window.animator().alphaValue = 0
        }, completionHandler: {
            MainActor.assumeIsolated {                                   // AppKit runs completions on the main thread
                if window.alphaValue == 0 { window.orderOut(nil) }
            }
        })
    }

    /// `--qa-hud <level>`: shows a level change of every display as a shortcut would (Debug QA).
    func showForQA(_ level: String) {
        log.info("QA: HUD \(level, privacy: .public)")
        handle(LevelChange(sequence: (lastShown ?? 0) + 1, kind: .level, source: .shortcut, display: nil))
    }

    // MARK: Window

    private func present(_ text: HUDText, display: DisplayKey?, status: BoostStatus) {
        guard presentsWindows,
              let frame = HUDPlacement.currentFrame(size: HUDPlacement.size, display: display, services: services) else {
            return
        }
        let level = Self.level(of: display, status: status, settings: services.settings)
        let isBoosting = Self.isBoosting(display, status: status)
        let root = HUDView(text: text, level: level, isBoosting: isBoosting).overbrightThemeRoot()
        let window = self.window ?? HUDWindow(frame: frame, interactive: false)
        self.window = window
        let hosting = NSHostingView(rootView: root)
        window.contentView = PanelContainer.make(around: hosting, material: PanelContainer.currentMaterial,
                                                 cornerRadius: Radius.hud, effect: .hudWindow)
        window.setFrame(frame, display: true)
        if !window.isVisible { window.alphaValue = 0 }
        window.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.18                                      // hudIn (DESIGN.md §3.1)
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window.animator().alphaValue = 1
        }
    }

    /// Extra light is on screen on `display`: the bar's boost fill is warm only then (DESIGN.md §2.1).
    static func isBoosting(_ display: DisplayKey?, status: BoostStatus) -> Bool {
        status.isOn && (status.displays.first { $0.key == display }?.appliedGain ?? 1) > 1
    }

    /// The level the bar shows: the display's stored level while on, Standard while off.
    static func level(of display: DisplayKey?, status: BoostStatus, settings: SettingsStore) -> LevelPosition {
        guard status.isOn else { return .standard }
        if settings[DisplaySettings.linkLevels] { return settings[DisplaySettings.linkedLevel] }
        guard let display else { return .standard }
        return settings[DisplaySettings.perDisplay][display]?.level ?? LevelPreset.brightRoom.position
    }
}
