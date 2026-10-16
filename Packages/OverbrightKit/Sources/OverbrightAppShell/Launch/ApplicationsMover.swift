// OverbrightAppShell/Launch/ApplicationsMover.swift — "Move to Applications?" for a launch from elsewhere.
// ARCHITECTURE.md §7.4 (launch order: after the single-instance check, before Welcome), §9.2 rule 8, §10.2;
// DESIGN.md §4.4, §12.4. Seam written by WP0a (§10.0): `init(settings:)` and the instance method `offerIfNeeded()` are
// fixed; WP0b wrote the body (`ApplicationsMoverTests`).
//
// Shortcuts actions and opening at login work only from Applications, so a copy launched from Downloads, a disk image
// or a translocated path asks once: [Move to Applications] [Not Now]. "Not Now" is remembered for this version
// (`OnboardingSettings.declinedMoveVersion`) and asked again after an update. Moving puts the bundle in /Applications
// (replacing an older copy, which goes to the Trash) and clears the quarantine flag of the copy the user chose to move.
//
// A successful move never returns into the launch. The bundle this process runs from may be gone (a move from
// Downloads renames it), and every module's resource bundle is looked up under `Bundle.main` on first use (SwiftPM's
// accessor stops the process when it finds none), so nothing after the move may run here. The mover relaunches the
// moved copy, waits for LaunchServices' answer (at most `relaunchWait`; no answer counts as launched) and exits at once
// (`quit`, `exit(EXIT_SUCCESS)`): no service has started, no window is open and no setting has been written yet. The new
// process waits for this one to exit (`SingleInstance`, `--after-move`) and never hands over to it.
//
// When the relaunch fails, a moved bundle goes back where it was (a copy in Applications goes to the Trash), the failure
// alert says so, and the app carries on from where it is. Only if the bundle cannot be put back does this copy quit
// after the alert, because it cannot run from a path that no longer exists. Debug QA runs (any `--qa-…` switch) never
// ask: a modal alert would block their scripted surfaces. Failures are logged with the error's domain and code; the
// description, which names the user's folders, stays `.private` (§9.2 rule 8).
import AppKit
import Darwin
import Foundation
import OverbrightCore
import os

private let log = Log.logger(.app)

/// The move-to-Applications offer, run before Welcome.
final class ApplicationsMover {
    /// The user's answer.
    enum Answer: Equatable { case move, notNow }

    /// What the mover asks and shows (alerts in the app, fakes in tests).
    struct Prompts {
        /// "Move Overbright to the Applications folder?"
        var ask: @MainActor () -> Answer
        /// "Overbright couldn't be moved…"
        var reportFailure: @MainActor () -> Void
    }

    /// The longest wait for LaunchServices' answer to the relaunch.
    static let relaunchWait: Duration = .seconds(10)

    private let settings: SettingsStore
    private let bundleURL: URL
    private let version: String
    private let arguments: LaunchArguments
    private let destinationFolder: URL
    private let prompts: Prompts
    private let relaunch: @MainActor (URL) throws -> Void
    private let quit: @MainActor () -> Void
    private let trash: (URL) throws -> Void

    /// A mover that remembers "Not Now" in `settings`.
    convenience init(settings: SettingsStore) {
        self.init(settings: settings, bundleURL: Bundle.main.bundleURL, version: AppInfo.current().version,
                  arguments: .current, destinationFolder: URL(filePath: "/Applications", directoryHint: .isDirectory),
                  prompts: .alerts, relaunch: Self.relaunch(from:), quit: Self.exitAfterRelaunch,
                  trash: BundleMove.moveToTrash)
    }

    /// Tests inject the bundle, the folders, the prompts, the relaunch (it throws LaunchServices' error), the quit
    /// that follows a relaunch, and what happens to an older copy.
    init(settings: SettingsStore, bundleURL: URL, version: String, arguments: LaunchArguments, destinationFolder: URL,
         prompts: Prompts, relaunch: @escaping @MainActor (URL) throws -> Void, quit: @escaping @MainActor () -> Void,
         trash: @escaping (URL) throws -> Void) {
        self.settings = settings; self.bundleURL = bundleURL; self.version = version; self.arguments = arguments
        self.destinationFolder = destinationFolder; self.prompts = prompts; self.relaunch = relaunch
        self.quit = quit; self.trash = trash
    }

    /// Asks the user to move Overbright to /Applications when it runs from elsewhere. On "Move" it moves, relaunches
    /// from there and quits (it never returns then, see the file header); on a failure it says so and returns.
    func offerIfNeeded() {
        guard Self.shouldOffer(bundleURL: bundleURL, version: version,
                               declinedVersion: settings[OnboardingSettings.declinedMoveVersion],
                               isQARun: !arguments.debugOnlySwitches.isEmpty) else { return }
        switch prompts.ask() {
        case .notNow:
            settings[OnboardingSettings.declinedMoveVersion] = version
            log.info("move to Applications: not now (\(self.version, privacy: .public))")
        case .move:
            moveAndRelaunch()
        }
    }

    private func moveAndRelaunch() {
        let moved: URL
        do {
            moved = try BundleMove.perform(bundleURL, into: destinationFolder,
                                           copyOnly: LoginItemController.isTranslocated(bundleURL), trash: trash)
        } catch {
            let failure = error as NSError
            log.error("move to Applications failed: \(failure.domain, privacy: .public) \(failure.code, privacy: .public) (\(failure.localizedDescription, privacy: .private))")
            prompts.reportFailure()
            return
        }
        do {
            try relaunch(moved)
        } catch {
            let failure = error as NSError
            log.error("relaunch from Applications failed: \(failure.domain, privacy: .public) \(failure.code, privacy: .public) (\(failure.localizedDescription, privacy: .private))")
            let canCarryOn = BundleMove.putBack(moved, to: bundleURL, trash: trash)
            prompts.reportFailure()
            if canCarryOn { return }
            log.error("move to Applications: the bundle could not be put back; this copy quits")
            quit()
            return
        }
        log.info("moved to Applications and relaunched from there; this copy quits before anything starts")
        quit()
    }

    // MARK: Pure helpers (unit-tested)

    /// Whether to ask: an app bundle outside the Applications folders (/Applications and ~/Applications, any depth),
    /// or any translocated copy; not when "Not Now" was answered for this version; never in a Debug QA run.
    nonisolated static func shouldOffer(bundleURL: URL, version: String, declinedVersion: String?, isQARun: Bool,
                                        home: URL = FileManager.default.homeDirectoryForCurrentUser) -> Bool {
        guard !isQARun, bundleURL.pathExtension == "app", declinedVersion != version else { return false }
        if LoginItemController.isTranslocated(bundleURL) { return true }
        return !isInApplications(bundleURL, home: home)
    }

    /// Inside /Applications or ~/Applications (symbolic links resolved).
    nonisolated static func isInApplications(_ url: URL, home: URL) -> Bool {
        let path = url.resolvingSymlinksInPath().standardizedFileURL.path(percentEncoded: false)
        let folders = ["/Applications", home.appending(path: "Applications").standardizedFileURL.path(percentEncoded: false)]
        return folders.contains { folder in path.hasPrefix(folder.hasSuffix("/") ? folder : folder + "/") }
    }

    // MARK: Relaunch and quit

    /// Ends this process right after the relaunch, before anything of the launch runs (the file header says why).
    static func exitAfterRelaunch() {
        exit(EXIT_SUCCESS)
    }

    /// Opens the moved copy as a new instance (it waits for this one to exit, `--after-move`) and blocks until
    /// LaunchServices answers, at most `relaunchWait`. Throws the error LaunchServices reports. No answer in time counts
    /// as launched: the new copy is most likely starting, and this one must not go on from a bundle that moved.
    private static func relaunch(from url: URL) throws {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        configuration.arguments = [SingleInstance.afterMoveArgument, String(ProcessInfo.processInfo.processIdentifier)]
        let answer = LaunchAnswer()
        // The completion handler runs on a concurrent queue (§8.1 rule 2), so this launch-time wait on the main thread
        // cannot hold it up.
        NSWorkspace.shared.openApplication(at: url, configuration: configuration) { @Sendable _, error in
            answer.finish(error)
        }
        switch answer.wait(atMost: relaunchWait) {
        case .success?: return
        case .failure(let error)?: throw error
        case nil: log.error("relaunch from Applications: no answer from LaunchServices in time; quitting as launched")
        }
    }

    /// LaunchServices' answer to the relaunch, handed from its queue to the waiting main thread.
    private nonisolated final class LaunchAnswer: Sendable {
        private let answered = DispatchSemaphore(value: 0)
        private let error = OSAllocatedUnfairLock<(any Error)?>(initialState: nil)

        /// Called once, from the completion handler.
        func finish(_ error: (any Error)?) {
            self.error.withLock { $0 = error }
            answered.signal()
        }

        /// The answer, or nil when none came within `limit`.
        func wait(atMost limit: Duration) -> Result<Void, any Error>? {
            guard answered.wait(timeout: .now() + limit.timeInterval) == .success else { return nil }
            if let error = error.withLock({ $0 }) { return .failure(error) }
            return .success(())
        }
    }
}

extension ApplicationsMover.Prompts {
    /// The alerts of DESIGN.md §12.4.
    static var alerts: ApplicationsMover.Prompts {
        ApplicationsMover.Prompts(
            ask: {
                let alert = NSAlert()
                alert.messageText = String(localized: "Move Overbright to the Applications folder?", bundle: .module,
                                           comment: "Move to Applications alert: title, shown at launch outside Applications")
                alert.informativeText = String(localized: "Shortcuts actions and opening at login work only from Applications.",
                                               bundle: .module, comment: "Move to Applications alert: message")
                alert.addButton(withTitle: String(localized: "Move to Applications", bundle: .module,
                                                  comment: "Move to Applications alert: default button (title case)"))
                alert.addButton(withTitle: String(localized: "Not Now", bundle: .module,
                                                  comment: "Move to Applications alert: button that keeps the app where it is; asked again after an update"))
                NSApp.activate()
                return alert.runModal() == .alertFirstButtonReturn ? .move : .notNow
            },
            reportFailure: {
                let alert = NSAlert()
                alert.alertStyle = .warning
                alert.messageText = String(localized: "Overbright couldn’t be moved. Drag it to the Applications folder in Finder.",
                                           bundle: .module, comment: "Move to Applications alert: the move failed")
                alert.addButton(withTitle: String(localized: "OK", bundle: .module,
                                                  comment: "Move to Applications alert: closes the failure alert"))
                alert.runModal()
            })
    }
}
