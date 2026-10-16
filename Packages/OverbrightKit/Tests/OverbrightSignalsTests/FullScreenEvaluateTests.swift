// OverbrightSignalsTests/FullScreenEvaluateTests.swift — the pure full-screen heuristic over the owner's window lists.
// ARCHITECTURE.md §7.3, §10.8 (fixtures: layers 0/24/2001/2004, the 30-pt menu bar window, the notch band).
import CoreGraphics
import OverbrightCore
import Testing
@testable import OverbrightSignals

@Suite struct FullScreenEvaluateTests {
    typealias F = WindowFixtures
    private let msiKey = DisplayFixture.Keys.mpg322ux
    private let builtInKey = DisplayFixture.Keys.builtIn

    private func evaluate(_ windows: [F.Window], _ displays: [FullScreenDetector.Display],
                          _ context: FullScreenDetector.Context) -> FullScreenDetector.Result {
        FullScreenDetector.evaluate(windows: windows, displays: displays, context: context, windowServerPID: F.windowServer)
    }

    @Test func theRecordedDesktopIsNotFullScreen() {
        let result = evaluate(F.msiDesktop, [F.msiAlone], F.context(frontmost: F.editor))
        #expect(result.fullScreenDisplays.isEmpty)
        #expect(result.fronts[msiKey] == FullScreenDetector.Front())
        #expect(result.frontmostDisplays == [msiKey])
    }

    @Test func theRecordedMenuBarIsTheWindowServersThirtyPointWindow() {
        let observed = FullScreenDetector.observedMenuBar(windows: F.msiDesktop, displays: [F.msiAlone],
                                                          windowServerPID: F.windowServer)
        #expect(observed == [msiKey: true])
        #expect(F.msiDesktop[0].bounds.height == 30 && F.msiDesktop[0].layer == 24)
        #expect(FullScreenDetector.observedMenuBar(windows: Array(F.msiDesktop.dropFirst()), displays: [F.msiAlone],
                                                   windowServerPID: F.windowServer) == [msiKey: false])
    }

    @Test func lockedScreenWindowsAtLayers2001And2004NeverCount() {
        // loginwindow is frontmost and its display-sized window covers the MSI exactly, at layer 2004.
        let result = evaluate(F.msiLocked, [F.msiAlone], F.context(frontmost: F.loginWindow))
        #expect(result.fullScreenDisplays.isEmpty)
        #expect(result.frontmostDisplays.isEmpty)        // loginwindow has no layer-0 window
    }

    @Test func anExactCoverByTheFrontmostAppCountsEvenWithTheMenuBar() {
        let windows = [F.menuBar(on: F.msiAlone), F.window(F.player, 0, 0, 2560, 1440)] + F.msiDesktop.dropFirst()
        let result = evaluate(windows, [F.msiAlone], F.context(frontmost: F.player))
        #expect(result.fullScreenDisplays == [msiKey])
        #expect(result.fronts[msiKey]?.ownerPID == F.player)
    }

    @Test func anExactCoverByABackgroundAppCountsOnlyWithoutTheMenuBar() {
        // A movie full screen on the MSI while the user types on the built-in (separate Spaces).
        let movie = F.window(F.player, 1728, 0, 2560, 1440)
        let typing = F.window(F.editor, 100, 100, 800, 600)
        let withMenuBar = evaluate([F.menuBar(on: F.builtIn), F.menuBar(on: F.msi), typing, movie], [F.builtIn, F.msi],
                                   F.context(frontmost: F.editor))
        #expect(withMenuBar.fullScreenDisplays.isEmpty)
        let fullScreenSpace = evaluate([F.menuBar(on: F.builtIn), typing, movie], [F.builtIn, F.msi],
                                       F.context(frontmost: F.editor))
        #expect(fullScreenSpace.fullScreenDisplays == [msiKey])
        #expect(fullScreenSpace.frontmostDisplays == [builtInKey])
    }

    @Test func belowTheNotchBandCountsOnlyWithoutTheMenuBar() {
        let belowBand = F.window(F.notes, 0, 32, 1728, 1085)
        // A zoomed window has the same frame while the menu bar shows: not full screen.
        let zoomed = evaluate([F.menuBar(on: F.builtIn), belowBand], [F.builtIn], F.context(frontmost: F.notes))
        #expect(zoomed.fullScreenDisplays.isEmpty)
        let fullScreen = evaluate([belowBand], [F.builtIn], F.context(frontmost: F.notes))
        #expect(fullScreen.fullScreenDisplays == [builtInKey])
        #expect(FullScreenDetector.coverage(belowBand.bounds, F.builtIn) == .belowBand)
        #expect(FullScreenDetector.coverage(belowBand.bounds, F.msiAlone) == nil)
    }

    @Test func ourOwnWindowsAndTheDocksNeverCount() {
        // The Compatibility overlay, Fill Light and calibration windows are full-screen windows of OUR process.
        let ours = F.window(F.ourPID, 0, 0, 2560, 1440)
        #expect(evaluate([ours], [F.msiAlone], F.context(frontmost: F.ourPID)).fullScreenDisplays.isEmpty)
        #expect(evaluate([ours], [F.msiAlone], F.context(frontmost: F.ourPID)).frontmostDisplays.isEmpty)
        let dock = F.window(F.dock, 0, 0, 2560, 1440)
        #expect(evaluate([dock], [F.msiAlone], F.context(frontmost: F.editor)).fullScreenDisplays.isEmpty)
    }

    @Test func accessoryAppsCountOnlyWhileFrontmost() {
        let shade = F.window(F.shade, 0, 0, 2560, 1440)                 // listed by NSWorkspace, not a regular app
        let background = evaluate([shade], [F.msiAlone], F.context(frontmost: F.editor))
        #expect(background.fullScreenDisplays.isEmpty)
        let front = evaluate([shade], [F.msiAlone], F.context(frontmost: F.shade))
        #expect(front.fullScreenDisplays == [msiKey])
    }

    @Test func ownersNSWorkspaceDoesNotListNeverCountUnlessFrontmost() {
        // The regular-app rule is an allowlist: a window server client NSWorkspace does not list at all is not a
        // regular app, whatever covers the display.
        let unlisted: Int32 = 7000
        let cover = F.window(unlisted, 0, 0, 2560, 1440)
        #expect(evaluate([cover], [F.msiAlone], F.context(frontmost: F.editor)).fullScreenDisplays.isEmpty)
        #expect(evaluate([F.window(unlisted, 0, 0, 1277, 1440), F.window(F.player, 1283, 0, 1277, 1440)], [F.msiAlone],
                         F.context(frontmost: F.editor)).fullScreenDisplays.isEmpty)      // nor a Split View tile
        #expect(evaluate([cover], [F.msiAlone], F.context(frontmost: unlisted)).fullScreenDisplays == [msiKey])
        // The same window of a regular app counts without the menu bar.
        #expect(evaluate([cover], [F.msiAlone], F.context(frontmost: F.editor, regular: [unlisted]))
                    .fullScreenDisplays == [msiKey])
    }

    @Test func transparentAndTitleBarWindowsNeverCount() {
        let invisible = F.window(F.player, 0, 0, 2560, 1440, alpha: 0)
        #expect(evaluate([invisible], [F.msiAlone], F.context(frontmost: F.player)).fullScreenDisplays.isEmpty)
        // A full-screen app parks its title-bar window above the screen at layer 0.
        let titleBar = F.window(F.player, 0, -32, 2560, 32)
        let movie = F.window(F.player, 0, 0, 2560, 1440)
        let result = evaluate([titleBar, movie], [F.msiAlone], F.context(frontmost: F.player))
        #expect(result.fullScreenDisplays == [msiKey])
        #expect(result.frontmostDisplays == [msiKey])
    }

    @Test func theMenuBarIsMatchedByTheWindowServersPIDNotByLayerAlone() {
        // Another app's window at the menu-bar layer, with the menu bar's exact frame, is not the menu bar.
        let impostor = F.window(F.shade, 0, 0, 2560, 30, layer: FullScreenDetector.menuBarLayer)
        let observed = FullScreenDetector.observedMenuBar(windows: [impostor], displays: [F.msiAlone],
                                                          windowServerPID: F.windowServer)
        #expect(observed == [msiKey: false])
        // An unidentified WindowServer counts the menu bar as present (only exact-and-frontmost can match then).
        let unknown = FullScreenDetector.observedMenuBar(windows: [], displays: [F.msiAlone], windowServerPID: nil)
        #expect(unknown == [msiKey: true])
        let background = FullScreenDetector.evaluate(windows: [F.window(F.player, 0, 0, 2560, 1440)], displays: [F.msiAlone],
                                                     context: F.context(frontmost: F.editor), windowServerPID: nil)
        #expect(background.fullScreenDisplays.isEmpty)
    }

    @Test func eachDisplaysMenuBarIsItsOwn() {
        // Tops aligned, so only x tells the two menu bars apart.
        let observed = FullScreenDetector.observedMenuBar(windows: [F.menuBar(on: F.builtIn)], displays: [F.builtIn, F.msi],
                                                          windowServerPID: F.windowServer)
        #expect(observed == [builtInKey: true, msiKey: false])
    }

    @Test func theFrontmostAppsTopmostWindowNamesItsDisplays() {
        let straddling = F.window(F.editor, 1500, 100, 800, 600)          // across both displays
        let behind = F.window(F.editor, 2000, 100, 300, 300)              // a lower window of the same app
        let result = evaluate([F.menuBar(on: F.builtIn), F.menuBar(on: F.msi), straddling, behind], [F.builtIn, F.msi],
                              F.context(frontmost: F.editor))
        #expect(result.frontmostDisplays == [builtInKey, msiKey])
        let menuOnly = evaluate([F.menuBar(on: F.builtIn), F.window(F.notes, 10, 40, 300, 300)], [F.builtIn, F.msi],
                                F.context(frontmost: F.player))
        #expect(menuOnly.frontmostDisplays.isEmpty)                        // frontmost with only its menu bar
    }

    @Test func everyDisplayGetsAnEntry() {
        let result = evaluate([], [F.builtIn, F.msi], F.context(frontmost: nil))
        #expect(Set(result.fronts.keys) == [builtInKey, msiKey])
        #expect(result.fullScreenDisplays.isEmpty && result.frontmostDisplays.isEmpty)
    }
}

@Suite struct MenuBarPresenceTests {
    private let key = DisplayFixture.Keys.mpg322ux
    private func at(_ seconds: Double) -> MonotonicInstant {
        MonotonicInstant(sinceOrigin: .milliseconds(Int64(seconds * 1000)))
    }

    @Test func absenceIsStickyForThreeSeconds() {
        var presence = MenuBarPresence()
        #expect(presence.update(observed: [key: false], at: at(10)).present == [key: false])
        let hover = presence.update(observed: [key: true], at: at(11))      // hovering at the top edge
        #expect(hover.present == [key: false])
        #expect(hover.resolvesAt == at(13))
        #expect(presence.update(observed: [key: true], at: at(12.9)).present == [key: false])
        let settled = presence.update(observed: [key: true], at: at(13))
        #expect(settled.present == [key: true] && settled.resolvesAt == nil)
    }

    @Test func eachNewAbsenceRestartsTheWindow() {
        var presence = MenuBarPresence()
        _ = presence.update(observed: [key: false], at: at(0))
        _ = presence.update(observed: [key: false], at: at(2.5))
        #expect(presence.update(observed: [key: true], at: at(4)).present == [key: false])
        #expect(presence.update(observed: [key: true], at: at(5.5)).present == [key: true])
    }

    @Test func aPresentMenuBarWithoutHistoryIsPresentAndGoneDisplaysAreForgotten() {
        var presence = MenuBarPresence()
        #expect(presence.update(observed: [key: true], at: at(0)).present == [key: true])
        _ = presence.update(observed: [key: false], at: at(1))
        _ = presence.update(observed: [:], at: at(1.5))                      // the display went away
        #expect(presence.update(observed: [key: true], at: at(2)).present == [key: true])
    }
}
