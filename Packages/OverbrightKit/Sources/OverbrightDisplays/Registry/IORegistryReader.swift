// OverbrightDisplays/Registry/IORegistryReader.swift — the read-only IOKit walk behind `IORegistryFacts`.
// ARCHITECTURE.md §8.1 rule 3 (an IORegistry walk at reconfiguration leaves the main actor: `snapshot()` is
// `@concurrent`), §9.2 rule 6 (public IOKit property reads of undocumented keys, each optional), §10.4.
// Thread: any (nonisolated; IOKit property reads are thread-safe). Reads named properties only, never a whole
// property table (the backlight node carries kilobytes of calibration data), and opens no user client.
import Foundation
import IOKit

/// Reads `IORegistryFacts` from the live IORegistry.
nonisolated enum IORegistryReader {
    /// The facts now, off the caller's actor.
    @concurrent static func snapshot() async -> IORegistryFacts { read() }

    /// The facts now, on the calling thread (`--diagnostics`, the first pass of `SystemDisplayDirectory.onlineDisplays`).
    static func read() -> IORegistryFacts {
        var hasFramebuffers = false
        var externals: [ExternalPanelFacts] = []
        forEachService(IOServiceMatching("IOMobileFramebufferShim")) { service in
            hasFramebuffers = true
            guard IORegistryValue.bool(property(service, "external")) == true,
                  let attributes = IORegistryValue.dictionary(property(service, "DisplayAttributes")),
                  let facts = ExternalPanelFacts.parse(displayAttributes: attributes) else { return true }
            externals.append(facts)
            return true
        }
        return IORegistryFacts(builtIn: builtInPanel(), externals: externals, hasFramebufferServices: hasFramebuffers,
                               isClamshellClosed: clamshellClosed())
    }

    // MARK: Entries

    /// The device tree's `backlight` node plus `AppleARMBacklight`'s display parameters.
    private static func builtInPanel() -> BuiltInPanelFacts? {
        var backlight: [String: Any]?
        forEachService(IOServiceNameMatching("backlight")) { service in
            let keys = ["EDRPotentialHeadroom", "user-accessible-max-nits"]
            let values = keys.compactMap { key in property(service, key).map { (key, $0) } }
            guard !values.isEmpty else { return true }
            backlight = Dictionary(values, uniquingKeysWith: { first, _ in first })
            return false
        }
        var parameters: [String: Any]?
        forEachService(IOServiceMatching("AppleARMBacklight")) { service in
            parameters = IORegistryValue.dictionary(property(service, "IODisplayParameters"))
            return parameters == nil
        }
        return BuiltInPanelFacts.parse(backlight: backlight, displayParameters: parameters)
    }

    /// `IOPMrootDomain` ▸ `AppleClamshellState`; nil without a lid.
    private static func clamshellClosed() -> Bool? {
        var closed: Bool?
        forEachService(IOServiceMatching("IOPMrootDomain")) { service in
            closed = IORegistryValue.bool(property(service, "AppleClamshellState"))
            return false
        }
        return closed
    }

    // MARK: IOKit

    /// Calls `body` for each service matching `matching` until it returns false. Releases every object.
    private static func forEachService(_ matching: CFMutableDictionary?, _ body: (io_service_t) -> Bool) {
        guard let matching else { return }
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS else { return }
        defer { IOObjectRelease(iterator) }
        var service = IOIteratorNext(iterator)
        var proceed = true
        while service != 0 {
            if proceed { proceed = body(service) }
            IOObjectRelease(service)
            service = IOIteratorNext(iterator)
        }
    }

    /// One named property of `entry` as a Foundation value (`Data`, `NSNumber`, `String`, `[String: Any]`).
    private static func property(_ entry: io_registry_entry_t, _ key: String) -> Any? {
        IORegistryEntryCreateCFProperty(entry, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue()
    }
}
