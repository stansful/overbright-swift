// OverbrightDisplays/Directory/SystemDisplayDirectory.swift — the real `DisplayDirectory`. ARCHITECTURE.md §3.6, §7.1,
// §10.4; D8. Thread: main (NSScreen, CoreGraphics display queries).
// Seeded by WP0a: a read-only snapshot of the online displays from public CoreGraphics and NSScreen facts, read at
// `start()` (or on demand by `--diagnostics` through `onlineDisplays()`). WP2 owns it afterwards and adds the
// reconfiguration callback (begin, remove and debounced after phases), IORegistry facts, clamshell and mirror handling.
// Names are for the UI only; no code compares them (D8).
import AppKit
import CoreGraphics
import Observation
import OverbrightCore

/// Online displays, built-in first, then by key.
@Observable public final class SystemDisplayDirectory: DisplayDirectory, ServiceLifecycle {
    /// Online displays.
    public private(set) var displays: [DisplayFacts] = []
    /// Increments on every change of `displays`.
    public private(set) var generation = 0

    /// An empty directory; constructing it touches nothing.
    public init() {}

    /// The facts of one online display.
    public func facts(for key: DisplayKey) -> DisplayFacts? { displays.first { $0.ref.key == key } }

    /// Re-reads the online displays (read-only).
    public func reload() {
        displays = Self.onlineDisplays()
        generation += 1
    }

    // MARK: ServiceLifecycle

    /// "displays".
    public var serviceName: String { "displays" }
    /// Reads the displays.
    public func start() async { reload() }
    /// Nothing runs.
    public func stop() async {}
    /// Nothing runs.
    public func stopNow() {}

    // MARK: Reading

    /// A read-only snapshot of every online display, built-in first, then by key.
    public static func onlineDisplays() -> [DisplayFacts] {
        var ids = [CGDirectDisplayID](repeating: 0, count: 32)
        var count: UInt32 = 0
        guard CGGetOnlineDisplayList(UInt32(ids.count), &ids, &count) == .success else { return [] }
        let screens = NSScreen.screens
        let facts: [DisplayFacts] = ids.prefix(Int(count)).compactMap { id in
            guard let key = DisplayKey.of(id) else { return nil }
            let screen = screens.first { $0.overbrightDisplayID == id }
            let isBuiltIn = CGDisplayIsBuiltin(id) != 0
            let capacity = Int(CGDisplayGammaTableCapacity(id))
            let vendor = CGDisplayVendorNumber(id), model = CGDisplayModelNumber(id)
            let potential = screen.map { Double($0.maximumPotentialExtendedDynamicRangeColorComponentValue) }
            return DisplayFacts(ref: DisplayRef(key: key, id: id), name: screen?.localizedName ?? "",
                                isBuiltIn: isBuiltIn,
                                isMirrored: CGDisplayMirrorsDisplay(id) != kCGNullDirectDisplay && screen == nil,
                                gammaCapacity: capacity, vendorID: vendor == 0 ? nil : vendor,
                                productID: model == 0 ? nil : model, hasNotch: (screen?.safeAreaInsets.top ?? 0) > 0,
                                panelClass: panelClass(isBuiltIn: isBuiltIn, capacity: capacity, potential: potential))
        }
        return facts.sorted { a, b in a.isBuiltIn != b.isBuiltIn ? a.isBuiltIn : a.ref.key < b.ref.key }
    }

    /// The coarse class from public facts only (WP0a seed; WP2 adds the IORegistry inputs: OLED by minimum luminance,
    /// Apple XDR externals by vendor and peak, PQ support).
    static func panelClass(isBuiltIn: Bool, capacity: Int, potential: Double?) -> PanelClass {
        if capacity == 0 { return .virtualDisplay }
        if isBuiltIn { return (potential ?? 1) > 2 ? .builtInXDR : .builtInLCD }
        return (potential ?? 1) > 1 ? .hdrExternal : .sdrExternal
    }
}
