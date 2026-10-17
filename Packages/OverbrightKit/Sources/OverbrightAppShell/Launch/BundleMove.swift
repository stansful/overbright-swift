// OverbrightAppShell/Launch/BundleMove.swift — the file work behind "Move to Applications" (DESIGN.md §12.4).
// ARCHITECTURE.md §7.4. Pure file-system operations on the paths it is given, so tests run it in a temporary folder.
//
// The bundle goes to `<folder>/<name>.app`. An older copy there goes to the Trash first (never deleted outright), and
// `perform` keeps where the Trash put it. A bundle on a read-only volume (a disk image) or a translocated copy is copied
// instead of moved; anything else is moved (the running process keeps its open files). The quarantine flag is removed
// from the moved copy only, because the user chose to move it there: a quarantined copy in Applications would be
// translocated again. When the move or the copy itself fails, `perform` brings the older copy back from the Trash
// before it throws (a partial copy left in its place goes to the Trash first), so the failure alert's "Drag it to the
// Applications folder" is true: Applications holds what it held. When the relaunch from the new place fails, `putBack`
// undoes the move, so the running process carries on from a bundle that exists, and brings the older copy back from
// the Trash once its place is free again.
import Darwin
import Foundation

/// Moves an app bundle into a folder.
enum BundleMove {
    /// Where `perform` left things.
    struct Placement: Equatable {
        /// The bundle's new location, `<folder>/<name>.app`.
        var moved: URL
        /// Where the Trash put the older copy that was at `moved` (nil: there was none, or the Trash did not say).
        var trashedOlderCopy: URL?
    }

    /// What `putBack` achieved.
    struct Undo: Equatable {
        /// The original bundle exists (again): the process running from it can carry on.
        var originalExists: Bool
        /// The older copy came back from the Trash; nil when there was none to bring back, or its place is still taken.
        var olderCopyRestored: Bool?
    }

    /// Puts a URL in the Trash and returns where it went (`FileManager.trashItem`'s resulting URL; tests use a folder).
    typealias Trash = (URL) throws -> URL?

    /// Moves (or, with `copyOnly` or when moving fails, copies) `bundle` into `folder`; returns the new location and
    /// where an older copy there went. That older copy goes through `trash` first (the Trash; tests use a folder).
    /// When the move and the copy fail, the older copy comes back from the Trash (`restoreOlderCopy`), then the error
    /// is thrown.
    static func perform(_ bundle: URL, into folder: URL, copyOnly: Bool, fileManager: FileManager = .default,
                        trash: Trash = moveToTrash) throws -> Placement {
        let destination = folder.appending(path: bundle.lastPathComponent, directoryHint: .isDirectory)
        guard destination.standardizedFileURL != bundle.standardizedFileURL else { return Placement(moved: destination) }
        var trashed: URL?
        if fileManager.fileExists(atPath: destination.path(percentEncoded: false)) {
            trashed = try trash(destination)
        }
        do {
            if copyOnly {
                try fileManager.copyItem(at: bundle, to: destination)
            } else {
                do {
                    try fileManager.moveItem(at: bundle, to: destination)
                } catch {
                    try fileManager.copyItem(at: bundle, to: destination)           // read-only source (disk image)
                }
            }
        } catch {
            if let trashed { restoreOlderCopy(trashed, to: destination, fileManager: fileManager, trash: trash) }
            throw error
        }
        removeQuarantine(under: destination, fileManager: fileManager)
        return Placement(moved: destination, trashedOlderCopy: trashed)
    }

    /// After a failed move or copy: the older copy goes from `trashed` back to `destination`. Whatever the failure left
    /// there (a partial copy of the new bundle: the place was free before) goes through `trash` first, never deleted;
    /// when it cannot go, the older copy stays in the Trash. Returns whether the older copy is back.
    @discardableResult
    static func restoreOlderCopy(_ trashed: URL, to destination: URL, fileManager: FileManager = .default,
                                 trash: Trash = moveToTrash) -> Bool {
        let place = destination.path(percentEncoded: false)
        if fileManager.fileExists(atPath: place) { _ = try? trash(destination) }
        guard !fileManager.fileExists(atPath: place) else { return false }
        return (try? fileManager.moveItem(at: trashed, to: destination)) != nil
    }

    /// Undoes `perform` after a failed relaunch: a bundle that was moved goes back to `original`; a copy (the original
    /// is still there) goes through `trash`. Once the new bundle has left its place, the older copy comes back there
    /// from the Trash. When the bundle can go neither back nor away, it stays in the folder and so does the older copy
    /// in the Trash (`originalExists` false: the caller says where Overbright is now).
    static func putBack(_ placement: Placement, to original: URL, fileManager: FileManager = .default,
                        trash: Trash = moveToTrash) -> Undo {
        let moved = placement.moved
        guard moved.standardizedFileURL != original.standardizedFileURL else { return Undo(originalExists: true) }
        let originalExists: Bool
        if fileManager.fileExists(atPath: original.path(percentEncoded: false)) {
            originalExists = true                                              // a copy: the original never left
            _ = try? trash(moved)
        } else {
            try? fileManager.moveItem(at: moved, to: original)
            originalExists = fileManager.fileExists(atPath: original.path(percentEncoded: false))
        }
        // Free when the new bundle has left (the Trash may not say where it put it: a nil URL is still a success).
        let placeIsFree = !fileManager.fileExists(atPath: moved.path(percentEncoded: false))
        guard let older = placement.trashedOlderCopy, placeIsFree else { return Undo(originalExists: originalExists) }
        let restored = (try? fileManager.moveItem(at: older, to: moved)) != nil
        return Undo(originalExists: originalExists, olderCopyRestored: restored)
    }

    /// Puts `url` in the Trash (never deleted outright: the user can put an older copy back); returns where it went.
    nonisolated static func moveToTrash(_ url: URL) throws -> URL? {
        var resulting: NSURL?
        try FileManager.default.trashItem(at: url, resultingItemURL: &resulting)
        return resulting as URL?
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
