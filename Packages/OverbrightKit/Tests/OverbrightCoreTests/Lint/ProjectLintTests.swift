// OverbrightCoreTests/Lint/ProjectLintTests.swift — the Xcode project's build settings that scripts/check-modules.sh
// cannot see (ARCHITECTURE.md §8.6): the app target (App/, its intent adapters) and the dormant Controls extension
// (Controls/, Shared/) compile only in the Xcode build, so zero warnings has to be a setting of theirs; and a Debug
// build links its binary once, so the App Intents metadata is always extracted (§7.7, scripts/smoke.sh); and the
// update check's repository is a build setting a release can set (D2).
import Foundation
import Testing

@Suite struct ProjectLintTests {
    /// The object IDs of §8.6: the app target's and the extension's Debug and Release configurations.
    private static let appDebug = "0B21E7000000000000000061", appRelease = "0B21E7000000000000000062"
    private static let controlsDebug = "0B21E7000000000000000081", controlsRelease = "0B21E7000000000000000082"

    private let project: String = {
        let url = SourceScan.repository.appending(path: "Overbright.xcodeproj/project.pbxproj")
        return (try? String(contentsOf: url, encoding: .utf8)) ?? ""
    }()

    /// §9.2: zero warnings in the code only the Xcode build compiles, in both configurations of both targets.
    @Test(arguments: [appDebug, appRelease, controlsDebug, controlsRelease])
    func warningsAreErrors(configuration: String) throws {
        let settings = try #require(Self.buildSettings(of: configuration, in: project), "\(configuration)")
        #expect(settings["SWIFT_TREAT_WARNINGS_AS_ERRORS"] == "YES", "\(configuration)")
        #expect(settings["GCC_TREAT_WARNINGS_AS_ERRORS"] == "YES", "\(configuration)")
    }

    /// §7.7: a Debug build that splits the binary into `<name>.debug.dylib` and `__preview.dylib` links twice into one
    /// dependency file, and when the preview dylib finishes last the App Intents extraction skips the intents and the
    /// Focus filter. Neither target has previews of its own, so neither splits.
    @Test(arguments: [appDebug, controlsDebug])
    func debugBuildsLinkOnce(configuration: String) throws {
        let settings = try #require(Self.buildSettings(of: configuration, in: project), "\(configuration)")
        #expect(settings["ENABLE_DEBUG_DYLIB"] == "NO", "\(configuration)")
    }

    /// D2, §8.6: the update check's repository comes from the build setting, empty in the project (no network), so
    /// `scripts/build.sh` can pass the one release.yml publishes from; a literal in Info.plist could not be set.
    @Test(arguments: [appDebug, appRelease])
    func updateRepositoryIsABuildSetting(configuration: String) throws {
        let settings = try #require(Self.buildSettings(of: configuration, in: project), "\(configuration)")
        #expect(settings["OVERBRIGHT_GITHUB_REPOSITORY"] == "", "\(configuration)")
        let plist = try String(contentsOf: SourceScan.repository.appending(path: "App/Info.plist"), encoding: .utf8)
        let entry = try NSRegularExpression(
            pattern: "<key>OverbrightGitHubRepository</key>\\s*<string>\\$\\(OVERBRIGHT_GITHUB_REPOSITORY\\)</string>")
        #expect(!SourceScan.matches(entry, in: plist).isEmpty, "App/Info.plist takes $(OVERBRIGHT_GITHUB_REPOSITORY)")
    }

    /// The parser reads one configuration's settings and nothing of the next one.
    @Test func buildSettingsParserReadsOneConfiguration() {
        let text = """
            \t\t0B21E7000000000000000061 /* Debug */ = {
            \t\t\tisa = XCBuildConfiguration;
            \t\t\tbuildSettings = {
            \t\t\t\tENABLE_DEBUG_DYLIB = NO;
            \t\t\t\tLD_RUNPATH_SEARCH_PATHS = (
            \t\t\t\t\t"$(inherited)",
            \t\t\t\t);
            \t\t\t\tOVERBRIGHT_GITHUB_REPOSITORY = "";
            \t\t\t};
            \t\t\tname = Debug;
            \t\t};
            \t\t0B21E7000000000000000062 /* Release */ = {
            \t\t\tbuildSettings = {
            \t\t\t\tSWIFT_TREAT_WARNINGS_AS_ERRORS = YES;
            \t\t\t};
            \t\t};
            """
        let settings = Self.buildSettings(of: Self.appDebug, in: text)
        #expect(settings == ["ENABLE_DEBUG_DYLIB": "NO", "OVERBRIGHT_GITHUB_REPOSITORY": ""])
        #expect(Self.buildSettings(of: Self.controlsDebug, in: text) == nil)
    }

    // MARK: Helpers

    /// The single-line settings (`NAME = value;`, quotes removed) of the configuration with `id`; nil without one.
    /// List values (`NAME = ( … );`) are left out.
    static func buildSettings(of id: String, in project: String) -> [String: String]? {
        let lines = project.components(separatedBy: "\n")
        guard let start = lines.firstIndex(where: { $0.hasPrefix("\t\t\(id) /*") }) else { return nil }
        var settings: [String: String] = [:]
        for line in lines[(start + 1)...] {
            if line.hasPrefix("\t\t}") { break }
            guard line.hasPrefix("\t\t\t\t"), !line.hasPrefix("\t\t\t\t\t"), line.hasSuffix(";"),
                  let equals = line.range(of: " = ") else { continue }
            let name = line[..<equals.lowerBound].trimmingCharacters(in: .whitespaces)
            var value = String(line[equals.upperBound...].dropLast())
            if value.hasPrefix("\""), value.hasSuffix("\""), value.count >= 2 { value = String(value.dropFirst().dropLast()) }
            settings[name] = value
        }
        return settings
    }
}
