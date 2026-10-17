// OverbrightAppShell/StatusItem/StatusItemQA.swift — DEBUG-only QA of the status menu (`--qa-menu`, ARCHITECTURE.md
// §8.5): menus cannot be rendered, so their rows are written to `qa-trace.txt` (next to `--qa-snapshot`'s PNGs, else in
// the temporary folder), then the menu opens on our own status button (an in-process `performClick`, no synthesized
// input). Cranny's MenuBarQA pattern (the owner's MIT code). The shared `QAHooks.swift` calls `runMenuQA(traceDirectory:)`
// (WP13's wiring). The menu closes by itself after `menuQAOpenTime`: AppKit tracks it inside the main-actor job that
// opened it, and until it closes no other main-actor job runs, so the run never reached its snapshot or
// `--qa-exit-after` and left the menu open on screen (WP14). Compiled out of Release.
#if DEBUG
import AppKit
import Foundation
import OverbrightCore
import os

private let log = Log.logger(.menuBar)

extension StatusItemController {
    /// How long `--qa-menu` keeps the menu open, in seconds.
    static let menuQAOpenTime: TimeInterval = 3

    /// Writes the menu's rows to `<traceDirectory>/qa-trace.txt` and opens the menu for `menuQAOpenTime`.
    func runMenuQA(traceDirectory: URL?) {
        let lines = menuModel().dump()
        let directory = traceDirectory ?? FileManager.default.temporaryDirectory
        let url = directory.appending(path: "qa-trace.txt")
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try (lines.joined(separator: "\n") + "\n").write(to: url, atomically: true, encoding: .utf8)
            log.info("QA: menu rows written to \(url.path, privacy: .private)")
        } catch {
            log.error("QA: menu rows not written: \(error.localizedDescription, privacy: .public)")
        }
        Self.runInEveryMode(after: Self.menuQAOpenTime) { [weak self] in self?.item?.menu?.cancelTracking() }
        showMenu()
    }

    /// Runs `action` once after `interval` from a main-run-loop timer in the common modes, so it also fires while a
    /// menu tracks (the run loop then runs in `.eventTracking`, and the main actor's queued jobs wait for the menu).
    @discardableResult
    static func runInEveryMode(after interval: TimeInterval, _ action: @escaping @MainActor () -> Void) -> Timer {
        let pending = PendingAction(action)
        let timer = Timer(timeInterval: interval, repeats: false) { _ in
            MainActor.assumeIsolated { pending.run() }                    // main run loop: the main thread
        }
        RunLoop.main.add(timer, forMode: .common)
        return timer
    }
}

/// A main-actor action handed to a `Timer`, whose block must be `Sendable`; it only ever runs on the main thread.
private final class PendingAction: @unchecked Sendable {
    let run: @MainActor () -> Void
    init(_ run: @escaping @MainActor () -> Void) { self.run = run }
}
#endif
