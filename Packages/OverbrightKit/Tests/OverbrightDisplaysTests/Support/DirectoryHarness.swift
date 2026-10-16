// OverbrightDisplaysTests/Support/DirectoryHarness.swift — a `DisplayDirectoryModel` over scripted reads and a
// `ManualTimeSource`, recording every event with the list as the observer saw it. The real `SystemDisplayDirectory`
// is the same model wired to CoreGraphics, NSScreen and IOKit (constructed only in hardware-gated suites, D24).
import CoreGraphics
import Foundation
import OverbrightCore
@testable import OverbrightDisplays

/// A value behind a lock (the registry read runs off the main actor in the real directory).
/// `@unchecked Sendable`: `stored` is only touched under `lock`.
nonisolated final class LockedValue<Value: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: Value
    /// A box holding `value`.
    init(_ value: Value) { stored = value }
    /// The value.
    var value: Value {
        get { lock.withLock { stored } }
        set { lock.withLock { stored = newValue } }
    }
}

/// Scripted CoreGraphics/NSScreen reads.
final class RawSource {
    /// What the next read returns.
    var displays: [RawDisplay]
    /// Number of reads so far.
    private(set) var reads = 0
    init(_ displays: [RawDisplay]) { self.displays = displays }
    func read() -> [RawDisplay] {
        reads += 1
        return displays
    }
}

/// The model under test, its inputs and what its observers saw.
final class DirectoryHarness {
    let time = ManualTimeSource()
    let raw: RawSource
    let registry: LockedValue<IORegistryFacts>
    let model: DisplayDirectoryModel
    /// Every event in order.
    private(set) var events: [SystemEvent] = []
    /// The display IDs listed when each event arrived.
    private(set) var listedAtEvent: [[CGDirectDisplayID]] = []
    private var token: ObservationToken?

    /// The owner's built-in display and MSI, lid open.
    init(displays: [RawDisplay] = [RawDisplayFixtures.builtIn(), RawDisplayFixtures.msi()],
         registry: IORegistryFacts = RawDisplayFixtures.ownerRegistry()) {
        let raw = RawSource(displays)
        let box = LockedValue(registry)
        self.raw = raw
        self.registry = box
        model = DisplayDirectoryModel(time: time, readRaw: { raw.read() }, readRegistry: { box.value })
        token = model.addEventObserver { [weak self] event in
            guard let self else { return }
            events.append(event)
            listedAtEvent.append(model.displays.map(\.ref.id))
        }
    }

    /// The model after its first full pass.
    static func started(displays: [RawDisplay] = [RawDisplayFixtures.builtIn(), RawDisplayFixtures.msi()]) async
        -> DirectoryHarness {
        let harness = DirectoryHarness(displays: displays)
        await harness.model.reload()
        return harness
    }

    /// One reconfiguration callback, as `ReconfigurationCallback` delivers it on main.
    func callback(_ display: CGDirectDisplayID, _ flags: CGDisplayChangeSummaryFlags) {
        model.reconfigured(display: display, flags: flags)
    }

    /// Moves the clock, after letting tasks scheduled by the last callback start their sleep (a sleep that starts
    /// after `advance` would be measured from the advanced time).
    func advance(_ duration: Duration) async {
        await settle()
        await time.advance(by: duration)
    }

    /// Lets main-actor tasks that were just created run up to their first suspension.
    func settle() async {
        for _ in 0..<20 { await Task.yield() }
    }

    /// How many `displaysReconfigured` events arrived.
    var reconfiguredCount: Int { events.count(where: { $0 == .displaysReconfigured }) }

    /// Stops observing.
    func stopObserving() { token?.cancel() }
}
