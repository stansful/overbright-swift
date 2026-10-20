// OverbrightAppShell/HUD/HUDController.swift — the on-screen level indicator. ARCHITECTURE.md §4.9 (`status.lastChange`
// by its increasing `sequence`), §7.6; DESIGN.md §6 (when, where, how long; never two), §12.9, §15; D19. Seam written by
// WP0a (§10.0): `init(services:)`, `start()` and `stop()` are fixed. The rules are `HUDPolicy`'s; a level change shows
// the level the display is set to, as value and bar (`HUDContent`), everything else Design's `HUDText`; the place is
// shared with the Keep-this-level prompt (`HUDSlot`). VoiceOver hears every qualifying change even when the window does
// not show (the setting is off, or the prompt holds the place). A change to every display shows on the display under
// the pointer. "Preparing…" stays up until the display is ready (at most 3 s), then the level reached shows for 1.5 s.
// While it shows, the HUD follows the engine's status, not the moment of the change: its words, its bar and the bar's
// warmth are re-read whenever what they show changes (a boost that reaches the screen after the shortcut warms the bar,
// a top that moves changes Max's value), in place, with no new announcement or showing and the same timer (WP14
// OBS-QA-HUD-TEXT). Its timers are one `TimeSource.sleep` per showing (no repeating timer, DESIGN.md §17), and the wait
// for a ready display and the following observe the engine's status instead of polling it, only while the HUD shows.
// The window keeps one hosting view and container, made on its first showing and again only when the material
// changes: every redraw and every later showing hands it a new root (no new view, no frame unless it moved, no fade
// while it shows). Hidden, the window keeps that view, as it always kept its last one: releasing it after each fade
// cost a new view, container and first render per showing for no measurable footprint (energy U2).
import AppKit
import OverbrightCore
import OverbrightDesign
import os
import SwiftUI

private let log = Log.logger(.panel)

/// Shows the HUD for level changes from shortcuts, intents, Focus and Back to Standard, "Preparing…" and automation
/// stops.
final class HUDController {
    /// What the HUD draws: its words, the level its bar shows and whether the bar's boost fill is warm.
    struct Drawing: Equatable {
        /// The words.
        var text: HUDText
        /// The level the bar shows (for a reason, the window shows the line instead of the bar).
        var level: LevelPosition
        /// Extra light is on screen on the display (DESIGN.md §2.1: the bar's boost fill is warm only then).
        var isBoosting: Bool
    }

    private let services: OverbrightServices
    private let slot: HUDSlot
    private let makeText: (LevelChange, BoostStatus, DisplayKey?) -> HUDText?
    private var observation: ObservationToken?
    private var readyObservation: ObservationToken?
    /// Follows the status while the HUD shows (nil while hidden or while "Preparing…" waits for the display).
    private var following: ObservationToken?
    private var window: HUDWindow?
    /// The window's hosting view, kept across showings (nil before the first).
    private var hosting: NSHostingView<HUDRoot>?
    /// The material of the hosting view's container (a change of the accessibility options makes a new one).
    private var hostingMaterial: PanelContainer.Material?
    private var hideTask: Task<Void, Never>?

    /// Tests turn windows off: the controller then decides and records, but orders nothing in (and asks no screen
    /// where the pointer is).
    var presentsWindows = true
    /// The sequence of the last change handled.
    private(set) var lastShown: UInt64?
    /// What the HUD draws now (nil while hidden).
    private(set) var drawn: Drawing?
    /// What the HUD says now (nil while hidden).
    var visible: HUDText? { drawn?.text }
    /// Number of showings (a new change while visible updates it and counts again).
    private(set) var showCount = 0
    /// Hosting views made so far: one for the window, and another only when the container's material changes.
    private(set) var hostingViewsMade = 0

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
        guard let drawing = drawing(of: change, status: status, about: display) else { return }
        services.announcer.announce(drawing.text.announcement, kind: presentation.announcement)
        readyObservation?.cancel()
        readyObservation = nil
        following?.cancel()
        following = nil
        guard presentation.showsWindow, slot.claim(.hud, onEvicted: { [weak self] in self?.hide() }) else { return }
        let placed = change.display ?? pointer
        show(drawing, placed: placed)
        if case .preparing = change.kind, HUDPolicy.isPreparing(status, display: change.display) {
            waitUntilReady(change, about: display, placed: placed)
        } else {
            follow(change, about: display, placed: placed)
            hide(after: presentation.duration)
        }
    }

    /// Closes the HUD now.
    func hide() {
        hideTask?.cancel()
        hideTask = nil
        readyObservation?.cancel()
        readyObservation = nil
        following?.cancel()
        following = nil
        drawn = nil
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

    private func show(_ drawing: Drawing, placed: DisplayKey?) {
        drawn = drawing
        showCount += 1
        present(drawing, placed: placed)
    }

    /// What `change` draws about `display` over `status`: the words, the bar's level and its warmth.
    private func drawing(of change: LevelChange, status: BoostStatus, about display: DisplayKey?) -> Drawing? {
        makeText(change, status, display).map { text in
            Drawing(text: text, level: HUDContent.level(of: display, status: status, services: services),
                    isBoosting: Self.isBoosting(display, status: status))
        }
    }

    /// Keeps the visible HUD of `change` on the status now (the engine's status and the settings its words read):
    /// redrawn in place whenever what it draws changes, until it hides or a newer change takes over.
    private func follow(_ change: LevelChange, about display: DisplayKey?, placed: DisplayKey?) {
        following?.cancel()
        let boost = services.boost
        following = OverbrightCore.observe({ [weak self] in
            self?.drawing(of: change, status: boost.status, about: display)
        }) { [weak self] drawing in
            guard let self, let drawing, drawn != nil, lastShown == change.sequence, drawing != drawn else { return }
            drawn = drawing
            present(drawing, placed: placed)
        }
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
        guard drawn != nil, lastShown == change.sequence else { return }  // closed, or a newer change took over
        let status = services.boost.status
        let reached = LevelChange(sequence: change.sequence, kind: .level, source: change.source, display: change.display)
        guard let drawing = drawing(of: reached, status: status, about: display) else {
            hide()
            return
        }
        services.announcer.announce(drawing.text.announcement, kind: .feedback)
        show(drawing, placed: placed)
        follow(reached, about: display, placed: placed)
        hide(after: HUDPolicy.levelDuration)
    }

    // MARK: Window

    /// Draws `drawing` on the display `placed`: redrawn in place while the HUD shows, faded in (`hudIn`) when it is
    /// hidden or fading out.
    private func present(_ drawing: Drawing, placed: DisplayKey?) {
        guard presentsWindows,
              let frame = HUDPlacement.currentFrame(size: HUDPlacement.size, display: placed, services: services) else {
            return
        }
        let window = preparedWindow(drawing, frame: frame)
        guard !window.isVisible || window.alphaValue < 1 else { return }  // shown: the new root is all it needs
        if !window.isVisible { window.alphaValue = 0 }
        window.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.18                                      // hudIn (DESIGN.md §3.1)
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window.animator().alphaValue = 1
        }
    }

    /// The HUD window drawing `drawing` at `frame`, not ordered in: the window's hosting view gets the new root (a
    /// hosting view and its container are made only when the window has none or the material changed), and the frame
    /// is set only when it changed. `present` fades it in; tests call this alone.
    func preparedWindow(_ drawing: Drawing, frame: CGRect,
                        material: PanelContainer.Material = PanelContainer.currentMaterial) -> HUDWindow {
        let window = self.window ?? HUDWindow(frame: frame, interactive: false)
        self.window = window
        let root = HUDRoot(drawing: drawing)
        if let hosting, hostingMaterial == material {
            hosting.rootView = root
        } else {
            let hosting = NSHostingView(rootView: root)
            self.hosting = hosting
            hostingMaterial = material
            hostingViewsMade += 1
            window.contentView = PanelContainer.make(around: hosting, material: material, cornerRadius: Radius.hud,
                                                     effect: .hudWindow)
        }
        if window.frame != frame { window.setFrame(frame, display: true) }
        return window
    }

    /// Extra light is on screen on `display`: the bar's boost fill is warm only then (DESIGN.md §2.1).
    static func isBoosting(_ display: DisplayKey?, status: BoostStatus) -> Bool {
        status.isOn && (status.displays.first { $0.key == display }?.appliedGain ?? 1) > 1
    }
}
