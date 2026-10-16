// OverbrightDisplays/Registry/IORegistryFacts.swift — one read-only snapshot of the IORegistry facts Overbright uses.
// ARCHITECTURE.md §8.1 rule 3 (read off the main actor at reconfiguration), §9.2 rule 6, §10.4, D8;
// docs/research/display-facts.md §5. The value is pure; `IORegistryReader` fills it.
import Foundation

/// The built-in panel, every external panel with `DisplayAttributes`, whether Apple-silicon framebuffer services exist
/// (the "no framebuffer service" virtual-display rule needs them), and the lid state.
public nonisolated struct IORegistryFacts: Hashable, Sendable {
    /// The built-in panel; nil on Macs without one or when the keys are missing.
    public var builtIn: BuiltInPanelFacts?
    /// One entry per external `IOMobileFramebufferShim` that carries `DisplayAttributes` (a connected display).
    public var externals: [ExternalPanelFacts]
    /// At least one `IOMobileFramebufferShim` service exists (Apple silicon). Only then does a missing service mark an
    /// external display as virtual; an Intel Mac has none at all.
    public var hasFramebufferServices: Bool
    /// `IOPMrootDomain` ▸ `AppleClamshellState`: the lid is closed (nil on Macs without a lid).
    public var isClamshellClosed: Bool?

    /// A snapshot with the given values.
    public init(builtIn: BuiltInPanelFacts? = nil, externals: [ExternalPanelFacts] = [],
                hasFramebufferServices: Bool = false, isClamshellClosed: Bool? = nil) {
        self.builtIn = builtIn; self.externals = externals
        self.hasFramebufferServices = hasFramebufferServices; self.isClamshellClosed = isClamshellClosed
    }

    /// Nothing known (before the first read, in previews, on a Mac whose IORegistry has none of the keys).
    public static let unknown = IORegistryFacts()

    /// Reads the IORegistry now (read-only public IOKit property reads; ≈ 1 ms). Prefer `IORegistryReader.snapshot()`
    /// from the main actor, which runs off it.
    public static func read() -> IORegistryFacts { IORegistryReader.read() }

    /// The attributes of the external display CoreGraphics reports with `vendor`, `product` and `serial`: the only
    /// vendor-and-product match, else the one whose serial matches too, else the first (identical models report the
    /// same panel). Nil when no attributes describe it.
    public func external(vendor: UInt32, product: UInt32, serial: UInt32) -> ExternalPanelFacts? {
        let candidates = externals.filter { $0.describes(vendor: vendor, product: product) }
        guard candidates.count > 1 else { return candidates.first }
        return candidates.first { $0.serialNumber == serial } ?? candidates.first
    }
}
