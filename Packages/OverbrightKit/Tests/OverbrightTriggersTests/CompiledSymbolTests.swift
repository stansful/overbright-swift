// OverbrightTriggersTests/CompiledSymbolTests.swift — the module's COMPILED objects reference no Metal library,
// function or pipeline selector or symbol (ARCHITECTURE.md D22, §10.5 "a test greps the module's symbols"), while the
// selectors of the clear-only pass are there (so the scan is not vacuous). Runs under `swift test`, which leaves the
// module's object file(s) next to the test bundle; elsewhere (an Xcode test run) the suite is skipped and the source
// scan of `TriggerModuleLintTests` still applies.
import Foundation
import MachO
import Testing

/// Where the module's object files are.
private nonisolated enum TriggerObjects {
    /// The `.o` files of OverbrightTriggers in the build folder of the running test bundle.
    static let files: [URL]? = {
        let bundleMarker = ".xctest/"
        var bundlePath: String?
        for index in 0..<_dyld_image_count() {
            guard let name = _dyld_get_image_name(index).map({ String(cString: $0) }),
                  let range = name.range(of: bundleMarker) else { continue }
            bundlePath = String(name[..<range.upperBound])
            break
        }
        guard let bundlePath else { return nil }
        let folder = URL(fileURLWithPath: bundlePath).deletingLastPathComponent()
        let fm = FileManager.default
        // Swift Build (SwiftPM 6.x on macOS): one prelinked object per module next to the test bundles.
        let prelinked = folder.appending(path: "OverbrightTriggers.o")
        if fm.fileExists(atPath: prelinked.path) { return [prelinked] }
        // SwiftPM's native build system: `<config>/OverbrightTriggers.build/*.o`.
        let moduleFolder = folder.appending(path: "OverbrightTriggers.build", directoryHint: .isDirectory)
        let names = (try? fm.contentsOfDirectory(atPath: moduleFolder.path)) ?? []
        let objects = names.filter { $0.hasSuffix(".o") }.map { moduleFolder.appending(path: $0) }
        return objects.isEmpty ? nil : objects
    }()
}

@Suite(.enabled(if: TriggerObjects.files != nil, "needs the SwiftPM object files of OverbrightTriggers"))
struct CompiledSymbolTests {
    private func contains(_ needle: String, in data: Data) -> Bool { data.range(of: Data(needle.utf8)) != nil }

    @Test func noLibraryFunctionOrPipelineIsReferenced() throws {
        let objects = try #require(TriggerObjects.files)
        let all = try objects.map { try Data(contentsOf: $0) }
        let forbidden = ["new" + "DefaultLibrary", "new" + "LibraryWith", "new" + "FunctionWith",
                         "new" + "RenderPipelineState", "new" + "ComputePipelineState",
                         "make" + "DefaultLibrary", "make" + "Library", "make" + "Function",
                         "make" + "RenderPipelineState", "make" + "ComputePipelineState"]
        for needle in forbidden {
            let culprits = zip(objects, all).filter { contains(needle, in: $0.1) }.map(\.0.lastPathComponent)
            #expect(culprits.isEmpty, "\(needle) referenced by \(culprits)")
        }
        // The clear-only pass is compiled in: its selectors are present.
        for needle in ["newCommandQueue", "nextDrawable", "renderCommandEncoderWithDescriptor:", "presentDrawable:"] {
            #expect(all.contains { contains(needle, in: $0) }, "\(needle) should be referenced")
        }
    }
}
