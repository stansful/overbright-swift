// OverbrightSettingsUI/Calibration/ComparisonSequence.swift — step 1's sequence of the calibration window (DESIGN.md
// §9, §15): once the session is ready, the display under test shows Brighter and Standard three times each, at most
// one change per 1.5 s (§3.4). `CalibrationModel` owns it and does each change (the session's comparison and the
// VoiceOver announcement of the label); this type only paces them on `TimeSource`, so manual time drives the tests.
import Foundation
import Observation
import OverbrightCore

/// Step 1's changes between Standard and Brighter.
@Observable final class ComparisonSequence {
    /// The sequence runs (Show Again waits for it).
    private(set) var isRunning = false
    /// Changes shown in the current sequence (Brighter, Standard, … six in all); the answers wait for the first.
    private(set) var flips = 0
    @ObservationIgnored private var task: Task<Void, Never>?

    /// Brighter and Standard three times each.
    static let flipsPerSequence = 6
    /// At most one change per 1.5 s (DESIGN.md §3.4, §9).
    static let flipInterval: Duration = .milliseconds(1500)
    /// How often the sequence looks whether the session is ready (it shows a trigger and waits for extra range first).
    static let readinessPoll: Duration = .milliseconds(100)

    /// Starts the sequence over: waits while `isPreparing()`, then calls `show` for each change, Brighter first
    /// (`true`) and `flipInterval` apart. `show` returns false when the step moved on, which ends the sequence.
    func start(time: any TimeSource, isPreparing: @escaping @MainActor () -> Bool,
               show: @escaping @MainActor (_ brighter: Bool) -> Bool) {
        stop()
        flips = 0
        isRunning = true
        task = Task { [weak self] in
            do {
                while isPreparing() { try await time.sleep(for: Self.readinessPoll) }
                for flip in 0..<Self.flipsPerSequence {
                    if flip > 0 { try await time.sleep(for: Self.flipInterval) }
                    guard let self, show(flip.isMultiple(of: 2)) else { return }
                    self.flips = flip + 1
                }
            } catch {
                return                                                   // cancelled
            }
            self?.isRunning = false
        }
    }

    /// Ends the sequence where it is.
    func stop() {
        task?.cancel()
        task = nil
        isRunning = false
    }
}
