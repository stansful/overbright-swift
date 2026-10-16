// OverbrightDisplays/Monitor/DisplayMonitor.swift — the read-only `--monitor` loop. ARCHITECTURE.md §8.5, D20, D26;
// docs/HARDWARE-TEST.md (the `kill -9` test). Thread: main (NSScreen).
//
// The shell calls `run(interval:duration:output:)` for `--monitor` (the §10.0 seam) and quits when it returns. Every
// `interval` it prints one JSON line per online display (`MonitorLine`): the table's class against the profile base
// (D26) and its ratio, the table maximum and middle entry, and the current, potential and reference headroom. It
// starts no service, opens no window and NEVER writes: it only calls `GammaPort`'s capacity, read and profile-base
// reads (test `DisplayMonitorTests`: fake ports, no write and no restore; plus a source scan of this folder).
import CoreGraphics
import Foundation
import OverbrightCore
import OverbrightPolicy

/// Prints the state of every display until Ctrl-C or `duration`.
public enum DisplayMonitor {
    /// Writes one line per display through `output` every `interval`, for `duration` (nil: until the process is
    /// interrupted), reading the real displays (read-only).
    public static func run(interval: Duration, duration: Duration?, output: (String) -> Void) async {
        let time = SystemTimeSource()
        let gamma = CoreGraphicsGamma()
        let headroom = SystemHeadroomPort(time: time)
        await run(gamma: gamma, headroom: headroom, time: time, interval: interval, duration: duration,
                  displays: { liveDisplays() }, output: output)
    }

    /// The loop over any ports (tests pass fakes). The first lines print at once; a line is printed while less than
    /// `duration` has passed; cancellation ends the loop.
    static func run(gamma: any GammaPort, headroom: any HeadroomPort, time: any TimeSource, interval: Duration,
                    duration: Duration?, displays: () -> [DisplayRef], output: (String) -> Void) async {
        let start = time.now
        while !Task.isCancelled {
            let elapsed = time.now - start
            if let duration, elapsed >= duration { return }
            for display in displays() {
                output(line(for: display, gamma: gamma, headroom: headroom, seconds: elapsed.timeInterval).json)
            }
            do { try await time.sleep(for: interval) } catch { return }
        }
    }

    /// One display's line now.
    static func line(for display: DisplayRef, gamma: any GammaPort, headroom: any HeadroomPort,
                     seconds: Double) -> MonitorLine {
        MonitorLine(seconds: seconds, display: display, table: table(of: display.id, gamma: gamma),
                    reading: headroom.reading(for: display))
    }

    /// The table read back and judged against the profile base (read-only).
    static func table(of id: CGDirectDisplayID, gamma: any GammaPort) -> MonitorLine.Table {
        guard gamma.capacity(of: id) > 0 else { return .none }
        do {
            let table = try gamma.read(id)
            let base = gamma.profileBase(of: id, count: table.count)
            let middle = table.count > 0 ? Double(table.green[table.count / 2]) : 0
            return .read(tableClass: TableClassifier.classify(table, expectedBase: base),
                         maximum: Double(table.maximum), middle: middle, entries: table.count)
        } catch {
            return .failed(String(describing: error))
        }
    }

    /// The online displays with a UUID (CoreGraphics only: no NSScreen or IORegistry work per tick).
    private static func liveDisplays() -> [DisplayRef] {
        CoreGraphicsDisplayReader.onlineIDs().compactMap { id in DisplayKey.of(id).map { DisplayRef(key: $0, id: id) } }
    }
}
