// OverbrightSignalsTests/FullScreenVideoTests.swift — full-screen video: the covering window's OWNER holds a
// display-sleep assertion. ARCHITECTURE.md §6.5, §7.3, §10.8.
import CoreGraphics
import OverbrightCore
import Testing
@testable import OverbrightSignals

@Suite struct FullScreenVideoTests {
    typealias F = WindowFixtures
    private let msiKey = DisplayFixture.Keys.mpg322ux
    private let builtInKey = DisplayFixture.Keys.builtIn

    private func evaluate(_ windows: [F.Window], frontmost: Int32?, holders: Set<Int32>) -> FullScreenDetector.Result {
        FullScreenDetector.evaluate(windows: windows, displays: [F.builtIn, F.msi],
                                    context: F.context(frontmost: frontmost, holders: holders),
                                    windowServerPID: F.windowServer)
    }

    @Test func aPlayingFullScreenWindowIsVideo() {
        let movie = F.window(F.player, 1728, 0, 2560, 1440)
        let result = evaluate([F.menuBar(on: F.builtIn), movie], frontmost: F.player, holders: [F.player])
        #expect(result.fullScreenDisplays == [msiKey])
        #expect(result.fullScreenVideoDisplays == [msiKey])
    }

    @Test func aFullScreenDocumentIsNotVideo() {
        let document = F.window(F.notes, 1728, 0, 2560, 1440)
        let result = evaluate([F.menuBar(on: F.builtIn), document], frontmost: F.notes, holders: [])
        #expect(result.fullScreenDisplays == [msiKey])
        #expect(result.fullScreenVideoDisplays.isEmpty)
    }

    @Test func anotherProcessPlayingDoesNotMakeItVideo() {
        // Music plays in the background; the full-screen window belongs to a writer.
        let document = F.window(F.notes, 1728, 0, 2560, 1440)
        let result = evaluate([F.menuBar(on: F.builtIn), document], frontmost: F.notes, holders: [F.player])
        #expect(result.fullScreenVideoDisplays.isEmpty)
    }

    @Test func videoOnOneDisplayWhileTypingOnTheOther() {
        let typing = F.window(F.editor, 100, 100, 800, 600)
        let movie = F.window(F.player, 1728, 0, 2560, 1440)
        let result = evaluate([F.menuBar(on: F.builtIn), typing, movie], frontmost: F.editor, holders: [F.player])
        #expect(result.fullScreenVideoDisplays == [msiKey])
        #expect(result.frontmostDisplays == [builtInKey])                  // per-app rules look here, not at the movie
        #expect(result.fronts[builtInKey]?.isFullScreen == false)
    }

    @Test func aPlayingWindowThatIsNotFullScreenIsNotVideo() {
        let windowed = F.window(F.player, 1900, 200, 1280, 720)
        let result = evaluate([F.menuBar(on: F.builtIn), F.menuBar(on: F.msi), windowed], frontmost: F.player,
                              holders: [F.player])
        #expect(result.fullScreenVideoDisplays.isEmpty && result.fullScreenDisplays.isEmpty)
        #expect(result.frontmostDisplays == [msiKey])
    }
}
