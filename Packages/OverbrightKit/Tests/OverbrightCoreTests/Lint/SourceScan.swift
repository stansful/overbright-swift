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

    private static let skippedFolders: Set<String> = [".git", ".swiftpm", "__pycache__", "build", "dist", "DerivedData"]
    private static let binarySuffixes = [".png", ".jpg", ".jpeg", ".icns", ".pdf", ".mov", ".car", ".zip", ".dmg"]

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

    /// The 1-based line numbers of the calls shaped like `GammaPort.write(_:to:)` in `text`: a `.write(` whose own
    /// argument list has a comma followed by the label `to:`. The scan follows the call over lines and through nested
    /// parentheses, brackets, braces and string literals, so `gamma.write(base.scaled(by: f), to: id)` and a call
    /// split over lines match, while `data.write(to: url)` (the label on the first argument) does not.
    static func gammaWriteLines(in text: String) -> [Int] {
        let bytes = Array(text.utf8)
        let call = Array(".write(".utf8)
        var found: [Int] = []
        var line = 1
        var index = 0
        while index < bytes.count {
            if bytes[index] == UInt8(ascii: "\n") {
                line += 1
            } else if bytes[index...].starts(with: call) {
                if argumentList(of: bytes, from: index + call.count, hasLabel: Array("to:".utf8)) { found.append(line) }
                index += call.count
                continue
            }
            index += 1
        }
        return found
    }

    /// Whether the argument list that starts at `start` (just after its opening parenthesis) has `label` right after
    /// one of its own commas (whitespace and line breaks between them are skipped).
    private static func argumentList(of bytes: [UInt8], from start: Int, hasLabel label: [UInt8]) -> Bool {
        let opening: Set<UInt8> = [UInt8(ascii: "("), UInt8(ascii: "["), UInt8(ascii: "{")]
        let closing: Set<UInt8> = [UInt8(ascii: ")"), UInt8(ascii: "]"), UInt8(ascii: "}")]
        let space: Set<UInt8> = [UInt8(ascii: " "), UInt8(ascii: "\t"), UInt8(ascii: "\n"), UInt8(ascii: "\r")]
        var depth = 1
        var index = start
        while index < bytes.count {
            let byte = bytes[index]
            if byte == UInt8(ascii: "\"") {                                // skip a string literal
                index += 1
                while index < bytes.count, bytes[index] != UInt8(ascii: "\"") {
                    index += bytes[index] == UInt8(ascii: "\\") ? 2 : 1
                }
            } else if opening.contains(byte) {
                depth += 1
            } else if closing.contains(byte) {
                depth -= 1
                if depth == 0 { return false }
            } else if byte == UInt8(ascii: ","), depth == 1 {
                var next = index + 1
                while next < bytes.count, space.contains(bytes[next]) { next += 1 }
                if bytes[next...].starts(with: label) { return true }
            }
            index += 1
        }
        return false
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
