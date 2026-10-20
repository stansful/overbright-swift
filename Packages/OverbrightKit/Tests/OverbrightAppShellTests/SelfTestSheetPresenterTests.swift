// OverbrightAppShellTests/SelfTestSheetPresenterTests.swift — the self-test's Save Log… (DESIGN.md §10) suggests a name
// with the run's start time. Nothing is ordered in.
import Foundation
import OverbrightCore
import OverbrightSettingsUI
import Testing
@testable import OverbrightAppShell

@MainActor @Suite struct SelfTestSheetPresenterTests {
    @Test func saveSuggestsANameWithTheStartTime() {
        let report = SelfTestReport(startedAt: Date(timeIntervalSinceReferenceDate: 800_000_000),
                                    machine: DisplayFixture.ownerMachine, appVersion: "0.1.0", displays: [:], journal: [])
        let name = SelfTestSheetPresenter.suggestedName(for: report)
        #expect(name.contains(SelfTestLog.fileName(startedAt: report.startedAt)))
        #expect(name.hasSuffix(".json") && !name.contains(":") && !name.contains("/"))
    }
}
