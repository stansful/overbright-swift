// scripts/soak-control.swift — the soak's control (ARCHITECTURE.md §10.15): a menu bar app that does nothing, run
// beside Overbright so scripts/soak.sh can tell the wake-ups the window server and the system hand every such app from
// Overbright's own. It subscribes to what Overbright subscribes to at rest and nothing else: one status item, and the
// Text Input Sources that Overbright's shortcut key caps read (it reads the keyboard layout once and follows the
// selected-input-source notification, so a keyboard layout switch wakes both). It quits when the process it follows
// exits (a dispatch source on that process, no timer), or at once without one. Original code, MIT; no dependency.
//
//   scripts/soak.sh and scripts/perf.sh build it (scripts/lib.sh build_perf_tools: xcrun swiftc →
//   build/logs/perf/tools/PerfControl.app, LSUIElement) and open it with --follow <pid>
import AppKit
import Carbon

/// One status item and the keyboard layout; quits with the followed process.
final class SoakControl: NSObject, NSApplicationDelegate {
    private var item: NSStatusItem?
    private var layoutObserver: (any NSObjectProtocol)?
    private var followed: (any DispatchSourceProcess)?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "circle.dotted", accessibilityDescription: "Soak control")
        self.item = item
        _ = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue()
        let name = Notification.Name(kTISNotifySelectedKeyboardInputSourceChanged as String)
        layoutObserver = DistributedNotificationCenter.default().addObserver(forName: name, object: nil,
                                                                             queue: .main) { _ in }
        let arguments = CommandLine.arguments
        guard let index = arguments.firstIndex(of: "--follow"), index + 1 < arguments.count,
              let pid = pid_t(arguments[index + 1]), kill(pid, 0) == 0 else {
            NSApp.terminate(nil)
            return
        }
        let source = DispatchSource.makeProcessSource(identifier: pid, eventMask: .exit, queue: .main)
        source.setEventHandler { MainActor.assumeIsolated { NSApp.terminate(nil) } }
        source.resume()
        followed = source
    }
}

let application = NSApplication.shared
let control = SoakControl()
application.delegate = control
application.run()
