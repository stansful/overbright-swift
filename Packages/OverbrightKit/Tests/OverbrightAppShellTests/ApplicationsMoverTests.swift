// OverbrightAppShellTests/ApplicationsMoverTests.swift — "Move Overbright to the Applications folder?" (DESIGN.md §4.4,
// §12.4; ARCHITECTURE.md §7.4): asked only outside /Applications or for a translocated copy, Not Now remembered per
// version, the move itself in a temporary folder (no real app is moved, no alert is shown, nothing is relaunched). A
// successful move relaunches and quits before anything else of the launch can run; a failed relaunch puts the bundle
// back (and the older copy back from the Trash), says so and carries on; a bundle that cannot go back stays in
// Applications, and the alert says so. Esc answers "Not Now". The real quit is checked in a child process (an exit test).
import AppKit
import Darwin
import Foundation
import OverbrightCore
import Testing
@testable import OverbrightAppShell

private let home = URL(filePath: "/Users/me", directoryHint: .isDirectory)

/// A scripted user and system: the answers given, and what the mover did, in order.
@MainActor private final class Script {
    enum Event: Equatable { case asked, failureShown, strandedShown, relaunched(String), quit }

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
                                  reportFailure: { self.events.append(.failureShown) },
                                  reportStranded: { self.events.append(.strandedShown) })
    }
    func relaunch(_ url: URL) throws {
        events.append(.relaunched(url.standardizedFileURL.path(percentEncoded: false)))
        if let relaunchError { throw relaunchError }
    }
    func quit() { events.append(.quit) }
    /// Older copies go to a "Trash" folder next to the sandbox's Applications folder, never to the user's Trash.
    nonisolated func trash(_ url: URL) throws -> URL? { try sandboxTrash(url) }

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

/// The sandbox's stand-in for the Trash: `<sandbox>/Trash/<UUID>/<name>`; returns the new location, as the Trash does.
private nonisolated func sandboxTrash(_ url: URL) throws -> URL? {
    let folder = url.deletingLastPathComponent().deletingLastPathComponent()
        .appending(path: "Trash/\(UUID().uuidString)", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    let trashed = folder.appending(path: url.lastPathComponent, directoryHint: .isDirectory)
    try FileManager.default.moveItem(at: url, to: trashed)
    return trashed
}

/// An older `Overbright.app` in `applications` holding the file `Contents/older` (so tests tell the copies apart).
private func olderCopy(in applications: URL) throws -> URL {
    let older = applications.appending(path: "Overbright.app", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: older.appending(path: "Contents", directoryHint: .isDirectory),
                                            withIntermediateDirectories: true)
    try Data("older".utf8).write(to: older.appending(path: "Contents/older"))
    return older
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
        _ = try olderCopy(in: applications)
        let settings = SettingsStore(defaults: InMemoryDefaults())
        let script = Script()
        script.answer = .move
        script.mover(settings: settings, bundle: bundle, applications: applications).offerIfNeeded()
        let moved = applications.appending(path: "Overbright.app", directoryHint: .isDirectory)
        #expect(script.events == [.asked, .relaunched(moved.standardizedFileURL.path(percentEncoded: false)), .quit])
        #expect(!exists(bundle))                                                  // moved, not copied
        #expect(exists(moved.appending(path: "Contents/Info.plist")))
        #expect(!hasQuarantine(moved) && !hasQuarantine(moved.appending(path: "Contents/Info.plist")))
        #expect(!exists(moved.appending(path: "Contents/older")))                // the older copy is in the Trash
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

    /// The move had put an older copy in the Trash: after the failed relaunch the bundle goes back, and the older copy
    /// comes back to Applications from the Trash (WP0b left it there).
    @Test func aFailedRelaunchBringsTheOlderCopyBackFromTheTrash() throws {
        let (bundle, applications) = try sandbox()
        defer { try? FileManager.default.removeItem(at: applications.deletingLastPathComponent()) }
        let older = try olderCopy(in: applications)
        let script = Script()
        script.answer = .move
        script.relaunchError = LaunchRefused()
        script.mover(settings: SettingsStore(defaults: InMemoryDefaults()), bundle: bundle, applications: applications)
            .offerIfNeeded()
        #expect(script.failures == 1 && script.quits == 0)
        #expect(exists(bundle.appending(path: "Contents/Info.plist")))
        #expect(exists(older.appending(path: "Contents/older")))                 // back in Applications
        #expect(!exists(older.appending(path: "Contents/Info.plist")))           // and not the moved bundle
    }

    /// `putBack` of a copy (the original stayed): the copy goes through the trash, the older copy comes back.
    @Test func undoingACopyRestoresTheOlderCopy() throws {
        let (bundle, applications) = try sandbox()
        defer { try? FileManager.default.removeItem(at: applications.deletingLastPathComponent()) }
        let older = try olderCopy(in: applications)
        let placement = try BundleMove.perform(bundle, into: applications, copyOnly: true, trash: sandboxTrash)
        #expect(placement.trashedOlderCopy != nil && !exists(older.appending(path: "Contents/older")))
        let undo = BundleMove.putBack(placement, to: bundle, trash: sandboxTrash)
        #expect(undo == BundleMove.Undo(originalExists: true, olderCopyRestored: true))
        #expect(exists(older.appending(path: "Contents/older")) && exists(bundle))
    }

    /// The bundle cannot go back (its folder became read-only): this copy cannot run from a path that is gone, so it
    /// quits after an alert that says Overbright is in Applications now (not that it "couldn't be moved"); the older
    /// copy stays in the Trash, because the new one has its place.
    @Test func aBundleThatCannotGoBackQuitsAfterTheAlert() throws {
        let (bundle, applications) = try sandbox()
        let downloads = bundle.deletingLastPathComponent()
        defer {
            try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: downloads.path(percentEncoded: false))
            try? FileManager.default.removeItem(at: applications.deletingLastPathComponent())
        }
        _ = try olderCopy(in: applications)
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
        #expect(script.failures == 0 && script.events.suffix(2) == [.strandedShown, .quit])
        #expect(!exists(bundle) && exists(applications.appending(path: "Overbright.app/Contents/Info.plist")))
        #expect(!exists(applications.appending(path: "Overbright.app/Contents/older")))
    }

    /// A translocated or read-only source is copied (it cannot be removed), quarantine cleared on the copy only; when
    /// the relaunch of the copy fails, the copy goes (to the Trash in the app) and the source stays.
    @Test func copyOnlyKeepsTheSourceAndAFailedRelaunchRemovesTheCopy() throws {
        let (bundle, applications) = try sandbox()
        defer { try? FileManager.default.removeItem(at: applications.deletingLastPathComponent()) }
        let placement = try BundleMove.perform(bundle, into: applications, copyOnly: true, trash: sandboxTrash)
        let moved = placement.moved
        #expect(exists(bundle) && hasQuarantine(bundle))
        #expect(!hasQuarantine(moved) && placement.trashedOlderCopy == nil)
        #expect(BundleMove.putBack(placement, to: bundle, trash: sandboxTrash) == BundleMove.Undo(originalExists: true))
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
                    prompts: ApplicationsMover.Prompts(ask: { .move }, reportFailure: { exit(EX_SOFTWARE) },
                                                       reportStranded: { exit(EX_SOFTWARE) }),
                    relaunch: { _ in }, quit: ApplicationsMover.exitAfterRelaunch, trash: { try sandboxTrash($0) })
                mover.offerIfNeeded()
                exit(EX_SOFTWARE)                                                 // the rest of the launch
            }
        }
    }

    /// The offer's alert (DESIGN.md §12.4): [Move to Applications] is the default (Return), and Esc answers "Not Now"
    /// (NSAlert gives Escape only to a button titled Cancel). Built, never shown.
    @Test func escapeAnswersNotNow() {
        let alert = ApplicationsMover.askAlert()
        #expect(alert.buttons.map(\.title) == ["Move to Applications", "Not Now"])
        #expect(alert.buttons[0].keyEquivalent == "\r")
        #expect(alert.buttons[1].keyEquivalent == "\u{1b}")
        #expect(ApplicationsMover.strandedAlert().buttons.map(\.title) == ["OK"])
        #expect(ApplicationsMover.strandedAlert().messageText.hasPrefix("Overbright is now in the Applications folder"))
    }
}
