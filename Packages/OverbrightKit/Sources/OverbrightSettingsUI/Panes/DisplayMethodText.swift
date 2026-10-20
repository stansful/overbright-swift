// OverbrightSettingsUI/Panes/DisplayMethodText.swift — the footnote of Displays ▸ ‹display› ▸ Method (DESIGN.md §7.4):
// what Automatic does (and that it uses Compatibility mode where macOS ignores color table changes), and what
// Compatibility mode costs. "Compatibility mode" is the method's only name (DESIGN.md §16: never "fallback").
import Foundation
import OverbrightCore

/// The Method footnotes.
enum DisplayMethodText {
    /// The choice the Method pop-up shows for a stored `preference`: a Compatibility-mode choice stored before the
    /// overlay was disabled (`MechanismPreference.overlayIsAvailable`) shows as Color table, the method Policy uses
    /// for it, so the pop-up never selects a choice it does not offer.
    static func shown(_ preference: MechanismPreference) -> MechanismPreference {
        MechanismPreference.selectableCases.contains(preference) ? preference : .table
    }

    /// The footnote for the chosen `preference`, given the mechanism the display uses now; nil for Color table.
    static func footnote(preference: MechanismPreference, effective: Mechanism) -> String? {
        switch preference {
        case .automatic where effective == .overlay:
            String(localized: "Automatic uses Compatibility mode, because macOS ignores color table changes on this Mac.", bundle: .module,
                   comment: "Settings ▸ Displays: footnote of Method when Automatic chose Compatibility mode")
        case .automatic:
            String(localized: "Overbright picks the method that works on this Mac.", bundle: .module,
                   comment: "Settings ▸ Displays: footnote of Method set to Automatic")
        case .overlay:
            String(localized: "Brightens through an overlay. The pointer isn’t brightened, and screen recordings may show the overlay.",
                   bundle: .module, comment: "Settings ▸ Displays: footnote of Method set to Compatibility mode")
        case .table:
            nil
        }
    }
}
