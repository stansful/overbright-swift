// OverbrightTriggers/Assets/HLGStillAsset.swift — our own tiny HLG still for T4: generated at run time, verified by
// read-back, cached under a versioned name and moved into place atomically. ARCHITECTURE.md §4.7 ("HLG still asset"),
// §8.2 (Caches), D4. Thread: off the main actor (`@concurrent`); touches files only, never the display.
//
// No binary asset is in the repo: the clip is made from scratch (BT.2020 primaries, BT.2100 HLG transfer, BT.2020
// matrix, 10-bit, 16 × 16 px, one frame, about 1 KB) by `encode(_:into:)` in HLGStillAsset+Encoding.swift and checked
// by `inspect(_:)` in HLGStillReport.swift. HEVC Main10 is tried first, ProRes 422 (a software encoder on every Mac)
// second [VERIFIED: 24/24 codec × level × size combinations, also with the software HEVC encoder].
//
// Errors are logged with a path-free summary in `.public` and their description (which can hold the cache path, i.e.
// the user's home folder name) in `.private` only (§9.2 rule 8). Temporaries a crash left mid-encode are swept on
// the next call.
import Darwin
import Foundation
import OverbrightCore
import os

/// Generation, verification and caching of the T4 still.
nonisolated enum HLGStillAsset {
    /// The codecs, in the order they are tried.
    nonisolated enum Codec: String, CaseIterable, Codable, Sendable {
        /// HEVC Main10 (`hvc1`): the smallest file; needs a 10-bit HEVC encoder (all Apple silicon).
        case hevcMain10
        /// Apple ProRes 422 (`apcn`, 10-bit 4:2:2): a software encoder on every Mac; a larger file.
        case proRes422

        /// The sample description's codec FourCC.
        var fourCC: String {
            switch self {
            case .hevcMain10: "hvc1"
            case .proRes422: "apcn"
            }
        }
    }

    /// The flat grey the frame shows.
    nonisolated enum Level: String, CaseIterable, Codable, Sendable {
        case black, sdrWhite, peak

        /// The level for a trigger pixel: black → black, SDR white → HLG reference white, 1.6 → HLG peak (the
        /// ladder's "T4 at peak" rung, §4.7).
        init(_ pixel: TriggerPixel) {
            switch pixel {
            case .black: self = .black
            case .sdrWhite: self = .sdrWhite
            case .bright: self = .peak
            }
        }

        /// The 10-bit narrow-range luma code. HLG reference white is 75 % signal (ITU-R BT.2408): 64 + 0.75 × 876 ≈ 721.
        var lumaCode: UInt16 {
            switch self {
            case .black: 64
            case .sdrWhite: 721
            case .peak: 940
            }
        }
    }

    /// What to generate.
    nonisolated struct Spec: Hashable, Codable, Sendable {
        /// The codec.
        var codec: Codec = .hevcMain10
        /// The grey level.
        var level: Level = .black
        /// The frame's edge in pixels (any decoder handles 16).
        var edge: Int = 16
        /// Versioned, so a format change never reuses a stale cache entry: `hlg-still-v1-<codec>-<level>-<edge>.mov`.
        var fileName: String { "hlg-still-v1-\(codec.rawValue)-\(level.rawValue)-\(edge).mov" }
    }

    /// Why a still could not be made. The `String` payloads are writer error descriptions and may hold paths: log
    /// them `.private` only.
    nonisolated enum Failure: Error, Sendable {
        case cannotAddInput
        case pixelBuffer
        case startFailed(String)
        case appendFailed(String)
        case finishFailed(String)
        case noVideoTrack
        case verificationFailed(HLGStillReport)
        case moveFailed(Int32)
        /// One path-free "<codec>: <summary>" entry per codec tried.
        case allCodecsFailed([String])

        /// The case name and its numbers, without any description or path: safe for a `.public` log.
        var publicSummary: String {
            switch self {
            case .cannotAddInput: "cannotAddInput"
            case .pixelBuffer: "pixelBuffer"
            case .startFailed: "startFailed"
            case .appendFailed: "appendFailed"
            case .finishFailed: "finishFailed"
            case .noVideoTrack: "noVideoTrack"
            case .verificationFailed: "verificationFailed"
            case .moveFailed(let code): "moveFailed(errno \(code))"
            case .allCodecsFailed(let failures): "allCodecsFailed(\(failures.joined(separator: "; ")))"
            }
        }
    }

    /// Temporaries (`.<UUID>.mov`) older than this are left over from a crash mid-encode and are removed. Younger ones
    /// may belong to a generation running now (another level, or another process) and are kept.
    static let staleTemporaryAge: TimeInterval = 5 * 60

    private static let log = Log.logger(.trigger)

    /// A verified still in `directory` (created if needed), generated on first use. A cached file is re-verified
    /// and used when it satisfies its spec; otherwise each codec of `codecs` is tried in order: the clip is encoded
    /// to a temporary name next to the final one, verified by read-back, then renamed over the final name in one
    /// atomic step, so a half-written or unverified file is never used and a corrupt one is replaced.
    @concurrent
    static func ensureCached(level: Level, edge: Int = 16, codecs: [Codec] = Codec.allCases,
                             in directory: URL) async throws -> (url: URL, report: HLGStillReport) {
        let fm = FileManager.default
        try fm.createDirectory(at: directory, withIntermediateDirectories: true)
        sweepStaleTemporaries(in: directory)
        var failures: [String] = []
        for codec in codecs {
            let spec = Spec(codec: codec, level: level, edge: edge)
            let destination = directory.appending(path: spec.fileName, directoryHint: .notDirectory)
            if fm.fileExists(atPath: destination.path), let report = try? await inspect(destination),
               report.satisfies(spec) {
                return (destination, report)
            }
            let temporary = directory.appending(path: temporaryName(), directoryHint: .notDirectory)
            do {
                try await encode(spec, into: temporary)
                let report = try await inspect(temporary)
                guard report.satisfies(spec) else { throw Failure.verificationFailed(report) }
                try moveAtomically(temporary, over: destination)
                log.info("HLG still generated: \(spec.fileName, privacy: .public), \(report.fileBytes) bytes")
                return (destination, report)
            } catch {
                try? fm.removeItem(at: temporary)
                let summary = LoggedError.publicSummary(error), detail = String(describing: error)
                log.error("HLG still \(spec.fileName, privacy: .public) failed: \(summary, privacy: .public) (\(detail, privacy: .private))")
                failures.append("\(codec.rawValue): \(summary)")
            }
        }
        throw Failure.allCodecsFailed(failures)
    }

    /// A fresh temporary file name: `.<UUID>.mov` (hidden, never a still's name).
    static func temporaryName() -> String { ".\(UUID().uuidString).mov" }

    /// Whether `name` is one of our temporary names.
    static func isTemporaryName(_ name: String) -> Bool {
        guard name.hasPrefix("."), name.hasSuffix(".mov") else { return false }
        return UUID(uuidString: String(name.dropFirst().dropLast(4))) != nil
    }

    /// Removes our temporaries in `directory` last modified before `now - staleTemporaryAge` (left by a crash
    /// mid-encode). Nothing else in the folder is touched; a file that cannot be read or removed is skipped.
    static func sweepStaleTemporaries(in directory: URL, now: Date = Date()) {
        let fm = FileManager.default
        guard let names = try? fm.contentsOfDirectory(atPath: directory.path) else { return }
        let cutoff = now.addingTimeInterval(-staleTemporaryAge)
        for name in names where isTemporaryName(name) {
            let url = directory.appending(path: name, directoryHint: .notDirectory)
            guard let modified = (try? fm.attributesOfItem(atPath: url.path))?[.modificationDate] as? Date,
                  modified < cutoff else { continue }
            do {
                try fm.removeItem(at: url)
                log.info("Removed a stale HLG still temporary")
            } catch {
                log.error("Stale HLG still temporary not removed: \(LoggedError.publicSummary(error), privacy: .public)")
            }
        }
    }

    /// `rename(2)`: replaces `destination` (a corrupt file included) in one step, or fails and leaves it as it was.
    static func moveAtomically(_ source: URL, over destination: URL) throws {
        let result = source.withUnsafeFileSystemRepresentation { from in
            destination.withUnsafeFileSystemRepresentation { to -> Int32 in
                guard let from, let to else { return -1 }
                return Darwin.rename(from, to)
            }
        }
        guard result == 0 else { throw Failure.moveFailed(errno) }
    }
}
