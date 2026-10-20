// OverbrightAppShell/App/AppDelegate.swift — a thin orchestrator. ARCHITECTURE.md §7.4 (launch, quit), §7.6 (launch UI),
// §8.5 (launch arguments), §10.0 (shared shell file), §10.15; D7, D13, D24, D27.
//
// Launch order: what opened the app is read first, from the current Apple event (§7.6; AppKit dispatches it only after
// `applicationWillFinishLaunching`), then `LaunchSequence`: a Release build given a Debug-only switch (`--qa-…`)
// exits with `EX_USAGE` before anything else → `ShellDefaults` → the composition root builds the hub (no I/O) →
// command-line modes (`--diagnostics`, `--monitor`, `--restore-gamma`) run and quit here, before any service starts,
// any window opens or any preference is written → single instance (skipped for CLI modes and launches wired to the
// simulated ports) → move to Applications → settings upgrade → controllers, router connection, status item, Dock and
// HUD → `LaunchGate` runs the launch check, then starts the services (Displays first, Boost last) → QA hooks (Debug;
// their surfaces show once the launch work is done) → launch UI (anchored to the placed status item; see
// `PanelPlacement` for the item MenuBarAgent has not placed yet; silent for a login launch and a launch by a URL or an
// intent).
// Quit (`QuitFlow`): a quit from inside the app is cancelled once, the services stop in reverse (Boost first) within
// `EngineTiming.quitTimeout`, then the app terminates (not `.terminateLater`, see `QuitFlow`); a quit Apple Event (a
// script, the Dock, Activity Monitor, log out, restart, shut down) terminates at once; `applicationWillTerminate`
// runs every `stopNow()`, which writes the baselines synchronously.
import AppKit
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
    private var icon: StatusIconPresence?
    private var panel: PanelController?
    private var welcome: WelcomeWindowController?
    private var hud: HUDController?
    private var levelConfirmationPrompt: LevelConfirmationPromptController?
    private var dock: DockMenuController?
    private var quitFlow: QuitFlow?
    private let launchGate = LaunchGate()
    /// The current Apple event, read first thing in `applicationDidFinishLaunching` (tests inject one).
    private let currentAppleEvent: () -> NSAppleEventDescriptor?
    /// Runs the launch order (`LaunchSequence.run`; tests record instead).
    private let runLaunch: (LaunchSequence.Effects) -> Void
    /// What opened this launch (§7.6), read from the first Apple event.
    private(set) var opening = LaunchUI.Opening.user
    private var openingReading: LaunchUI.Reading?
    private var hasShownLaunchUI = false
    private var urlOpenedDuringLaunch = false
    /// URLs that arrived before the controllers existed (a launch by a URL can deliver it that early).
    private var pendingURLs: [URL] = []
    #if DEBUG
    private var scenario: Task<Void, Never>?
    /// `--qa-state`: the panel opens with the "Why?" row expanded.
    private var qaExpandsWhy = false
    /// `--qa-panel`: the panel stays open on clicks elsewhere.
    private var qaKeepsPanelOpen = false
    #endif

    /// How long the launch UI waits for MenuBarAgent to place the status item before the panel opens at the top-right
    /// of the main screen (it then follows the item once placed).
    private static let placementWait: Duration = .seconds(1)

    /// Created by `@NSApplicationDelegateAdaptor`; everything starts in `applicationDidFinishLaunching`.
    override public convenience init() {
        self.init(currentAppleEvent: { NSAppleEventManager.shared().currentAppleEvent },
                  runLaunch: { _ = LaunchSequence.run($0) })
    }

    /// A delegate that reads the first Apple event through `currentAppleEvent` and runs the launch through
    /// `runLaunch` (tests).
    init(currentAppleEvent: @escaping () -> NSAppleEventDescriptor?,
         runLaunch: @escaping (LaunchSequence.Effects) -> Void) {
        self.currentAppleEvent = currentAppleEvent; self.runLaunch = runLaunch
        super.init()
    }

    /// The launch order of the file header: what opened the app first, while the open-application event is current.
    public func applicationDidFinishLaunching(_ notification: Notification) {
        readOpening()
        let arguments = LaunchArguments.current
        let time = SystemTimeSource()
        runLaunch(LaunchSequence.Effects(
            refusedSwitches: { CompositionRoot.refusedSwitches(arguments) },
            refuse: { Self.refuse($0) },
            makeShell: { self.makeShell(arguments, time: time) },
            runCommandLineMode: { self.runCommandLineMode(arguments, shell: $0) },
            handOver: { self.handOver(arguments, shell: $0) },
            offerMove: { ApplicationsMover(settings: $0.services.settings).offerIfNeeded() },
            upgradeSettings: { $0.services.settings.upgradeStoredSettings() },   // never in a CLI mode
            buildControllers: { self.buildControllers($0) },
            startLaunchWork: { self.startLaunchWork($0) },
            applyQAHooks: { self.applyQAHooks(arguments, shell: $0) },
            showLaunchUI: { _ in self.scheduleLaunchUI() },
            willRun: { log.debug("launch: \($0.rawValue, privacy: .public)") }))
    }

    /// `QuitFlow`: a user quit is cancelled once, stops the services and terminates; a quit Apple Event terminates.
    public func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        quitFlow?.reply(isQuitEvent: QuitFlow.isQuitEvent()) ?? .terminateNow
    }

    /// The synchronous fallback: every service's `stopNow()` in reverse order (nothing in a CLI mode).
    public func applicationWillTerminate(_ notification: Notification) {
        guard launchGate.runsTerminateHooks, let shell else { return }
        #if DEBUG
        scenario?.cancel()
        #endif
        shell.runner.stopNow()
        hud?.stop()
        levelConfirmationPrompt?.stop()
    }

    /// Opening Overbright again (Finder, Spotlight, `open`, the Dock icon) always shows something (D13).
    public func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        guard let appControl, let settings = shell?.services.settings else { return false }
        show(LaunchUI.reopenSurface(welcomeFinished: settings[OnboardingSettings.completedVersion] != nil,
                                    iconVisibility: appControl.iconVisibility))
        return false
    }

    /// The Dock icon's menu (General ▸ Show in Dock).
    public func applicationDockMenu(_ sender: NSApplication) -> NSMenu? { dock?.menu() }

    /// `overbright://` URLs (§7.7): the settings route opens Settings; the control route goes to the router (`off`
    /// always, `on` only with the app's token, both through the policy). A URL that arrives before the launch UI
    /// decided makes the launch a background one (§7.6).
    public func application(_ application: NSApplication, open urls: [URL]) {
        if !hasShownLaunchUI { urlOpenedDuringLaunch = true }
        guard appControl != nil else {
            pendingURLs += urls                                            // handled once the controllers exist
            return
        }
        for url in urls {
            switch URLRoute.parse(url) {
            case .settings(let pane): appControl?.openSettings(pane)
            case .control(let on, let token): Task { _ = try? await Self.intentRouter?.control(on: on, token: token) }
            case nil: log.error("ignored URL with scheme \(url.scheme ?? "-", privacy: .public)")
            }
        }
    }

    /// ⌘, (OverbrightScenes): our Settings window.
    func openSettings() { appControl?.openSettings(nil) }

    // MARK: Launch steps

    /// What opened the app (login, URL, the user), from the current Apple event: logged with the event's class and
    /// ID, journaled when the launch UI decides ([HW: H-L2] reads both).
    private func readOpening() {
        let reading = LaunchUI.currentReading(event: currentAppleEvent())
        openingReading = reading
        opening = reading.opening
        log.info("launch opening: \(reading.logDescription, privacy: .public)")
    }

    private static func refuse(_ refused: [String]) {
        let switches = refused.joined(separator: " ")
        log.error("refusing to start: \(switches, privacy: .public) only work in Debug builds")
        let message = "Overbright: \(switches) only work in Debug builds; this Release build does not start "
            + "rather than ignore them and use the real displays.\n"
        FileHandle.standardError.write(Data(message.utf8))
        exit(EX_USAGE)
    }

    private func makeShell(_ arguments: LaunchArguments, time: SystemTimeSource) -> Shell {
        let defaults = ShellDefaults.forLaunch(arguments)
        let fixture = CompositionRoot.simulatedFixture(for: arguments)
        let context = CompositionRoot.context(defaults: defaults, fixture: fixture, time: time)
        let ports = CompositionRoot.ports(fixture: fixture, context: context,
                                          liveSignals: CompositionRoot.wiresLiveSignals(arguments))
        var scriptedStatus: BoostStatus?
        var scriptedFillLightOn = false
        #if DEBUG
        QAHooks.applyAppearance(defaults.defaults)
        qaKeepsPanelOpen = QAHooks.keepsPanelOpen(arguments)
        if let state = QAHooks.scriptedState(arguments, settings: context.settings, qaSuite: defaults.qaSuite) {
            scriptedStatus = state.status
            scriptedFillLightOn = state.fillLightOn
            qaExpandsWhy = state.expandsWhy
        }
        #endif
        let shell = CompositionRoot.makeShell(context, ports: ports, scriptedStatus: scriptedStatus,
                                              scriptedFillLightOn: scriptedFillLightOn)
        self.shell = shell
        quitFlow = QuitFlow(gate: launchGate, runner: shell.runner)
        return shell
    }

    /// `--diagnostics`, `--monitor` and `--restore-gamma`: run, then quit. True when one of them runs.
    private func runCommandLineMode(_ arguments: LaunchArguments, shell: Shell) -> Bool {
        if let path = arguments.diagnosticsPath {
            Task {
                let report = DiagnosticsReport.build(.of(shell, forClipboard: false))
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

    /// D27: another Overbright runs in this session → it shows itself and this launch quits.
    private func handOver(_ arguments: LaunchArguments, shell: Shell) -> Bool {
        guard !CompositionRoot.skipsSingleInstanceCheck(arguments, ports: shell.ports),
              SingleInstance.handOverIfRunning(arguments: arguments) else { return false }
        log.info("another Overbright runs in this session; handed over")
        NSApp.terminate(nil)
        return true
    }

    /// Controllers, the router connection, the status item (installed by `connect`), the Dock and the HUD.
    private func buildControllers(_ shell: Shell) {
        let services = shell.services
        let appControl = ShellAppControl(settings: services.settings,
                                         loginItems: LoginItemController(service: shell.ports.loginItems))
        services.app = appControl
        let statusItem = StatusItemController(services: services)
        let icon = StatusIconPresence(services: services, statusItem: statusItem)
        let panel = PanelController(services: services)
        #if DEBUG
        panel.closesOnOutsideClicks = !qaKeepsPanelOpen
        panel.expandsWhy = qaExpandsWhy
        #endif
        let welcome = WelcomeWindowController(services: services)
        statusItem.onClick = { [weak panel, weak statusItem] in panel?.toggle(from: statusItem?.button) }
        appControl.connect(ShellAppControl.Controllers(
            icon: icon, panel: panel, settings: SettingsWindowController(services: services), welcome: welcome,
            help: HelpWindowController(services: services), calibration: CalibrationWindowController(services: services),
            selfTest: SelfTestSheetPresenter(), diagnostics: { [weak self] in self?.clipboardDiagnostics() }))
        appControl.installIcon()
        Self.intentRouter?.connect(boost: services.boost, displays: services.displays, signals: services.signals)
        let dock = DockMenuController(services: services)
        dock.start()
        let hud = HUDController(services: services)
        let levelConfirmationPrompt = LevelConfirmationPromptController(services: services)
        hud.start()
        levelConfirmationPrompt.start()
        self.appControl = appControl; self.icon = icon; self.panel = panel; self.welcome = welcome
        self.dock = dock; self.hud = hud; self.levelConfirmationPrompt = levelConfirmationPrompt
        if !pendingURLs.isEmpty {
            let urls = pendingURLs
            pendingURLs = []
            application(NSApplication.shared, open: urls)
        }
    }

    /// The signal handlers, then `LaunchGate`: the launch check and every service, in order.
    private func startLaunchWork(_ shell: Shell) {
        shell.signalHandlers?.install()
        launchGate.launch { await CompositionRoot.runLaunchWork(shell) }
    }

    private func applyQAHooks(_ arguments: LaunchArguments, shell: Shell) {
        #if DEBUG
        guard let appControl, let welcome, let icon, let hud else { return }
        scenario = QAHooks.apply(arguments, to: QAHooks.Targets(shell: shell, appControl: appControl, welcome: welcome,
                                                                statusItem: icon.statusItem, hud: hud))
        #endif
    }

    // MARK: Launch UI

    /// Waits for the status item to be placed (at most `placementWait`) and at least `backgroundLaunchGrace`, then
    /// shows what the launch shows (§7.6).
    private func scheduleLaunchUI() {
        Task {
            let started = ContinuousClock.now
            await icon?.statusItem.waitUntilPlaced(atMost: Self.placementWait)   // the panel anchors to the placed icon
            let left = LaunchUI.backgroundLaunchGrace - started.duration(to: .now)
            if left > .zero { try? await Task.sleep(for: left) }
            showLaunchSurface()
        }
    }

    private func showLaunchSurface() {
        guard let appControl, let services = shell?.services else { return }
        let settings = services.settings
        hasShownLaunchUI = true
        let background = LaunchUI.isBackgroundLaunch(opening: opening, openedURLDuringLaunch: urlOpenedDuringLaunch,
                                                     intentRequests: Self.intentRouter?.requestCount ?? 0)
        if let reading = openingReading {
            let seconds = services.time.now.sinceOrigin.timeInterval
            services.journal.record(reading.journalEvent(seconds: seconds, background: background))
        }
        let surface = LaunchUI.surface(isLoginLaunch: opening == .login, isBackgroundLaunch: background,
                                       welcomeFinished: settings[OnboardingSettings.completedVersion] != nil,
                                       iconVisibility: appControl.iconVisibility)
        log.info("launch UI: \(String(describing: surface), privacy: .public) (opening \(String(describing: self.opening), privacy: .public))")
        show(surface)
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
        return DiagnosticsReport.json(DiagnosticsReport.build(.of(shell, forClipboard: true)))
    }
}
