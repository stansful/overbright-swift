// OverbrightPanelUI/Panel/OLEDNotice.swift — "Use extra brightness on this OLED display?", asked before extra
// brightness turns on for an OLED display from the card, the chip or the menu. DESIGN.md §12.4 (title-case buttons),
// §5.4; D8.
import AppKit
import Foundation
import OverbrightCore

/// The OLED notice alert.
public enum OLEDNotice {
    /// The alert's title.
    public static var title: String {
        String(localized: "Use extra brightness on this OLED display?", bundle: .module,
               comment: "Panel: title of the alert shown before extra brightness turns on for an OLED display")
    }

    /// The alert's text.
    public static var message: String {
        String(localized: "Bright content that stays in one place for a long time, like the menu bar, can wear OLED panels unevenly. Overbright keeps extra brightness lower on OLED displays and pauses it after 5 minutes without input.",
               bundle: .module, comment: "Panel: text of the OLED notice alert")
    }

    /// The confirming button.
    public static var turnOn: String {
        String(localized: "Turn On", bundle: .module, comment: "Panel: OLED notice button that turns extra brightness on")
    }

    /// The cancelling button.
    public static var cancel: String {
        String(localized: "Cancel", bundle: .module, comment: "Panel: OLED notice button that keeps extra brightness off")
    }

    /// Shows the alert (app-modal) and returns whether the user chose Turn On. `displayName` is unused in the copy
    /// (the question names "this OLED display") but kept for VoiceOver context in the alert's accessibility label.
    public static func confirm(_ displayName: String) -> Bool {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: turnOn)
        alert.addButton(withTitle: cancel)
        alert.window.setAccessibilityLabel(displayName)
        NSApp.activate()
        return alert.runModal() == .alertFirstButtonReturn
    }
}
