// OverbrightCore/Fakes/Fixtures/DisplayFixture.swift — the named display setups of ARCHITECTURE.md §3.9, used by tests,
// #Previews and `--qa-simulate <raw value>` (§8.5). "Measured" values are the owner's (Mac16,5 M4 Max built-in,
// MSI MPG322UX QD-OLED; docs/research/display-facts.md); the rest are spec values or illustrative stand-ins, marked so.
// Keys are synthetic UUIDs (prefix 0B21E7F1), never the owner's real display UUIDs.

/// A named display setup: the Mac, its displays' facts, their headroom scripts and their profile bases.
public nonisolated enum DisplayFixture: String, CaseIterable, Sendable {
    /// M4 Max built-in, P3-1600 preset, SDR max 600 nits, notch: grant 1600 ÷ 600 = 2.667 (measured).
    case builtinXDRLidOpen = "builtin-xdr-lid-open"
    /// The same built-in in the P3-600 preset: potential 6, no gain at full brightness (inferred).
    case builtinXDRPreset600 = "builtin-xdr-preset-600"
    /// MSI MPG322UX OLED with macOS HDR on: potential 4.6549, frame average 265.05, min 0.0003 nits, PQ (measured).
    case mpg322uxHDROn = "mpg322ux-hdr-on"
    /// The MSI with macOS HDR off: potential 1.0 ("Turn on HDR", measured).
    case mpg322uxHDROff = "mpg322ux-hdr-off"
    /// Pro Display XDR: 1600 nits peak, SDR 500, grant 3.2 (spec).
    case proDisplayXDR = "pro-display-xdr"
    /// Studio Display XDR: 2000 nits peak, SDR 1000, grant 2.0 (spec; potential 20 is inferred, maybe capped at 16).
    case studioDisplayXDR = "studio-display-xdr"
    /// A MacBook Air-class LCD built-in: potential 2 (inferred).
    case lcdOnly = "lcd-only"
    /// The built-in plus a Sidecar display (virtual, no transfer table).
    case sidecar = "sidecar"
    /// The built-in plus a projector mirroring it (own table, no NSScreen of its own: dim only).
    case hardwareMirror = "hardware-mirror"
    /// A Mac17,5 on macOS 26.3, where table writes succeed but change nothing (`CompatibilityModels`). The panel
    /// values are the M4 Max built-in's, as stand-ins: the point of the fixture is the ignored writes.
    case neoIgnoresWrites = "neo-ignores-writes"
    /// The built-in with a calibrated (non-identity, per-channel) profile base.
    case calibratedProfile = "calibrated-profile"
    /// The built-in and the MSI (HDR on) with the names a Russian UI shows (no logic may compare names, D8).
    case russianNames = "russian-names"

    /// Synthetic display keys of the fixtures (stable across runs; tests refer to displays by these).
    public enum Keys {
        /// Every built-in display of every fixture.
        public static let builtIn = DisplayKey(rawValue: "0B21E7F1-0000-4000-8000-000000000001")
        /// The MSI MPG322UX OLED.
        public static let mpg322ux = DisplayKey(rawValue: "0B21E7F1-0000-4000-8000-000000000002")
        /// The Pro Display XDR.
        public static let proDisplayXDR = DisplayKey(rawValue: "0B21E7F1-0000-4000-8000-000000000003")
        /// The Studio Display XDR.
        public static let studioDisplayXDR = DisplayKey(rawValue: "0B21E7F1-0000-4000-8000-000000000004")
        /// The Sidecar display.
        public static let sidecar = DisplayKey(rawValue: "0B21E7F1-0000-4000-8000-000000000005")
        /// The mirroring projector.
        public static let projector = DisplayKey(rawValue: "0B21E7F1-0000-4000-8000-000000000006")
    }

    /// The owner's Mac: Mac16,5 (M4 Max), macOS 27.0.1 (26A434).
    public static let ownerMachine = MachineIdentity(model: "Mac16,5", osBuild: "26A434", osMajor: 27, osMinor: 0, osPatch: 1)

    /// The Mac of this fixture.
    public var machine: MachineIdentity {
        switch self {
        case .lcdOnly: MachineIdentity(model: "Mac15,12", osBuild: "26A434", osMajor: 27, osMinor: 0, osPatch: 1)
        // Illustrative build number of macOS 26.3.
        case .neoIgnoresWrites: MachineIdentity(model: "Mac17,5", osBuild: "25D125", osMajor: 26, osMinor: 3, osPatch: 0)
        default: Self.ownerMachine
        }
    }

    /// Table writes succeed, read back correctly and change nothing on screen (`FakeGammaPort.ignoresWrites`).
    public var tableWritesIgnored: Bool { self == .neoIgnoresWrites }

    /// The displays, built-in first.
    public var displays: [FixtureDisplay] {
        switch self {
        case .builtinXDRLidOpen, .neoIgnoresWrites: [Self.builtInXDR()]
        case .builtinXDRPreset600: [Self.builtInXDR(potential: 6, grant: 1)]
        case .mpg322uxHDROn: [Self.mpg322ux(hdr: true)]
        case .mpg322uxHDROff: [Self.mpg322ux(hdr: false)]
        case .proDisplayXDR: [Self.proDisplay]
        case .studioDisplayXDR: [Self.studioDisplay]
        case .lcdOnly: [Self.lcdBuiltIn]
        case .sidecar: [Self.builtInXDR(), Self.sidecarDisplay]
        case .hardwareMirror: [Self.builtInXDR(), Self.projector]
        case .calibratedProfile: [Self.builtInXDR(base: FixtureTables.calibrated(count: 1024))]
        case .russianNames: [Self.builtInXDR(name: "Встроенный дисплей Retina"), Self.mpg322ux(hdr: true)]
        }
    }

    // MARK: Displays

    private static func builtInXDR(name: String = "Built-in Retina Display", potential: Double = 16,
                                   grant: Double = 1600.0 / 600, base: GammaTable = .identity(count: 1024)) -> FixtureDisplay {
        FixtureDisplay(
            facts: DisplayFacts(ref: DisplayRef(key: Keys.builtIn, id: 1), name: name, isBuiltIn: true, gammaCapacity: 1024,
                                vendorID: 0x610, panelPeakNits: 1600, sdrMaxNits: 600, hasNotch: true,
                                panelClass: .builtInXDR),
            headroom: HeadroomScript(potential: potential, grant: grant),
            profileBase: base)
    }

    private static func mpg322ux(hdr: Bool) -> FixtureDisplay {
        FixtureDisplay(
            facts: DisplayFacts(ref: DisplayRef(key: Keys.mpg322ux, id: 2), name: "MPG322UX OLED", isBuiltIn: false,
                                gammaCapacity: 1024, vendorID: 0x3669 /* EDID PNP "MSI" */, supportsPQ: true,
                                panelPeakNits: 465.49, panelFrameAverageNits: 265.05, panelMinNits: 0.0003,
                                panelClass: .oledExternal),
            headroom: hdr ? HeadroomScript(potential: 4.6549, grant: 465.49 / 265.05)
                          : HeadroomScript(potential: 1, grant: 1),
            profileBase: .identity(count: 1024))
    }

    private static let proDisplay = FixtureDisplay(
        facts: DisplayFacts(ref: DisplayRef(key: Keys.proDisplayXDR, id: 3), name: "Pro Display XDR", isBuiltIn: false,
                            gammaCapacity: 1024, vendorID: 0x610, supportsPQ: true, panelPeakNits: 1600, sdrMaxNits: 500,
                            panelClass: .appleXDRExternal),
        headroom: HeadroomScript(potential: 16, grant: 3.2),
        profileBase: .identity(count: 1024))

    private static let studioDisplay = FixtureDisplay(
        facts: DisplayFacts(ref: DisplayRef(key: Keys.studioDisplayXDR, id: 4), name: "Studio Display XDR", isBuiltIn: false,
                            gammaCapacity: 1024, vendorID: 0x610, supportsPQ: true, panelPeakNits: 2000, sdrMaxNits: 1000,
                            panelClass: .appleXDRExternal),
        headroom: HeadroomScript(potential: 20, grant: 2),
        profileBase: .identity(count: 1024))

    private static let lcdBuiltIn = FixtureDisplay(
        facts: DisplayFacts(ref: DisplayRef(key: Keys.builtIn, id: 1), name: "Built-in Retina Display", isBuiltIn: true,
                            gammaCapacity: 1024, vendorID: 0x610, panelPeakNits: 500, sdrMaxNits: 500, hasNotch: true,
                            panelClass: .builtInLCD),
        headroom: HeadroomScript(potential: 2, grant: 1.25),
        profileBase: .identity(count: 1024))

    private static let sidecarDisplay = FixtureDisplay(
        facts: DisplayFacts(ref: DisplayRef(key: Keys.sidecar, id: 5), name: "Sidecar Display", isBuiltIn: false,
                            gammaCapacity: 0, vendorID: 0x756e6b6e /* placeholder vendor 'unkn' */,
                            panelClass: .virtualDisplay),
        headroom: HeadroomScript(potential: 1, grant: 1),
        profileBase: nil)

    private static let projector = FixtureDisplay(
        facts: DisplayFacts(ref: DisplayRef(key: Keys.projector, id: 6), name: "Projector", isBuiltIn: false,
                            isMirrored: true, gammaCapacity: 256, supportsPQ: false, panelClass: .sdrExternal),
        headroom: HeadroomScript(potential: 1, grant: 1, hasOwnScreen: false),
        profileBase: .identity(count: 256))
}
