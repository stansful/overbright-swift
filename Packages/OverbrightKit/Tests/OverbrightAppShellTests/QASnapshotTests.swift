// OverbrightAppShellTests/QASnapshotTests.swift — the Debug QA capture and its timing (ARCHITECTURE.md §8.5, §9.1):
// `--qa-snapshot` draws a window's SwiftUI root again in an opaque, non-vibrant host, so a dark surface keeps light
// text on a dark background (`cacheDisplay` of the window's own views drew black text over the material);
// `-OverbrightQAAppearance` pins the whole app's appearance; `--qa-panel` keeps the panel open on clicks elsewhere;
// the surfaces wait for the launch work (`QAHooks.apply` too), and a level HUD is captured while it shows. Windows are
// built, never ordered in.
#if DEBUG
import Foundation
import AppKit
import OverbrightCore
import OverbrightDesign
import OverbrightPanelUI
import SwiftUI
import Testing
@testable import OverbrightAppShell

@MainActor @Suite struct QASnapshotTests {
    /// A panel as the controller builds it (SwiftUI over the popover material), in `appearance`, never ordered in.
    private func panelWindow(_ appearance: NSAppearance.Name) -> NSWindow {
        let text = Text(verbatim: "Overbright · Bright room").font(.largeTitle).foregroundStyle(.primary)
        let host = NSHostingView(rootView: text.padding(24).frame(width: 320, height: 120))
        let window = OverbrightPanel(frame: CGRect(x: 0, y: 0, width: 320, height: 120))
        window.contentView = PanelContainer.make(around: host, material: .popover)
        window.appearance = NSAppearance(named: appearance)
        window.contentView?.layoutSubtreeIfNeeded()
        return window
    }

    /// The background's brightness (a corner) and the brightest and darkest pixel's.
    private func tones(_ rep: NSBitmapImageRep) throws -> (background: CGFloat, lightest: CGFloat, darkest: CGFloat) {
        let background = try #require(rep.colorAt(x: 3, y: 3)).brightnessComponent
        var lightest: CGFloat = 0
        var darkest: CGFloat = 1
        for x in stride(from: 0, to: rep.pixelsWide, by: 2) {
            for y in stride(from: 0, to: rep.pixelsHigh, by: 2) {
                guard let color = rep.colorAt(x: x, y: y) else { continue }
                lightest = max(lightest, color.brightnessComponent)
                darkest = min(darkest, color.brightnessComponent)
            }
        }
        return (background, lightest, darkest)
    }

    /// Dark: light text on a dark card; light: dark text on a light one. Before, the dark panel's text came out black.
    @Test func aDarkSurfaceKeepsLightTextOnADarkBackground() throws {
        let dark = try tones(try #require(QAHooks.picture(of: panelWindow(.darkAqua))))
        #expect(dark.background < 0.3, "background \(dark.background)")
        #expect(dark.lightest > 0.8, "the text is dark on a dark card: \(dark.lightest)")
        let light = try tones(try #require(QAHooks.picture(of: panelWindow(.aqua))))
        #expect(light.background > 0.7 && light.darkest < 0.2, "\(light)")
        let rep = try #require(QAHooks.picture(of: panelWindow(.darkAqua)))
        #expect(rep.size == CGSize(width: 320, height: 120))                 // the hosting view's size
    }

    /// Every surface's SwiftUI host is found: a hosting view inside a container (the panel, the HUD, Welcome) and a
    /// hosting controller's view (Settings, Help); vibrant appearances become their opaque counterparts.
    @Test func everySurfacesSwiftUIRootIsFound() throws {
        let panel = panelWindow(.darkAqua)
        #expect(QAHooks.snapshotHost(in: try #require(panel.contentView)) != nil)
        let settings = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 200, height: 100), styleMask: [.titled],
                                backing: .buffered, defer: true)
        settings.contentViewController = NSHostingController(rootView: Text(verbatim: "Settings"))
        #expect(QAHooks.snapshotHost(in: try #require(settings.contentView)) != nil)
        #expect(QAHooks.snapshotHost(in: NSView()) == nil)
        let vibrant = try #require(NSAppearance(named: .vibrantDark))
        #expect(QAHooks.opaque(vibrant)?.name == .darkAqua)
        #expect(QAHooks.opaque(try #require(NSAppearance(named: .vibrantLight)))?.name == .aqua)
    }

    /// `-OverbrightQAAppearance light|dark` pins the app (every window follows `NSApp`), not only Settings.
    @Test func thePinnedAppearanceIsTheApps() {
        let defaults = InMemoryDefaults()
        #expect(QAHooks.pinnedAppearance(defaults) == nil)
        defaults.set("dark", forKey: QAHooks.appearanceKey)
        #expect(QAHooks.pinnedAppearance(defaults)?.name == .darkAqua)
        defaults.set("light", forKey: QAHooks.appearanceKey)
        #expect(QAHooks.pinnedAppearance(defaults)?.name == .aqua)
        defaults.set("sepia", forKey: QAHooks.appearanceKey)
        #expect(QAHooks.pinnedAppearance(defaults) == nil)
    }

    /// `--qa-panel` keeps the panel open on clicks elsewhere (a mouse-down anywhere in the session closed it before
    /// the capture in about one run in eight); every other launch closes it on an outside click.
    @Test func theQAPanelStaysOpenOnClicksElsewhere() {
        #expect(QAHooks.keepsPanelOpen(LaunchArguments(["Overbright", "--qa-simulate", "--qa-panel"])))
        #expect(!QAHooks.keepsPanelOpen(LaunchArguments(["Overbright", "--qa-simulate"])))
        let panel = PanelController(services: TestShell.shell().services)
        #expect(panel.closesOnOutsideClicks && !panel.watchesOutsideClicks)  // nothing watched while closed
    }

    /// A level HUD shows for 1.5 s: the default capture falls while it shows (1 s for a HUD state, which shows at
    /// once; 2 s with `--qa-hud`, which shows 1 s in); 3 s otherwise; `--qa-snapshot-at` always wins.
    @Test func aLevelHUDIsCapturedWhileItShows() {
        func delay(_ arguments: [String]) -> Double { QAHooks.snapshotDelay(LaunchArguments(["Overbright"] + arguments)) }
        #expect(delay(["--qa-state", "hud-boost"]) == 1 && delay(["--qa-state", "hud-dim"]) <= 1.2)
        #expect(delay(["--qa-hud", "max"]) == 2)
        #expect(delay(["--qa-state", "boosting", "--qa-panel"]) == 3 && delay([]) == 3)
        #expect(delay(["--qa-state", "hud-boost", "--qa-snapshot-at", "0.5"]) == 0.5)
        #expect(ScriptedStatuses.hudNames.allSatisfy { delay(["--qa-state", $0]) < 1.5 })
        #expect(QAHooks.seconds(.infinity) == .seconds(86_400) && QAHooks.seconds(.nan) == .zero)
        #expect(QAHooks.seconds(-1) == .zero && QAHooks.seconds(1.25) == .milliseconds(1250))
    }

    /// The surfaces wait for the launch work: the wait ends once the engine is ready, not before.
    @Test func theSurfacesWaitForTheLaunchWork() async {
        final class Flag { var isSet = false }
        let boost = PreviewBoostControl(fixture: .builtinXDRLidOpen)
        boost.status.isReady = false
        let shown = Flag()
        let waiting = Task {
            await QAHooks.waitUntilReady(boost, polling: .milliseconds(5))
            shown.isSet = true
        }
        try? await Task.sleep(for: .milliseconds(100))
        #expect(!shown.isSet)                                                 // still waiting for the engine
        boost.status.isReady = true
        await waiting.value
        #expect(shown.isSet)
    }

    /// `QAHooks.apply` itself holds every surface back until the engine is ready: neither the snapshot (due at once)
    /// nor `--qa-hud`'s level (due 1 s in) comes while the launch work runs, both come once it is done. No window is
    /// ordered in (the HUD presents none; the test process shows no window, so the capture writes only its folder).
    @Test func applyShowsNothingBeforeTheLaunchWork() async throws {
        _ = NSApplication.shared                                              // the capture reads `NSApp.windows`
        let folder = FileManager.default.temporaryDirectory
            .appending(path: "overbright-qa-apply-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: folder) }
        var launching = PreviewBoostControl(fixture: .builtinXDRLidOpen).status
        launching.isReady = false
        let shell = TestShell.shell(scriptedStatus: launching)
        let boost = try #require(shell.services.boost as? PreviewBoostControl)
        let services = shell.services
        let hud = HUDController(services: services, slot: HUDSlot()) { change, _ in
            HUDText(symbol: .sunMax, displayName: nil, value: "v\(change.sequence)", reason: nil, announcement: "")
        }
        hud.presentsWindows = false
        let targets = QAHooks.Targets(
            shell: shell, appControl: ShellAppControl(settings: services.settings,
                                                      loginItems: LoginItemController(service: shell.ports.loginItems)),
            welcome: WelcomeWindowController(services: services), statusItem: StatusItemController(services: services),
            hud: hud)
        let arguments = LaunchArguments(["Overbright", "--qa-simulate", "--qa-hud", "max",
                                         "--qa-snapshot", folder.path(percentEncoded: false), "--qa-snapshot-at", "0"])
        let task = QAHooks.apply(arguments, to: targets)
        defer { task?.cancel() }
        func levelWasSet() -> Bool { boost.calls.contains { $0.hasPrefix("setLevel(") } }
        try? await Task.sleep(for: .milliseconds(1_300))
        #expect(!exists(folder) && !levelWasSet(), "a surface showed before the launch work was done")
        boost.status.isReady = true
        let deadline = ContinuousClock.now + .seconds(5)
        while !(exists(folder) && levelWasSet()), ContinuousClock.now < deadline {
            try? await Task.sleep(for: .milliseconds(20))
        }
        #expect(exists(folder) && levelWasSet())
    }

    private func exists(_ url: URL) -> Bool { FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) }
}
#endif
