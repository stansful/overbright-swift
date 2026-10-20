// OverbrightCore/Platform/Platform.swift — logging, haptics, file locations, version info. Ported from Cranny's
// CrannyCore/Platform/Platform.swift (the owner's MIT code) with the renames of ARCHITECTURE.md §10.1; Overbright's
// log categories (§8.3) and haptic patterns. ARCHITECTURE.md §3.1, §8.2, §8.3.
import AppKit
import Foundation
import os

// MARK: - Logging

/// One `Logger` category per area (Console: subsystem app.overbright.Overbright). ARCHITECTURE.md §8.3.
public nonisolated enum LogCategory: String, Sendable, CaseIterable {
    case app, settings, storage, updates, onboarding, displays, gamma, trigger, engine, policy, signals
    case fillLight, hotKeys, intents, menuBar, panel, diagnostics, selfTest
}

/// `private let log = Log.logger(.engine)` at file scope. Interpolate user data with `privacy: .private`
/// (display names, app names, paths); codes, states, counts and numbers with `privacy: .public`.
public nonisolated enum Log {
    /// The logging subsystem (also the bundle ID and the Application Support and Caches folder name, D1).
    public static let subsystem = "app.overbright.Overbright"
    /// A logger for `category`.
    public static func logger(_ category: LogCategory) -> Logger { Logger(subsystem: subsystem, category: category.rawValue) }
}

// MARK: - Haptics

/// The haptic patterns Overbright uses (the slider's detent and preset ticks).
public nonisolated enum HapticPattern: Sendable {
    /// The slider crosses the Standard detent.
    case alignment
    /// The slider crosses a preset tick.
    case levelChange
}

/// Never for hover or automatic changes. Every haptic has a visual counterpart.
@MainActor public final class Haptics {
    private let isEnabled: @MainActor () -> Bool
    /// Haptics that play only while `isEnabled()` (General ▸ Haptic feedback, `GeneralSettings.haptics`).
    public init(isEnabled: @escaping @MainActor () -> Bool) { self.isEnabled = isEnabled }
    /// Plays `pattern` now (felt only while a finger is on a Force Touch trackpad).
    public func play(_ pattern: HapticPattern) {
        guard isEnabled() else { return }
        let p: NSHapticFeedbackManager.FeedbackPattern = switch pattern {
        case .alignment: .alignment
        case .levelChange: .levelChange
        }
        NSHapticFeedbackManager.defaultPerformer.perform(p, performanceTime: .now)
    }
}

// MARK: - Files

/// ~/Library/Application Support/app.overbright.Overbright/ and ~/Library/Caches/app.overbright.Overbright/ — the
/// only places Overbright writes files (ARCHITECTURE.md §8.2).
public nonisolated struct AppPaths: Sendable {
    /// Application Support/app.overbright.Overbright: self-test logs (`selfTestFolder`).
    public let root: URL
    /// Caches/app.overbright.Overbright: rebuildable data (strategy cache, HLG stills, update cache).
    public let caches: URL
    /// Paths under explicit roots.
    public init(root: URL, caches: URL) { self.root = root; self.caches = caches }

    /// The self-test logs folder under `root` (§8.2).
    public static let selfTestFolder = "SelfTest"
    /// The update cache folder under `caches` (§8.2).
    public static let updatesFolder = "updates"

    /// The user's real folders (the app; never in tests or previews).
    public static let live: AppPaths = {
        let fm = FileManager.default
        let support = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fm.homeDirectoryForCurrentUser.appending(path: "Library/Application Support", directoryHint: .isDirectory)
        let caches = fm.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? fm.homeDirectoryForCurrentUser.appending(path: "Library/Caches", directoryHint: .isDirectory)
        return AppPaths(root: support.appending(path: Log.subsystem, directoryHint: .isDirectory),
                        caches: caches.appending(path: Log.subsystem, directoryHint: .isDirectory))
    }()

    /// A fresh throw-away root for tests and previews (nothing is created until first use).
    public static func temporary() -> AppPaths {
        let base = FileManager.default.temporaryDirectory.appending(path: "overbright-\(UUID().uuidString)", directoryHint: .isDirectory)
        return AppPaths(root: base.appending(path: "Support"), caches: base.appending(path: "Caches"))
    }
}

/// A Codable document on disk with a default value, for caches and indexes that can be rebuilt (the update cache, the
/// strategy cache). Built on `JSONDocumentFile`: a missing file reads as the default; a corrupt one is set aside under a
/// unique name and reads as the default; a file that exists but cannot be READ (permissions, I/O) also reads as the
/// default, but then every `save` throws `JSONFileStoreError.unreadableFile` instead of replacing it. Saves are
/// atomic and serialized by the actor in call order.
public actor JSONFileStore<Value: Codable & Sendable> {
    /// The document's location.
    public nonisolated var url: URL { file.url }
    private let file: JSONDocumentFile<Value>
    private let defaultValue: Value
    private var revision = 0
    private var unreadable = false

    /// A store for `url` that reads as `defaultValue` until something is saved. No I/O happens here.
    public init(url: URL, defaultValue: Value) {
        self.file = JSONDocumentFile(url: url)
        self.defaultValue = defaultValue
    }

    /// The saved value, or `defaultValue` (missing, corrupt or unreadable file; see the type's documentation).
    public func load() -> Value {
        do {
            switch try file.load() {
            case .loaded(let value): unreadable = false; return value
            case .missing, .corrupt: unreadable = false; return defaultValue
            }
        } catch {
            unreadable = true
            Log.logger(.storage).error("cannot read \(self.url.lastPathComponent, privacy: .public), keeping it: \(error.localizedDescription, privacy: .public)")
            return defaultValue
        }
    }

    /// Writes `value` atomically. Throws `JSONFileStoreError.unreadableFile` after a `load()` that could not read an
    /// existing file (it is kept, never replaced by a default), and any encoding or file-system error.
    public func save(_ value: Value) throws {
        guard !unreadable else { throw JSONFileStoreError.unreadableFile(url) }
        revision += 1
        try file.write(value, revision: revision)
    }
}

/// Why a `JSONFileStore` did not save.
public nonisolated enum JSONFileStoreError: Error, Equatable, Sendable {
    /// The last `load()` found the file but could not read it; saving would replace it.
    case unreadableFile(URL)
}

// MARK: - App info and versions

/// Identity and version of a bundle (About, diagnostics, the update check, self-test reports).
public nonisolated struct AppInfo: Sendable, Codable {
    /// The bundle identifier, "(none)" if missing.
    public let bundleIdentifier: String
    /// CFBundleShortVersionString ("0.1.0").
    public let version: String
    /// CFBundleVersion.
    public let build: String
    /// The info of `bundle` (the app by default).
    public static func current(_ bundle: Bundle = .main) -> AppInfo {
        AppInfo(bundleIdentifier: bundle.bundleIdentifier ?? "(none)",
                version: bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0",
                build: bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0")
    }
}

/// "v1.2" / "1.10.0" / "1.2.0-beta.1" (pre-release suffix sorts before the release).
public nonisolated struct SemanticVersion: Comparable, Sendable, CustomStringConvertible {
    /// The numeric components (missing ones are 0).
    public let major: Int, minor: Int, patch: Int
    /// The part after "-" ("beta.1"), nil for a release.
    public let prerelease: String?
    /// Parses "1", "1.2", "v1.2.3" or "1.2.3-beta.1"; nil for anything else.
    public init?(_ string: String) {
        var s = Substring(string)
        if s.hasPrefix("v") { s = s.dropFirst() }
        let parts = s.split(separator: "-", maxSplits: 1)
        let nums = parts.first.map { $0.split(separator: ".").map { Int($0) } } ?? []
        guard (1...3).contains(nums.count), nums.allSatisfy({ $0 != nil }) else { return nil }
        let n = nums.compactMap { $0 } + [0, 0]
        (major, minor, patch) = (n[0], n[1], n[2])
        prerelease = parts.count > 1 ? String(parts[1]) : nil
    }
    /// Numeric order; a pre-release sorts before its release, pre-releases compare numerically.
    public static func < (a: Self, b: Self) -> Bool {
        if (a.major, a.minor, a.patch) != (b.major, b.minor, b.patch) { return (a.major, a.minor, a.patch) < (b.major, b.minor, b.patch) }
        switch (a.prerelease, b.prerelease) {
        case (nil, _): return false
        case (_, nil): return true
        case let (x?, y?): return x.compare(y, options: .numeric) == .orderedAscending
        }
    }
    /// "1.2.3" or "1.2.3-beta.1".
    public var description: String { "\(major).\(minor).\(patch)" + (prerelease.map { "-\($0)" } ?? "") }
}
