// OverbrightDisplaysTests/Fixtures/RawDisplayFixtures.swift — CoreGraphics/NSScreen reads and IORegistry snapshots of
// the setups in Core's `DisplayFixture` (same synthetic keys and IDs), so `DisplayFactsBuilder` can be checked against
// the facts every other package tests with. The CoreGraphics numbers of the MSI are the owner's (vendor 13929 =
// 0x3669, model 19922, serial 16843009, read-only); the others are illustrative.
import CoreGraphics
import Foundation
import OverbrightCore
@testable import OverbrightDisplays

/// Raw displays and registry snapshots for the builder tests.
enum RawDisplayFixtures {
    /// The M4 Max built-in (P3-1600 preset, notch). Model and serial 0 so the facts equal Core's fixture.
    static func builtIn(name: String = "Built-in Retina Display", potential: Double = 16,
                        screen: Bool = true) -> RawDisplay {
        RawDisplay(id: 1, key: DisplayFixture.Keys.builtIn, isBuiltIn: true, gammaCapacity: 1024, tableReadable: true,
                   vendor: 0x610, model: 0, serial: 0, mirrorsDisplay: kCGNullDirectDisplay,
                   screen: screen ? RawDisplay.Screen(name: name, potential: potential, hasNotch: true) : nil)
    }

    /// The MSI MPG322UX OLED (HDR on: potential 4.6549).
    static func msi(name: String = "MPG322UX OLED", potential: Double = 4.6549) -> RawDisplay {
        RawDisplay(id: 2, key: DisplayFixture.Keys.mpg322ux, isBuiltIn: false, gammaCapacity: 1024, tableReadable: true,
                   vendor: 13929, model: 19922, serial: 16843009, mirrorsDisplay: kCGNullDirectDisplay,
                   screen: RawDisplay.Screen(name: name, potential: potential, hasNotch: false))
    }

    /// A Sidecar display: macOS's placeholder vendor, no transfer table.
    static let sidecar = RawDisplay(id: 5, key: DisplayFixture.Keys.sidecar, isBuiltIn: false, gammaCapacity: 0,
                                    tableReadable: false, vendor: DisplayFactsBuilder.placeholderVendor, model: 0,
                                    serial: 0, mirrorsDisplay: kCGNullDirectDisplay,
                                    screen: RawDisplay.Screen(name: "Sidecar Display", potential: 1, hasNotch: false))

    /// A projector in a hardware mirror set with the built-in: its own table, no NSScreen of its own.
    static let projector = RawDisplay(id: 6, key: DisplayFixture.Keys.projector, isBuiltIn: false, gammaCapacity: 256,
                                      tableReadable: true, vendor: 0x4C2D, model: 0x0F00, serial: 0,
                                      mirrorsDisplay: 1, screen: nil)

    /// The projector's framebuffer attributes (SDR: no PQ).
    static let projectorAttributes = ExternalPanelFacts(vendorID: 0x4C2D, productID: 0x0F00, serialNumber: 0,
                                                        productName: "Projector", maxNits: 300, frameAverageNits: 300,
                                                        minNits: 0.3, supportsPQ: false, supportsHLG: false)

    /// The owner's built-in panel facts, parsed from the saved IORegistry values.
    static var ownerBuiltInPanel: BuiltInPanelFacts? {
        BuiltInPanelFacts.parse(backlight: OwnerIORegistry.builtInBacklight,
                                displayParameters: OwnerIORegistry.builtInDisplayParameters)
    }

    /// The MSI's facts, parsed from the saved `DisplayAttributes`.
    static var msiAttributes: ExternalPanelFacts? {
        ExternalPanelFacts.parse(displayAttributes: OwnerIORegistry.msiDisplayAttributes)
    }

    /// The owner's Mac with the lid open: the built-in panel, the MSI and the projector's attributes, framebuffer
    /// services present (Apple silicon).
    static func ownerRegistry(lidClosed: Bool? = false, extra: [ExternalPanelFacts] = [projectorAttributes])
        -> IORegistryFacts {
        IORegistryFacts(builtIn: ownerBuiltInPanel, externals: [msiAttributes].compactMap { $0 } + extra,
                        hasFramebufferServices: true, isClamshellClosed: lidClosed)
    }
}
