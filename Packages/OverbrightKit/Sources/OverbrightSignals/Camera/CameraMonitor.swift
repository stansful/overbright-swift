// OverbrightSignals/Camera/CameraMonitor.swift — `SystemSnapshot.isCameraInUse`. ARCHITECTURE.md §7.1 ("Camera in use":
// runs while Fill Light's camera rule is on), §7.3, D12, D22.
// Event-driven: listeners on every device's running state and on the device list (hot-plug re-registers them); each
// change re-reads the devices, applies the transport filter and feeds `CameraDebouncer`; one deadline publishes the
// value once it has held (1 s on, 3 s off). Nothing runs while stopped.
// Thread: main (CoreMediaIO's listener proc hops here through `MainHop`; see `CoreMediaIOCameras`).
import OverbrightCore

/// Watches the cameras while the camera rule is on.
final class CameraMonitor {
    /// Receives each new debounced value (set by the owner once it exists).
    var onChange: (@MainActor (Bool) -> Void)?
    private let devices: any CameraDevices
    private let time: any TimeSource
    private let deadline: DeadlineTimer
    private var filter: CameraFilter = .anyCamera
    private var debouncer = CameraDebouncer()
    private var listeners: ObservationToken?
    private var observedDevices: [UInt32] = []

    /// A monitor over `devices`.
    init(devices: any CameraDevices, time: any TimeSource) {
        self.devices = devices; self.time = time
        deadline = DeadlineTimer(time: time)
    }

    /// Listening now.
    private(set) var isRunning = false
    /// The debounced value.
    var isInUse: Bool { debouncer.published }

    /// Starts listening with `filter` and reads the devices once.
    func start(filter: CameraFilter) {
        self.filter = filter
        isRunning = true
        refresh()
    }

    /// Stops listening; a published "in use" becomes false at once (the rule is off, nothing waits for it).
    func stop() {
        listeners?.cancel()
        listeners = nil
        observedDevices = []
        deadline.cancel()
        isRunning = false
        let wasInUse = debouncer.published
        debouncer = CameraDebouncer()
        if wasInUse { onChange?(false) }
    }

    /// Applies a new filter (Settings ▸ Fill Light ▸ Cameras).
    func setFilter(_ filter: CameraFilter) {
        guard filter != self.filter else { return }
        self.filter = filter
        if isRunning { refresh() }
    }

    /// Re-reads the devices (every listener callback lands here).
    func refresh() {
        guard isRunning else { return }
        let ids = devices.deviceIDs()
        if listeners == nil || ids != observedDevices {
            listeners?.cancel()
            listeners = devices.observe(devices: ids) { [weak self] in self?.refresh() }
            observedDevices = ids
        }
        let inUse = ids.contains { id in
            CameraTransport.counts(transport: devices.transportType(id), filter: filter)
                && devices.isRunningSomewhere(id) == true
        }
        if let due = debouncer.observe(inUse, at: time.now) {
            deadline.schedule(at: due) { [weak self] in self?.resolve() }
        } else {
            deadline.cancel()
        }
    }

    private func resolve() {
        if debouncer.resolve(at: time.now) { onChange?(debouncer.published) }
    }
}
