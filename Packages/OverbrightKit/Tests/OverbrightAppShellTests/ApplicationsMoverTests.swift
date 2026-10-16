// OverbrightAppShellTests/ApplicationsMoverTests.swift — "Move Overbright to the Applications folder?" (DESIGN.md §4.4,
// §12.4; ARCHITECTURE.md §7.4): asked only outside /Applications or for a translocated copy, Not Now remembered per
// version, the move itself in a temporary folder (no real app is moved, no alert is shown, nothing is relaunched). A
// successful move relaunches and quits before anything else of the launch can run; a failed relaunch puts the bundle
// back, says so and carries on. The real quit is checked in a child process (an exit test).
import Darwin
import Foundation
import OverbrightCore
import Testing
@testable import OverbrightAppShell

private let home = URL(filePath: "/Users/me", directoryHint: .isDirectory)

/// A scripted user and system: the answers given, and what the mover did, in order.
@MainActor private final class Script {
    enum Event: Equatable { case asked, failureShown, relaunched(String), quit }

    var answer: ApplicationsMover.Answer = .notNow
    /// The error the relaunch throws (nil: LaunchServices launched the moved copy).
    var relaunchError: (any Error)?
    private(set) var events: [Event] = []

    var asked: Int { events.filter { $0 == .asked }.count }
    var failures: Int { events.filter { $0 == .failureShown }.count }
    var relaunched: [String] { events.compactMap { if case .relaunched(let path) = $0 { path } else { nil } } }
    var quits: Int { events.filter { $0 == .quit }.count }

    var prompts: ApplicationsMover.Prompts {
        ApplicationsMover.Prompts(ask: { self.events.append(.asked); return self.answer },
                                  reportFailure: { self.events.append(.failureShown) })
    }
    func relaunch(_ url: URL) throws {
        events.append(.relaunched(url.standardizedFileURL.path(percentEncoded: false)))
        if let relaunchError { throw relaunchError }
    }
    func quit() { events.append(.quit) }
    /// Older copies are removed, never put in the user's Trash.
    nonisolated func trash(_ url: URL) throws { try FileManager.default.removeItem(at: url) }

    func mover(settings: SettingsStore, bundle: URL, applications: URL,
               arguments: [String] = ["Overbright"]) -> ApplicationsMover {
        ApplicationsMover(settings: settings, bundleURL: bundle, version: "0.1.0", arguments: LaunchArguments(arguments),
                          destinationFolder: applications, prompts: prompts, relaunch: relaunch, quit: quit,
                          trash: trash)
    }
}

/// A fresh folder in the temporary directory (`overbright-mover-<name>`) with an `Overbright.app` bundle (one file
/// inside) carrying a quarantine flag, and an empty "Applications" folder.
private func sandbox(_ name: String = UUID().uuidString) throws -> (bundle: URL, applications: URL) {
    let root = sandboxRoot(name)
    let downloads = root.appending(path: "Downloads", directoryHint: .isDirectory)
    let applications = root.appending(path: "Applications", directoryHint: .isDirectory)
    let bundle = downloads.appending(path: "Overbright.app", directoryHint: .isDirectory)
    let contents = bundle.appending(path: "Contents", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: applications, withIntermediateDirectories: true)
    let info = contents.appending(path: "Info.plist")
    try Data("<plist/>".utf8).write(to: info)
    for path in [bundle.path(percentEncoded: false), info.path(percentEncoded: false)] {
        let flag = "0083;00000000;Safari;"
        _ = flag.withCString { setxattr(path, BundleMove.quarantineAttribute, $0, strlen($0), 0, 0) }
    }
    return (bundle, applications)
}

private func sandboxRoot(_ name: String) -> URL {
    FileManager.default.temporaryDirectory.appending(path: "overbright-mover-\(name)", directoryHint: .isDirectory)
}

private func hasQuarantine(_ url: URL) -> Bool {
    getxattr(url.path(percentEncoded: false), BundleMove.quarantineAttribute, nil, 0, 0, 0) >= 0
}

private func exists(_ url: URL) -> Bool { FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) }

private struct LaunchRefused: Error {}

@MainActor @Suite struct ApplicationsMoverTests {
    /// Outside /Applications (Downloads, a disk image) or translocated → ask; inside either Applications folder → never.
    @Test func offersOnlyOutsideApplicationsOrWhenTranslocated() {
        func offers(_ path: String) -> Bool {
            ApplicationsMover.shouldOffer(bundleURL: URL(filePath: path), version: "0.1.0", declinedVersion: nil,
                                          isQARun: false, home: home)
        }
        #expect(offers("/Users/me/Downloads/Overbright.app"))
        #expect(offers("/Volumes/Overbright 0.1.0/Overbright.app"))
        #expect(offers("/private/var/folders/xy/T/AppTranslocation/1234-ABCD/d/Overbright.app"))
        #expect(offers("/Users/me/Desktop/Overbright.app"))
        #expect(!offers("/Applications/Overbright.app"))
        #expect(!offers("/Applications/Utilities/Overbright.app"))
        #expect(!offers("/Users/me/Applications/Overbright.app"))
        #expect(offers("/ApplicationsBackup/Overbright.app"))                     // a prefix is not the folder
        #expect(!offers("/Users/me/Downloads/xctest"))                            // not an app bundle (tests, tools)
    }

    /// "Not Now" is remembered per version: asked again after an update. A Debug QA run never asks.
    @Test func notNowIsRememberedPerVersion() {
        let downloads = URL(filePath: "/Users/me/Downloads/Overbright.app")
        #expect(!ApplicationsMover.shouldOffer(bundleURL: downloads, version: "0.1.0", declinedVersion: "0.1.0",
                                               isQARun: false, home: home))
        #expect(ApplicationsMover.shouldOffer(bundleURL: downloads, version: "0.2.0", declinedVersion: "0.1.0",
                                              isQARun: false, home: home))
        #expect(!ApplicationsMover.shouldOffer(bundleURL: downloads, version: "0.2.0", declinedVersion: nil,
                                               isQARun: true, home: home))
    }

    @Test func notNowStoresTheVersionAndAsksOnce() {
        let settings = SettingsStore(defaults: InMemoryDefaults())
        let script = Script()
        let mover = script.mover(settings: settings, bundle: URL(filePath: "/Users/me/Downloads/Overbright.app"),
                                 applications: URL(filePath: "/nonexistent"))
        mover.offerIfNeeded()
        #expect(script.asked == 1 && settings[OnboardingSettings.declinedMoveVersion] == "0.1.0")
        mover.offerIfNeeded()                                                     // this version: not again
        #expect(script.events == [.asked])
    }

    @Test func aQARunNeverAsks() {
        let settings = SettingsStore(defaults: InMemoryDefaults())
        let script = Script()
        let mover = script.mover(settings: settings, bundle: URL(filePath: "/Users/me/Downloads/Overbright.app"),
                                 applications: URL(filePath: "/nonexistent"),
                                 arguments: ["Overbright", "--qa-simulate", "--qa-defaults-suite", "x"])
        mover.offerIfNeeded()
        #expect(script.events.isEmpty && settings[OnboardingSettings.declinedMoveVersion] == nil)
    }

    /// "Move": the bundle moves into the folder, an older copy goes to the Trash, the quarantine flag goes, the moved
    /// copy is relaunched, and this one quits right after: the quit is the last thing the mover does, with nothing
    /// shown and nothing stored.
    @Test func moveMovesClearsQuarantineRelaunchesAndQuits() throws {
        let (bundle, applications) = try sandbox()
        defer { try? FileManager.default.removeItem(at: applications.deletingLastPathComponent()) }
        let older = applications.appending(path: "Overbright.app", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: older, withIntermediateDirectories: true)
        let settings = SettingsStore(defaults: InMemoryDefaults())
        let script = Script()
        script.answer = .move
        script.mover(settings: settings, bundle: bundle, applications: applications).offerIfNeeded()
        let moved = applications.appending(path: "Overbright.app", directoryHint: .isDirectory)
        #expect(script.events == [.asked, .relaunched(moved.standardizedFileURL.path(percentEncoded: false)), .quit])
        #expect(!exists(bundle))                                                  // moved, not copied
        #expect(exists(moved.appending(path: "Contents/Info.plist")))
        #expect(!hasQuarantine(moved) && !hasQuarantine(moved.appending(path: "Contents/Info.plist")))
        #expect(settings[OnboardingSettings.declinedMoveVersion] == nil)
    }

    /// LaunchServices refuses the moved copy: it goes back where it was (the running process's bundle exists again),
    /// the failure alert shows, and the launch carries on (no quit).
    @Test func aFailedRelaunchPutsTheBundleBackSaysSoAndCarriesOn() throws {
        let (bundle, applications) = try sandbox()
        defer { try? FileManager.default.removeItem(at: applications.deletingLastPathComponent()) }
        let settings = SettingsStore(defaults: InMemoryDefaults())
        let script = Script()
        script.answer = .move
        script.relaunchError = LaunchRefused()
        script.mover(settings: settings, bundle: bundle, applications: applications).offerIfNeeded()
        #expect(script.events.count == 3 && script.relaunched.count == 1 && script.failures == 1 && script.quits == 0)
        #expect(script.events.last == .failureShown)
        #expect(exists(bundle.appending(path: "Contents/Info.plist")))
        #expect(!exists(applications.appending(path: "Overbright.app")))
        #expect(settings[OnboardingSettings.declinedMoveVersion] == nil)
    }

    /// The bundle cannot go back (its folder became read-only): this copy cannot run from a path that is gone, so it
    /// quits after the alert.
    @Test func aBundleThatCannotGoBackQuitsAfterTheAlert() throws {
        let (bundle, applications) = try sandbox()
        let downloads = bundle.deletingLastPathComponent()
        defer {
            try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: downloads.path(percentEncoded: false))
            try? FileManager.default.removeItem(at: applications.deletingLastPathComponent())
        }
        let settings = SettingsStore(defaults: InMemoryDefaults())
        let script = Script()
        script.answer = .move
        script.relaunchError = LaunchRefused()
        let mover = ApplicationsMover(
            settings: settings, bundleURL: bundle, version: "0.1.0", arguments: LaunchArguments(["Overbright"]),
            destinationFolder: applications, prompts: script.prompts,
            relaunch: { url in
                // The folder the bundle came from turns read-only between the move and the failed relaunch.
                try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: downloads.path(percentEncoded: false))
                try script.relaunch(url)
            },
            quit: script.quit, trash: script.trash)
        mover.offerIfNeeded()
        #expect(script.failures == 1 && script.events.last == .quit)
        #expect(!exists(bundle) && exists(applications.appending(path: "Overbright.app")))
    }

    /// A translocated or read-only source is copied (it cannot be removed), quarantine cleared on the copy only; when
    /// the relaunch of the copy fails, the copy goes (to the Trash in the app) and the source stays.
    @Test func copyOnlyKeepsTheSourceAndAFailedRelaunchRemovesTheCopy() throws {
        let (bundle, applications) = try sandbox()
        defer { try? FileManager.default.removeItem(at: applications.deletingLastPathComponent()) }
        let trash: (URL) throws -> Void = { try FileManager.default.removeItem(at: $0) }
        let moved = try BundleMove.perform(bundle, into: applications, copyOnly: true, trash: trash)
        #expect(exists(bundle) && hasQuarantine(bundle))
        #expect(!hasQuarantine(moved))
        #expect(BundleMove.putBack(moved, to: bundle, trash: trash))
        #expect(exists(bundle) && !exists(moved))
    }

    /// A folder that cannot be written: the failure alert, no relaunch, no quit, nothing remembered.
    @Test func aFailedMoveSaysSoAndCarriesOn() throws {
        let (bundle, applications) = try sandbox()
        defer {
            try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: applications.path(percentEncoded: false))
            try? FileManager.default.removeItem(at: applications.deletingLastPathComponent())
        }
        try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: applications.path(percentEncoded: false))
        let settings = SettingsStore(defaults: InMemoryDefaults())
        let script = Script()
        script.answer = .move
        script.mover(settings: settings, bundle: bundle, applications: applications).offerIfNeeded()
        #expect(script.events == [.asked, .failureShown])
        #expect(exists(bundle))
    }

    /// The app's own quit after a relaunch ends the process at once with success: whatever the launch would do after
    /// `offerIfNeeded()` never runs (here: a failing exit). Run in a child process, in a temporary folder named after
    /// this process, which removes it afterwards.
    @Test func theRealQuitEndsTheProcessBeforeTheLaunchGoesOn() async {
        defer { try? FileManager.default.removeItem(at: sandboxRoot("exit-\(getpid())")) }
        await #expect(processExitsWith: .success) {
            await MainActor.run {
                guard let (bundle, applications) = try? sandbox("exit-\(getppid())") else { exit(EX_IOERR) }
                let mover = ApplicationsMover(
                    settings: SettingsStore(defaults: InMemoryDefaults()), bundleURL: bundle, version: "0.1.0",
                    arguments: LaunchArguments(["Overbright"]), destinationFolder: applications,
                    prompts: ApplicationsMover.Prompts(ask: { .move }, reportFailure: { exit(EX_SOFTWARE) }),
                    relaunch: { _ in }, quit: ApplicationsMover.exitAfterRelaunch,
                    trash: { try FileManager.default.removeItem(at: $0) })
                mover.offerIfNeeded()
                exit(EX_SOFTWARE)                                                 // the rest of the launch
            }
        }
    }
}
