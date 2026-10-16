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

    /// D3: no competitor name outside the allowlist, in every text file of Sources, Tests, App, Controls, Shared,
    /// scripts and docs (the same rules as `scripts/lint-copy.py`).
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
        let files = SourceScan.files(in: [sources, SourceScan.tests, "App", "Controls", "Shared", "scripts", "docs"])
        var hits: [String] = []
        for file in files {
            for (index, line) in file.lines.enumerated() where denylisted(line) && !allowed(file, line) {
                hits.append("\(file.path):\(index + 1)")
            }
        }
        #expect(files.count > 300)
        #expect(files.contains { $0.path == "docs/ARCHITECTURE.md" })
        #expect(hits.isEmpty, "competitor names outside the D3 allowlist: \(hits)")
    }

    /// D24, §2.1 rule 6: exactly one file calls the CoreGraphics table setters and the global ColorSync restore.
    @Test func noSecondDisplayStateWriter() {
        let setters = ["CGSet" + "DisplayTransferByTable", "CGSet" + "DisplayTransferByFormula",
                       "CGSet" + "DisplayTransferByByteTable", "CGDisplay" + "RestoreColorSyncSettings"]
        let writer = "\(sources)/OverbrightDisplays/Gamma/CoreGraphicsGamma.swift"
        let files = SourceScan.files(in: code + [SourceScan.tests], extensions: ["swift", "m", "c", "h"])
        let hits = lines(in: files.filter { $0.path != writer }) { line in setters.contains(where: line.contains) }
        #expect(files.contains { $0.path == writer })
        #expect(hits.isEmpty, "only CoreGraphicsGamma.swift may change display state: \(hits)")
    }

    /// §4.5 invariant 3: only `TableWriter` and `LaunchRescue` call `GammaPort.write` and the global restore
    /// (the hang watchdog and the signal handlers write through `TableWriter.writeBaselines(fromLedger:)`).
    @Test func onlyTableWriterAndRescueWrite() throws {
        let gammaWrite = try NSRegularExpression(pattern: "\\.write\\(\\s*[^,()]+,\\s*to:")
        let restore = ".restoreSystem" + "ColorSettings("
        let allowed: Set<String> = ["\(sources)/OverbrightBoost/Writer/TableWriter.swift",
                                    "\(sources)/OverbrightBoost/Safety/LaunchRescue.swift"]
        let files = SourceScan.files(in: code, extensions: ["swift"])
        let hits = lines(in: files.filter { !allowed.contains($0.path) }) { line in
            !SourceScan.matches(gammaWrite, in: line).isEmpty || line.contains(restore)
        }
        #expect(SourceScan.matches(gammaWrite, in: "try gamma.write(baseline, to: display.id)").count == 1)
        #expect(SourceScan.matches(gammaWrite, in: "try data.write(to: url, options: .atomic)").isEmpty)
        #expect(hits.isEmpty, "GammaPort writes outside TableWriter and LaunchRescue: \(hits)")
    }

    /// D24: tests never construct a writing real port, and suites gated by `OVERBRIGHT_HARDWARE` only read.
    @Test func noWritesInHardwareTests() throws {
        let gammaWrite = try NSRegularExpression(pattern: "\\.write\\(\\s*[^,()]+,\\s*to:")
        let restore = "restoreSystem" + "ColorSettings("
        let realPort = "CoreGraphics" + "Gamma("
        let files = SourceScan.files(in: [SourceScan.tests], extensions: ["swift"])
        let gated = files.filter { file in file.codeLines.contains { $0.text.contains("OVERBRIGHT_" + "HARDWARE") } }
        let writes = lines(in: gated) { line in !SourceScan.matches(gammaWrite, in: line).isEmpty || line.contains(restore) }
        let realPorts = lines(in: files.filter { file in !gated.contains { $0.path == file.path } }) { line in
            line.contains(realPort)
        }
        #expect(files.count > 20)
        #expect(writes.isEmpty, "hardware-gated suites must only read: \(writes)")
        #expect(realPorts.isEmpty, "the real gamma port only in hardware-gated suites: \(realPorts)")
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
}
