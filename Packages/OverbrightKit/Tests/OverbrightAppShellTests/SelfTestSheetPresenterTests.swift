// OverbrightAppShellTests/SelfTestSheetPresenterTests.swift — the self-test outside Settings (DESIGN.md §10): the
// presenter builds one window hosting SettingsUI's sheet and lets it go when it closes; Save Log… suggests a name with
// the run's start time. Nothing is ordered in.
import AppKit
import Foundation
import OverbrightCore
import OverbrightSettingsUI
import SwiftUI
import Testing
@testable import OverbrightAppShell

@MainActor @Suite struct SelfTestSheetPresenterTests {
    @Test func thePresenterHostsTheSheetAndLetsItGo() {
        _ = NSApplication.shared
        let presenter = SelfTestSheetPresenter(services: .preview())
        let window = presenter.preparedWindow()
        #expect(presenter.window === window)
        #expect(window.contentViewController is NSHostingController<SelfTestSheet>)
        #expect(!window.title.isEmpty && window.styleMask.contains(.titled))
        presenter.dismiss()
        #expect(presenter.window == nil)
    }

    @Test func saveSuggestsANameWithTheStartTime() {
        let report = SelfTestReport(startedAt: Date(timeIntervalSinceReferenceDate: 800_000_000),
                                    machine: DisplayFixture.ownerMachine, appVersion: "0.1.0", displays: [:], journal: [])
        let name = SelfTestSheetPresenter.suggestedName(for: report)
        #expect(name.contains(SelfTestLog.fileName(startedAt: report.startedAt)))
        #expect(name.hasSuffix(".json") && !name.contains(":") && !name.contains("/"))
    }
}
