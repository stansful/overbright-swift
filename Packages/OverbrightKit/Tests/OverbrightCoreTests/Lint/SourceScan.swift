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
        lines.enumerated().compactMap { index, line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("//") || trimmed.hasPrefix("*") || trimmed.hasPrefix("/*") { return nil }
            return (index + 1, line)
        }
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
