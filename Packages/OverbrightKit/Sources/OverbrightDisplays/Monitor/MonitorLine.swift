// OverbrightDisplays/Monitor/MonitorLine.swift — one `--monitor` JSON line. ARCHITECTURE.md §8.5, D20, D26;
// docs/HARDWARE-TEST.md §0 step 5. Pure: formats values the monitor has already read.
import CoreGraphics
import Foundation
import OverbrightCore

/// One display's state at one instant, as a JSON object on one line.
nonisolated struct MonitorLine: Hashable, Sendable {
    /// What reading the table gave.
    enum Table: Hashable, Sendable {
        /// Read: its class against the profile base (D26), maximum and middle entry.
        case read(tableClass: TableClass, maximum: Double, middle: Double, entries: Int)
        /// No table (capacity 0).
        case none
        /// The read failed.
        case failed(String)
    }

    /// Seconds since the monitor started.
    var seconds: Double
    /// The display.
    var display: DisplayRef
    /// The table.
    var table: Table
    /// The display's EDR values; nil without its own screen.
    var reading: HeadroomReading?

    /// The JSON text: `t`, `key`, `id`, `class` (`matchesBase`, `scaled`, `foreign`, `invalid`, `noTable` or
    /// `unreadable`), `ratio` (scaled only; null when a clamped plateau hides it), `max`, `mid`, `entries`, `current`,
    /// `potential`, `reference` (null without a screen), `error` (unreadable only). Keys sorted; numbers rounded to
    /// 6 decimals.
    var json: String {
        var object: [String: Any] = ["t": Self.rounded(seconds), "key": display.key.rawValue, "id": Int(display.id),
                                     "current": reading.map { Self.rounded($0.current) } ?? NSNull(),
                                     "potential": reading.map { Self.rounded($0.potential) } ?? NSNull(),
                                     "reference": reading.map { Self.rounded($0.reference) } ?? NSNull()]
        switch table {
        case let .read(tableClass, maximum, middle, entries):
            object["class"] = Self.code(tableClass)
            object["max"] = Self.rounded(maximum)
            object["mid"] = Self.rounded(middle)
            object["entries"] = entries
            if case .scaled(let ratio) = tableClass { object["ratio"] = ratio.map(Self.rounded) ?? NSNull() }
        case .none:
            object["class"] = "noTable"
        case .failed(let message):
            object["class"] = "unreadable"
            object["error"] = message
        }
        guard let data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]),
              let text = String(data: data, encoding: .utf8) else { return "{}" }
        return text
    }

    /// The machine code of a table class (the same codes as `--diagnostics`).
    static func code(_ tableClass: TableClass) -> String {
        switch tableClass {
        case .matchesBase: "matchesBase"
        case .scaled: "scaled"
        case .foreign: "foreign"
        case .invalid: "invalid"
        }
    }

    private static func rounded(_ value: Double) -> Double {
        value.isFinite ? (value * 1_000_000).rounded() / 1_000_000 : 0
    }
}
