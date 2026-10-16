// OverbrightDisplays/Directory/DisplayDirectoryModel.swift — the state of the display directory: the list, its
// generation, the event stream and the reconfiguration timing. ARCHITECTURE.md §3.6, §4.1, §4.3, §7.1, §10.4; D9.
// Thread: main.
//
// `SystemDisplayDirectory` owns one, wired to the real readers, the C callback and the screen-parameters
// notification; tests drive one with fake readers and a `ManualTimeSource` (the real directory is constructed only in
// hardware-gated suites, D24). Events go to observers synchronously, in registration order, before the method that
// caused them returns, like `SystemSignals` (§4.1): a removal reaches every observer before the list changes.
import CoreGraphics
import Observation
import OverbrightCore
import os

private let log = Log.logger(.displays)

/// The online displays and the display events of §7.1.
@Observable final class DisplayDirectoryModel: DisplayDirectory, ReconfigurationReceiver {
    /// Online displays, built-in first, then by key.
    private(set) var displays: [DisplayFacts] = []
    /// Increments on every change of `displays`.
    private(set) var generation = 0

    /// The timing of reconfiguration callbacks.
    let pipeline: ReconfigurationPipeline
    private let readRaw: () -> [RawDisplay]
    private let readRegistry: @Sendable () async -> IORegistryFacts
    /// The IORegistry facts of the last full pass (screen-parameter refreshes reuse them).
    @ObservationIgnored private(set) var registry: IORegistryFacts = .unknown
    @ObservationIgnored private var observers: [(id: UInt64, handler: @MainActor (SystemEvent) -> Void)] = []
    @ObservationIgnored private var lastObserverID: UInt64 = 0

    /// A model that reads CoreGraphics/NSScreen facts with `readRaw` (main) and the IORegistry with `readRegistry`
    /// (off the main actor), and waits on `time`.
    init(time: any TimeSource, readRaw: @escaping () -> [RawDisplay],
         readRegistry: @escaping @Sendable () async -> IORegistryFacts) {
        self.readRaw = readRaw
        self.readRegistry = readRegistry
        pipeline = ReconfigurationPipeline(time: time)
        pipeline.onBegan = { [weak self] in self?.began() }
        pipeline.onRemoved = { [weak self] id in self?.removed(id) }
        pipeline.onSettle = { [weak self] pass in await self?.settle(pass) }
    }

    /// The facts of one online display.
    func facts(for key: DisplayKey) -> DisplayFacts? { displays.first { $0.ref.key == key } }

    // MARK: Events

    /// Registers `handler` for `displayConfigurationBegan`, `displayRemoved`, `displaysReconfigured` and
    /// `screenParametersChanged`, until the token is cancelled or released.
    func addEventObserver(_ handler: @escaping @MainActor (SystemEvent) -> Void) -> ObservationToken {
        lastObserverID += 1
        let id = lastObserverID
        observers.append((id, handler))
        return ObservationToken { [weak self] in self?.observers.removeAll { $0.id == id } }
    }

    /// Number of registered event observers.
    var observerCount: Int { observers.count }

    // MARK: Inputs

    /// A full pass: IORegistry (off the main actor), then CoreGraphics and NSScreen; publishes a changed list.
    func reload() async {
        let registry = await readRegistry()
        self.registry = registry
        publish(DisplayFactsBuilder.facts(from: readRaw(), registry: registry))
    }

    /// One reconfiguration callback (from `ReconfigurationCallback`, on main).
    func reconfigured(display: CGDirectDisplayID, flags: CGDisplayChangeSummaryFlags) {
        pipeline.handle(display: display, flags: flags)
    }

    /// `NSApplication.didChangeScreenParametersNotification` (also posted when headroom changes): re-reads the cheap
    /// CoreGraphics and NSScreen facts with the last IORegistry facts, unless a reconfiguration pass is pending (the
    /// displays are in flux and that pass reads everything), then emits `screenParametersChanged`.
    func screenParametersChanged() {
        if !pipeline.isPending {
            publish(DisplayFactsBuilder.facts(from: readRaw(), registry: registry))
        }
        emit(.screenParametersChanged)
    }

    /// Drops any pending reconfiguration pass (stop).
    func cancelPending() { pipeline.cancel() }

    // MARK: Pipeline reactions

    private func began() {
        log.info("displays: configuration began")
        emit(.displayConfigurationBegan)
    }

    /// The event first (controllers order their windows out), then the list.
    private func removed(_ id: CGDirectDisplayID) {
        log.info("displays: display \(id, privacy: .public) removed")
        emit(.displayRemoved(id))
        let remaining = displays.filter { $0.ref.id != id }
        if remaining.count != displays.count { publish(remaining) }
    }

    /// The debounced pass always reports `displaysReconfigured`; the confirming pass only when it changed the list.
    private func settle(_ pass: ReconfigurationPipeline.Pass) async {
        let before = displays
        await reload()
        log.info("displays: \(pass == .debounced ? "settled" : "confirmed", privacy: .public) with \(self.displays.count, privacy: .public) displays, generation \(self.generation, privacy: .public)")
        if pass == .debounced || displays != before { emit(.displaysReconfigured) }
    }

    // MARK: Private

    private func publish(_ facts: [DisplayFacts]) {
        guard facts != displays else { return }
        displays = facts
        generation += 1
    }

    private func emit(_ event: SystemEvent) {
        for observer in observers { observer.handler(event) }
    }
}
