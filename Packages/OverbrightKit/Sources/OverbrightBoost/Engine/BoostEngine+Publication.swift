// OverbrightBoost/Engine/BoostEngine+Publication.swift — status publication: `status` changes only when what the UI
// reads changed, and a change of minor fields only (each display's reading, which places the allowed-now marker, and
// the applied gain while a ramp runs) is published at most every 250 ms. ARCHITECTURE.md §4.1, DESIGN.md §17 ("the
// allowed-now marker ≤ 4 Hz"). Nothing in the engine reads `status`: decisions and safety writes read the controllers,
// so no write waits for a publish. MainActor.
import Foundation
import OverbrightCore

extension BoostEngine {
    /// Republishes `status` when it changed. A change of minor fields only (`differsInMinorFieldsOnly`) waits for a
    /// trailing one-shot publish `minorPublishInterval` later, which carries whatever changed by then; any other change
    /// publishes at once with the latest minor values and takes the waiting publish with it.
    func publish() {
        guard !isApplying else { return }
        let next = currentStatus()
        guard next != status else { return }
        if Self.differsInMinorFieldsOnly(status, next) {
            armMinorPublish()
            return
        }
        assign(next)
    }

    /// Publishes now whatever changed, minor fields included (the stop: no task outlives it, §4.5 invariant 4).
    func publishNow() {
        let next = currentStatus()
        if next != status {
            assign(next)
        } else {
            minorPublishSlot.cancel()
        }
    }

    /// The status the engine would publish now.
    func currentStatus() -> BoostStatus {
        let now = time.wallClock
        let pausedUntil = settings[AutomationSettings.pausedUntil].flatMap { $0 > now ? $0 : nil }
        let statuses = displays.displays.compactMap { controllers[$0.ref.key]?.status() }
        return BoostStatus(isOn: isMasterOn, isReady: isReady, pausedUntil: pausedUntil, autoOffAt: autoOffAt,
                           displays: statuses, banner: lastDecision?.banner, symbol: symbol(), lastChange: lastChange,
                           pendingLowLevel: pendingLowLevel)
    }

    /// Whether `next` differs from `published` only in what may wait for the trailing publish: each display's reading
    /// and the grant learned from readings (`lastGrant`), and, while a display ramps (`ramping` or `disarming` in both),
    /// its applied gain and factor. Phase, target, decision, symbol, banner, `lastChange`, `pendingLowLevel`, on, ready,
    /// pause, auto-off and the display set are major.
    static func differsInMinorFieldsOnly(_ published: BoostStatus, _ next: BoostStatus) -> Bool {
        guard published.isOn == next.isOn, published.isReady == next.isReady,
              published.pausedUntil == next.pausedUntil, published.autoOffAt == next.autoOffAt,
              published.banner == next.banner, published.symbol == next.symbol,
              published.lastChange == next.lastChange, published.pendingLowLevel == next.pendingLowLevel,
              published.displays.count == next.displays.count else { return false }
        return zip(published.displays, next.displays).allSatisfy { majorPart(of: $0) == majorPart(of: $1) }
    }

    /// A display's status without its minor fields.
    static func majorPart(of display: DisplayStatus) -> DisplayStatus {
        var major = display
        major.lastReading = nil
        major.lastGrant = nil
        if display.phase == .ramping || display.phase == .disarming {
            major.appliedGain = 0
            major.appliedFactor = 0
        }
        return major
    }

    /// Publishes `next`; a waiting minor publish is no longer needed.
    private func assign(_ next: BoostStatus) {
        minorPublishSlot.cancel()
        status = next
        #if DEBUG
        publishCount += 1
        #endif
    }

    /// One trailing publish `minorPublishInterval` from now, unless one is already waiting.
    private func armMinorPublish() {
        guard !minorPublishSlot.isRunning else { return }
        minorPublishSlot.run { [weak self] in
            guard let self else { return }
            do { try await self.time.sleep(for: EngineTiming.minorPublishInterval) } catch { return }
            let next = self.currentStatus()
            if next != self.status { self.assign(next) }
        }
    }
}
