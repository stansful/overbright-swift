// OverbrightBoostTests/Fakes/RecordingHeadroom.swift — a HeadroomPort that records every reading it hands out.
// ARCHITECTURE.md §9.1 (the interlock property: every write is backed by a reading of the same display at most
// 150 ms old with `G ≤ 0.97 × H`).
import OverbrightCore

/// Forwards to a `ScriptedHeadroom` and keeps every reading, so tests can check what the interlock saw.
@MainActor final class RecordingHeadroom: HeadroomPort {
    let scripted: ScriptedHeadroom
    private(set) var readings: [HeadroomReading] = []
    /// When set, every reading of this display is nil (a display that lost its own NSScreen).
    var blinded: Set<DisplayKey> = []

    init(_ scripted: ScriptedHeadroom) { self.scripted = scripted }

    func reading(for display: DisplayRef) -> HeadroomReading? {
        guard !blinded.contains(display.key), let reading = scripted.reading(for: display) else { return nil }
        readings.append(reading)
        if readings.count > 20_000 { readings.removeFirst(10_000) }
        return reading
    }

    func reset() { readings = [] }
}
