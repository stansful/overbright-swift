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

/// Scripted CoreGraphics/NSScreen reads, in the real reader's two steps: the online IDs with their NSScreen facts,
/// then the CoreGraphics facts of those IDs (the step that reads every transfer table).
final class RawSource {
    /// What the displays look like now (the next reads see it).
    var displays: [RawDisplay]
    /// Online IDs that have no UUID (yet): listed online, left out by the CoreGraphics read like `DisplayKey.of` nil.
    var withoutUUID: Set<CGDirectDisplayID> = []
    /// Number of CoreGraphics reads (UUID, capacity, table read, vendor, model, serial, mirror per display) so far.
    private(set) var reads = 0
    /// Number of online-ID and NSScreen reads so far.
    private(set) var screenReads = 0
    init(_ displays: [RawDisplay]) { self.displays = displays }

    /// `CoreGraphicsDisplayReader.onlineScreens()`.
    func readScreens() -> OnlineScreens {
        screenReads += 1
        let ids = displays.map(\.id) + withoutUUID.sorted().filter { id in !displays.contains { $0.id == id } }
        let screens = displays.compactMap { raw in raw.screen.map { (raw.id, $0) } }
        return OnlineScreens(ids: ids, screens: Dictionary(screens, uniquingKeysWith: { first, _ in first }))
    }

    /// `CoreGraphicsDisplayReader.displays(in:gamma:)`: the listed displays that have a UUID, with `online`'s screens.
    func readDisplays(_ online: OnlineScreens) -> [RawDisplay] {
        reads += 1
        return online.ids.compactMap { id in
            guard !withoutUUID.contains(id), var raw = displays.first(where: { $0.id == id }) else { return nil }
            raw.screen = online.screens[id]
            return raw
        }
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
        model = DisplayDirectoryModel(time: time, readScreens: { raw.readScreens() },
                                      readDisplays: { raw.readDisplays($0) }, readRegistry: { box.value })
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
