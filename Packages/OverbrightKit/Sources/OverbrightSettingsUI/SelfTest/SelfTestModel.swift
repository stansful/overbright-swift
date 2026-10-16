// OverbrightSettingsUI/SelfTest/SelfTestModel.swift — what the self-test sheet shows and does (DESIGN.md §10;
// ARCHITECTURE.md §8.4): before the run, a checkbox per display and Test every method; while it runs, a progress line
// and bar per display, refreshed once a second from the journal (`SelfTestProgress`), and Stop, which cancels the task
// that awaits the engine (the runner returns every display to Standard at once and reports what it measured); after
// it, the results per display, Save Log… (through `AppControl.saveSelfTestLog`, a Save panel), Copy (the JSON on the
// clipboard) and Done. The engine holds Overbright off for the run and never writes a scaled table. Every finished
// report is also kept in Application Support's SelfTest folder (the last ten).
import AppKit
import Foundation
import Observation
import OverbrightCore
import os

private let log = Log.logger(.selfTest)

/// The self-test sheet's state.
@Observable final class SelfTestModel {
    /// Where the sheet is.
    enum Phase: Equatable {
        /// The consent text and the options.
        case before
        /// The test runs.
        case running
        /// The report is in.
        case results(SelfTestReport)
    }

    /// A display that can be tested.
    struct Display: Identifiable, Hashable {
        let key: DisplayKey
        let name: String
        var id: DisplayKey { key }
    }

    /// The step the sheet shows.
    private(set) var phase: Phase = .before
    /// The displays that can be tested (every display with its own picture: not virtual, not a mirror member).
    let displays: [Display]
    /// The displays to test (all by default).
    var chosen: Set<DisplayKey>
    /// Test every rung instead of stopping at the first that holds ("about 3 minutes per display").
    var everyMethod = false
    /// The progress per display while it runs.
    private(set) var progress: [SelfTestProgress] = []

    @ObservationIgnored private let services: OverbrightServices
    @ObservationIgnored private let options = SelfTestOptions()
    @ObservationIgnored private var run: Task<Void, Never>?
    @ObservationIgnored private var ticker: Task<Void, Never>?
    @ObservationIgnored private var startedAt = 0.0
    @ObservationIgnored private var plan: [SelfTestPlan.Rung] = []
    @ObservationIgnored private let copyText: @MainActor (String) -> Void
    @ObservationIgnored private let archiveFolder: URL?

    /// A model over `services`; `copy` puts text on the clipboard (tests record it); the archive goes to
    /// `archiveFolder` (default: Application Support's SelfTest folder; nil keeps nothing).
    init(services: OverbrightServices, copy: @escaping @MainActor (String) -> Void = SelfTestModel.copyToPasteboard,
         archiveFolder: URL?? = nil) {
        self.services = services
        copyText = copy
        self.archiveFolder = archiveFolder
            ?? services.paths.root.appending(path: AppPaths.selfTestFolder, directoryHint: .isDirectory)
        displays = services.displays.displays
            .filter { $0.panelClass != .virtualDisplay && !$0.isMirrored }
            .map { Display(key: $0.ref.key, name: $0.name) }
        chosen = Set(displays.map(\.key))
    }

    /// The test can start: at least one display is chosen.
    var canRun: Bool { phase == .before && !chosen.isEmpty }

    /// Starts the test on the chosen displays.
    func start() {
        guard canRun else { return }
        let order = displays.map(\.key).filter(chosen.contains)
        let options = SelfTestOptions(everyStrategy: everyMethod, secondsPerStrategy: self.options.secondsPerStrategy,
                                      displays: Set(order))
        plan = SelfTestPlan.rungs(everyMethod: everyMethod, machine: services.machine)
        startedAt = services.time.now.sinceOrigin.timeInterval
        phase = .running
        refreshProgress()
        log.info("self-test started: \(order.count, privacy: .public) display(s), every method \(options.everyStrategy, privacy: .public)")
        let boost = services.boost
        run = Task { [weak self] in
            let report = await boost.runSelfTest(options)
            self?.finish(report)
        }
        ticker = Task { [weak self, time = services.time] in
            while !Task.isCancelled {
                do { try await time.sleep(for: .seconds(1)) } catch { return }
                self?.refreshProgress()
            }
        }
    }

    /// Stop: cancels the run; the engine returns every display to Standard and the report holds what was measured.
    func stop() {
        guard phase == .running else { return }
        run?.cancel()
        log.info("self-test stopped")
    }

    /// The sheet closes: a run still going is stopped.
    func close() {
        run?.cancel()
        ticker?.cancel()
    }

    /// Save Log…: the app's Save panel writes the JSON.
    func save() {
        guard case .results(let report) = phase else { return }
        services.app?.saveSelfTestLog(report)
    }

    /// Copy: the JSON on the clipboard.
    func copy() {
        guard case .results(let report) = phase, let data = try? SelfTestLog.data(report) else { return }
        copyText(String(decoding: data, as: UTF8.self))
    }

    /// The name of a display in a report (the name it has now; a display that went away keeps a generic one).
    func name(of key: String) -> String {
        displays.first { $0.key.rawValue == key }?.name
            ?? services.displays.displays.first { $0.ref.key.rawValue == key }?.name
            ?? SelfTestText.unknownDisplay
    }

    /// The report's displays in the sheet's order.
    func orderedResults(_ report: SelfTestReport) -> [(key: String, results: [SelfTestStrategyResult])] {
        let order = displays.map(\.key.rawValue)
        return report.displays.sorted { lhs, rhs in
            (order.firstIndex(of: lhs.key) ?? .max, lhs.key) < (order.firstIndex(of: rhs.key) ?? .max, rhs.key)
        }.map { (key: $0.key, results: $0.value) }
    }

    // MARK: Private

    private func refreshProgress() {
        guard phase == .running else { return }
        let order = displays.map(\.key).filter(chosen.contains)
        progress = SelfTestProgress.make(displays: order, plan: plan, everyMethod: everyMethod,
                                         secondsPerRung: Double(options.secondsPerStrategy) + 1,
                                         events: services.journal.snapshot(), since: startedAt,
                                         now: services.time.now.sinceOrigin.timeInterval)
    }

    private func finish(_ report: SelfTestReport) {
        ticker?.cancel()
        ticker = nil
        run = nil
        phase = .results(report)
        log.info("self-test finished: \(report.displays.count, privacy: .public) display(s)")
        guard let folder = archiveFolder else { return }
        Task {
            do {
                try await SelfTestLog.archive(report, in: folder)
            } catch {
                let failure = error as NSError
                log.error("self-test log not kept: \(failure.domain, privacy: .public) \(failure.code, privacy: .public) (\(failure.localizedDescription, privacy: .private))")
            }
        }
    }

    /// The general pasteboard.
    static func copyToPasteboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}
