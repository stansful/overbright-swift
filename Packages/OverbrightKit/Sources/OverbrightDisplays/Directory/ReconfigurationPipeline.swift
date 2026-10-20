// OverbrightDisplays/Directory/ReconfigurationPipeline.swift — the timing of display reconfiguration (D9).
// ARCHITECTURE.md §4.3, §4.4 (`ReconfigurationPipeline.debounce`, `.confirmation`), §7.1, §10.4. Thread: main.
//
// One reconfiguration calls back once per online display with the begin flag, then once per added, removed and online
// display in the after phase. The pipeline turns that burst into:
// - **began**, once per burst (overlays go to factor 1; no display queries in the begin phase);
// - **removed(id)**, at once for every remove flag, never debounced (the display's trigger and overlay windows are
//   ordered out before AppKit can move them to another screen);
// - **settle(.debounced)** 0.5 s after the last after-phase callback, then **settle(.confirming)** 2 s after it (facts
//   that lag, such as NSScreen objects and IORegistry attributes, are read again). Any new callback restarts both.
// A begin phase that never gets an after phase settles by itself after `unfinishedBeginTimeout`, so overlays parked at
// factor 1 are never left there. Every wait is one `TimeSource.sleep` in one stored task (§8.1 rule 5).
import CoreGraphics
import OverbrightCore

/// Turns reconfiguration callbacks into began / removed / settle reactions.
final class ReconfigurationPipeline {
    /// Which settle pass runs.
    enum Pass: Hashable, Sendable {
        /// 0.5 s after the last after-phase callback.
        case debounced
        /// 2 s after the last after-phase callback.
        case confirming
    }

    /// The debounce of the after phase (D9).
    static let debounce: Duration = .milliseconds(500)
    /// The confirming pass, counted from the last after-phase callback (D9).
    static let confirmation: Duration = .seconds(2)
    /// A begin phase without any after phase settles after this long.
    static let unfinishedBeginTimeout: Duration = .seconds(5)

    /// The begin phase of a burst started (called once per burst).
    var onBegan: () -> Void = {}
    /// A display was removed (called at once, before any debounce).
    var onRemoved: (CGDirectDisplayID) -> Void = { _ in }
    /// A settle pass is due.
    var onSettle: (Pass) async -> Void = { _ in }

    /// A settle pass is scheduled or running: the displays may be in flux.
    private(set) var isPending = false

    private let time: any TimeSource
    private var task: Task<Void, Never>?
    private var isInBeginPhase = false

    /// A pipeline that waits on `time`.
    init(time: any TimeSource) { self.time = time }

    /// One callback: `flags` for `display`.
    func handle(display: CGDirectDisplayID, flags: CGDisplayChangeSummaryFlags) {
        switch ReconfigurationPhase(flags: flags) {
        case .began:
            guard !isInBeginPhase else { return }
            isInBeginPhase = true
            onBegan()
            schedule(after: Self.unfinishedBeginTimeout)
        case .removed:
            isInBeginPhase = false
            onRemoved(display)
            schedule(after: Self.debounce)
        case .changed:
            isInBeginPhase = false
            schedule(after: Self.debounce)
        }
    }

    /// Drops any scheduled pass (stop).
    func cancel() {
        task?.cancel()
        task = nil
        isPending = false
        isInBeginPhase = false
    }

    // MARK: Private

    private func schedule(after delay: Duration) {
        task?.cancel()
        isPending = true
        task = Task { [weak self, time] in
            do { try await time.sleep(for: delay) } catch { return }
            guard let self, !Task.isCancelled else { return }
            self.isInBeginPhase = false
            await self.onSettle(.debounced)
            do { try await time.sleep(for: Self.confirmation - Self.debounce) } catch { return }
            guard !Task.isCancelled else { return }
            await self.onSettle(.confirming)
            guard !Task.isCancelled else { return }
            self.isPending = false
            self.task = nil
        }
    }
}
