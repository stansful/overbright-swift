// OverbrightTriggersTests/TriggerModuleLintTests.swift — source scans for the module's own acceptance rules
// (ARCHITECTURE.md §10.5): no `.metal` file and no Metal library, function or pipeline API (D22); only the system
// presenter orders a window in, and no test can reach it (§9.1, D24); EDR layer properties stay in this module's
// strategy, surface and overlay files. API names are split in two here, so this file never matches its own scans.
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
        let found = hits(orderIn, in: sources, except: ["Windows/WindowPresenting.swift"])
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
