// OverbrightFillLight/Style/FillLightStyle.swift — what a frame window shows, from settings and headroom (pure).
// ARCHITECTURE.md §7.6 ("value = brightness × min(0.97 × H, 2.0), else ≤ 1.0"), D5 (the 0.97 margin), D6
// (our own EDR content holds headroom); DESIGN.md §7.7 (ranges), §11 ("up to 2× white").
import OverbrightCore

/// Everything a `FillLightSurface` needs to draw the light: the band's width, the colour and its value, whether to ask
/// for EDR headroom, and whether the frame reaches the top of the display.
public nonisolated struct FillLightStyle: Hashable, Sendable {
    /// The brightest light the frame shows, in multiples of SDR white (DESIGN.md §11: "up to 2× white").
    public static let maximumGain = 2.0
    /// The share of the granted headroom the frame may use, as for the boost (D5): never clip at the grant.
    public static let headroomMargin = 0.97
    /// The smallest content headroom tag that reads back above 1.0 (§4.7: tags ≤ 1.0001 read back as 1.0).
    public static let minimumHeadroomRequest = 1.01
    /// A display has extra range when its potential headroom exceeds this (HDR off and SDR displays read 1.0).
    public static let extraRangePotential = 1.01
    /// The Brightness setting's range (DESIGN.md §7.7: 20–100 %).
    public static let brightnessRange: ClosedRange<Double> = 0.2...1
    /// Values are rounded to this step, so headroom noise never re-colours the frame.
    public static let valueStep = 0.01

    /// The Width setting in points (clamped by `FrameGeometry`).
    public var width: Double
    /// The hue: the black-body colour of the Warmth setting, largest component 1 (`ColorTemperature`).
    public var color: LinearRGB
    /// The multiplier of `color`: ≤ 1 without EDR, up to `maximumGain` with it.
    public var value: Double
    /// The content headroom to ask macOS for (the tag of the colour); nil = SDR content, no EDR request.
    public var headroomRequest: Double?
    /// The display shows a full-screen Space: the frame reaches the top (DESIGN.md §11).
    public var reachesTop: Bool

    /// A style from its parts (tests and previews; the controller uses `make`).
    public init(width: Double, color: LinearRGB, value: Double, headroomRequest: Double?, reachesTop: Bool) {
        self.width = width; self.color = color; self.value = value
        self.headroomRequest = headroomRequest; self.reachesTop = reachesTop
    }

    /// The colour the surface shows: `color × value`, in extended linear sRGB.
    public var displayedColor: LinearRGB { color.scaled(by: value) }

    /// The style for the current settings on a display whose latest headroom reading is `reading` (nil: no reading,
    /// e.g. a display without its own screen), drawn by a surface that renders with `rendering`.
    ///
    /// With extra range (a surface that shows EDR and a potential above 1): the frame asks for
    /// `brightness × 2 ÷ 0.97` of headroom (at least 1.01, at most the potential) and shows
    /// `brightness × min(0.97 × H, 2)`, never less than `brightness` (SDR white needs no headroom), so it follows the
    /// grant as macOS raises it and never exceeds 97 % of it. Without: `brightness`, no request.
    public static func make(width: Double, warmth: Double, brightness: Double, reading: HeadroomReading?,
                            rendering: FillLightRendering, reachesTop: Bool) -> FillLightStyle {
        let b = brightness.isFinite ? min(max(brightness, brightnessRange.lowerBound), brightnessRange.upperBound)
                                    : FillLightSettings.brightness.defaultValue
        let color = ColorTemperature.linearSRGB(warmth: warmth)
        guard rendering.showsEDR, let reading, reading.potential > extraRangePotential else {
            return FillLightStyle(width: width, color: color, value: rounded(b, .down), headroomRequest: nil,
                                  reachesTop: reachesTop)
        }
        let current = reading.current.isFinite ? reading.current : 1
        let gain = min(max(headroomMargin * current, 1), maximumGain)
        let request = min(max(b * maximumGain / headroomMargin, minimumHeadroomRequest),
                          max(reading.potential, minimumHeadroomRequest))
        return FillLightStyle(width: width, color: color, value: rounded(b * gain, .down),
                              headroomRequest: rounded(request, .up), reachesTop: reachesTop)
    }

    /// `value` on the `valueStep` grid: the value rounds down (never past 97 % of the grant), the request up.
    private static func rounded(_ value: Double, _ rule: FloatingPointRoundingRule) -> Double {
        let steps = value / valueStep
        let nudged = rule == .down ? steps + 1e-9 : steps - 1e-9   // 0.8 × 2 ÷ 0.01 is 159.999…, not 160
        return nudged.rounded(rule) * valueStep
    }
}
