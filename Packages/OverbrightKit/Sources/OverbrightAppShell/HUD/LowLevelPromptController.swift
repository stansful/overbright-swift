// OverbrightAppShell/HUD/LowLevelPromptController.swift — "Keep this level?". ARCHITECTURE.md §4.9 (the engine
// publishes `status.pendingLowLevel` and reverts at its deadline by itself), §7.6; DESIGN.md §6 (in the HUD's place on
// that display; "Going back in 10 s" counting down; [Go Back] [Keep]; Return = Keep, Esc = Go Back; excluded from
// capture; VoiceOver hears "Keep this level? Going back in 10 seconds."), §12.9. Seam written by WP0a (§10.0):
// `init(services:)`, `start()` and `stop()` are fixed. The countdown is one `TimeSource.sleep` per second while shown.
import AppKit
import OverbrightCore
import OverbrightDesign
import os
import SwiftUI

private let log = Log.logger(.panel)

/// Shows the Keep-this-level prompt while the engine has a pending low-level confirmation.
final class LowLevelPromptController {
    private let services: OverbrightServices
    private let slot: HUDSlot
    private var observation: ObservationToken?
    private var window: HUDWindow?
    private var countdown: Task<Void, Never>?

    /// Tests turn windows off: the controller then decides and records, but orders nothing in.
    var presentsWindows = true
    /// The confirmation the prompt shows now (nil while hidden).
    private(set) var shown: LowLevelConfirmation?
    /// The countdown the prompt shows.
    let model = LowLevelPromptModel()
    /// The seconds the prompt shows now.
    var secondsLeft: Int { model.secondsLeft }

    /// A controller for the app's services.
    convenience init(services: OverbrightServices) { self.init(services: services, slot: .shared) }

    /// A controller with its own slot (tests).
    init(services: OverbrightServices, slot: HUDSlot) {
        self.services = services
        self.slot = slot
    }

    /// Starts observing `status.pendingLowLevel` (a pending confirmation shows at once).
    func start() {
        guard observation == nil else { return }
        let boost = services.boost
        update(boost.status.pendingLowLevel)
        observation = OverbrightCore.observe({ boost.status.pendingLowLevel }) { [weak self] pending in
            self?.update(pending)
        }
    }

    /// Stops observing and closes the prompt.
    func stop() {
        observation?.cancel()
        observation = nil
        update(nil)
    }

    /// Keep (Return): confirms the level.
    func keep() {
        services.boost.keepLowLevel()
        update(nil)
    }

    /// Go Back (Esc): returns to the previous level now.
    func goBack() {
        services.boost.revertLowLevel()
        update(nil)
    }

    /// Shows, updates or closes the prompt for `pending`.
    func update(_ pending: LowLevelConfirmation?) {
        guard let pending else {
            close()
            return
        }
        guard pending != shown else { return }
        if let current = shown, current.display == pending.display, window?.isVisible ?? !presentsWindows {
            // The same display's level is still moving (a drag): restart the countdown in place, without ordering the
            // window front again, so the slider keeps the pointer and the panel stays open.
            shown = pending
            model.secondsLeft = Self.seconds(until: pending.deadline, now: services.time.wallClock)
            runCountdown(to: pending.deadline)
            return
        }
        shown = pending
        slot.claim(.prompt) { [weak self] in self?.close() }
        model.secondsLeft = Self.seconds(until: pending.deadline, now: services.time.wallClock)
        services.announcer.announce(LowLevelPromptText.announcement(model.secondsLeft), kind: .feedback)
        present(pending)
        runCountdown(to: pending.deadline)
    }

    /// Whole seconds left until `deadline` (rounded up, never negative).
    static func seconds(until deadline: Date, now: Date) -> Int {
        max(Int(deadline.timeIntervalSince(now).rounded(.up)), 0)
    }

    // MARK: Private

    private func runCountdown(to deadline: Date) {
        countdown?.cancel()
        let time = services.time
        countdown = Task { [weak self] in
            while !Task.isCancelled {
                do { try await time.sleep(for: .seconds(1)) } catch { return }
                guard let self, self.shown != nil else { return }
                self.model.secondsLeft = Self.seconds(until: deadline, now: time.wallClock)
                if self.model.secondsLeft == 0 { return }                // the engine reverts at the deadline
            }
        }
    }

    private func present(_ pending: LowLevelConfirmation) {
        guard presentsWindows,
              let frame = HUDPlacement.currentFrame(size: HUDPlacement.promptSize, display: pending.display,
                                                    services: services) else { return }
        let window = self.window ?? HUDWindow(frame: frame, interactive: true)
        window.onCancel = { [weak self] in self?.goBack() }
        self.window = window
        window.setFrame(frame, display: false)
        let view = LowLevelPromptView(model: model, keep: { [weak self] in self?.keep() },
                                      goBack: { [weak self] in self?.goBack() })
            .overbrightThemeRoot()
        window.contentView = PanelContainer.make(around: NSHostingView(rootView: view),
                                                 material: PanelContainer.currentMaterial, cornerRadius: Radius.hud,
                                                 effect: .hudWindow)
        window.makeKeyAndOrderFront(nil)
        log.info("keep-level prompt shown")
    }

    private func close() {
        countdown?.cancel()
        countdown = nil
        shown = nil
        slot.leave(.prompt)
        window?.orderOut(nil)
    }
}
