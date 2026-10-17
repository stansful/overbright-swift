// OverbrightDisplays/Directory/AppleXDRProducts.swift — the SDR maximum and panel peak of Apple's XDR externals.
// ARCHITECTURE.md §3.2 (`DisplayFacts.sdrMaxNits`), §5.1 (`sdrMax`: 500 nits on the Pro Display XDR, 1000 on the
// Studio Display XDR), D8; docs/research/display-facts.md §3, §5. Their IORegistry attributes carry no SDR white:
// `MaxFrameAverage` is the full-screen sustained HDR level on these panels (1000 nits on the Pro Display XDR), not
// the highest SDR white, so these values come from the product. The product IDs are the ones macOS's own display
// override database lists for vendor 0x610 (`/System/Library/Displays/Contents/Resources/Overrides/
// DisplayVendorID-610`, read once, read-only, macOS 27.0.1), whose Pro Display XDR entries also give a 500-nit
// backlight. Pure; names are never compared (D8).

/// Apple's XDR externals by CoreGraphics product ID.
nonisolated enum AppleXDRProducts {
    /// What the product's specification says.
    struct Product: Hashable, Sendable {
        /// The highest SDR white the user can select (§5.1 `sdrMax`).
        var sdrMaxNits: Double
        /// The panel peak, used only when the IORegistry carries none.
        var peakNits: Double
    }

    /// Pro Display XDR: 500 nits SDR, 1600 nits peak (spec).
    static let proDisplayXDR = Product(sdrMaxNits: 500, peakNits: 1600)
    /// Studio Display XDR: 1000 nits SDR, 2000 nits peak (spec).
    static let studioDisplayXDR = Product(sdrMaxNits: 1000, peakNits: 2000)

    /// `CGDisplayModelNumber` → product, for vendor `PanelClassifier.appleVendor`.
    static let byProductID: [UInt32: Product] = [
        0xAE21: proDisplayXDR, 0xAE22: proDisplayXDR, 0xAE23: proDisplayXDR,
        0xAE2D: proDisplayXDR, 0xAE2E: proDisplayXDR, 0xAE2F: proDisplayXDR,
        0xAE42: studioDisplayXDR, 0xAE43: studioDisplayXDR,
    ]

    /// The XDR product CoreGraphics reports with `vendor` and `product`; nil for any other display.
    static func product(vendor: UInt32, product: UInt32) -> Product? {
        vendor == PanelClassifier.appleVendor ? byProductID[product] : nil
    }
}
