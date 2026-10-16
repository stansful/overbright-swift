// OverbrightSettingsUITests/SettingsChromeSnapshotTests.swift — the Settings chrome WP0b delivers (DESIGN.md §7.1, §7.2,
// §7.6, §7.8, §7.9) in Light, Dark and Increase Contrast (ARCHITECTURE.md §9.1, §9.3 #5): the sidebar, the sidebar
// while searching, the "All settings were reset." banner, the shortcut recorder with and without keys, a pane's
// "Reset ‹Pane›…" footer, Reset All with Undo Reset, and About. The panes are seeded (WP11 fills and snapshots them).
// Rendered in-process, never ordered in.
import AppKit
import OverbrightCore
import OverbrightDesign
import SwiftUI
import Testing
@testable import OverbrightSettingsUI

@MainActor @Suite struct SettingsChromeSnapshotTests {
    /// Every piece of chrome, with the size the window gives it (nil: its own fitting size).
    static func chrome() -> [(name: String, view: AnyView, size: CGSize?)] {
        let services = OverbrightServices.preview()
        let sidebar = CGSize(width: SettingsMetrics.sidebarWidth.ideal, height: 420)
        let index = SettingsSearchIndex(panes: SettingsPane.all, rows: SettingsPaneCatalog.rows(services: services),
                                        keywords: KnownPaneKeywords.all)
        let banner = ResetAllController(services: services)
        _ = banner.takeAnnouncement()                                                     // no VoiceOver post in a test
        let afterReset = ResetAllController(services: OverbrightServices.preview())
        afterReset.resetAll()
        afterReset.dismissBanner()
        return [
            // No selection: a selected row's material does not draw outside a shown window.
            ("sidebar", AnyView(SettingsSidebar(panes: SettingsPane.all, results: nil, selection: .constant(nil))), sidebar),
            ("sidebar-search", AnyView(SettingsSidebar(panes: SettingsPane.all, results: index.search("battery"),
                                                       selection: .constant(nil))), sidebar),
            ("undo-banner", AnyView(UndoBanner(controller: banner).padding(Space.xl)), nil),
            ("recorder", AnyView(recorders()), nil),
            ("pane-footer", AnyView(PaneFooter(pane: .pane(.general), settings: services.settings)
                .frame(width: SettingsMetrics.windowSize.width - SettingsMetrics.sidebarWidth.ideal)), nil),
            ("reset-all", AnyView(Form { ResetAllRow(controller: afterReset) }.formStyle(.grouped)),
             CGSize(width: 600, height: 110)),
            ("about", AnyView(Form { AboutContent(services: services) }.formStyle(.grouped)
                .environment(SettingsNavigator(target: "about"))),
             CGSize(width: SettingsMetrics.windowSize.width - SettingsMetrics.sidebarWidth.ideal,
                    height: SettingsMetrics.windowSize.height)),
        ]
    }

    /// A recorder without a shortcut ("Record Shortcut") and one with key caps and its clear button.
    static func recorders() -> some View {
        VStack(alignment: .leading, spacing: Space.m) {
            ShortcutRecorder(title: "Brighter", keys: nil) { _ in }
            ShortcutRecorder(title: "Brighter", keys: "⌃⌥⌘=") { _ in }
        }
        .padding(Space.xl)
    }

    @Test(arguments: ChromeAppearance.allCases)
    func theChromeRenders(_ appearance: ChromeAppearance) throws {
        for (name, view, size) in Self.chrome() {
            let rep = try ChromeSnapshot.render(view, appearance, size: size)
            #expect(rep.pixelsWide > 40 && rep.pixelsHigh > 20, "\(name)")
            #expect(ChromeSnapshot.inkFraction(rep) > 0.005, "\(name) \(appearance.rawValue): nothing drawn")
            try ChromeSnapshot.write(rep, name, appearance)
        }
    }

    @Test func darkAndLightDiffer() throws {
        let view = PaneFooter(pane: .pane(.general), settings: OverbrightServices.preview().settings).frame(width: 600)
        let light = try ChromeSnapshot.render(view, .light)
        let dark = try ChromeSnapshot.render(view, .dark)
        #expect(ChromeSnapshot.backgroundBrightness(light) > ChromeSnapshot.backgroundBrightness(dark) + 0.3)
    }
}
