// OverbrightTriggersTests/TriggerModuleLintTests.swift — source scans for the module's own acceptance rules
// (ARCHITECTURE.md §10.5): no `.metal` file and no Metal library, function or pipeline API (D22); only the system
// presenter orders a window in, and no test can reach it (§9.1, D24); EDR layer properties stay in this module's
// strategy, surface and overlay files; only allowlisted values reach a `.public` log, so no error description does
// (§9.2 rule 8; the scan is `Support/PublicLogLint.swift`). API names are split in two here, so this file never matches
// its own scans.
import Foundation
import Testing

@Suite struct TriggerModuleLintTests {
    /// Packages/OverbrightKit.
    private static let package = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    private static let sources = package.appending(path: "Sources/OverbrightTriggers", directoryHint: .isDirectory)
    private static let tests = package.appending(path: "Tests/OverbrightTriggersTests", directoryHint: .isDirectory)

    /// (path relative to `root`, code lines with their numbers) of every file under `root` with `pathExtension`.
    private func files(under root: URL, pathExtension: String = "swift") -> [(path: String, lines: [(Int, String)])] {
        guard let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil) else { return [] }
        var found: [(String, [(Int, String)])] = []
        for case let url as URL in enumerator where url.pathExtension == pathExtension {
            guard let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
            let code = text.components(separatedBy: "\n").enumerated().compactMap { index, line -> (Int, String)? in
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                return trimmed.hasPrefix("//") ? nil : (index + 1, line)
            }
            found.append((String(url.path.dropFirst(root.path.count + 1)), code))
        }
        return found.sorted { $0.0 < $1.0 }
    }

    private func hits(_ needles: [String], in files: [(path: String, lines: [(Int, String)])],
                      except allowed: Set<String> = []) -> [String] {
        files.filter { !allowed.contains($0.path) }.flatMap { file in
            file.lines.filter { _, line in needles.contains(where: line.contains) }.map { "\(file.path):\($0.0)" }
        }
    }

    @Test func theModuleUsesNoShaderLibraryFunctionOrPipeline() {
        let api = ["make" + "DefaultLibrary", "make" + "Library", "make" + "Function", "make" + "RenderPipelineState",
                   "make" + "ComputePipelineState", "MTL" + "Library", "MTL" + "Function", "MTL" + "RenderPipeline",
                   "MTL" + "ComputePipeline", "new" + "DefaultLibrary", "new" + "Library", "new" + "Function",
                   "Shader" + "Library", "metal" + "lib"]
        let sources = files(under: Self.sources)
        #expect(sources.count > 15)
        #expect(sources.contains { $0.path == "Surfaces/MetalClearPass.swift" })
        let found = hits(api, in: sources)
        #expect(found.isEmpty, "a clear-only pass needs no library, function or pipeline (D22): \(found)")
        #expect(files(under: Self.sources, pathExtension: "metal").isEmpty)
    }

    @Test func onlyTheSystemPresenterOrdersAWindowIn() {
        let orderIn = ["order" + "Front", "makeKeyAndOrder" + "Front", "order" + "Back", "order" + "Window(",
                       "run" + "Modal"]
        let sources = files(under: Self.sources)
        let found = hits(orderIn, in: sources, except: ["Windows/System" + "WindowPresenter.swift"])
        #expect(found.isEmpty, "windows reach the screen only through the system presenter: \(found)")
        #expect(!hits(["order" + "FrontRegardless"], in: sources).isEmpty, "the presenter itself is scanned")
    }

    @Test func testsNeverReachTheRealPresenterOrScreens() {
        let real = ["System" + "WindowPresenter", "System" + "TriggerScreens", "Metal" + "ClearSurface(",
                    "TriggerEnvironment" + ".live", ".live(" + "time:", "SystemTriggerFactory(" + "time:",
                    "order" + "Front", "MTLCreate" + "SystemDefaultDevice"]
        let gated = "MetalClearPassTests.swift"   // OVERBRIGHT_HARDWARE only: an off-screen texture, no window
        let found = hits(real, in: files(under: Self.tests), except: [gated])
        #expect(found.isEmpty, "no test may put a window or an EDR request on screen: \(found)")
    }

    @Test func errorDescriptionsNeverReachAPublicLog() throws {
        // A description can hold a path (a CocoaError's NSFilePath): only allowlisted values go out `.public`, so a
        // description bound to a name first (`let detail = String(describing: error)`) is caught too.
        let sources = files(under: Self.sources)
        let found = try sources.flatMap { file in
            try PublicLogLint.violations(in: file.lines).map { "\(file.path):\($0)" }
        }
        #expect(found.isEmpty, "only LoggedError summaries, raw values, file names, IDs and counts go out .public: \(found)")
        #expect(sources.contains { $0.lines.contains { $0.1.contains("LoggedError.publicSummary") } })
        #expect(sources.contains { $0.lines.contains { $0.1.contains("privacy: .public") } }, "the scan sees the logs")
    }

    /// The lint itself (C-PLATFORM-10): it flags every `.public` interpolation off the allowlist, whatever the value
    /// was called, and passes the module's own permitted forms.
    @Test func thePublicLogLintFlagsEverythingOffItsAllowlist() throws {
        func lines(_ code: String) -> [(Int, String)] {
            code.components(separatedBy: "\n").enumerated().map { ($0.offset + 1, $0.element) }
        }
        let flagged = [
            #"let detail = String(describing: error)"# + "\n" + #"log.error("failed: \(detail, privacy: .public)")"#,
            #"let text = error.localizedDescription"# + "\n" + #"log.error("\(text, privacy:.public)")"#,
            #"log.error("failed: \(error, privacy: .public)")"#,
            #"log.error("\(String(describing: error), privacy: .public)")"#,
            #"log.error("\(failure.localizedDescription, privacy: .public)")"#,
            #"log.info("at \(url.path, privacy: .public)")"#,
            #"log.info("\(spec.fileName + detail, privacy: .public)")"#,
            #"let summary = String(describing: error)"# + "\n" + #"log.error("\(summary, privacy: .public)")"#,
            // An interpolation split across lines is judged whole (C-PLATFORM-10).
            #"let detail = String(describing: error)"# + "\n" + #"log.error("failed: \(detail,"# + "\n"
                + #"                     privacy: .public)")"#,
            #"log.error("failed: \(error,"# + "\n" + #"privacy:"# + "\n" + #".public)")"#,
            // A name one function binds to a summary and another to a description is no summary.
            #"func a(_ error: any Error) {"# + "\n" + #"    let summary = LoggedError.publicSummary(error)"# + "\n"
                + #"    log.error("\(summary, privacy: .public)")"# + "\n" + "}" + "\n"
                + #"func b(_ error: any Error) {"# + "\n" + #"    let summary = String(describing: error)"# + "\n"
                + #"    log.error("\(summary, privacy: .public)")"# + "\n" + "}",
            #"var summary = LoggedError.publicSummary(error)"# + "\n" + #"summary = error.localizedDescription"# + "\n"
                + #"log.error("\(summary, privacy: .public)")"#,
            // A summary that a compound assignment extends, or whose binding goes on after the call, is no summary.
            #"var summary = LoggedError.publicSummary(error)"# + "\n" + #"summary += String(describing: error)"# + "\n"
                + #"log.error("\(summary, privacy: .public)")"#,
            #"var summary = LoggedError.publicSummary(error)"# + "\n" + #"summary+=detail"# + "\n"
                + #"log.error("\(summary, privacy: .public)")"#,
            #"let summary = LoggedError.publicSummary(error) + String(describing: error)"# + "\n"
                + #"log.error("\(summary, privacy: .public)")"#,
            #"let summary = LoggedError.publicSummary(error).appending(detail)"# + "\n"
                + #"log.error("\(summary, privacy: .public)")"#,
            #"let summary = LoggedError.publicSummary(error)"# + "\n" + #"    + error.localizedDescription"# + "\n"
                + #"log.error("\(summary, privacy: .public)")"#,
            #"log.error("\(LoggedError.publicSummary(error).appending(detail), privacy: .public)")"#,
            // A stray `\(` (in a raw string) cannot hide a later `.public` interpolation from the scan.
            ##"let pattern = #"\("#"## + "\n" + #"log.error("\(detail, privacy: .public)")"#,
        ]
        for code in flagged {
            #expect(try !PublicLogLint.violations(in: lines(code)).isEmpty, "\(code)")
        }
        let allowed = [
            #"log.error("T4 failed: \(LoggedError.publicSummary(error), privacy: .public)")"#,
            #"let summary = LoggedError.publicSummary(error), detail = String(describing: error)"# + "\n"
                + #"log.error("\(level.rawValue, privacy: .public): \(summary, privacy: .public) (\(detail, privacy: .private))")"#,
            #"log.info("HLG still generated: \(spec.fileName, privacy: .public), \(report.fileBytes) bytes")"#,
            #"log.info("display \(self.host.display.id, privacy: .public), \(windows.count, privacy: .public) windows")"#,
            #"log.info("Removed \(count, privacy: .public) trigger windows")"#,
            #"log.error("T4 failed: \(LoggedError.publicSummary(error),"# + "\n" + #"    privacy: .public)")"#,
            #"func a(_ error: any Error) {"# + "\n" + #"    let summary = LoggedError.publicSummary(error)"# + "\n"
                + #"    log.error("\(summary, privacy: .public)")"# + "\n" + "}" + "\n"
                + #"func b(_ error: any Error) {"# + "\n" + #"    let summary: String = LoggedError.publicSummary(error)"#
                + "\n" + #"    if summary == "" { return }"# + "\n" + #"    log.error("\(summary, privacy: .public)")"# + "\n" + "}",
            #"let summary = LoggedError.publicSummary(error)  // the file name only"# + "\n"
                + #"if summary.count <= 80, retries >= 1 { log.error("\(summary, privacy: .public)") }"#,
            #"let summary ="# + "\n" + #"    LoggedError.publicSummary(error)"# + "\n"
                + #"log.error("\(summary, privacy: .public)")"#,
        ]
        for code in allowed {
            #expect(try PublicLogLint.violations(in: lines(code)).isEmpty, "\(code)")
        }
    }

    @Test func edrLayerPropertiesStayInTheStrategyFiles() {
        let properties = ["preferredDynamic" + "Range", "wantsExtendedDynamicRange" + "Content",
                          "contents" + "Headroom", "AVPlayer" + "Layer"]
        let allowed: Set<String> = ["Strategies/TaggedLayerTrigger.swift", "Strategies/HLGStillTrigger.swift",
                                    "Surfaces/MetalClearPass.swift", "Surfaces/MetalClearSurface.swift",
                                    "Overlay/CompatibilityOverlay.swift"]
        let found = hits(properties, in: files(under: Self.sources), except: allowed)
        #expect(found.isEmpty, "EDR surfaces are built only by the strategies, surfaces and the overlay: \(found)")
    }
}
