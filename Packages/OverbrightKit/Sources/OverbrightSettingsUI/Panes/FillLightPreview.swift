// OverbrightSettingsUI/Panes/FillLightPreview.swift — the miniature at the top of Settings ▸ Fill Light (DESIGN.md
// §7.7): a 200 × 125 pt picture of the chosen display with the frame drawn to scale in the chosen warmth and
// brightness, as an SDR approximation (the real light can be brighter than white; DESIGN.md §11). The inner edge is
// rounded like the real frame's (radius min(24, width), to scale). The colour is a black-body approximation of the
// kelvin value in sRGB, enough for a preview; FillLight owns the exact one.
import Foundation
import OverbrightDesign
import SwiftUI

/// A miniature display with the Fill Light frame.
struct FillLightPreview: View {
    /// The frame's width on the display, in points.
    let width: Double
    /// The colour temperature in kelvin.
    let kelvin: Double
    /// 0.2 … 1.
    let brightness: Double
    /// The display's width in points (the miniature scales the frame by it).
    let displayWidth: Double

    /// The miniature's size (DESIGN.md §7.7).
    static let size = CGSize(width: 200, height: 125)
    /// The real frame's largest inner corner radius (DESIGN.md §11).
    static let innerRadiusLimit = 24.0

    var body: some View {
        let scale = Self.size.width / max(displayWidth, 1)
        let frame = max(width * scale, StrokeWidth.regular)
        let inner = min(Self.innerRadiusLimit, width) * scale
        let (r, g, b) = Self.components(kelvin: kelvin)
        ZStack {
            RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
                .fill(Color(red: r, green: g, blue: b).opacity(brightness))
            RoundedRectangle(cornerRadius: inner, style: .continuous)
                .fill(.background)
                .padding(frame)
            RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
                .strokeBorder(.separator, lineWidth: StrokeWidth.regular)
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .accessibilityHidden(true)
    }

    /// sRGB components (0 … 1) of a black body at `kelvin`, by the usual fitted curves (1,000–40,000 K).
    static func components(kelvin: Double) -> (Double, Double, Double) {
        let t = min(max(kelvin, 1000), 40000) / 100
        let red = t <= 66 ? 255 : 329.698727446 * pow(t - 60, -0.1332047592)
        let green = t <= 66 ? 99.4708025861 * log(t) - 161.1195681661 : 288.1221695283 * pow(t - 60, -0.0755148492)
        let blue = t >= 66 ? 255 : (t <= 19 ? 0 : 138.5177312231 * log(t - 10) - 305.0447927307)
        func unit(_ value: Double) -> Double { min(max(value, 0), 255) / 255 }
        return (unit(red), unit(green), unit(blue))
    }
}

#Preview("Fill Light preview") {
    HStack(spacing: Space.xl) {
        FillLightPreview(width: 48, kelvin: 5100, brightness: 0.8, displayWidth: 1512)
        FillLightPreview(width: 120, kelvin: 3000, brightness: 1, displayWidth: 1512)
    }
    .padding()
}
