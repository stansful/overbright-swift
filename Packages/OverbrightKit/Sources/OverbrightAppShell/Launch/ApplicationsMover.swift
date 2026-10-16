// OverbrightAppShell/Launch/ApplicationsMover.swift — "Move to Applications?" for a launch from elsewhere.
// ARCHITECTURE.md §7.4 (launch order: after the single-instance check, before Welcome), §10.2; DESIGN.md §4.4, §12.4.
// Seam written by WP0a (§10.0): `init(settings:)` and the instance method `offerIfNeeded()` are fixed; WP0b wrote the
// body (`ApplicationsMoverTests`).
//
// Shortcuts actions and opening at login work only from Applications, so a copy launched from Downloads, a disk image
// or a translocated path asks once: [Move to Applications] [Not Now]. "Not Now" is remembered for this version
// (`OnboardingSettings.declinedMoveVersion`) and asked again after an update. Moving puts the bundle in /Applications
// (replacing an older copy, which goes to the Trash), clears the quarantine flag of the copy the user chose to move,
// relaunches it from there and quits this one; the new process waits for this one to exit (`SingleInstance`,
// `--after-move`). A failure says so and the app carries on from where it is. Debug QA runs (any `--qa-…` switch)
// never ask: a modal alert would block their scripted surfaces.
import AppKit
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

    private let settings: SettingsStore
    private let bundleURL: URL
    private let version: String
    private let arguments: LaunchArguments
    private let destinationFolder: URL
    private let prompts: Prompts
    private let relaunch: @MainActor (URL) -> Void
    private let trash: (URL) throws -> Void

    /// A mover that remembers "Not Now" in `settings`.
    convenience init(settings: SettingsStore) {
        self.init(settings: settings, bundleURL: Bundle.main.bundleURL, version: AppInfo.current().version,
                  arguments: .current, destinationFolder: URL(filePath: "/Applications", directoryHint: .isDirectory),
                  prompts: .alerts, relaunch: Self.relaunch(from:), trash: BundleMove.moveToTrash)
    }

    /// Tests inject the bundle, the folders, the prompts, the relaunch and what happens to an older copy.
    init(settings: SettingsStore, bundleURL: URL, version: String, arguments: LaunchArguments, destinationFolder: URL,
         prompts: Prompts, relaunch: @escaping @MainActor (URL) -> Void, trash: @escaping (URL) throws -> Void) {
        self.settings = settings; self.bundleURL = bundleURL; self.version = version; self.arguments = arguments
        self.destinationFolder = destinationFolder; self.prompts = prompts; self.relaunch = relaunch
        self.trash = trash
    }

    /// Asks the user to move Overbright to /Applications when it runs from elsewhere, and moves it on "Move".
    func offerIfNeeded() {
        guard Self.shouldOffer(bundleURL: bundleURL, version: version,
                               declinedVersion: settings[OnboardingSettings.declinedMoveVersion],
                               isQARun: !arguments.debugOnlySwitches.isEmpty) else { return }
        switch prompts.ask() {
        case .notNow:
            settings[OnboardingSettings.declinedMoveVersion] = version
            log.info("move to Applications: not now (\(self.version, privacy: .public))")
        case .move:
            do {
                let moved = try BundleMove.perform(bundleURL, into: destinationFolder,
                                                   copyOnly: LoginItemController.isTranslocated(bundleURL), trash: trash)
                log.info("moved to Applications; relaunching")
                relaunch(moved)
            } catch {
                log.error("move to Applications failed: \(error.localizedDescription, privacy: .public)")
                prompts.reportFailure()
            }
        }
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

    // MARK: Relaunch

    /// Opens the moved copy as a new instance (it waits for this one to quit, `--after-move`), then quits.
    private static func relaunch(from url: URL) {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        configuration.arguments = [SingleInstance.afterMoveArgument, String(ProcessInfo.processInfo.processIdentifier)]
        // The completion handler runs on a background queue (§8.1 rule 2): hop to the main actor for everything.
        NSWorkspace.shared.openApplication(at: url, configuration: configuration) { @Sendable _, error in
            let failure = error?.localizedDescription
            Task { @MainActor in
                if let failure { log.error("relaunch after the move failed: \(failure, privacy: .public)") }
                NSApp.terminate(nil)
            }
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
