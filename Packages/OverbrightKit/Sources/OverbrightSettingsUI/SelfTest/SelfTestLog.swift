// OverbrightSettingsUI/SelfTest/SelfTestLog.swift — the self-test log as a file (DESIGN.md §10 "Sharing"; ARCHITECTURE.md
// §8.2, §8.4): the `SelfTestReport` as pretty-printed JSON with sorted keys and ISO 8601 dates (what Copy puts on the
// clipboard and Save Log… writes), and the archive of the last ten logs in Application Support's SelfTest folder,
// named by their start time. Encoding and file work leave the main actor (§8.1 rule 3). The report holds display
// models, the macOS version and measurements; never files, window titles or app names.
import Foundation
import OverbrightCore

/// Encoding and keeping self-test logs.
public nonisolated enum SelfTestLog {
    /// How many logs the archive keeps (§8.2).
    static let kept = 10

    /// The report as JSON.
    @concurrent public static func encode(_ report: SelfTestReport) async throws -> Data {
        try data(report)
    }

    /// The report as JSON (synchronous, for callers already off the main actor).
    static func data(_ report: SelfTestReport) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(report)
    }

    /// "2026-10-16T142005Z.json": the archive name of a log started at `date` (no colons: Finder shows them as
    /// slashes).
    public static func fileName(startedAt date: Date) -> String {
        var style = Date.ISO8601FormatStyle(timeZone: .gmt)
        style = style.year().month().day().dateSeparator(.dash).time(includingFractionalSeconds: false).timeSeparator(.omitted)
        return date.formatted(style).replacingOccurrences(of: ":", with: "-") + ".json"
    }

    /// Saves `report` as JSON at `url` (Save Log…, through the app's Save panel).
    @concurrent public static func save(_ report: SelfTestReport, to url: URL) async throws {
        try data(report).write(to: url, options: .atomic)
    }

    /// Writes `report` into `folder` (created when missing) and removes the oldest logs beyond `kept`. Returns the
    /// file written.
    @concurrent @discardableResult
    static func archive(_ report: SelfTestReport, in folder: URL) async throws -> URL {
        let manager = FileManager.default
        try manager.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appending(path: fileName(startedAt: report.startedAt))
        try data(report).write(to: url, options: .atomic)
        let logs = try manager.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }
            .sorted { $0.lastPathComponent > $1.lastPathComponent }       // ISO names sort by time: newest first
        for old in logs.dropFirst(kept) { try? manager.removeItem(at: old) }
        return url
    }
}
