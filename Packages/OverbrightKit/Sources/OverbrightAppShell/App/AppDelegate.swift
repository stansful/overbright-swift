// OverbrightAppShell/App/AppDelegate.swift — a thin orchestrator. ARCHITECTURE.md §7.4 (launch, quit), §7.6 (launch UI),
// §8.5 (launch arguments), §10.0 (shared shell file, contract owner), §10.15 (WP13 completes it); D7, D13, D24, D27.
//
// Launch order: `ShellDefaults` → the composition root builds the hub (no I/O) → command-line modes
// (`--diagnostics`, `--monitor`, `--restore-gamma`) run and quit here, before any service starts, any window opens or
// any preference is written → single instance (skipped for CLI modes and `--qa-simulate`) → move to Applications →
// settings upgrade → controllers, router connection and status item → `LaunchGate` runs the launch check, then
// starts the services (Displays first, Boost last) → QA hooks → launch UI.
// Quit: a user quit is cancelled once, the services stop in reverse (Boost first) within `EngineTiming.quitTimeout`,
// then the app terminates (see `applicationShouldTerminate` for why not `.terminateLater`); a system quit (log out,
// restart, shut down) terminates at once; `applicationWillTerminate` runs `stopNow()` as the synchronous fallback.
import AppKit
import CoreServices
import Foundation
import OverbrightBoost
import OverbrightChannel
import OverbrightCore
import OverbrightDisplays
import OverbrightIntents
import os

private let log = Log.logger(.app)

/// The app's delegate, installed by `OverbrightApp` through `@NSApplicationDelegateAdaptor`.
public final class AppDelegate: NSObject, NSApplicationDelegate {
    /// The App Intents router that `OverbrightApp.init` created and registered with `AppDependencyManager` before
    /// launch (§7.7). The delegate connects it once the services exist.
    public static var intentRouter: IntentRouter?

    private var shell: Shell?
    private var appControl: ShellAppControl?
    private var statusItem: StatusItemController?
    private var panel: PanelController?
    private var welcome: WelcomeWindowController?
    private var hud: HUDController?
    private var lowLevelPrompt: LowLevelPromptController?
    private var iconMonitor: IconVisibilityMonitor?
    private var controlPublisher: ControlStatePublisher?
    private let launchGate = LaunchGate()
    private var isLoginLaunch = false
    private var quit = QuitState.running

    /// Where a user quit is (`applicationShouldTerminate`).
    private enum QuitState { case running, stopping, stopped }

    /// Created by `@NSApplicationDelegateAdaptor`; everything starts in `applicationDidFinishLaunching`.
    override public init() { super.init() }

    /// Reads whether this is a login launch while the open-application event is current.
    public func applicationWillFinishLaunching(_ notification: Notification) {
        isLoginLaunch = LaunchUI.currentLaunchIsLogin()
    }

    /// The launch order of the file header.
    public func applicationDidFinishLaunching(_ notification: Notification) {
        let arguments = LaunchArguments.current
        let defaults = ShellDefaults.forLaunch(arguments)
        let time = SystemTimeSource()
        let ports = CompositionRoot.ports(for: arguments, time: time)
        var scriptedStatus: BoostStatus?
        #if DEBUG
        scriptedStatus = QAHooks.scriptedStatus(arguments)
        #endif
        let settings = SettingsStore(defaults: defaults.defaults)
        let shell = CompositionRoot.makeShell(settings: settings, paths: ports.fixture == nil ? .live : .temporary(),
                                              machine: .current(), time: time, ports: ports,
                                              scriptedStatus: scriptedStatus)
        self.shell = shell
        if runCommandLineMode(arguments, shell: shell) { return }

        if !arguments.skipsSingleInstanceCheck, SingleInstance.handOverIfRunning(arguments: arguments) {
            log.info("another Overbright runs in this session; handed over")
            NSApp.terminate(nil)
            return
        }
        ApplicationsMover(settings: settings).offerIfNeeded()
        settings.upgradeStoredSettings()                 // once per install and revision; never in a CLI mode

        let services = shell.services
        let appControl = ShellAppControl(settings: settings)
        services.app = appControl
        let statusItem = StatusItemController(services: services)
        let panel = PanelController(services: services)
        let welcome = WelcomeWindowController(services: services)
        statusItem.onClick = { [weak panel, weak statusItem] in panel?.toggle(from: statusItem?.button) }
        appControl.connect(ShellAppControl.Controllers(
            statusItem: statusItem, panel: panel, settings: SettingsWindowController(services: services),
            welcome: welcome, help: HelpWindowController(services: services),
            calibration: CalibrationWindowController(services: services),
            selfTest: SelfTestSheetPresenter(services: services),
            diagnostics: { [weak self] in self?.clipboardDiagnostics() }))
        self.appControl = appControl; self.statusItem = statusItem; self.panel = panel; self.welcome = welcome

        Self.intentRouter?.connect(boost: services.boost, displays: services.displays, signals: services.signals)
        let controlPublisher = ControlStatePublisher(boost: services.boost)
        controlPublisher.start()
        self.controlPublisher = controlPublisher

        if settings[GeneralSettings.showsMenuBarIcon] {
            statusItem.install()
            if let item = statusItem.item {
                let monitor = IconVisibilityMonitor(statusItem: item)
                monitor.start()
                iconMonitor = monitor
            }
        }
        let hud = HUDController(services: services)
        let lowLevelPrompt = LowLevelPromptController(services: services)
        hud.start()
        lowLevelPrompt.start()
        self.hud = hud; self.lowLevelPrompt = lowLevelPrompt

        let rescue = shell.rescue, lifecycle = shell.lifecycle
        launchGate.launch {
            let outcome = await rescue.runLaunchCheck()
            log.info("launch check: \(String(describing: outcome), privacy: .public)")
            for service in lifecycle { await service.start() }
        }
        #if DEBUG
        QAHooks.apply(arguments, to: QAHooks.Targets(services: services, appControl: appControl, welcome: welcome))
        #endif
        let surface = LaunchUI.surface(isLoginLaunch: isLoginLaunch, isBackgroundLaunch: false,
                                       welcomeFinished: settings[OnboardingSettings.completedVersion] != nil,
                                       iconVisibility: appControl.iconVisibility)
        Task {
            await statusItem.waitUntilPlaced(atMost: .seconds(1))   // the panel anchors to the placed icon
            show(surface)
        }
    }

    /// A user quit while the services are still starting waits for them (at most `LaunchGate.quitWait`); then the
    /// services stop in reverse order, Boost first, within `EngineTiming.quitTimeout`, and the app terminates.
    ///
    /// Not `.terminateLater`: on macOS 27.0.1 AppKit's wait for `reply(toApplicationShouldTerminate:)` serves neither
    /// the main dispatch queue nor the main actor [VERIFIED in this app, WP0a], so the ramped stop could never run there.
    /// A user quit is therefore cancelled, the stop runs, and the app terminates again. A quit sent by the system (log
    /// out, restart, shut down: the quit event has a reason) is never cancelled: it terminates at once and
    /// `applicationWillTerminate` writes the baselines synchronously.
    public func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard launchGate.runsTerminateHooks, let lifecycle = shell?.lifecycle else { return .terminateNow }
        switch quit {
        case .stopped:
            return .terminateNow
        case .stopping:
            return .terminateCancel
        case .running:
            if Self.isSystemQuit() { return .terminateNow }
            quit = .stopping
            log.info("quit: stopping \(lifecycle.count, privacy: .public) services")
            let stopThenTerminate = { [weak self] in
                Task {
                    await Self.stop(lifecycle, within: EngineTiming.quitTimeout)
                    self?.quit = .stopped
                    NSApp.terminate(nil)
                }
            }
            if !launchGate.defersQuit(reply: { _ = stopThenTerminate() }) { _ = stopThenTerminate() }
            return .terminateCancel
        }
    }

    /// The synchronous fallback: every service's `stopNow()` in reverse order (nothing in a CLI mode).
    public func applicationWillTerminate(_ notification: Notification) {
        guard launchGate.runsTerminateHooks, let shell else { return }
        for service in shell.lifecycle.reversed() { service.stopNow() }
        controlPublisher?.stop()
        hud?.stop()
        lowLevelPrompt?.stop()
    }

    /// Opening Overbright again (Finder, Spotlight, `open`) always shows something (D13).
    public func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        guard let appControl, let settings = shell?.services.settings else { return false }
        show(LaunchUI.reopenSurface(welcomeFinished: settings[OnboardingSettings.completedVersion] != nil,
                                    iconVisibility: appControl.iconVisibility))
        return false
    }

    /// `overbright://` URLs (§7.7): the settings route opens Settings; the control route is WP8's.
    public func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            switch URLRoute.parse(url) {
            case .settings(let pane): appControl?.openSettings(pane)
            case .control: log.info("control route received; WP8 handles it")
            case nil: log.error("ignored URL with scheme \(url.scheme ?? "-", privacy: .public)")
            }
        }
    }

    /// ⌘, (OverbrightScenes): our Settings window.
    func openSettings() { appControl?.openSettings(nil) }

    // MARK: Private

    /// `--diagnostics`, `--monitor` and `--restore-gamma`: run, then quit. True when one of them runs.
    private func runCommandLineMode(_ arguments: LaunchArguments, shell: Shell) -> Bool {
        if let path = arguments.diagnosticsPath {
            Task {
                let report = DiagnosticsReport.build(CompositionRoot.diagnosticsInputs(shell, forClipboard: false))
                if !DiagnosticsReport.save(report, to: path) { exit(1) }
                NSApp.terminate(nil)
            }
            return true
        }
        if arguments.runsMonitor {
            Task {
                await DisplayMonitor.run(interval: .milliseconds(250), duration: arguments.monitorDuration) { line in
                    FileHandle.standardOutput.write(Data((line + "\n").utf8))
                }
                NSApp.terminate(nil)
            }
            return true
        }
        if arguments.restoresGamma {
            Task {
                let outcome = await shell.rescue.rescueNow()
                FileHandle.standardOutput.write(Data("restore-gamma: \(String(describing: outcome))\n".utf8))
                NSApp.terminate(nil)
            }
            return true
        }
        return false
    }

    private func show(_ surface: LaunchUI.Surface) {
        switch surface {
        case .nothing: break
        case .welcome: welcome?.show(step: nil)
        case .panel: appControl?.showPanel()
        case .settingsGeneral: appControl?.openSettings("general")
        }
    }

    private func clipboardDiagnostics() -> Data? {
        guard let shell else { return nil }
        return DiagnosticsReport.json(DiagnosticsReport.build(CompositionRoot.diagnosticsInputs(shell, forClipboard: true)))
    }

    /// A quit the system sends at log out, restart or shut down (the quit event carries a reason).
    private static func isSystemQuit() -> Bool {
        guard let event = NSAppleEventManager.shared().currentAppleEvent,
              event.eventClass == AEEventClass(kCoreEventClass), event.eventID == AEEventID(kAEQuitApplication) else {
            return false
        }
        return event.attributeDescriptor(forKeyword: AEKeyword(kAEQuitReason)) != nil
    }

    /// Stops `services` in reverse order, giving up waiting after `limit`.
    private static func stop(_ services: [any ServiceLifecycle], within limit: Duration) async {
        let stopping = Task { for service in services.reversed() { await service.stop() } }
        let timeout = Task { try? await Task.sleep(for: limit) }
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await stopping.value }
            group.addTask { await timeout.value }
            await group.next()
            group.cancelAll()
        }
        timeout.cancel()
    }
}
