// OverbrightCoreTests/Lint/SourceLintTests.swift — the source scans of ARCHITECTURE.md §9.1 "Lint tests (Core)":
// D3 (clean room), D22 (no shaders), D24 (one display-state writer, no writes in hardware tests), §2.1 rules 6–7
// (EDR properties, networking), §4.5 invariants 3 and 10, §4.7 (no `NSColor` component initialisers for EDR) and the
// Policy purity rule of §10.3 (no clocks, I/O or randomness). `noCodeCreatesAPreferencesSuite` lives with
// InMemoryDefaultsTests. Comment lines are not code, except for the clean-room scan, which reads everything.
// API names that only one file may use are spelled in two parts here, so this file never matches its own scans.
import Foundation
import Testing

@Suite struct SourceLintTests {
    private let sources = SourceScan.sources
    private let code = [SourceScan.sources, "App", "Controls", "Shared"]

    /// D3: no competitor name outside the allowlist, in every text file of the repository: the root's README, notices
    /// and Makefile, the workflows, the Xcode project and Package.swift as much as the sources, tests, scripts and
    /// docs (the same files and rules as `scripts/lint-copy.py`).
    @Test func noDenylistedNamesOutsideAllowlist() throws {
        let caseless = try NSRegularExpression(pattern: "v[iíì]v[iíì]d|lumen[\\s-]*digital|bright[\\s-]*intosh|better[\\s-]*display",
                                               options: .caseInsensitive)
        let cased = try NSRegularExpression(pattern: "\\bLunar\\b|lunar\\.app|fyi\\.lunar")
        let identifierLiteral = try NSRegularExpression(pattern: "\"[A-Za-z0-9._-]+\"")
        let conflictCatalog = "\(sources)/OverbrightPolicy/Conflicts/ConflictCatalog.swift"
        let markedDefinitions: Set<String> = ["scripts/lint-copy.py", "scripts/l10n/l10n.py"]
        func denylisted(_ text: String) -> Bool {
            !SourceScan.matches(caseless, in: text).isEmpty || !SourceScan.matches(cased, in: text).isEmpty
        }
        func allowed(_ file: ScannedFile, _ line: String) -> Bool {
            if file.isUnder("docs/research") { return true }
            if file.path.hasSuffix(".md"), line.contains("<!-- denylist-ok -->") { return true }
            if markedDefinitions.contains(file.path), line.contains("denylist-ok") { return true }
            if file.path == conflictCatalog {
                let literals = SourceScan.matches(identifierLiteral, in: line)
                let stripped = identifierLiteral.stringByReplacingMatches(
                    in: line, range: NSRange(line.startIndex..., in: line), withTemplate: "\"\"")
                return literals.contains(where: denylisted) && !denylisted(stripped)
            }
            return false
        }
        let files = SourceScan.repositoryFiles()
        var hits: [String] = []
        for file in files {
            for (index, line) in file.lines.enumerated() where denylisted(line) && !allowed(file, line) {
                hits.append("\(file.path):\(index + 1)")
            }
        }
        #expect(files.count > 300)
        for path in ["README.md", "THIRD_PARTY_NOTICES.md", "Makefile", ".github/workflows/ci.yml",
                     "Packages/OverbrightKit/Package.swift", "Overbright.xcodeproj/project.pbxproj", "docs/ARCHITECTURE.md"] {
            #expect(files.contains { $0.path == path }, "\(path) is not in the clean-room scan")
        }
        #expect(hits.isEmpty, "competitor names outside the D3 allowlist: \(hits)")
    }

    /// D24, §2.1 rule 6: exactly one file calls the CoreGraphics table setters and the global ColorSync restore. The
    /// scan covers the scripts too (`render-icon.swift` runs with `xcrun swift`; Python could reach the setters
    /// through `ctypes`, a shell script through either).
    @Test func noSecondDisplayStateWriter() {
        let setters = ["CGSet" + "DisplayTransferByTable", "CGSet" + "DisplayTransferByFormula",
                       "CGSet" + "DisplayTransferByByteTable", "CGDisplay" + "RestoreColorSyncSettings"]
        let writer = "\(sources)/OverbrightDisplays/Gamma/CoreGraphicsGamma.swift"
        let files = SourceScan.files(in: code + [SourceScan.tests], extensions: ["swift", "m", "c", "h"])
            + SourceScan.files(in: ["scripts"], extensions: ["swift", "py", "sh"])
        let hits = lines(in: files.filter { $0.path != writer }) { line in setters.contains(where: line.contains) }
        #expect(files.contains { $0.path == writer })
        for script in ["scripts/render-icon.swift", "scripts/run.sh", "scripts/lint-copy.py"] {
            #expect(files.contains { $0.path == script }, "\(script)")
        }
        #expect(hits.isEmpty, "only CoreGraphicsGamma.swift may change display state: \(hits)")
    }

    /// §4.5 invariant 3: only `TableWriter` and `LaunchRescue` call `GammaPort.write` and the global restore
    /// (the hang watchdog and the signal handlers write through `TableWriter.writeBaselines(fromLedger:)`), with or
    /// without a receiver, or reference them.
    @Test func onlyTableWriterAndRescueWrite() {
        let allowed: Set<String> = ["\(sources)/OverbrightBoost/Writer/TableWriter.swift",
                                    "\(sources)/OverbrightBoost/Safety/LaunchRescue.swift"]
        let files = SourceScan.files(in: code, extensions: ["swift"]).filter { !allowed.contains($0.path) }
        let hits = gammaWrites(in: files)
        #expect(files.contains { $0.path == "\(sources)/OverbrightCore/Ports/GammaPort.swift" })   // declarations only
        #expect(hits.isEmpty, "GammaPort writes outside TableWriter and LaunchRescue: \(hits)")
    }

    /// The write scan finds the shapes WP4 and WP5 write (a call in the first argument, a subscript, a call over
    /// several lines, implicit `self`, method references, the restore) and leaves `Data.write(to:)`, declarations,
    /// other `write` methods, enum cases, comments and strings alone.
    @Test func gammaWriteScanFindsEveryShape() {
        let restore = "restoreSystem" + "ColorSettings"
        let calls = ["try gamma.write(baseline, to: display.id)",
                     "try gamma.write(baseline.scaled(by: f), to: display.id)",
                     "try gamma.write(GammaTable.identity(count: n), to: id)",
                     "try gamma.write(GammaTable.identity(count: max(n, 2)), to: id)",
                     "try gamma.write(tables[key], to: id)",
                     "try gamma.write(table,to:id)",
                     "try gamma.write(\n    table,\n    to: display.id)",
                     "try gamma.write(table\n    , to: id)",
                     "try gamma.write(label(\"a)\"), to: id)",
                     "try gamma.write(table, to : id)",
                     "try gamma.write(table, to:id,)",
                     "try gamma.write(table, /* the base */ to: id)",
                     "try gamma?.write(flag ? a : b, to: id)",
                     "try write(table, to: id)",
                     "try self.write(table, to: id)",
                     "try gamma.write (table, to: id)",
                     "displays.forEach { try? gamma.write(base, to: $0) }",
                     "let w = gamma.write(_:to:)",
                     "let w = write(_ : to :)",
                     "let w = gamma.write",
                     "ids.forEach(gamma.write)",
                     "gamma.\(restore)()",
                     "\(restore)()",
                     "self.\(restore)()",
                     "let r = gamma.\(restore)",
                     "try gamma.write(table, to: id) // try gamma.write(table, to: id)"]
        for call in calls { #expect(SourceScan.gammaWriteLines(in: call) == [1], "\(call)") }
        #expect(SourceScan.gammaWriteLines(in: "let a = 1\n\ntry gamma.write(\n    table, to: id)\nlet b = 2") == [3])
        #expect(SourceScan.gammaWriteLines(in: "try gamma\n    .write(table, to: id)") == [2])
        let wrapper = "extension GammaPort {\n    func reset(_ id: CGDirectDisplayID) throws {\n"
            + "        try write(.identity, to: id)\n        \(restore)()\n    }\n}"
        #expect(SourceScan.gammaWriteLines(in: wrapper) == [3, 4])
        let others = ["try data.write(to: url, options: .atomic)",
                      "try data.write(to: url)",
                      "FileHandle.standardOutput.write(Data((line + \"\\n\").utf8))",
                      "try data.write(to: url)\nlet range = clamp(a, to: b)",
                      "try data.write(to: url(for: name, in: folder))",
                      "handle.write(contentsOf: data)",
                      "try \"x\".write(toFile: path, atomically: true, encoding: .utf8)",
                      "log.write(\"a, to: b\")",
                      "func write(_ table: GammaTable, to display: CGDirectDisplayID) throws",
                      "public func write(_ table: GammaTable, to display: CGDirectDisplayID) throws {",
                      "public func \(restore)() {}",
                      "try write(value, revision: revision)",
                      "let outcome = writer.write(request, to: display, reading: reading, epoch: epoch)",
                      "try overwrite(table, to: id)",
                      "let count = gamma.writeCount",
                      "case .write: break",
                      "let kinds: [Kind] = [.write, .read]",
                      "var write = false",
                      "log.info(\"gamma.write(table, to: id) and \(restore)()\")",
                      "let a = 1 // try gamma.write(table, to: id)",
                      "/* try gamma.write(table, to: id) */ let a = 1",
                      "let s = \"\"\"\n    try gamma.write(table, to: id)\n    \"\"\""]
        for other in others { #expect(SourceScan.gammaWriteLines(in: other).isEmpty, "\(other)") }
    }

    /// D24: tests never construct a real display port (a writing one once WP2 lands), not even through
    /// `CompositionRoot.livePorts`, and suites gated by `OVERBRIGHT_HARDWARE` only read.
    @Test func noWritesInHardwareTests() {
        let realPorts = ["CoreGraphics" + "Gamma(", "System" + "HeadroomPort(", "System" + "DisplayDirectory(",
                         "live" + "Ports("]
        let files = SourceScan.files(in: [SourceScan.tests], extensions: ["swift"])
        let gated = files.filter { file in file.codeLines.contains { $0.text.contains("OVERBRIGHT_" + "HARDWARE") } }
        let writes = gammaWrites(in: gated)
        let constructions = lines(in: files.filter { file in !gated.contains { $0.path == file.path } }) { line in
            realPorts.contains(where: line.contains)
        }
        #expect(files.count > 20)
        #expect(writes.isEmpty, "hardware-gated suites must only read: \(writes)")
        #expect(constructions.isEmpty, "the real display ports only in hardware-gated suites: \(constructions)")
    }

    /// §2.1 rule 6: EDR layer properties and `AVPlayerLayer` only in Triggers, FillLight and Design's
    /// `EDRPreviewSurface.swift`.
    @Test func noEDRPropertiesOutsideAllowedModules() {
        let properties = ["preferredDynamic" + "Range", "wantsExtendedDynamicRange" + "Content", "contents" + "Headroom",
                          "AVPlayer" + "Layer"]
        let allowedFolders = ["\(sources)/OverbrightTriggers", "\(sources)/OverbrightFillLight"]
        let allowedFile = "\(sources)/OverbrightDesign/Components/EDRPreviewSurface.swift"
        let files = SourceScan.files(in: code, extensions: ["swift"]).filter { file in
            file.path != allowedFile && !allowedFolders.contains(where: file.isUnder)
        }
        let hits = lines(in: files) { line in properties.contains(where: line.contains) }
        #expect(hits.isEmpty, "EDR surfaces outside Triggers, FillLight and EDRPreviewSurface: \(hits)")
    }

    /// D2, §2.1 rule 7: networking APIs only in OverbrightUpdates.
    @Test func noNetworkingOutsideUpdates() throws {
        let network = try NSRegularExpression(pattern: "\\b(URLSession|NWConnection|NWPathMonitor|CFSocket)\\b|^\\s*import\\s+Network\\b")
        let files = SourceScan.files(in: code, extensions: ["swift"]).filter { !$0.isUnder("\(sources)/OverbrightUpdates") }
        let hits = lines(in: files) { line in !SourceScan.matches(network, in: line).isEmpty }
        #expect(hits.isEmpty, "networking outside OverbrightUpdates: \(hits)")
    }

    /// D22: no Metal shader sources or compiled libraries anywhere in what the app is built from.
    @Test func bundleShipsNoShaderSources() {
        let roots = ["Packages/OverbrightKit", "App", "Controls", "Shared"]
        let shaders = roots.flatMap { root -> [String] in
            let base = SourceScan.repository.appending(path: root, directoryHint: .isDirectory)
            guard let enumerator = FileManager.default.enumerator(at: base, includingPropertiesForKeys: nil) else { return [] }
            var found: [String] = []
            for case let url as URL in enumerator {
                if url.lastPathComponent.hasPrefix(".build") { enumerator.skipDescendants(); continue }
                if ["metal", "metallib"].contains(url.pathExtension) { found.append(url.lastPathComponent) }
            }
            return found
        }
        #expect(shaders.isEmpty, "Metal shader files are not allowed (D22): \(shaders)")
    }

    /// D8, §4.5 invariant 10: no code compares display or app names (they are localized; macOS localizes them).
    @Test func noNameComparisons() throws {
        let names = "(name|localizedName|displayName)"
        let comparison = try NSRegularExpression(pattern:
            "\\.\(names)\\s*(==|!=)|(==|!=)\\s*[A-Za-z0-9_.$?]*\\.\(names)\\b|\\.\(names)\\??\\.(contains|hasPrefix|hasSuffix|starts|range|caseInsensitiveCompare|localizedCaseInsensitiveContains|localizedStandardContains|compare|lowercased|uppercased)\\b")
        let files = SourceScan.files(in: code, extensions: ["swift"])
        let hits = lines(in: files) { line in !SourceScan.matches(comparison, in: line).isEmpty }
        #expect(!SourceScan.matches(comparison, in: "if facts.name == \"Built-in\" {").isEmpty)
        #expect(!SourceScan.matches(comparison, in: "app.localizedName.contains(\"x\")").isEmpty)
        #expect(SourceScan.matches(comparison, in: "Text(verbatim: status.name)").isEmpty)
        #expect(hits.isEmpty, "names are never compared (D8): \(hits)")
    }

    /// §4.7: `NSColor(colorSpace:components:count:)` stores 8-bit components and wraps values above 1.0, so EDR colours
    /// start from `CGColor` in Triggers, FillLight and Design.
    @Test func noNSColorComponentInitForEDR() {
        let initializer = "NSColor(" + "colorSpace:"
        let folders = ["OverbrightTriggers", "OverbrightFillLight", "OverbrightDesign"].map { "\(sources)/\($0)" }
        let files = SourceScan.files(in: folders, extensions: ["swift"])
        let hits = lines(in: files) { line in line.contains(initializer) }
        #expect(!files.isEmpty)
        #expect(hits.isEmpty, "use CGColor for EDR colours: \(hits)")
    }

    /// §10.3: Policy is pure: no clocks, no I/O, no randomness (the engine passes `now` and `minuteOfDay` in).
    @Test func policyReadsNoClockIOOrRandomness() throws {
        let impure = try NSRegularExpression(pattern:
            "\\bDate\\(\\)|\\bDate\\.now\\b|\\bProcessInfo\\b|\\bFileManager\\b|\\bUserDefaults\\b|\\bBundle\\.main\\b|\\bURLSession\\b|\\bContinuousClock\\b|\\bSuspendingClock\\b|\\bDispatchTime\\b|\\bCFAbsoluteTimeGetCurrent\\b|\\bmach_absolute_time\\b|\\.random\\(|\\bUUID\\(\\)|\\bsysctl")
        let files = SourceScan.files(in: ["\(sources)/OverbrightPolicy"], extensions: ["swift"])
        let hits = lines(in: files) { line in !SourceScan.matches(impure, in: line).isEmpty }
        #expect(files.count > 5)
        #expect(hits.isEmpty, "Policy must stay pure: \(hits)")
    }

    // MARK: Helpers

    /// "path:line" of every code line of `files` that `matches`.
    private func lines(in files: [ScannedFile], where matches: (String) -> Bool) -> [String] {
        files.flatMap { file in
            file.codeLines.filter { matches($0.text) }.map { "\(file.path):\($0.number)" }
        }
    }

    /// "path:line" of every `GammaPort.write(_:to:)`-shaped call in the code of `files` (whole statements, not lines).
    private func gammaWrites(in files: [ScannedFile]) -> [String] {
        files.flatMap { file in SourceScan.gammaWriteLines(in: file.codeText).map { "\(file.path):\($0)" } }
    }
}
