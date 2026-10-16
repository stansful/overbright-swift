// OverbrightAppShell/StatusItem/StatusItemQA.swift — DEBUG-only QA of the status menu (`--qa-menu`, ARCHITECTURE.md
// §8.5): menus cannot be rendered, so their rows are written to `qa-trace.txt` (next to `--qa-snapshot`'s PNGs, else in
// the temporary folder), then the menu opens on our own status button (an in-process `performClick`, no synthesized
// input). Cranny's MenuBarQA pattern (the owner's MIT code). The shared `QAHooks.swift` calls `runMenuQA(traceDirectory:)`
// (WP13's wiring). Compiled out of Release.
#if DEBUG
import AppKit
import Foundation
import OverbrightCore
import os

private let log = Log.logger(.menuBar)

extension StatusItemController {
    /// Writes the menu's rows to `<traceDirectory>/qa-trace.txt` and opens the menu.
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
        showMenu()
    }
}
#endif
