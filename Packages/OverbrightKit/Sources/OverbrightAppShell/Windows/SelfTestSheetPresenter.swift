// OverbrightAppShell/Windows/SelfTestSheetPresenter.swift — the self-test's Save Log… panel. ARCHITECTURE.md §8.4,
// §10.13; DESIGN.md §10. Settings ▸ Advanced presents SettingsUI's `SelfTestSheet` as a SwiftUI sheet itself;
// `saveLog(_:)` is what `AppControl.saveSelfTestLog` does: a Save panel for a JSON file, then the report written off the
// main actor (only the user's choice of place ever receives a log; the archive of the last ten is SettingsUI's).
import AppKit
import OverbrightCore
import OverbrightSettingsUI
import os
import UniformTypeIdentifiers

private let log = Log.logger(.selfTest)

/// Saves self-test logs.
final class SelfTestSheetPresenter {
    /// Save Log…: a Save panel for a JSON file, then the report written there.
    func saveLog(_ report: SelfTestReport) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = Self.suggestedName(for: report)
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            Task {
                do {
                    try await SelfTestLog.save(report, to: url)
                    log.info("self-test log saved")
                } catch {
                    let failure = error as NSError
                    log.error("self-test log not saved: \(failure.domain, privacy: .public) \(failure.code, privacy: .public) (\(failure.localizedDescription, privacy: .private))")
                }
            }
        }
    }

    /// "Overbright Self-Test 2026-10-16T142005Z.json".
    static func suggestedName(for report: SelfTestReport) -> String {
        let stamp = SelfTestLog.fileName(startedAt: report.startedAt)
        return String(localized: "Overbright Self-Test \(stamp)", table: "Calibration", bundle: .module,
                      comment: "Self-test: the suggested file name of a saved log; the argument is its date and time with “.json”")
    }
}
