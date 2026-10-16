// OverbrightDisplays/Registry/ExternalPanelFacts.swift — what the IORegistry says about one external panel.
// ARCHITECTURE.md §3.2, §10.4, D8; docs/research/display-facts.md §3, §5. Pure parsing of an
// `IOMobileFramebufferShim`'s `DisplayAttributes` dictionary (Apple silicon; the display's EDID / DisplayID as macOS
// decoded it). Luminances are 16.16 fixed point: the owner's MSI MPG322UX reads Max 30506349, MaxFrameAverage
// 17370142 and Min 18, i.e. 465.49, 265.05 and 0.0003 nits. Every key is optional.
import Foundation

/// One external panel's identity, luminance range and transfer-function support.
public nonisolated struct ExternalPanelFacts: Hashable, Sendable {
    /// `ProductAttributes.LegacyManufacturerID`: the EDID vendor (equals `CGDisplayVendorNumber`).
    public var vendorID: UInt32?
    /// `ProductAttributes.ProductID` (equals `CGDisplayModelNumber`).
    public var productID: UInt32?
    /// `ProductAttributes.SerialNumber` (equals `CGDisplaySerialNumber`); tells two identical monitors apart.
    public var serialNumber: UInt32?
    /// `ProductAttributes.ProductName`: a fallback display name for the UI only (D8: never compared).
    public var productName: String?
    /// `Luminance.Max` in nits: the panel peak.
    public var maxNits: Double?
    /// `Luminance.MaxFrameAverage` in nits: the HDR-mode SDR white on the measured OLED.
    public var frameAverageNits: Double?
    /// `Luminance.Min` in nits: ≤ 0.005 means a self-emissive (OLED) panel.
    public var minNits: Double?
    /// `SupportsPQEOTF`: HDR10 input, the "Turn on HDR" verdict.
    public var supportsPQ: Bool?
    /// `SupportsHLGEOTF` (diagnostics).
    public var supportsHLG: Bool?

    /// Facts with the given values.
    public init(vendorID: UInt32? = nil, productID: UInt32? = nil, serialNumber: UInt32? = nil,
                productName: String? = nil, maxNits: Double? = nil, frameAverageNits: Double? = nil,
                minNits: Double? = nil, supportsPQ: Bool? = nil, supportsHLG: Bool? = nil) {
        self.vendorID = vendorID; self.productID = productID; self.serialNumber = serialNumber
        self.productName = productName; self.maxNits = maxNits; self.frameAverageNits = frameAverageNits
        self.minNits = minNits; self.supportsPQ = supportsPQ; self.supportsHLG = supportsHLG
    }

    /// The facts of one `DisplayAttributes` dictionary; nil when it identifies no product.
    static func parse(displayAttributes attributes: [String: Any]) -> ExternalPanelFacts? {
        let product = IORegistryValue.dictionary(attributes["ProductAttributes"])
        let luminance = IORegistryValue.dictionary(attributes["Luminance"])
        let facts = ExternalPanelFacts(
            vendorID: IORegistryValue.uint32(product?["LegacyManufacturerID"]),
            productID: IORegistryValue.uint32(product?["ProductID"]),
            serialNumber: IORegistryValue.uint32(product?["SerialNumber"]),
            productName: IORegistryValue.string(product?["ProductName"]).flatMap { $0.isEmpty ? nil : $0 },
            maxNits: IORegistryValue.fixedPointInteger(luminance?["Max"]).flatMap(nonNegative),
            frameAverageNits: IORegistryValue.fixedPointInteger(luminance?["MaxFrameAverage"]).flatMap(nonNegative),
            minNits: IORegistryValue.fixedPointInteger(luminance?["Min"]).flatMap(nonNegative),
            supportsPQ: IORegistryValue.bool(attributes["SupportsPQEOTF"]),
            supportsHLG: IORegistryValue.bool(attributes["SupportsHLGEOTF"]))
        return facts.vendorID == nil && facts.productID == nil ? nil : facts
    }

    /// Whether these attributes describe a display CoreGraphics reports with `vendor` and `product`.
    func describes(vendor: UInt32, product: UInt32) -> Bool {
        vendorID == vendor && productID == product
    }

    private static func nonNegative(_ value: Double) -> Double? { value.isFinite && value >= 0 ? value : nil }
}
