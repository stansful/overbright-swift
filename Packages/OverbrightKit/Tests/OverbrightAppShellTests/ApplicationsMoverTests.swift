// OverbrightAppShellTests/ApplicationsMoverTests.swift — "Move Overbright to the Applications folder?" (DESIGN.md §4.4,
// §12.4; ARCHITECTURE.md §7.4): asked only outside /Applications or for a translocated copy, Not Now remembered per
// version, the move itself in a temporary folder (no real app is moved, no alert is shown, nothing is relaunched).
import Darwin
import Foundation
import OverbrightCore
import Testing
@testable import OverbrightAppShell

private let home = URL(filePath: "/Users/me", directoryHint: .isDirectory)

/// A scripted user: the answers given and the failures shown.
@MainActor private final class Script {
    var answer: ApplicationsMover.Answer = .notNow
    private(set) var asked = 0
    private(set) var failures = 0
    private(set) var relaunched: [URL] = []

    var prompts: ApplicationsMover.Prompts {
        ApplicationsMover.Prompts(ask: { self.asked += 1; return self.answer }, reportFailure: { self.failures += 1 })
    }
    func relaunch(_ url: URL) { relaunched.append(url) }
    /// Older copies are removed, never put in the user's Trash.
    nonisolated func trash(_ url: URL) throws { try FileManager.default.removeItem(at: url) }
}

/// A fresh folder in the temporary directory with an `Overbright.app` bundle (one file inside) carrying a quarantine
/// flag, and an empty "Applications" folder.
private func sandbox() throws -> (bundle: URL, applications: URL) {
    let root = FileManager.default.temporaryDirectory.appending(path: "overbright-mover-\(UUID().uuidString)")
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

private func hasQuarantine(_ url: URL) -> Bool {
    getxattr(url.path(percentEncoded: false), BundleMove.quarantineAttribute, nil, 0, 0, 0) >= 0
}

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
        let mover = ApplicationsMover(settings: settings, bundleURL: URL(filePath: "/Users/me/Downloads/Overbright.app"),
                                      version: "0.1.0", arguments: LaunchArguments(["Overbright"]),
                                      destinationFolder: URL(filePath: "/nonexistent"), prompts: script.prompts,
                                      relaunch: script.relaunch, trash: script.trash)
        mover.offerIfNeeded()
        #expect(script.asked == 1 && settings[OnboardingSettings.declinedMoveVersion] == "0.1.0")
        mover.offerIfNeeded()                                                     // this version: not again
        #expect(script.asked == 1 && script.relaunched.isEmpty)
    }

    @Test func aQARunNeverAsks() {
        let settings = SettingsStore(defaults: InMemoryDefaults())
        let script = Script()
        let mover = ApplicationsMover(settings: settings, bundleURL: URL(filePath: "/Users/me/Downloads/Overbright.app"),
                                      version: "0.1.0",
                                      arguments: LaunchArguments(["Overbright", "--qa-simulate", "--qa-defaults-suite", "x"]),
                                      destinationFolder: URL(filePath: "/nonexistent"), prompts: script.prompts,
                                      relaunch: script.relaunch, trash: script.trash)
        mover.offerIfNeeded()
        #expect(script.asked == 0 && settings[OnboardingSettings.declinedMoveVersion] == nil)
    }

    /// "Move": the bundle moves into the folder, an older copy goes to the Trash, the quarantine flag goes, and the
    /// moved copy is relaunched.
    @Test func moveMovesClearsQuarantineAndRelaunches() throws {
        let (bundle, applications) = try sandbox()
        defer { try? FileManager.default.removeItem(at: applications.deletingLastPathComponent()) }
        let older = applications.appending(path: "Overbright.app", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: older, withIntermediateDirectories: true)
        let settings = SettingsStore(defaults: InMemoryDefaults())
        let script = Script()
        script.answer = .move
        let mover = ApplicationsMover(settings: settings, bundleURL: bundle, version: "0.1.0",
                                      arguments: LaunchArguments(["Overbright"]), destinationFolder: applications,
                                      prompts: script.prompts, relaunch: script.relaunch, trash: script.trash)
        mover.offerIfNeeded()
        let moved = applications.appending(path: "Overbright.app", directoryHint: .isDirectory)
        #expect(script.relaunched.map(\.standardizedFileURL) == [moved.standardizedFileURL] && script.failures == 0)
        #expect(!FileManager.default.fileExists(atPath: bundle.path(percentEncoded: false)))      // moved, not copied
        #expect(FileManager.default.fileExists(atPath: moved.appending(path: "Contents/Info.plist").path(percentEncoded: false)))
        #expect(!hasQuarantine(moved) && !hasQuarantine(moved.appending(path: "Contents/Info.plist")))
        #expect(settings[OnboardingSettings.declinedMoveVersion] == nil)
    }

    /// A translocated or read-only source is copied (it cannot be removed), quarantine cleared on the copy only.
    @Test func copyOnlyKeepsTheSource() throws {
        let (bundle, applications) = try sandbox()
        defer { try? FileManager.default.removeItem(at: applications.deletingLastPathComponent()) }
        let moved = try BundleMove.perform(bundle, into: applications, copyOnly: true,
                                           trash: { try FileManager.default.removeItem(at: $0) })
        #expect(FileManager.default.fileExists(atPath: bundle.path(percentEncoded: false)) && hasQuarantine(bundle))
        #expect(!hasQuarantine(moved))
    }

    /// A folder that cannot be written: the failure alert, no relaunch, nothing remembered.
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
        let mover = ApplicationsMover(settings: settings, bundleURL: bundle, version: "0.1.0",
                                      arguments: LaunchArguments(["Overbright"]), destinationFolder: applications,
                                      prompts: script.prompts, relaunch: script.relaunch, trash: script.trash)
        mover.offerIfNeeded()
        #expect(script.failures == 1 && script.relaunched.isEmpty)
        #expect(FileManager.default.fileExists(atPath: bundle.path(percentEncoded: false)))
    }
}
