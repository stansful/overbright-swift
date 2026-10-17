// OverbrightAppShellTests/StatusItemIconWindowTests.swift — the "Overbright's icon isn't visible" window (DESIGN.md
// §4.4, §5.13 `menubar-hidden`): titled with its heading, so VoiceOver and Mission Control name it; its two sentences
// joined by Design's localized joiner (no stray space after 。 in Japanese or Chinese); a snapshot in Light, Dark and
// Increase Contrast, written only with `OVERBRIGHT_SNAPSHOT_DIR` (C-PANEL-21, C-PANEL-31). Never ordered in.
import AppKit
import OverbrightCore
import OverbrightDesign
import SwiftUI
import Testing
@testable import OverbrightAppShell

@MainActor @Suite struct StatusItemIconWindowTests {
    @Test func theTextJoinsItsSentencesAsTheLanguageDoes() {
        let with = IconNotVisibleWindowController.message(toggleKeys: "⌃⌥⌘B", namesMenuBarSetting: true)
        let first = IconNotVisibleWindowController.message(toggleKeys: "⌃⌥⌘B", namesMenuBarSetting: false)
        let second = String(localized: "To show it, turn on Overbright under Allow in the Menu Bar in Menu Bar settings.",
                            table: "StatusMenu", bundle: .module)
        #expect(with == CopyFormat.sentences(first, second))
        #expect(!IconNotVisibleWindowController.heading.isEmpty)
    }

    @Test(arguments: ["light", "dark", "increaseContrast"])
    func theWindowRenders(_ appearance: String) throws {
        let names: [String: NSAppearance.Name] = ["light": .aqua, "dark": .darkAqua,
                                                  "increaseContrast": .accessibilityHighContrastAqua]
        let view = IconNotVisibleView(message: IconNotVisibleWindowController.message(toggleKeys: "⌃⌥⌘B",
                                                                                     namesMenuBarSetting: true),
                                      openSettings: {}, dismiss: {})
            .background(Color(nsColor: .windowBackgroundColor))
            .overbrightThemeRoot(OverbrightTheme(increaseContrast: appearance == "increaseContrast"))
        let host = NSHostingView(rootView: view)
        host.appearance = NSAppearance(named: try #require(names[appearance]))
        host.frame = CGRect(origin: .zero, size: host.fittingSize)
        let window = NSWindow(contentRect: host.frame, styleMask: [.borderless], backing: .buffered, defer: true)
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        let rep = try #require(host.bitmapImageRepForCachingDisplay(in: host.bounds))
        host.cacheDisplay(in: host.bounds, to: rep)
        window.contentView = nil
        #expect(rep.size.width == 420 && rep.size.height > 100)
        let background = try #require(rep.colorAt(x: 2, y: 2)).brightnessComponent
        var ink = false
        for x in stride(from: 0, to: rep.pixelsWide, by: 3) where !ink {
            for y in stride(from: 0, to: rep.pixelsHigh, by: 3) {
                if let color = rep.colorAt(x: x, y: y), abs(color.brightnessComponent - background) > 0.3 { ink = true; break }
            }
        }
        #expect(ink, "\(appearance): nothing drawn")
        if let directory = SnapshotOutput.directory("AppShell"), let data = rep.representation(using: .png, properties: [:]) {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try data.write(to: directory.appending(path: "menubar-hidden-window-\(appearance).png"))
        }
    }
}
