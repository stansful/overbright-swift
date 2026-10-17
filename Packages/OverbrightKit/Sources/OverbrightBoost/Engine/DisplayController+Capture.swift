// OverbrightBoost/Engine/DisplayController+Capture.swift — the baseline capture before an arm or a dim, judged against the
// display's profile base. ARCHITECTURE.md §4.5 invariant 5, §4.8 (capture), D26. MainActor.
import Foundation
import OverbrightCore
import OverbrightPolicy

extension DisplayController {
    // MARK: Capture (§4.8)

    /// Reads the table and keeps it as the baseline when `BaselineRules` allows it. A scaled or invalid read does not
    /// arm: with `failsOnReject` the display fails as `foreignTableAtLaunch` (or `attributedDrift` once the conflict
    /// probe names an app). Our own write that is not the baseline (a re-base adopted a new base but could not write
    /// it yet) is never captured: the stored baseline stays.
    @discardableResult
    func captureBaseline(failsOnReject: Bool = true) -> Bool {
        let read: GammaTable
        do {
            read = try deps.gamma.read(ref.id)
        } catch {
            deps.journal.record("baseline.readFailed", display: key, time: deps.time, category: .gamma)
            return false
        }
        if isOwnStaleWrite(read) {
            deps.journal.record("baseline.keptOverOwnWrite", display: key, time: deps.time)
            return true
        }
        let expected = deps.gamma.profileBase(of: ref.id, count: read.count)
        switch BaselineRules.capture(read, expectedBase: expected, previous: baseline) {
        case .accept(let foreign):
            baseline = read
            expectedBase = expected
            if foreign { deps.journal.record("baseline.foreign", display: key, time: deps.time) }
            return true
        case .reject(let tableClass):
            var values: [String: Double] = [:]
            if case .scaled(let ratio?) = tableClass { values["ratio"] = ratio }
            deps.journal.record("baseline.rejected", display: key, values: values, time: deps.time)
            if failsOnReject { failForForeignTable() }
            return false
        }
    }

    /// `failed(foreignTableAtLaunch)` now; `failed(attributedDrift(app))` if the conflict probe names a writer.
    func failForForeignTable() {
        fail(.foreignTableAtLaunch)
        let stamp = generation
        checkSlot.run { [weak self] in
            guard let self, let app = await self.deps.conflicts.attributeDrift(), self.isCurrent(stamp),
                  self.trip == .foreignTableAtLaunch else { return }
            self.trip = .attributedDrift(app)
            self.phase = .failed(.attributedDrift(app))
            self.notify(needsReduction: true)
        }
    }
}
