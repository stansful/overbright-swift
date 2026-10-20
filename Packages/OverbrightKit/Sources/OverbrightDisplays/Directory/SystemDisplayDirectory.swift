// OverbrightDisplays/Directory/SystemDisplayDirectory.swift — the real `DisplayDirectory`. ARCHITECTURE.md §3.6, §7.1,
// §10.4; D8, D9. Thread: main (NSScreen, CoreGraphics display queries); the IORegistry walk runs off it (§8.1 rule 3).
//
// `start()` registers the reconfiguration callback (`ReconfigurationCallback`, a C function that hops to main),
// observes `NSApplication.didChangeScreenParametersNotification` (`queue: .main`) and reads the displays once.
// Reactions (`DisplayDirectoryModel`, timing in `ReconfigurationPipeline`):
// - begin flag → `displayConfigurationBegan` (once per burst; no display queries);
// - remove flag → `displayRemoved(id)` at once, then the display leaves `displays` (no debounce);
// - after phase → a full pass 0.5 s after the last callback (`displaysReconfigured`) and a confirming pass at 2 s;
// - screen parameters → the online IDs and NSScreen facts again (unless a pass is pending), the CoreGraphics facts
//   of the last read reused while the online IDs are the same (no table read per notification, energy D1), then
//   `screenParametersChanged`.
// Events reach `addEventObserver` handlers synchronously on main; the composition root relays them into the engine's
// event stream (WP13). Clamshell: the built-in display is left out while the lid is closed. Hardware mirrors: a member
// without its own NSScreen is `isMirrored` (dim only). Names are for the UI only; no code compares them (D8).
import AppKit
import CoreGraphics
import Foundation
import Observation
import OverbrightCore
import os

private let log = Log.logger(.displays)

/// Online displays, built-in first, then by key, kept current by the reconfiguration callback.
public final class SystemDisplayDirectory: DisplayDirectory, ServiceLifecycle {
    private let model: DisplayDirectoryModel
    private let context: ReconfigurationContext
    private var isRegistered = false
    private var screenObserver: (any NSObjectProtocol)?

    /// A directory that debounces on `time` and reads tables through `gamma` (the "failed read" virtual-display
    /// rule). Constructing it touches nothing; `start()` does.
    public init(time: any TimeSource = SystemTimeSource(), gamma: any GammaPort = CoreGraphicsGamma()) {
        model = DisplayDirectoryModel(time: time,
                                      readScreens: { CoreGraphicsDisplayReader.onlineScreens() },
                                      readDisplays: { CoreGraphicsDisplayReader.displays(in: $0, gamma: gamma) },
                                      readRegistry: { await IORegistryReader.snapshot() })
        context = ReconfigurationContext(receiver: model)
    }

    /// Online displays (observable through the model).
    public var displays: [DisplayFacts] { model.displays }
    /// Increments on every change of `displays`.
    public var generation: Int { model.generation }
    /// The facts of one online display.
    public func facts(for key: DisplayKey) -> DisplayFacts? { model.facts(for: key) }

    /// Registers `handler` for `displayConfigurationBegan`, `displayRemoved(id)`, `displaysReconfigured` and
    /// `screenParametersChanged`, delivered synchronously on main in registration order, until the token is
    /// cancelled or released.
    public func addEventObserver(_ handler: @escaping @MainActor (SystemEvent) -> Void) -> ObservationToken {
        model.addEventObserver(handler)
    }

    // MARK: ServiceLifecycle

    /// "displays".
    public var serviceName: String { "displays" }

    /// Registers the reconfiguration callback and the screen-parameters observer, then reads the displays.
    public func start() async {
        if !isRegistered {
            isRegistered = ReconfigurationCallback.register(context)
            if !isRegistered { log.error("displays: the reconfiguration callback could not be registered") }
        }
        if screenObserver == nil {
            screenObserver = NotificationCenter.default.addObserver(
                forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated { self?.model.screenParametersChanged() }      // queue: .main
            }
        }
        await model.reload()
        log.info("displays: started with \(self.model.displays.count, privacy: .public) displays")
    }

    /// Stops listening (the list stays as it was).
    public func stop() async { stopNow() }

    /// Removes the callback and the observer and drops any pending pass.
    public func stopNow() {
        if isRegistered {
            ReconfigurationCallback.unregister(context)
            isRegistered = false
        }
        if let screenObserver {
            NotificationCenter.default.removeObserver(screenObserver)
            self.screenObserver = nil
        }
        model.cancelPending()
    }

    // MARK: Reading without a service

    /// A read-only snapshot of every online display, built-in first, then by key (`--diagnostics`; no service
    /// started). Reads the IORegistry on the calling thread.
    public static func onlineDisplays() -> [DisplayFacts] {
        DisplayFactsBuilder.facts(from: CoreGraphicsDisplayReader.onlineDisplays(gamma: CoreGraphicsGamma()),
                                  registry: IORegistryReader.read())
    }
}
