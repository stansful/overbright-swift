// OverbrightDisplaysTests/Fixtures/OwnerIORegistry.swift — IORegistry properties saved from the owner's Mac
// (MacBook Pro Mac16,5, M4 Max, macOS 27.0.1; MSI MPG322UX QD-OLED with HDR on), read with `ioreg -a` (read-only,
// 2026-10-16). docs/research/display-facts.md §3, §5. Parsed with PropertyListSerialization, which yields the same
// Foundation types IOKit hands out (NSNumber, CFBoolean, Data, String, dictionaries).
import Foundation

/// The owner's IORegistry values.
enum OwnerIORegistry {
    /// `IOMobileFramebufferShim` (external = Yes) ▸ `DisplayAttributes` of the MSI MPG322UX OLED, verbatim.
    static let msiDisplayAttributes = plist("""
    <dict>
        <key>AspectRatio</key><integer>15</integer>
        <key>Chromaticity</key>
        <dict>
            <key>Blue</key><dict><key>X</key><integer>9408</integer><key>Y</key><integer>3648</integer></dict>
            <key>Green</key><dict><key>X</key><integer>16000</integer><key>Y</key><integer>46464</integer></dict>
            <key>Red</key><dict><key>X</key><integer>44800</integer><key>Y</key><integer>19968</integer></dict>
        </dict>
        <key>ContinuousFrequencySupport</key><string>CVTv1X</string>
        <key>DefaultColorSpaceIsSRGB</key><false/>
        <key>DefaultWhitePoint</key>
        <dict><key>Gamma</key><integer>144179</integer><key>X</key><integer>20544</integer><key>Y</key><integer>21568</integer></dict>
        <key>HasHDMILegacyEDID</key><false/>
        <key>Luminance</key>
        <dict>
            <key>Max</key><integer>30506349</integer>
            <key>MaxFrameAverage</key><integer>17370142</integer>
            <key>Min</key><integer>18</integer>
        </dict>
        <key>MaxHorizontalImageSize</key><integer>70</integer>
        <key>MaxVerticalImageSize</key><integer>39</integer>
        <key>MaximumRefreshRate</key><integer>240</integer>
        <key>MaximumVariableRefreshRate</key><integer>15728640</integer>
        <key>MinimumRefreshRate</key><integer>48</integer>
        <key>MinimumVariableRefreshRate</key><integer>3145728</integer>
        <key>NativeFormatHorizontalPixels</key><integer>3840</integer>
        <key>NativeFormatVerticalPixels</key><integer>2160</integer>
        <key>PortID</key><integer>32</integer>
        <key>PreciseAspectRatio</key><integer>117629</integer>
        <key>ProductAttributes</key>
        <dict>
            <key>AlphanumericSerialNumber</key><string></string>
            <key>LegacyManufacturerID</key><integer>13929</integer>
            <key>ManufacturerID</key><string>MSI</string>
            <key>ProductID</key><integer>19922</integer>
            <key>ProductName</key><string>MPG322UX OLED</string>
            <key>SerialNumber</key><integer>16843009</integer>
            <key>WeekOfManufacture</key><integer>44</integer>
            <key>YearOfManufacture</key><integer>2024</integer>
        </dict>
        <key>SupportsActiveOff</key><true/>
        <key>SupportsBT2020RGB</key><integer>512</integer>
        <key>SupportsBT2020YCC</key><integer>128</integer>
        <key>SupportsBT2020cYCC</key><integer>0</integer>
        <key>SupportsHDRGammaEOTF</key><false/>
        <key>SupportsHDRStaticMetadataType1</key><true/>
        <key>SupportsHLGEOTF</key><false/>
        <key>SupportsPQEOTF</key><true/>
        <key>SupportsStandby</key><true/>
        <key>SupportsSuspend</key><true/>
        <key>SupportsVariableRefreshRate</key><true/>
        <key>WhitePoints</key>
        <array><dict><key>Gamma</key><integer>144179</integer><key>X</key><integer>20544</integer><key>Y</key><integer>21568</integer></dict></array>
    </dict>
    """)

    /// Device tree `backlight` node (IOPlatformDevice) of the built-in panel: the keys Overbright reads plus two
    /// neighbours. Data values are the raw little-endian bytes: `EDRPotentialHeadroom = <00001000>`,
    /// `user-accessible-max-nits = <00005802>` (16.16 fixed point), `aurora-maximum-nits = <00007a44>` (a float).
    static let builtInBacklight = plist("""
    <dict>
        <key>EDRPotentialHeadroom</key><data>AAAQAA==</data>
        <key>user-accessible-max-nits</key><data>AABYAg==</data>
        <key>aurora-maximum-nits</key><data>AAB6RA==</data>
        <key>device_type</key><data>YmFja2xpZ2h0AA==</data>
        <key>name</key><data>YmFja2xpZ2h0AA==</data>
    </dict>
    """)

    /// `AppleARMBacklight` ▸ `IODisplayParameters`, verbatim.
    static let builtInDisplayParameters = plist("""
    <dict>
        <key>BrightnessMicroAmps</key>
        <dict><key>max</key><integer>13799</integer><key>min</key><integer>26</integer><key>value</key><integer>3199</integer></dict>
        <key>BrightnessMilliNits</key>
        <dict>
            <key>max</key><integer>1599999</integer><key>min</key><integer>976</integer>
            <key>uncalMilliNits</key><integer>140000</integer><key>value</key><integer>381794</integer>
        </dict>
        <key>brightness</key>
        <dict><key>max</key><integer>65536</integer><key>min</key><integer>0</integer><key>value</key><integer>32768</integer></dict>
        <key>rawBrightness</key>
        <dict><key>max</key><integer>2047</integer><key>min</key><integer>0</integer><key>value</key><integer>1488</integer></dict>
    </dict>
    """)

    /// The `vcgt` tag of the MSI's ColorSync profile (a formula tag: gamma 1, min 0, max 1 on every channel, i.e. an
    /// identity base), read from `CGDisplayCopyColorSpace(…).copyICCData()` (read-only), verbatim.
    static let msiProfileVCGT: [UInt8] = hex(
        "76636774 00000000 00000001 00010000 00000000 00010000 00010000 00000000 00010000 00010000 00000000 00010000")

    // MARK: Helpers

    /// A `<dict>` fragment as a Foundation dictionary.
    static func plist(_ fragment: String) -> [String: Any] {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <plist version="1.0">\(fragment)</plist>
        """
        let value = try? PropertyListSerialization.propertyList(from: Data(xml.utf8), format: nil)
        return value as? [String: Any] ?? [:]
    }

    /// Bytes from a hex string.
    static func hex(_ text: some StringProtocol) -> [UInt8] {
        let digits = Array(text.filter(\.isHexDigit))
        return stride(from: 0, to: digits.count - 1, by: 2).compactMap { UInt8(String(digits[$0...$0 + 1]), radix: 16) }
    }
}
