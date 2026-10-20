// OverbrightTriggers/Factory/SystemTriggerFactory.swift — the real `TriggerFactory`: makes the ladder's trigger
// windows, counts the open ones, and removes every one when the service stops. ARCHITECTURE.md §3.6, §4.7, §7.4 (stop
// order: Boost stops first, Triggers after it), §8.4 (`triggerWindows`), D22, D24. Thread: main.
//
// Making a handle opens nothing: a trigger's window is ordered in by its first `present(_:)`. Nothing runs until the
// engine arms a rung (zero work while off).
import CoreGraphics
import Foundation
import OverbrightCore
import os

private let log = Log.logger(.trigger)

/// Makes T1–T4 triggers (`TriggerFactory`); an ordered service (`ServiceLifecycle`).
public final class SystemTriggerFactory: TriggerFactory, ServiceLifecycle {
    /// Lab switches for the hardware session (both off by default).
    public struct Options: Hashable, Sendable {
        /// Enables T1 on macOS 14–25 through the deprecated `CALayer` EDR flag (untested on a real 14/15 Mac, D4).
        public var allowsLegacyLayerPath: Bool
        /// Tags T2/T3's `CAMetalLayer` (`contentsHeadroom` + `.high`, macOS 26+) and re-tags it on
        /// `requestHeadroom(_:)` (tag policy B for Metal, decided by H-T2c).
        public var tagsMetalLayers: Bool

        /// Both off by default.
        public init(allowsLegacyLayerPath: Bool = false, tagsMetalLayers: Bool = false) {
            self.allowsLegacyLayerPath = allowsLegacyLayerPath
            self.tagsMetalLayers = tagsMetalLayers
        }
    }

    private let environment: TriggerEnvironment
    private let registry = TriggerWindowRegistry()

    /// The factory of the app: real screens and windows, each display's own Metal device, sleeps on `time`, HLG stills
    /// in `cacheDirectory` (`AppPaths.caches`, created on first use). Constructing it touches nothing.
    public convenience init(time: any TimeSource, cacheDirectory: URL, options: Options = Options()) {
        var environment = TriggerEnvironment.live(time: time, cacheDirectory: cacheDirectory)
        environment.allowsLegacyLayerPath = options.allowsLegacyLayerPath
        environment.tagsMetalLayers = options.tagsMetalLayers
        self.init(environment: environment)
    }

    /// A factory over an explicit environment (tests: a recording presenter, fixed screens, scripted surfaces).
    init(environment: TriggerEnvironment) {
        self.environment = environment
    }

    // MARK: TriggerFactory

    /// Whether `strategy` can run on this Mac and OS: T1 needs macOS 26 (or the legacy switch); T2/T3 need a Metal
    /// device on the display, which `makeTrigger` checks per display; T4 and T4-alt run from macOS 14.
    public func isAvailable(_ strategy: TriggerStrategy) -> Bool {
        switch strategy {
        case .taggedLayer:
            if #available(macOS 26.0, *) { return true }
            return environment.allowsLegacyLayerPath
        case .metalOneShot, .metalKeepAlive, .hlgSampleBuffer, .hlgStill:
            return true
        }
    }

    /// A trigger for `request` on `display`, not yet presented (no window yet). Throws `TriggerError.displayGone`
    /// when the display has no screen, `.needsNewerMacOS(26)` for T1 where it cannot run, and `.noMetalDevice` for
    /// T2/T3 without a Metal device on that display.
    public func makeTrigger(_ request: TriggerRequest, on display: DisplayRef) throws -> any TriggerHandle {
        guard let screen = environment.screens.geometry(of: display.id) else { throw TriggerError.displayGone }
        guard isAvailable(request.strategy) else { throw TriggerError.needsNewerMacOS(26) }
        let host = TriggerHost(display: display,
                               shape: .trigger(placement: request.placement, edgePoints: request.edgePoints),
                               screens: environment.screens, presenter: environment.presenter)
        switch request.strategy {
        case .taggedLayer:
            return TaggedLayerTrigger(request: request, host: host, allowsLegacyPath: environment.allowsLegacyLayerPath,
                                      registry: registry)
        case .metalOneShot, .metalKeepAlive:
            let edge = TriggerGeometry.clampedEdge(request.edgePoints)
            let pixels = TriggerGeometry.pixelEdge(points: edge, backingScale: screen.backingScaleFactor)
            guard let surface = environment.makeClearSurface(display.id, pixels) else {
                log.error("No Metal device for display \(display.id)")
                throw TriggerError.noMetalDevice
            }
            return MetalClearTrigger(request: request, host: host, surface: surface, time: environment.time,
                                     tagsLayer: environment.tagsMetalLayers, registry: registry)
        case .hlgStill:
            return HLGStillTrigger(request: request, host: host, stills: environment.stills, time: environment.time,
                                   registry: registry)
        case .hlgSampleBuffer:
            return HLGSampleBufferTrigger(request: request, host: host, time: environment.time, registry: registry)
        }
    }

    /// Trigger windows that exist now (diagnostics `triggerWindows`; smoke asserts 0).
    public var openWindowCount: Int { registry.openWindowCount }

    // MARK: ServiceLifecycle

    /// "triggers".
    public var serviceName: String { "triggers" }

    /// Nothing to start: windows open only when the engine arms a rung.
    public func start() async {}

    /// Removes every trigger the engine left behind. Boost stops first and un-scales before it removes
    /// its own windows (§4.5 invariant 2), so this is only the backstop.
    public func stop() async { removeAll() }

    /// The same, synchronously (`applicationWillTerminate`).
    public func stopNow() { removeAll() }

    /// Orders out and releases every live trigger.
    public func removeAll() {
        let count = registry.openWindowCount
        registry.removeAll()
        if count > 0 { log.info("Removed \(count) trigger windows at stop") }
    }
}
