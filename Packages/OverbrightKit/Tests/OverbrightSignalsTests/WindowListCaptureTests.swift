// OverbrightSignalsTests/WindowListCaptureTests.swift — the window-server read up to the verdict: raw entries as
// `CGWindowListCopyWindowInfo` returns them, the WindowServer's PID found while no menu bar is on screen (a full-screen
// Space), and the rules that need that absence: below the notch band, Split View, an exact cover in the background.
// ARCHITECTURE.md §7.3, §10.8.
import AppKit
import CoreGraphics
import OverbrightCore
import Testing
@testable import OverbrightSignals

/// Counts the libproc scans one `make` asks for.
private final class ScanCounter {
    var scans = 0
    var checks = 0
}

@Suite struct WindowListCaptureTests {
    typealias F = WindowFixtures
    private let msiKey = DisplayFixture.Keys.mpg322ux
    private let builtInKey = DisplayFixture.Keys.builtIn
    private let paths: [Int32: String] = [
        WindowFixtures.windowServer: WindowFixtures.windowServerPath,
        WindowFixtures.chrome: "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
        300: "/Applications/Menu Bar Tool.app/Contents/MacOS/WindowServer",
    ]

    /// A snapshot as the live read builds it: `locate` (the libproc scan) answers `located`.
    private func make(_ entries: [NSDictionary], known: Int32? = nil, located: Int32? = WindowFixtures.windowServer,
                      counter: ScanCounter = ScanCounter()) -> WindowListSnapshot {
        WindowListSnapshot.make(entries, windowServerPID: known,
                                isWindowServer: { pid in
                                    counter.checks += 1
                                    return paths[pid].map(WindowServerProcess.isWindowServerPath) ?? false
                                },
                                locate: { counter.scans += 1; return located })
    }

    private func evaluate(_ snapshot: WindowListSnapshot, _ displays: [FullScreenDetector.Display],
                          frontmost: Int32?) -> FullScreenDetector.Result {
        FullScreenDetector.evaluate(windows: snapshot.windows, displays: displays,
                                    context: F.context(frontmost: frontmost), windowServerPID: snapshot.windowServerPID)
    }

    @Test func theRecordedFullScreenSpaceHasNoMenuBarYetTheWindowServerIsKnown() {
        let counter = ScanCounter()
        let snapshot = make(F.msiChromeFullScreenEntries, counter: counter)
        #expect(snapshot.windowServerPID == F.windowServer && counter.scans == 1)
        #expect(snapshot.windows.count == 4 && snapshot.windows.allSatisfy { $0.layer == 0 && $0.ownerPID == F.chrome })
        // Chrome is not frontmost (loginwindow is, the screen is locked): only the missing menu bar makes it count.
        #expect(evaluate(snapshot, [F.msiAlone], frontmost: F.loginWindow).fullScreenDisplays == [msiKey])
        // Without the PID the menu bar would count as present and the full-screen Space would go unseen.
        let unknown = make(F.msiChromeFullScreenEntries, located: nil)
        #expect(unknown.windowServerPID == nil)
        #expect(evaluate(unknown, [F.msiAlone], frontmost: F.loginWindow).fullScreenDisplays.isEmpty)
    }

    @Test func belowTheNotchWithTheMenuBarOffScreenIsFullScreen() {
        // Native full screen on the notched built-in used alone: the app stays below the camera band, its title bar is
        // parked above the screen, and every menu-bar window is off screen.
        let entries = [F.window(F.notes, 0, -28, 1728, 28), F.window(F.notes, 0, 32, 1728, 1085)].map { F.entry($0) }
        let snapshot = make(entries)
        #expect(snapshot.windowServerPID == F.windowServer)
        #expect(evaluate(snapshot, [F.builtIn], frontmost: F.notes).fullScreenDisplays == [builtInKey])
        // The same frame with the menu bar on screen is a zoomed window.
        let zoomed = make([F.entry(F.menuBar(on: F.builtIn))] + entries)
        #expect(evaluate(zoomed, [F.builtIn], frontmost: F.notes).fullScreenDisplays.isEmpty)
    }

    @Test func splitViewWithTheMenuBarOffScreenIsFullScreen() {
        let entries = [F.window(F.notes, 0, 32, 861, 1085), F.window(F.player, 867, 32, 861, 1085)].map { F.entry($0) }
        let result = evaluate(make(entries), [F.builtIn], frontmost: F.player)
        #expect(result.fullScreenDisplays == [builtInKey])
        #expect(result.fronts[builtInKey]?.ownerPID == F.player)
    }

    @Test func anOnScreenMenuBarNamesTheWindowServerByItsExecutableWithoutAScan() {
        // A menu-bar-layer window of another process (lower PID, an executable that happens to be called
        // "WindowServer" outside /System) sits next to the real menu bar.
        let impostor = F.window(300, 0, 0, 2560, 30, layer: FullScreenDetector.menuBarLayer)
        let counter = ScanCounter()
        let windows = [impostor, F.menuBar(on: F.msiAlone), F.window(F.editor, 446, 169, 1601, 1244)]
        let snapshot = make(windows.map { F.entry($0) }, counter: counter)
        #expect(snapshot.windowServerPID == F.windowServer)
        #expect(counter.scans == 0)
    }

    @Test func aKnownPIDIsUsedAsIs() {
        let counter = ScanCounter()
        let snapshot = make(F.msiChromeFullScreenEntries, known: F.windowServer, located: nil, counter: counter)
        #expect(snapshot.windowServerPID == F.windowServer)
        #expect(counter.scans == 0 && counter.checks == 0)
    }

    @Test func malformedEntriesAndOtherLayersAreSkipped() {
        let bounds = CGRect(x: 0, y: 0, width: 10, height: 10).dictionaryRepresentation
        let noBounds: NSDictionary = [kCGWindowLayer as String: 0, kCGWindowOwnerPID as String: Int(F.notes)]
        let noOwner: NSDictionary = [kCGWindowLayer as String: 0, kCGWindowBounds as String: bounds]
        let statusItem = F.entry(F.window(F.notes, 2000, 0, 30, 24, layer: 25))
        let noAlpha: NSDictionary = [kCGWindowLayer as String: 0, kCGWindowOwnerPID as String: Int(F.notes),
                                     kCGWindowBounds as String: bounds]
        let snapshot = make([noBounds, noOwner, statusItem, noAlpha])
        #expect(snapshot.windows == [F.window(F.notes, 0, 0, 10, 10)])          // a missing alpha reads as opaque
    }

    @Test func theScanFindsTheWindowServerOnlyUnderSystem() {
        let all: [Int32] = [1, 300, F.chrome, F.windowServer]
        #expect(WindowServerProcess.locate(among: all, path: { paths[$0] }) == F.windowServer)
        #expect(WindowServerProcess.locate(among: [1, 300, F.chrome], path: { paths[$0] }) == nil)
        #expect(WindowServerProcess.isWindowServerPath(F.windowServerPath))
        #expect(!WindowServerProcess.isWindowServerPath("/Applications/WindowServer Helper.app/Contents/MacOS/Helper"))
        #expect(!WindowServerProcess.isWindowServerPath("/Users/someone/bin/WindowServer"))
    }

    // MARK: In the tracker

    @MainActor @Test func theTrackerLooksTheWindowServerUpOncePerSession() async {
        let harness = SignalsHarness()
        let platform = harness.platform
        platform.screenList = [F.builtIn]
        platform.rawWindowList = [F.window(F.notes, 0, 32, 1728, 1085)].map { F.entry($0) }
        platform.locatedWindowServer = F.windowServer
        platform.frontmost = RunningAppInfo(bundleID: "com.example.notes", processID: F.notes)
        await harness.start()
        await harness.advance(.seconds(1))
        #expect(harness.monitor.snapshot.fullScreenDisplays == [builtInKey])
        #expect(platform.windowServerHints == [nil] && platform.windowServerScans == 1)
        platform.post(NSWorkspace.activeSpaceDidChangeNotification, in: platform.workspaceCenter)
        await harness.advance(.seconds(1))
        #expect(platform.windowServerHints == [nil, F.windowServer] && platform.windowServerScans == 1)
        #expect(harness.monitor.snapshot.fullScreenDisplays == [builtInKey])
    }
}
