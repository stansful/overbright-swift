// OverbrightSettingsUI/SelfTest/SelfTestProgress.swift — where a running self-test is, per display (DESIGN.md §10:
// "Built-in Display · Tagged layer, black · 12 s" with a determinate progress bar per display), read from the
// diagnostics journal the runner writes as it goes (ARCHITECTURE.md §8.3: "selftest.<verdict>" with the rung's index
// after every rung, "selftest.noReading" for a display without a reading) and the time since the last of them. The
// displays are measured one after another in the order the sheet lists them. Pure (tested).
import Foundation
import OverbrightCore

/// The progress of one display.
nonisolated struct SelfTestProgress: Hashable, Sendable {
    /// The display.
    var display: DisplayKey
    /// 0 … 1.
    var fraction: Double
    /// The rung under test now; nil before the display starts and after it finished.
    var rung: SelfTestPlan.Rung?
    /// Whole seconds the current rung has run.
    var secondsInRung: Int
    /// Every rung the display needs is done (or the runner stopped at a rung that held).
    var isFinished: Bool

    /// The verdict codes the runner journals after each rung (`SelfTestStrategyResult.Verdict` raw values).
    static let verdictCodes: Set<String> = Set(["held", "engagedButDropped", "noEngage", "invalidBaseline", "skipped"]
        .map { "selftest." + $0 })

    /// The progress of `displays` (in measuring order) at monotonic `now`, from the journal `events` recorded since
    /// the run started at `since`. A rung is expected to take `secondsPerRung`.
    static func make(displays: [DisplayKey], plan: [SelfTestPlan.Rung], everyMethod: Bool, secondsPerRung: Double,
                     events: [JournalEvent], since: Double, now: Double) -> [SelfTestProgress] {
        let own = events.filter { $0.category == LogCategory.selfTest.rawValue && $0.seconds >= since }
        let lastEvent = own.map(\.seconds).max() ?? since
        let available = plan.indices.filter { plan[$0].isAvailable }
        var current: DisplayKey?
        return displays.map { display in
            let mine = own.filter { $0.display == display.rawValue }
            let done = Set(mine.filter { verdictCodes.contains($0.code) }.compactMap { $0.values["rung"].map(Int.init) })
            let stoppedAtHold = !everyMethod && mine.contains { $0.code == "selftest.held" || $0.code == "selftest.invalidBaseline" }
            let finished = mine.contains { $0.code == "selftest.noReading" } || stoppedAtHold
                || available.allSatisfy(done.contains)
            if finished {
                return SelfTestProgress(display: display, fraction: 1, rung: nil, secondsInRung: 0, isFinished: true)
            }
            guard current == nil else {
                return SelfTestProgress(display: display, fraction: 0, rung: nil, secondsInRung: 0, isFinished: false)
            }
            current = display
            let next = available.first { !done.contains($0) }
            let seconds = max(now - lastEvent, 0)
            let within = min(seconds / max(secondsPerRung, 1), 0.99)
            let completed = Double(available.filter(done.contains).count)
            return SelfTestProgress(display: display, fraction: min((completed + within) / Double(max(available.count, 1)), 1),
                                    rung: next.map { plan[$0] }, secondsInRung: Int(seconds.rounded(.down)),
                                    isFinished: false)
        }
    }
}
