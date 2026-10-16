// OverbrightAppShell/Launch/BundleMove.swift — the file work behind "Move to Applications" (DESIGN.md §12.4).
// ARCHITECTURE.md §7.4. Pure file-system operations on the paths it is given, so tests run it in a temporary folder.
//
// The bundle goes to `<folder>/<name>.app`. An older copy there goes to the Trash first (never deleted outright). A
// bundle on a read-only volume (a disk image) or a translocated copy is copied instead of moved; anything else is
// moved (the running process keeps its open files). The quarantine flag is removed from the moved copy only, because
// the user chose to move it there: a quarantined copy in Applications would be translocated again.
import Darwin
import Foundation

/// Moves an app bundle into a folder.
enum BundleMove {
    /// Moves (or, with `copyOnly` or when moving fails, copies) `bundle` into `folder`; returns the new location. An
    /// older copy there goes through `trash` first (the Trash; tests remove it instead).
    static func perform(_ bundle: URL, into folder: URL, copyOnly: Bool, fileManager: FileManager = .default,
                        trash: (URL) throws -> Void = moveToTrash) throws -> URL {
        let destination = folder.appending(path: bundle.lastPathComponent, directoryHint: .isDirectory)
        guard destination.standardizedFileURL != bundle.standardizedFileURL else { return destination }
        if fileManager.fileExists(atPath: destination.path(percentEncoded: false)) {
            try trash(destination)
        }
        if copyOnly {
            try fileManager.copyItem(at: bundle, to: destination)
        } else {
            do {
                try fileManager.moveItem(at: bundle, to: destination)
            } catch {
                try fileManager.copyItem(at: bundle, to: destination)               // read-only source (disk image)
            }
        }
        removeQuarantine(under: destination, fileManager: fileManager)
        return destination
    }

    /// Puts `url` in the Trash (never deleted outright: the user can put an older copy back).
    nonisolated static func moveToTrash(_ url: URL) throws {
        try FileManager.default.trashItem(at: url, resultingItemURL: nil)
    }

    /// The extended attribute Gatekeeper reads.
    static let quarantineAttribute = "com.apple.quarantine"

    /// Removes the quarantine flag from `root` and everything inside it.
    static func removeQuarantine(under root: URL, fileManager: FileManager = .default) {
        var paths = [root.path(percentEncoded: false)]
        if let enumerator = fileManager.enumerator(at: root, includingPropertiesForKeys: nil) {
            for case let url as URL in enumerator { paths.append(url.path(percentEncoded: false)) }
        }
        for path in paths { removexattr(path, quarantineAttribute, XATTR_NOFOLLOW) }
    }
}
