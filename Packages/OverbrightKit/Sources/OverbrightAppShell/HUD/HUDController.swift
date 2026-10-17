// OverbrightAppShell/HUD/HUDController.swift — the on-screen level indicator. ARCHITECTURE.md §4.9 (`status.lastChange`
// by its increasing `sequence`), §7.6; DESIGN.md §6 (when, where, how long; never two), §12.9, §15; D19. Seam written by
// WP0a (§10.0): `init(services:)`, `start()` and `stop()` are fixed. The rules are `HUDPolicy`'s; a level change shows
// the level the display is set to, as value and bar (`HUDContent`), everything else Design's `HUDText`; the place is
// shared with the Keep-this-level prompt (`HUDSlot`). VoiceOver hears every qualifying change even when the window does
// not show (the setting is off, or the prompt holds the place). A change to every display shows on the display under
// the pointer. "Preparing…" stays up until the display is ready (at most 3 s), then the level reached shows for 1.5 s.
// Its timers are one `TimeSource.sleep` per showing (no repeating timer, DESIGN.md §17), and the wait for a ready
// display observes the engine's status instead of polling it.
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
    private let makeText: (LevelChange, BoostStatus, DisplayKey?) -> HUDText?
    private var observation: ObservationToken?
    private var readyObservation: ObservationToken?
    private var window: HUDWindow?
    private var hideTask: Task<Void, Never>?

    /// Tests turn windows off: the controller then decides and records, but orders nothing in (and asks no screen
    /// where the pointer is).
    var presentsWindows = true
    /// The sequence of the last change handled.
    private(set) var lastShown: UInt64?
    /// What the HUD shows now (nil while hidden).
    private(set) var visible: HUDText?
    /// The display the visible HUD is about.
    private(set) var visibleDisplay: DisplayKey?
    /// Number of showings (a new change while visible updates it and counts again).
    private(set) var showCount = 0

    /// A controller for the app's services.
    convenience init(services: OverbrightServices) {
        self.init(services: services, slot: .shared) { change, status, display in
            HUDContent.text(for: change, status: status, on: display, services: services)
        }
    }

    /// A controller with its own slot and words (tests).
    convenience init(services: OverbrightServices, slot: HUDSlot, text: @escaping (LevelChange, BoostStatus) -> HUDText?) {
        self.init(services: services, slot: slot) { change, status, _ in text(change, status) }
    }

    /// A controller whose words also know the display they are about.
    init(services: OverbrightServices, slot: HUDSlot, text: @escaping (LevelChange, BoostStatus, DisplayKey?) -> HUDText?) {
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

    /// Announces `change` and shows it if the rules allow it: one HUD, updated in place, gone `duration` after the
    /// last change; a turn-on's "Preparing…" waits for the display first.
    func handle(_ change: LevelChange) {
        let status = services.boost.status
        guard let presentation = HUDPolicy.presentation(for: change, lastShown: lastShown,
                                                        showsHUD: services.settings[GeneralSettings.showsHUD]) else {
            return
        }
        lastShown = change.sequence
        let pointer = presentsWindows && change.display == nil ? HUDPlacement.currentPointerDisplay(services: services) : nil
        let display = HUDContent.shownDisplay(for: change, underPointer: pointer, status: status)
        guard let text = makeText(change, status, display) else { return }
        services.announcer.announce(text.announcement, kind: presentation.announcement)
        readyObservation?.cancel()
        readyObservation = nil
        guard presentation.showsWindow, slot.claim(.hud, onEvicted: { [weak self] in self?.hide() }) else { return }
        show(text, about: display, placed: change.display ?? pointer)
        if case .preparing = change.kind, HUDPolicy.isPreparing(status, display: change.display) {
            waitUntilReady(change, about: display, placed: change.display ?? pointer)
        } else {
            hide(after: presentation.duration)
        }
    }

    /// Closes the HUD now.
    func hide() {
        hideTask?.cancel()
        hideTask = nil
        readyObservation?.cancel()
        readyObservation = nil
        visible = nil
        visibleDisplay = nil
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

    // MARK: Showing

    private func show(_ text: HUDText, about display: DisplayKey?, placed: DisplayKey?) {
        visible = text
        visibleDisplay = display
        showCount += 1
        present(text, about: display, placed: placed)
    }

    private func hide(after duration: Duration) {
        hideTask?.cancel()
        let time = services.time
        hideTask = Task { [weak self] in
            do { try await time.sleep(for: duration) } catch { return }
            self?.hide()
        }
    }

    /// "Preparing…" stays until no display it is about is preparing, or `HUDPolicy.preparingLimit` passed; then the
    /// level reached shows for 1.5 s.
    private func waitUntilReady(_ change: LevelChange, about display: DisplayKey?, placed: DisplayKey?) {
        let boost = services.boost
        let scope = change.display
        readyObservation = OverbrightCore.observe({ HUDPolicy.isPreparing(boost.status, display: scope) }) {
            [weak self] preparing in
            if !preparing { self?.showReached(change, about: display, placed: placed) }
        }
        hideTask?.cancel()
        let time = services.time
        hideTask = Task { [weak self] in
            do { try await time.sleep(for: HUDPolicy.preparingLimit) } catch { return }
            self?.showReached(change, about: display, placed: placed)
        }
    }

    /// The level a turn-on reached, in place of its "Preparing…", for 1.5 s.
    private func showReached(_ change: LevelChange, about display: DisplayKey?, placed: DisplayKey?) {
        readyObservation?.cancel()
        readyObservation = nil
        hideTask?.cancel()
        guard visible != nil, lastShown == change.sequence else { return }  // closed, or a newer change took over
        let status = services.boost.status
        let reached = LevelChange(sequence: change.sequence, kind: .level, source: change.source, display: change.display)
        guard let text = makeText(reached, status, display) else {
            hide()
            return
        }
        services.announcer.announce(text.announcement, kind: .feedback)
        show(text, about: display, placed: placed)
        hide(after: HUDPolicy.levelDuration)
    }

    // MARK: Window

    private func present(_ text: HUDText, about display: DisplayKey?, placed: DisplayKey?) {
        guard presentsWindows,
              let frame = HUDPlacement.currentFrame(size: HUDPlacement.size, display: placed, services: services) else {
            return
        }
        let status = services.boost.status
        let level = HUDContent.level(of: display, status: status, services: services)
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
}
