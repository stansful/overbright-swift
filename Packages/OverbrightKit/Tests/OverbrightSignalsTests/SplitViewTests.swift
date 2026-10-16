// OverbrightSignalsTests/SplitViewTests.swift — Split View: tiles cover ≥ 98 % with the menu bar absent. ARCHITECTURE.md
// §7.3, §10.8.
import CoreGraphics
import OverbrightCore
import Testing
@testable import OverbrightSignals

@Suite struct SplitViewTests {
    typealias F = WindowFixtures
    private let msiKey = DisplayFixture.Keys.mpg322ux

    /// Two full-height tiles with a 6-pt divider on the MSI.
    private let left = F.window(F.notes, 0, 0, 1277, 1440)
    private let right = F.window(F.player, 1283, 0, 1277, 1440)

    private func evaluate(_ windows: [F.Window], _ displays: [FullScreenDetector.Display] = [WindowFixtures.msiAlone],
                          frontmost: Int32?, holders: Set<Int32> = []) -> FullScreenDetector.Result {
        FullScreenDetector.evaluate(windows: windows, displays: displays,
                                    context: F.context(frontmost: frontmost, holders: holders),
                                    windowServerPID: F.windowServer)
    }

    @Test func twoTilesWithoutTheMenuBarAreFullScreen() {
        let result = evaluate([left, right], frontmost: F.player)
        #expect(result.fullScreenDisplays == [msiKey])
        #expect(result.fronts[msiKey]?.ownerPID == F.player)               // the frontmost app's tile
    }

    @Test func theOwnerIsTheTopmostTileWhenTheFrontmostAppHasNone() {
        let result = evaluate([left, right], frontmost: F.editor)
        #expect(result.fronts[msiKey]?.ownerPID == F.notes)
    }

    @Test func theMenuBarRulesSplitViewOut() {
        #expect(evaluate([F.menuBar(on: F.msiAlone), left, right], frontmost: F.player).fullScreenDisplays.isEmpty)
    }

    @Test func oneTileAloneIsNotFullScreen() {
        #expect(evaluate([left], frontmost: F.notes).fullScreenDisplays.isEmpty)
        // A gap of more than 2 % of the display is not a tiling.
        let narrow = F.window(F.player, 1400, 0, 1160, 1440)
        #expect(evaluate([left, narrow], frontmost: F.notes).fullScreenDisplays.isEmpty)
    }

    @Test func overlappingFullHeightWindowsAreNotTiles() {
        let first = F.window(F.notes, 0, 0, 1800, 1440)
        let second = F.window(F.player, 760, 0, 1800, 1440)                // overlaps the first by 1040 pt
        #expect(evaluate([first, second], frontmost: F.notes).fullScreenDisplays.isEmpty)
    }

    @Test func aFloatingPaletteOnTopDoesNotHideTheTiles() {
        let palette = F.window(F.notes, 1000, 300, 400, 500)              // not full height: skipped, not a tile
        let result = evaluate([palette, left, right], frontmost: F.notes)
        #expect(result.fullScreenDisplays == [msiKey])
        #expect(result.fronts[msiKey]?.ownerPID == F.notes)
    }

    @Test func tilesOnTheNotchedBuiltInCoverTheAreaBelowTheBand() {
        let leftTile = F.window(F.notes, 0, 32, 861, 1085)
        let rightTile = F.window(F.player, 867, 32, 861, 1085)
        let result = evaluate([leftTile, rightTile], [F.builtIn], frontmost: F.notes)
        #expect(result.fullScreenDisplays == [DisplayFixture.Keys.builtIn])
    }

    @Test func aSplitViewWhoseOwnerPlaysIsFullScreenVideo() {
        let result = evaluate([left, right], frontmost: F.player, holders: [F.player])
        #expect(result.fullScreenVideoDisplays == [msiKey])
        let notPlaying = evaluate([left, right], frontmost: F.player, holders: [F.notes])
        #expect(notPlaying.fullScreenVideoDisplays.isEmpty)               // the owner is the frontmost tile
    }
}
