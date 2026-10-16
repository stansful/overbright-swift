// OverbrightTriggers/Assets/HLGStillCache.swift — the factory's view of the HLG stills: one generation per level at a
// time, verified once per launch. ARCHITECTURE.md §4.7 ("HLG still asset"), §8.2 (Caches), §9.2 rule 8 (an error's
// description, which can hold the cache path, is logged `.private` only). Thread: main; the work runs in
// `HLGStillAsset.ensureCached`, off the main actor.
import Foundation
import OverbrightCore
import os

private let log = Log.logger(.trigger)

/// Verified stills in one cache folder (`~/Library/Caches/app.overbright.Overbright/` in the app, a temporary folder
/// in tests). Nothing happens until a T4 trigger presents (zero work while off, D22).
final class HLGStillCache {
    /// The folder the stills live in.
    let directory: URL
    /// The codecs tried, in order.
    let codecs: [HLGStillAsset.Codec]
    /// Number of generations started (each verifies or makes one still).
    private(set) var generations = 0
    private var verified: [HLGStillAsset.Level: URL] = [:]
    private var inFlight: [HLGStillAsset.Level: Task<URL?, Never>] = [:]

    init(directory: URL, codecs: [HLGStillAsset.Codec] = HLGStillAsset.Codec.allCases) {
        self.directory = directory
        self.codecs = codecs
    }

    /// The verified still for `level`, generating it on first use; nil when no codec produced a valid clip. Two
    /// triggers asking at once share one generation, so they never race for the same file.
    func url(for level: HLGStillAsset.Level) async -> URL? {
        if let url = verified[level], FileManager.default.fileExists(atPath: url.path) { return url }
        verified[level] = nil
        if let task = inFlight[level] { return await task.value }
        generations += 1
        let task = Task { [directory, codecs] () -> URL? in
            do {
                return try await HLGStillAsset.ensureCached(level: level, codecs: codecs, in: directory).url
            } catch {
                let summary = LoggedError.publicSummary(error), detail = String(describing: error)
                log.error("No HLG still for \(level.rawValue, privacy: .public): \(summary, privacy: .public) (\(detail, privacy: .private))")
                return nil
            }
        }
        inFlight[level] = task
        let url = await task.value
        inFlight[level] = nil
        if let url { verified[level] = url }
        return url
    }
}
