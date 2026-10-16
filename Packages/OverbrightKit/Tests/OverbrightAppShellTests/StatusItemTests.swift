// OverbrightAppShellTests/StatusItemTests.swift — the status item's symbol is a template drawn in code
// (DESIGN.md §4.1, D13), and the QA hooks' scripted statuses resolve (ARCHITECTURE.md §8.5). WP10 adds the six-state
// `StatusSymbolTests`.
import AppKit
import OverbrightCore
import Testing
@testable import OverbrightAppShell

@MainActor @Suite struct StatusItemTests {
    /// 18 × 18 pt, template (macOS tints it), no asset, and a bitmap that actually has ink.
    @Test func theOffSymbolIsATemplateDrawnInCode() throws {
        let image = StatusSymbolImage.image(for: .off)
        #expect(image.isTemplate)
        #expect(image.size == CGSize(width: 18, height: 18))
        let rep = try #require(NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 36, pixelsHigh: 36,
                                                bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                                colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0))
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        image.draw(in: CGRect(x: 0, y: 0, width: 36, height: 36))
        NSGraphicsContext.restoreGraphicsState()
        let inked = (0..<36).flatMap { x in (0..<36).map { y in (x, y) } }
            .filter { rep.colorAt(x: $0.0, y: $0.1).map { $0.alphaComponent > 0.5 } ?? false }
        #expect(inked.count > 40)                                                   // rays and the disc outline
        #expect(rep.colorAt(x: 18, y: 18)?.alphaComponent ?? 1 < 0.5)               // `off`: the disc is hollow
    }

    #if DEBUG
    /// `--qa-state` resolves PanelUI's scripted statuses and refuses unknown names.
    @Test func scriptedStatusesResolve() {
        #expect(QAHooks.scriptedStatus(LaunchArguments(["Overbright", "--qa-state", "off"]))?.isOn == false)
        #expect(QAHooks.scriptedStatus(LaunchArguments(["Overbright", "--qa-state", "standard"]))?.isOn == true)
        #expect(QAHooks.scriptedStatus(LaunchArguments(["Overbright", "--qa-state", "no-such-state"])) == nil)
        #expect(QAHooks.scriptedStatus(LaunchArguments(["Overbright"])) == nil)
    }
    #endif
}
