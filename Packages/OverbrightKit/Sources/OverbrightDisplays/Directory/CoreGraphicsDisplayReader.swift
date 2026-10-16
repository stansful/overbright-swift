// OverbrightDisplays/Directory/CoreGraphicsDisplayReader.swift — reads the online displays' CoreGraphics and NSScreen
// facts. ARCHITECTURE.md §3.6, §7.1 (NSScreen objects are re-fetched on every read), §8.1 rule 1, §10.4.
// Thread: main (NSScreen). Read-only: CoreGraphics display queries and the transfer-table read through `GammaPort`.
import AppKit
import CoreGraphics
import OverbrightCore

/// Reads `RawDisplay`s.
enum CoreGraphicsDisplayReader {
    /// Every online display that has a UUID, in CoreGraphics order. `gamma` answers capacity and the readability of
    /// the table (the "failed read" virtual-display rule).
    static func onlineDisplays(gamma: any GammaPort) -> [RawDisplay] {
        #if DEBUG
        dispatchPrecondition(condition: .onQueue(.main))
        #endif
        let screens = NSScreen.screens.compactMap { screen -> (CGDirectDisplayID, RawDisplay.Screen)? in
            guard let id = screen.overbrightDisplayID else { return nil }
            return (id, RawDisplay.Screen(name: screen.localizedName,
                                          potential: Double(screen.maximumPotentialExtendedDynamicRangeColorComponentValue),
                                          hasNotch: screen.safeAreaInsets.top > 0))
        }
        return onlineIDs().compactMap { id in
            guard let key = DisplayKey.of(id) else { return nil }
            let capacity = gamma.capacity(of: id)
            return RawDisplay(id: id, key: key, isBuiltIn: CGDisplayIsBuiltin(id) != 0, gammaCapacity: capacity,
                              tableReadable: capacity > 0 && (try? gamma.read(id)) != nil,
                              vendor: CGDisplayVendorNumber(id), model: CGDisplayModelNumber(id),
                              serial: CGDisplaySerialNumber(id), mirrorsDisplay: CGDisplayMirrorsDisplay(id),
                              screen: screens.first { $0.0 == id }?.1)
        }
    }

    /// `CGGetOnlineDisplayList`, however many displays are online. Any thread.
    nonisolated static func onlineIDs() -> [CGDirectDisplayID] {
        var count: UInt32 = 0
        guard CGGetOnlineDisplayList(0, nil, &count) == .success, count > 0 else { return [] }
        var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
        guard CGGetOnlineDisplayList(count, &ids, &count) == .success else { return [] }
        return Array(ids.prefix(Int(count)))
    }
}
