// OverbrightBoost/Safety/OnlineDisplays.swift — the online displays as CoreGraphics lists them (read-only).
// ARCHITECTURE.md §7.4 (the launch check reads every online display). Thread: main (called by `LaunchRescue`).
import CoreGraphics
import OverbrightCore

/// Where `LaunchRescue` finds the online displays when the composition root does not pass its own list.
enum OnlineDisplays {
    /// The most displays CoreGraphics is asked for (more than any Mac drives).
    static let capacity: UInt32 = 32

    /// Every online display CoreGraphics knows, mirror members included (each has its own table). A read-only query:
    /// nothing is written and no display state changes.
    static func coreGraphics() -> [DisplayRef] {
        var ids = [CGDirectDisplayID](repeating: 0, count: Int(capacity))
        var count: UInt32 = 0
        guard CGGetOnlineDisplayList(capacity, &ids, &count) == .success else { return [] }
        return ids.prefix(Int(count)).compactMap { id in DisplayKey.of(id).map { DisplayRef(key: $0, id: id) } }
    }
}
