// OverbrightDisplays/Directory/DisplayFactsBuilder.swift — CoreGraphics + NSScreen + IORegistry → `DisplayFacts`.
// ARCHITECTURE.md §3.2, §3.6 (`DisplayDirectory.displays`: built-in first, then by key), §10.4, D8. Pure, so every
// rule is tested with fixtures: virtual displays, hardware-mirror members, the closed lid, IORegistry matching, the
// panel class and the Apple XDR externals' SDR maximum (`AppleXDRProducts`). Names are carried for the UI and never
// compared (D8, §4.5 invariant 10).
import CoreGraphics
import OverbrightCore

/// Builds the directory's list from raw reads.
nonisolated enum DisplayFactsBuilder {
    /// macOS's placeholder vendor (`'unkn'`) for displays without a real EDID vendor (AirPlay, Sidecar, placeholders).
    static let placeholderVendor: UInt32 = 0x756e_6b6e
    /// Nits per unit of potential: `maximumPotential…` ≈ preset peak ÷ 100 nits (D8).
    static let nitsPerPotential = 100.0

    /// The online displays as `DisplayFacts`, built-in first, then by key. A built-in display is left out while the
    /// lid is closed (clamshell: its panel is dark and macOS removes it from the online list moments later).
    static func facts(from raw: [RawDisplay], registry: IORegistryFacts) -> [DisplayFacts] {
        raw.filter { !isBehindClosedLid($0, registry: registry) }
            .map { facts(for: $0, registry: registry) }
            .sorted { a, b in a.isBuiltIn != b.isBuiltIn ? a.isBuiltIn : a.ref.key < b.ref.key }
    }

    /// One display's facts.
    static func facts(for raw: RawDisplay, registry: IORegistryFacts) -> DisplayFacts {
        let external = raw.isBuiltIn ? nil : registry.external(vendor: raw.vendor, product: raw.model, serial: raw.serial)
        let builtIn = raw.isBuiltIn ? registry.builtIn : nil
        let virtual = isVirtual(raw, external: external, registry: registry)
        // An Apple XDR external's SDR maximum comes from the product, never from its frame average (§5.1).
        let xdr = raw.isBuiltIn || virtual ? nil : AppleXDRProducts.product(vendor: raw.vendor, product: raw.model)
        let potential = builtIn?.potentialHeadroom ?? raw.screen?.potential
        let registryPeak = raw.isBuiltIn ? builtIn?.panelPeakNits : external?.maxNits ?? xdr?.peakNits
        let peak = registryPeak ?? (virtual ? nil : potentialPeakNits(potential))
        return DisplayFacts(
            ref: DisplayRef(key: raw.key, id: raw.id),
            name: raw.screen?.name ?? external?.productName ?? "",
            isBuiltIn: raw.isBuiltIn,
            isMirrored: isMirrorMember(raw),
            gammaCapacity: raw.gammaCapacity,
            vendorID: raw.vendor == 0 ? nil : raw.vendor,
            productID: raw.model == 0 ? nil : raw.model,
            supportsPQ: external?.supportsPQ,
            panelPeakNits: peak,
            panelFrameAverageNits: external?.frameAverageNits,
            panelMinNits: external?.minNits,
            sdrMaxNits: raw.isBuiltIn ? builtIn?.sdrMaxNits : xdr?.sdrMaxNits,
            hasNotch: raw.screen?.hasNotch ?? false,
            panelClass: PanelClassifier.classify(isVirtual: virtual, isBuiltIn: raw.isBuiltIn,
                                                 vendor: raw.vendor == 0 ? nil : raw.vendor, potential: potential,
                                                 peakNits: peak, minNits: external?.minNits,
                                                 supportsPQ: external?.supportsPQ))
    }

    /// The documented fallback of a panel peak that neither the IORegistry nor the product gives (D8, §9.2 rule 6):
    /// potential × 100 nits, for a display with extra range (potential above the LCD limit of 2; an LCD built-in's
    /// fixed 2.0 says nothing about its peak). `maximumPotential…` reads ≈ preset peak ÷ 100 [VERIFIED: 16 on the M4
    /// Max, 4.6549 on the MSI], and macOS grants no more than the preset's peak, so the live Safe bound
    /// (`capNits × H ÷ panelPeak`) still holds with it below macOS's cap of 16 (a brighter panel reads 16; Apple's
    /// 2000-nit Studio Display XDR has its peak from `AppleXDRProducts`).
    static func potentialPeakNits(_ potential: Double?) -> Double? {
        guard let potential, potential.isFinite,
              potential > PanelClassifier.lcdPotentialLimit + PanelClassifier.epsilon else { return nil }
        return potential * nitsPerPotential
    }

    /// Virtual (Sidecar, AirPlay, placeholder, a display without a real framebuffer): no transfer table
    /// (capacity 0), a table that cannot be read, macOS's placeholder vendor, or, on a Mac with framebuffer services
    /// (Apple silicon), an external display that no framebuffer service describes.
    static func isVirtual(_ raw: RawDisplay, external: ExternalPanelFacts?, registry: IORegistryFacts) -> Bool {
        if raw.gammaCapacity == 0 || !raw.tableReadable || raw.vendor == placeholderVendor { return true }
        return !raw.isBuiltIn && registry.hasFramebufferServices && external == nil
    }

    /// A member of a (hardware) mirror set that does not own the set's NSScreen: its own table, no headroom reading.
    static func isMirrorMember(_ raw: RawDisplay) -> Bool {
        raw.mirrorsDisplay != kCGNullDirectDisplay && raw.screen == nil
    }

    /// The built-in display of a Mac whose lid is closed.
    static func isBehindClosedLid(_ raw: RawDisplay, registry: IORegistryFacts) -> Bool {
        raw.isBuiltIn && registry.isClamshellClosed == true
    }
}
