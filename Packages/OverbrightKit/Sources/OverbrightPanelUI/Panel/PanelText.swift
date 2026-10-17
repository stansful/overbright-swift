// OverbrightPanelUI/Panel/PanelText.swift — the panel's own words (header, empty state, the "Why?" row, the calibration
// tip, the Fill Light card, help tags). DESIGN.md §5.3–§5.11 (exact English; panel buttons sentence case), §12.7
// (VoiceOver). Engine-state copy (chips, banners, verdicts, readouts) is Design's.
import Foundation

/// Copy of the panel (PanelUI's catalog).
enum PanelText {
    // MARK: Header

    static var overflowLabel: String {
        String(localized: "More", bundle: .module, comment: "VoiceOver: the panel’s ⋯ menu button")
    }

    // MARK: Empty state and "Why?"

    static var nothingCapable: String {
        String(localized: "None of your displays can show extra brightness right now.", bundle: .module,
               comment: "Panel: sentence above the cards when no display can show extra brightness")
    }
    /// "1 display can't be adjusted" (plural forms in the catalog).
    static func cannotBeAdjusted(_ count: Int) -> String {
        String(localized: "\(count) displays can’t be adjusted", bundle: .module,
               comment: "Panel: collapsed row of displays that can neither be brightened nor dimmed")
    }
    static var why: String {
        String(localized: "Why?", bundle: .module, comment: "Panel: button that expands the row of displays that can’t be adjusted")
    }
    static var learnMore: String {
        String(localized: "Learn more", bundle: .module, comment: "Panel: link that opens the Help window at the matching answer")
    }

    // MARK: Calibration tip

    static var tipTitle: String {
        String(localized: "Check that it works", bundle: .module, comment: "Panel: title of the one-time calibration tip")
    }
    static func tipMessage(_ display: String) -> String {
        String(localized: "A one-minute check makes sure extra brightness is right for \(Bidi.isolated(display)).",
               bundle: .module, comment: "Panel: the one-time calibration tip; the placeholder is a display name")
    }
    static var calibrate: String {
        String(localized: "Calibrate…", bundle: .module, comment: "Panel: opens the calibration of this display (card context menu, calibration tip)")
    }
    static var notNow: String {
        String(localized: "Not now", bundle: .module, comment: "Panel: the calibration tip’s button that dismisses it")
    }

    // MARK: Fill Light card

    static var fillLight: String {
        String(localized: "Fill Light", bundle: .module, comment: "Panel: Fill Light (the ⋯ menu row that turns it on or off, and the title of its card)")
    }
    static var display: String {
        String(localized: "Display", bundle: .module, comment: "Panel: Fill Light card, the display pop-up’s label")
    }
    static var brightness: String {
        String(localized: "Brightness", bundle: .module, comment: "Panel: Fill Light card, the brightness slider’s label")
    }
    static var warmth: String {
        String(localized: "Warmth", bundle: .module, comment: "Panel: Fill Light card, the warmth slider’s label")
    }
    static var turnOff: String {
        String(localized: "Turn off", bundle: .module, comment: "Panel: Fill Light card, button that turns Fill Light off")
    }
    static var cool: String {
        String(localized: "Cool", bundle: .module, comment: "Panel: Fill Light card, the cool end of the Warmth slider")
    }
    static var warm: String {
        String(localized: "Warm", bundle: .module, comment: "Panel: Fill Light card, the warm end of the Warmth slider")
    }

    // MARK: Card

    static var compatibilityMode: String {
        String(localized: "Compatibility mode", bundle: .module,
               comment: "Panel ▸ Display card: caption under the readout of a display in Compatibility mode")
    }
    static var compatibilityFootnote: String {
        String(localized: "Brightens through an overlay. The pointer isn’t brightened, and screen recordings may show the overlay.",
               bundle: .module, comment: "Panel ▸ Display card: help tag of the Compatibility mode caption")
    }
    static var readoutHelp: String {
        String(localized: "For the most light, turn your display brightness all the way up first; Overbright adds to it.",
               bundle: .module, comment: "Panel ▸ Display card: help tag of the readout")
    }
    static var notCalibratedHelp: String {
        String(localized: "Not calibrated: this is an estimate.", bundle: .module,
               comment: "Panel ▸ Display card: help tag of an uncalibrated readout")
    }
    static var safeLimitReached: String {
        String(localized: "Safe limit reached: choose Peak for more", bundle: .module,
               comment: "Panel ▸ Display card: help tag of a disabled boost half when Safe adds nothing here")
    }
    static var littleGain: String {
        String(localized: "Little gain at full brightness", bundle: .module,
               comment: "Panel ▸ Display card: help tag of a disabled boost half when even Peak adds almost nothing")
    }
    static var linkedHelp: String {
        String(localized: "Same level on all displays", bundle: .module,
               comment: "Panel ▸ Display card: help tag of the link glyph before a display name")
    }
}
