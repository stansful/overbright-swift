// OverbrightDisplays/Directory/CoreGraphicsDisplayReader.swift — reads the online displays' CoreGraphics and NSScreen
// facts. ARCHITECTURE.md §3.6, §7.1 (NSScreen objects are re-fetched on every read), §8.1 rule 1, §10.4.
// Thread: main (NSScreen). Read-only: CoreGraphics display queries and the transfer-table read through `GammaPort`.
//
// Two steps, so a screen-parameters pass can stop after the first (energy D1): `onlineScreens()` lists the online IDs
// and reads each NSScreen (no per-display CoreGraphics query, no table read); `displays(in:gamma:)` adds the
// CoreGraphics facts of every listed display (UUID, capacity, a table read, vendor, model, serial, mirror).
import AppKit
import CoreGraphics
import OverbrightCore

/// Reads `RawDisplay`s.
enum CoreGraphicsDisplayReader {
    /// Every online display that has a UUID, in CoreGraphics order. `gamma` answers capacity and the readability of
    /// the table (the "failed read" virtual-display rule).
    static func onlineDisplays(gamma: any GammaPort) -> [RawDisplay] {
        displays(in: onlineScreens(), gamma: gamma)
    }

    /// The online IDs and the NSScreen facts (name, potential, notch) of each display that has its own screen.
    static func onlineScreens() -> OnlineScreens {
        #if DEBUG
        dispatchPrecondition(condition: .onQueue(.main))
        #endif
        var screens: [CGDirectDisplayID: RawDisplay.Screen] = [:]
        for screen in NSScreen.screens {
            guard let id = screen.overbrightDisplayID, screens[id] == nil else { continue }
            screens[id] = RawDisplay.Screen(name: screen.localizedName,
                                            potential: Double(screen.maximumPotentialExtendedDynamicRangeColorComponentValue),
                                            hasNotch: screen.safeAreaInsets.top > 0)
        }
        return OnlineScreens(ids: onlineIDs(), screens: screens)
    }

    /// The listed displays that have a UUID, with their CoreGraphics facts and `online`'s NSScreen facts.
    static func displays(in online: OnlineScreens, gamma: any GammaPort) -> [RawDisplay] {
        #if DEBUG
        dispatchPrecondition(condition: .onQueue(.main))
        #endif
        return online.ids.compactMap { id in
            guard let key = DisplayKey.of(id) else { return nil }
            let capacity = gamma.capacity(of: id)
            return RawDisplay(id: id, key: key, isBuiltIn: CGDisplayIsBuiltin(id) != 0, gammaCapacity: capacity,
                              tableReadable: capacity > 0 && (try? gamma.read(id)) != nil,
                              vendor: CGDisplayVendorNumber(id), model: CGDisplayModelNumber(id),
                              serial: CGDisplaySerialNumber(id), mirrorsDisplay: CGDisplayMirrorsDisplay(id),
                              screen: online.screens[id])
        }
    }

    /// `CGGetOnlineDisplayList`'s signature.
    typealias DisplayList = (UInt32, UnsafeMutablePointer<CGDirectDisplayID>?, UnsafeMutablePointer<UInt32>?) -> CGError

    /// How many IDs the first `CGGetOnlineDisplayList` call makes room for.
    nonisolated static let onlineListCapacity = 16

    /// `CGGetOnlineDisplayList`, however many displays are online. Any thread.
    nonisolated static func onlineIDs() -> [CGDirectDisplayID] { onlineIDs(list: CGGetOnlineDisplayList) }

    /// The online IDs from `list`: one call (one WindowServer round trip, ≈ 8 µs) while fewer than
    /// `onlineListCapacity` displays are online; when the room was filled, a count call and a list call of that
    /// size, as many as there are.
    nonisolated static func onlineIDs(list: DisplayList) -> [CGDirectDisplayID] {
        var ids = [CGDirectDisplayID](repeating: 0, count: onlineListCapacity)
        var count: UInt32 = 0
        guard list(UInt32(onlineListCapacity), &ids, &count) == .success else { return [] }
        if Int(count) < onlineListCapacity { return Array(ids.prefix(Int(count))) }
        guard list(0, nil, &count) == .success, count > 0 else { return [] }
        ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
        guard list(count, &ids, &count) == .success else { return [] }
        return Array(ids.prefix(Int(count)))
    }
}
