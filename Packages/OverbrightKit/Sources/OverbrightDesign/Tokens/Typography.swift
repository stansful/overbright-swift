// OverbrightDesign/Tokens/Typography.swift — the text styles of the panel and the HUD. DESIGN.md §2.2.
// System text styles only; SF Pro Rounded with monospaced digits for live numbers so they never jitter. Nothing below
// 10 pt. Settings, Welcome, calibration and Help use the system styles (`.title2`, `.headline`, `.body`, …) directly.
import AppKit
import SwiftUI

/// A text style of DESIGN.md §2.2. Views use `.font(OverbrightFont.readout.font)`, never a literal size.
public nonisolated enum OverbrightFont: String, CaseIterable, Sendable {
    /// "Overbright" in the panel header: 13 semibold.
    case panelTitle
    /// Display names on cards: 13 semibold, up to two lines.
    case cardTitle
    /// The readout ("Bright room · ×1.29"): 13 medium, rounded, monospaced digits.
    case readout
    /// Status and footer chips: 11 medium.
    case chip
    /// "Compatibility mode" under the readout: 11 regular, secondary.
    case caption
    /// Banner sentences: 12 regular, up to three lines.
    case banner
    /// The value tag above the slider thumb: 11 semibold, rounded, monospaced digits.
    case valueTag
    /// The HUD value: 15 semibold, rounded, monospaced digits.
    case hudValue
    /// The HUD display name and reasons: 11 regular.
    case hudLabel

    /// The point size.
    public var size: CGFloat {
        switch self {
        case .panelTitle, .cardTitle, .readout: 13
        case .chip, .caption, .valueTag, .hudLabel: 11
        case .banner: 12
        case .hudValue: 15
        }
    }

    /// The weight.
    public var weight: Font.Weight {
        switch self {
        case .panelTitle, .cardTitle, .valueTag, .hudValue: .semibold
        case .readout, .chip: .medium
        case .caption, .banner, .hudLabel: .regular
        }
    }

    /// Live numbers: SF Pro Rounded with monospaced digits.
    public var isLiveNumber: Bool {
        switch self {
        case .readout, .valueTag, .hudValue: true
        default: false
        }
    }

    /// The SwiftUI font.
    public var font: Font {
        let base = Font.system(size: size, weight: weight, design: isLiveNumber ? .rounded : .default)
        return isLiveNumber ? base.monospacedDigit() : base
    }

    /// The same font in AppKit, for measured-width fit tests and AppKit drawing.
    public var nsFont: NSFont {
        let base = isLiveNumber ? NSFont.monospacedDigitSystemFont(ofSize: size, weight: nsWeight)
                                : NSFont.systemFont(ofSize: size, weight: nsWeight)
        guard isLiveNumber, let rounded = base.fontDescriptor.withDesign(.rounded),
              let font = NSFont(descriptor: rounded, size: size) else { return base }
        return font
    }

    /// The width `text` takes in this style on one line.
    public func width(of text: String) -> CGFloat {
        ceil((text as NSString).size(withAttributes: [.font: nsFont]).width)
    }

    private var nsWeight: NSFont.Weight {
        switch weight {
        case .semibold: .semibold
        case .medium: .medium
        default: .regular
        }
    }
}
