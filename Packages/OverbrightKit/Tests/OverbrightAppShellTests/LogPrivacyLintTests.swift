// OverbrightAppShellTests/LogPrivacyLintTests.swift — ARCHITECTURE.md §9.2 rule 8 over WP0b's paths (§10.2): an error's
// description can name the user's folders (a CocoaError's file path, the bundle the user moved), so it never reaches a
// `.public` log; such lines log the error's domain and code `.public` and the description `.private`. The scanned
// paths are the shell's launch helpers, login item and windows, Updates, HotKeys, SettingsUI and Onboarding.
import Foundation
import Testing

@Suite struct LogPrivacyLintTests {
    /// Packages/OverbrightKit.
    private static let package = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    /// WP0b's sources: folders, or single files in a folder shared with other packages.
    private static let scanned = [
        "Sources/OverbrightAppShell/Launch", "Sources/OverbrightAppShell/LoginItem",
        "Sources/OverbrightAppShell/Windows/SettingsWindowController.swift",
        "Sources/OverbrightAppShell/Windows/WelcomeWindowController.swift",
        "Sources/OverbrightUpdates", "Sources/OverbrightHotKeys", "Sources/OverbrightSettingsUI",
        "Sources/OverbrightOnboarding",
    ]

    /// (path, code lines with their numbers) of every Swift file under `scanned`; comment lines are left out.
    private func sources() -> [(path: String, lines: [(Int, String)])] {
        var urls: [URL] = []
        for entry in Self.scanned {
            let url = Self.package.appending(path: entry)
            if url.pathExtension == "swift" { urls.append(url); continue }
            guard let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: nil) else { continue }
            for case let file as URL in enumerator where file.pathExtension == "swift" { urls.append(file) }
        }
        return urls.compactMap { url in
            guard let text = try? String(contentsOf: url, encoding: .utf8) else { return nil }
            let code = text.components(separatedBy: "\n").enumerated().compactMap { index, line -> (Int, String)? in
                line.trimmingCharacters(in: .whitespaces).hasPrefix("//") ? nil : (index + 1, line)
            }
            return (String(url.path.dropFirst(Self.package.path.count + 1)), code)
        }
    }

    @Test func errorDescriptionsNeverReachAPublicLog() throws {
        let patterns = [#"\\\(\s*error[\w.]*\s*,\s*privacy:\s*\.public"#,
                        #"localizedDescription\s*,\s*privacy:\s*\.public"#,
                        #"describing:\s*error[^)]*\)\s*,\s*privacy:\s*\.public"#]
        let regexes = try patterns.map { try Regex($0) }
        // Each pattern finds its shape; the domain-and-code form passes.
        let samples = [#"failed: \(error, privacy: .public)"#, #"\(failure.localizedDescription, privacy: .public)"#,
                       #"\(String(describing: error), privacy: .public)"#]
        for (regex, sample) in zip(regexes, samples) { #expect(!sample.ranges(of: regex).isEmpty, "\(sample)") }
        let allowed = #"\(failure.domain, privacy: .public) (\(failure.localizedDescription, privacy: .private))"#
        #expect(regexes.allSatisfy { allowed.ranges(of: $0).isEmpty })
        let files = sources()
        #expect(files.count > 40, "the scan found \(files.count) files")
        let found = files.flatMap { file in
            file.lines.filter { _, line in regexes.contains { !line.ranges(of: $0).isEmpty } }.map { "\(file.path):\($0.0)" }
        }
        #expect(found.isEmpty, "error descriptions are logged .private only: \(found)")
    }
}
