// OverbrightCoreTests/Lint/SourceScan.swift — reads the repository's text files for the lint tests (ARCHITECTURE.md
// §9.1 "Lint tests (Core)"). Paths are relative to the repository root; build outputs and caches are skipped.
import Foundation

/// One text file of the repository.
struct ScannedFile {
    /// The path from the repository root ("Packages/OverbrightKit/Sources/OverbrightCore/…").
    let path: String
    /// The file's lines.
    let lines: [String]

    /// The lines that are code, with their 1-based numbers: comment lines (`//`, `///`, `*`) are left out.
    var codeLines: [(number: Int, text: String)] {
        lines.enumerated().compactMap { index, line in Self.isComment(line) ? nil : (index + 1, line) }
    }

    /// The file's code as one text, comment lines blanked so line numbers stay: scans that follow a statement over
    /// several lines read this.
    var codeText: String { lines.map { Self.isComment($0) ? "" : $0 }.joined(separator: "\n") }

    private static func isComment(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        return trimmed.hasPrefix("//") || trimmed.hasPrefix("*") || trimmed.hasPrefix("/*")
    }

    /// Whether the file lives under `folder` (a repository-relative path prefix).
    func isUnder(_ folder: String) -> Bool { path.hasPrefix(folder.hasSuffix("/") ? folder : folder + "/") }
}

/// The repository's files as the lint tests see them.
enum SourceScan {
    /// Packages/OverbrightKit.
    static let package = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    /// The repository root.
    static let repository = package.deletingLastPathComponent().deletingLastPathComponent()
    /// The package's folders, from the repository root.
    static let sources = "Packages/OverbrightKit/Sources"
    /// The package's test folders.
    static let tests = "Packages/OverbrightKit/Tests"

    private static let skippedFolders: Set<String> = [".git", ".swiftpm", "__pycache__", "build", "dist", "DerivedData",
                                                      ".derived", "xcuserdata", ".idea"]
    private static let binarySuffixes = [".png", ".jpg", ".jpeg", ".icns", ".pdf", ".mov", ".car", ".zip", ".dmg"]

    /// Every text file of the repository, as `scripts/lint-copy.py`'s `scanned_files()` lists them for the clean-room
    /// scan: what git tracks plus the untracked files `.gitignore` does not exclude, or, without git, every file under
    /// the root except build outputs, SwiftPM caches and per-user state.
    static func repositoryFiles() -> [ScannedFile] {
        guard let paths = gitListedFiles() else { return files(in: [""]) }
        return paths.compactMap { path -> ScannedFile? in
            let name = (path as NSString).lastPathComponent
            if name == ".DS_Store" || binarySuffixes.contains(where: name.hasSuffix) { return nil }
            let url = repository.appending(path: path, directoryHint: .notDirectory)
            guard let text = try? String(contentsOf: url, encoding: .utf8) else { return nil }
            return ScannedFile(path: path, lines: text.components(separatedBy: "\n"))
        }
        .sorted { $0.path < $1.path }
    }

    /// `git ls-files --cached --others --exclude-standard` from the repository root; nil when git cannot list it.
    private static func gitListedFiles() -> [String]? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["-C", repository.path, "ls-files", "-z", "--cached", "--others", "--exclude-standard"]
        let output = Pipe()
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        do { try process.run() } catch { return nil }
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return nil }
        let paths = String(decoding: data, as: UTF8.self).split(separator: "\0").map(String.init)
        return paths.isEmpty ? nil : paths
    }

    /// Every text file under `folders` (repository-relative), optionally only with one of `extensions`.
    static func files(in folders: [String], extensions: Set<String>? = nil) -> [ScannedFile] {
        folders.flatMap { folder -> [ScannedFile] in
            let root = repository.appending(path: folder, directoryHint: .isDirectory)
            guard let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.isDirectoryKey])
            else { return [] }
            var found: [ScannedFile] = []
            for case let url as URL in enumerator {
                let name = url.lastPathComponent
                if (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true {
                    if name.hasPrefix(".build") || skippedFolders.contains(name) { enumerator.skipDescendants() }
                    continue
                }
                if let extensions, !extensions.contains(url.pathExtension) { continue }
                if name == ".DS_Store" || binarySuffixes.contains(where: name.hasSuffix) { continue }
                guard let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
                found.append(ScannedFile(path: relativePath(of: url), lines: text.components(separatedBy: "\n")))
            }
            return found
        }
        .sorted { $0.path < $1.path }
    }

    /// Every String Catalog: the package's `Sources/*/Resources/*.xcstrings`, `App/*.xcstrings`, `Controls/*.xcstrings`.
    static func catalogs() -> [(path: String, strings: [String: Any])] {
        files(in: [sources, "App", "Controls"], extensions: ["xcstrings"]).compactMap { file in
            guard let data = file.lines.joined(separator: "\n").data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let strings = json["strings"] as? [String: Any] else { return nil }
            return (file.path, strings)
        }
    }

    /// Every `value` string under a catalog entry's localizations (string units, plural and device variations), by
    /// language.
    static func values(of entry: [String: Any]) -> [(language: String, text: String)] {
        guard let localizations = entry["localizations"] as? [String: Any] else { return [] }
        return localizations.flatMap { language, node in collect(node).map { (language, $0) } }
    }

    /// Matches of `pattern` in `text`.
    static func matches(_ pattern: NSRegularExpression, in text: String) -> [String] {
        let range = NSRange(text.startIndex..., in: text)
        return pattern.matches(in: text, range: range).compactMap { Range($0.range, in: text).map { String(text[$0]) } }
    }

    /// The 1-based line numbers in `text` where code calls or references a writing member of `GammaPort`:
    /// - `write(_:to:)`: a call with exactly two arguments, the second labelled `to` (also `to :` and a trailing
    ///   comma), with a receiver (`gamma.write(…)`, `self.write(…)`, `.write(…)` under its receiver's line) or with
    ///   implicit `self` (in an `extension GammaPort` or a conforming wrapper); the reference `write(_:to:)`; and a
    ///   `.write` on a receiver that is not called (`let w = gamma.write`, `map(gamma.write)`).
    /// - `restoreSystemColorSettings`: every call or reference, with or without a receiver.
    /// Declarations (`func write(`, `func restoreSystemColorSettings(`), comments and string literals do not count. A
    /// call is followed over lines and through nested parentheses, brackets, braces, comments and string literals, so
    /// `gamma.write(base.scaled(by: f), to: id)` and a call split over lines match, while `data.write(to: url)` (the
    /// label on the first argument), `write(_:revision:)` and `TableWriter.write(_:to:reading:epoch:)` (four
    /// arguments) and an enum case `.write` (no receiver) do not.
    static func gammaWriteLines(in text: String) -> [Int] {
        let bytes = Array(text.utf8)
        let write = Array("write".utf8), restore = Array("restoreSystem".utf8) + Array("ColorSettings".utf8)
        var found: [Int] = []
        var line = 1
        var index = 0
        while index < bytes.count {
            if let end = literalEnd(bytes, at: index) ?? commentEnd(bytes, at: index) {
                line += bytes[index..<end].count(where: { $0 == UInt8(ascii: "\n") })
                index = end
                continue
            }
            let byte = bytes[index]
            if byte == UInt8(ascii: "\n") { line += 1 }
            guard isIdentifierStart(byte), index == 0 || !isIdentifierByte(bytes[index - 1]) else {
                index += 1
                continue
            }
            var end = index
            while end < bytes.count, isIdentifierByte(bytes[end]) { end += 1 }
            let isWrite = bytes[index..<end].elementsEqual(write), isRestore = bytes[index..<end].elementsEqual(restore)
            if isWrite || isRestore, !isDeclaration(bytes, before: index),
               isRestore || writesTable(bytes, name: index, after: end), found.last != line {
                found.append(line)
            }
            index = end
        }
        return found
    }

    /// Whether the `write` at `name` (ending at `end`) is `GammaPort.write(_:to:)`: a two-argument call whose second
    /// argument is labelled `to`, the reference `write(_:to:)`, or an uncalled `.write` on a receiver.
    private static func writesTable(_ bytes: [UInt8], name: Int, after end: Int) -> Bool {
        let open = skippingSpace(bytes, from: end)
        guard open < bytes.count, bytes[open] == UInt8(ascii: "(") else { return hasReceiver(bytes, before: name) }
        guard let list = arguments(of: bytes, from: open + 1) else { return false }
        let reference = bytes[(open + 1)..<list.end].filter { !spaces.contains($0) }
        if reference.elementsEqual(Array("_:to:".utf8)) { return true }
        return list.starts.count == 2 && hasLabel(bytes, at: list.starts[1], label: Array("to".utf8))
    }

    /// The start of each top-level argument of the list that begins at `start` (just after its opening parenthesis),
    /// and the index of its closing parenthesis; nil when the list never closes.
    private static func arguments(of bytes: [UInt8], from start: Int) -> (starts: [Int], end: Int)? {
        let opening: Set<UInt8> = [UInt8(ascii: "("), UInt8(ascii: "["), UInt8(ascii: "{")]
        let closing: Set<UInt8> = [UInt8(ascii: ")"), UInt8(ascii: "]"), UInt8(ascii: "}")]
        var starts: [Int] = []
        var expectsArgument = true
        var depth = 1
        var index = start
        while index < bytes.count {
            if let end = commentEnd(bytes, at: index) {
                index = end
                continue
            }
            let byte = bytes[index]
            if spaces.contains(byte) {
                index += 1
                continue
            }
            if depth == 1, byte == UInt8(ascii: ",") {
                expectsArgument = true
                index += 1
                continue
            }
            if closing.contains(byte) {
                depth -= 1
                if depth == 0 { return (starts, index) }
            } else if depth == 1, expectsArgument {
                starts.append(index)
                expectsArgument = false
            }
            if let end = literalEnd(bytes, at: index) {                    // a string literal argument
                index = end
                continue
            }
            if opening.contains(byte) { depth += 1 }
            index += 1
        }
        return nil
    }

    /// Whether the argument at `start` carries `label` (`to:`, `to :`).
    private static func hasLabel(_ bytes: [UInt8], at start: Int, label: [UInt8]) -> Bool {
        let end = start + label.count
        guard end <= bytes.count, bytes[start..<end].elementsEqual(label),
              end == bytes.count || !isIdentifierByte(bytes[end]) else { return false }
        let colon = skippingSpace(bytes, from: end)
        return colon < bytes.count && bytes[colon] == UInt8(ascii: ":")
    }

    /// Whether the identifier at `name` follows `func` (a declaration, not a call).
    private static func isDeclaration(_ bytes: [UInt8], before name: Int) -> Bool {
        let keyword = Array("func".utf8)
        var end = name
        while end > 0, spaces.contains(bytes[end - 1]) { end -= 1 }
        let start = end - keyword.count
        guard start >= 0, bytes[start..<end].elementsEqual(keyword) else { return false }
        return start == 0 || !isIdentifierByte(bytes[start - 1])
    }

    /// Whether the identifier at `name` is a member of a value (`gamma.write`, `ports.gamma?.write`, `f().write`),
    /// not an implicit member such as the enum case in `case .write:` or `[.write, .read]`.
    private static func hasReceiver(_ bytes: [UInt8], before name: Int) -> Bool {
        var dot = name
        while dot > 0, spaces.contains(bytes[dot - 1]) { dot -= 1 }
        guard dot > 0, bytes[dot - 1] == UInt8(ascii: ".") else { return false }
        var end = dot - 1
        while end > 0, spaces.contains(bytes[end - 1]) { end -= 1 }
        guard end > 0 else { return false }
        let last = bytes[end - 1]
        if [UInt8(ascii: ")"), UInt8(ascii: "]"), UInt8(ascii: "?"), UInt8(ascii: "!")].contains(last) { return true }
        guard isIdentifierByte(last) else { return false }
        var start = end - 1
        while start > 0, isIdentifierByte(bytes[start - 1]) { start -= 1 }
        let keywords: Set<String> = ["case", "return", "in", "try", "await", "where", "else", "throw", "is", "as"]
        return !keywords.contains(String(decoding: bytes[start..<end], as: UTF8.self))
    }

    /// The end of the string literal that starts at `index` (`"…"`, `"""…"""`, raw `#"…"#`), nil if none starts there.
    private static func literalEnd(_ bytes: [UInt8], at index: Int) -> Int? {
        let quote = UInt8(ascii: "\""), hash = UInt8(ascii: "#")
        var open = index
        while open < bytes.count, bytes[open] == hash { open += 1 }
        guard open < bytes.count, bytes[open] == quote else { return nil }
        let hashes = open - index
        let triple = open + 2 < bytes.count && bytes[open + 1] == quote && bytes[open + 2] == quote
        let closing = Array(repeating: quote, count: triple ? 3 : 1) + Array(repeating: hash, count: hashes)
        var cursor = open + (triple ? 3 : 1)
        while cursor < bytes.count {
            if hashes == 0, bytes[cursor] == UInt8(ascii: "\\") {
                cursor += 2
                continue
            }
            if !triple, bytes[cursor] == UInt8(ascii: "\n") { return cursor }   // unterminated: stop at the line end
            if bytes[cursor...].starts(with: closing) { return cursor + closing.count }
            cursor += 1
        }
        return bytes.count
    }

    /// The end of the comment that starts at `index` (`// …` up to the line break, `/* … */` nested), nil if none.
    private static func commentEnd(_ bytes: [UInt8], at index: Int) -> Int? {
        let slash = UInt8(ascii: "/"), star = UInt8(ascii: "*")
        guard index + 1 < bytes.count, bytes[index] == slash else { return nil }
        if bytes[index + 1] == slash {
            var end = index
            while end < bytes.count, bytes[end] != UInt8(ascii: "\n") { end += 1 }
            return end
        }
        guard bytes[index + 1] == star else { return nil }
        var depth = 1
        var cursor = index + 2
        while cursor + 1 < bytes.count, depth > 0 {
            if bytes[cursor] == slash, bytes[cursor + 1] == star {
                depth += 1
                cursor += 2
            } else if bytes[cursor] == star, bytes[cursor + 1] == slash {
                depth -= 1
                cursor += 2
            } else {
                cursor += 1
            }
        }
        return depth == 0 ? cursor : bytes.count
    }

    /// Whitespace and line breaks.
    private static let spaces: Set<UInt8> = [UInt8(ascii: " "), UInt8(ascii: "\t"), UInt8(ascii: "\n"),
                                             UInt8(ascii: "\r")]

    private static func skippingSpace(_ bytes: [UInt8], from start: Int) -> Int {
        var index = start
        while index < bytes.count, spaces.contains(bytes[index]) { index += 1 }
        return index
    }

    private static func isIdentifierStart(_ byte: UInt8) -> Bool {
        (UInt8(ascii: "a")...UInt8(ascii: "z")).contains(byte) || (UInt8(ascii: "A")...UInt8(ascii: "Z")).contains(byte)
            || byte == UInt8(ascii: "_")
    }

    private static func isIdentifierByte(_ byte: UInt8) -> Bool {
        isIdentifierStart(byte) || (UInt8(ascii: "0")...UInt8(ascii: "9")).contains(byte)
    }

    private static func collect(_ node: Any) -> [String] {
        if let dictionary = node as? [String: Any] {
            return dictionary.flatMap { key, child -> [String] in
                if key == "value", let text = child as? String { return [text] }
                return collect(child)
            }
        }
        if let array = node as? [Any] { return array.flatMap(collect) }
        return []
    }

    private static func relativePath(of url: URL) -> String {
        let root = repository.standardizedFileURL.path
        let path = url.standardizedFileURL.path
        return path.hasPrefix(root + "/") ? String(path.dropFirst(root.count + 1)) : path
    }
}
