// OverbrightAppShell/Windows/WelcomeWindowController.swift — the Welcome window. ARCHITECTURE.md §7.6, §10.2; D16;
// DESIGN.md §8. Seam written by WP0a (§10.0): `init(services:)` and `show(step:)` are fixed; WP0b ported Cranny's
// controller (the owner's MIT code) and WP12 fills the steps.
//
// 640 × 480, full-size content, hidden title bar, not resizable, centred on the main display, hosting `WelcomeView`
// around a `WelcomeSession`. Shown at the first launch that is not a login launch (the launch UI, `LaunchUI`), on a
// reopen while unfinished, from Settings ▸ About and by `--qa-welcome <step>`. The close button counts as Skip
// (`WelcomeSession.windowWillClose`); a visual QA run records nothing. The decisions are pure (`WelcomeWindowPolicy`)
// and tested without windows.
import AppKit
import Foundation
import OverbrightCore
import OverbrightOnboarding
import os
import SwiftUI

private let log = Log.logger(.onboarding)

/// Owns the Welcome window.
final class WelcomeWindowController: NSObject, NSWindowDelegate {
    private let services: OverbrightServices
    private let arguments: LaunchArguments
    private(set) var window: NSWindow?
    /// The open window's state (nil while no window exists).
    private(set) var session: WelcomeSession?
    /// The app that was frontmost before the window opened gets activation back when it closes.
    private var previousApp: NSRunningApplication?
    /// The app is quitting (⌘Q, the menu, a script): a close then is a quit, not a Skip.
    private var isTerminating = false
    private var terminateObserver: (any NSObjectProtocol)?

    /// A controller for the app's services.
    convenience init(services: OverbrightServices) {
        self.init(services: services, arguments: .current)
    }

    /// Tests pass the launch arguments.
    init(services: OverbrightServices, arguments: LaunchArguments) {
        self.services = services
        self.arguments = arguments
        super.init()
        terminateObserver = NotificationCenter.default.addObserver(forName: NSApplication.willTerminateNotification,
                                                                   object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.isTerminating = true }               // queue: .main
        }
    }

    isolated deinit {
        if let terminateObserver { NotificationCenter.default.removeObserver(terminateObserver) }
    }

    /// Shows Welcome at `step` (a `WelcomeStep` name; unknown or nil = the first step), or brings the open window
    /// forward. Call in response to a user action or at the first launch.
    func show(step: String?) {
        let isVisualQA = WelcomeWindowPolicy.isVisualQA(arguments)
        let window = preparedWindow(at: step, isVisualQA: isVisualQA)
        if isVisualQA {
            window.orderFrontRegardless()         // screenshots only: never take focus from whoever uses the Mac
        } else {
            NSApp.activate()
            window.makeKeyAndOrderFront(nil)
        }
        log.info("welcome shown at \(self.session?.step.rawValue ?? "-", privacy: .public)")
    }

    /// The Welcome window, not yet ordered in: the open one (unchanged), or a new one at `step`.
    func preparedWindow(at step: String?, isVisualQA: Bool = false) -> NSWindow {
        if let window { return window }
        let front = NSWorkspace.shared.frontmostApplication
        previousApp = front?.processIdentifier == ProcessInfo.processInfo.processIdentifier ? nil : front
        let session = WelcomeSession(services: services, initialStep: WelcomeWindowPolicy.step(named: step),
                                     recordsOutcome: !isVisualQA) { [weak self] _ in self?.window?.close() }
        self.session = session
        // The FRAME is 640 × 480 and the SwiftUI content covers all of it, title bar included. A hosting view that IS
        // the window's content view resizes the window to its content plus the hidden title bar on every layout
        // (NSHostingView.windowDidLayout; 32 pt on macOS 27, even with no sizing options), so it sits inside a plain
        // container instead (Cranny's finding).
        let host = NSHostingView(rootView: WelcomeView(session: session))
        host.sizingOptions = []
        let container = NSView(frame: CGRect(origin: .zero, size: WelcomeView.windowSize))
        host.frame = container.bounds
        host.autoresizingMask = [.width, .height]
        container.addSubview(host)
        let window = NSWindow(contentRect: CGRect(origin: .zero, size: WelcomeView.windowSize),
                              styleMask: [.titled, .closable, .fullSizeContentView], backing: .buffered, defer: false)
        window.contentView = container
        window.setFrame(CGRect(origin: window.frame.origin, size: WelcomeView.windowSize), display: false)
        window.title = WelcomeView.windowTitle
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
        window.isMovableByWindowBackground = true
        window.collectionBehavior = [.moveToActiveSpace, .fullScreenNone]
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()
        self.window = window
        return window
    }

    func windowWillClose(_ notification: Notification) {
        // The close button before an outcome counts as Skip (DESIGN.md §8); quitting Overbright while Welcome is open
        // records nothing, like its Quit Overbright button.
        log.info("welcome closing\(self.isTerminating ? " (quitting)" : "", privacy: .public)")
        if isTerminating { session?.appWillTerminate() } else { session?.windowWillClose() }
        window = nil
        session = nil
        // Cooperative activation hand-back, only while Overbright is still the active app: a close button clicked from
        // another app, or a Welcome that ends after the person moved on, takes nothing.
        if let previousApp,
           WelcomeWindowPolicy.handsBackActivation(isActive: NSApp.isActive,
                                                   previousAppIsRunning: !previousApp.isTerminated) {
            NSApp.yieldActivation(to: previousApp)
            previousApp.activate(from: .current, options: [])
        }
        previousApp = nil
    }
}

/// `WelcomeWindowController`'s decisions (pure, tested in OverbrightAppShellTests).
enum WelcomeWindowPolicy {
    /// The step a name asks for: a known step name, else the first step (an unknown QA step name shows step 1).
    static func step(named name: String?) -> WelcomeStep {
        name.flatMap(WelcomeStep.init(name:)) ?? .hello
    }

    /// A scripted Welcome capture (`--qa-welcome <step>`, Debug): it shows exactly what it asks for, takes no focus
    /// and records nothing. Other QA runs (`make run`) record in their own defaults suite like a real launch.
    static func isVisualQA(_ arguments: LaunchArguments) -> Bool {
        arguments.qaWelcomeStep != nil
    }

    /// Activation goes back to the app that was in front only while Overbright is still active (never steal focus).
    static func handsBackActivation(isActive: Bool, previousAppIsRunning: Bool) -> Bool {
        isActive && previousAppIsRunning
    }
}
