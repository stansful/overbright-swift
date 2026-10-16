// OverbrightSettingsUI/Panes/OLEDNoticeAlert.swift — "Use extra brightness on this OLED display?" (DESIGN.md §12.4),
// asked before extra brightness turns on for an OLED display from Settings ▸ Displays: its switch, or the first move of
// its slider into the boost half (the thumb waits at Standard until the question is answered). The idle pause it
// names is Settings ▸ Automations' (5 minutes by default).
import OverbrightDesign
import SwiftUI

extension View {
    /// The OLED notice while `isPresented`; `turnOn` runs on Turn On (Cancel leaves extra brightness off).
    func oledNotice(isPresented: Binding<Bool>, idleMinutes: Int, turnOn: @escaping @MainActor () -> Void) -> some View {
        alert(Text("Use extra brightness on this OLED display?", bundle: .module,
                   comment: "Settings ▸ Displays: title of the question before extra brightness turns on for an OLED display"),
              isPresented: isPresented) {
            Button(action: turnOn) {
                Text("Turn On", bundle: .module,
                     comment: "Settings ▸ Displays: OLED question button that turns extra brightness on (title case)")
            }
            Button(role: .cancel) {} label: { Text(verbatim: PaneWords.cancel) }
        } message: {
            Text(verbatim: OLEDNoticeText.message(idleMinutes: idleMinutes))
        }
    }
}

/// The OLED notice's words.
enum OLEDNoticeText {
    /// "Bright content that stays in one place … pauses it after 5 minutes without input."
    static func message(idleMinutes: Int, locale: Locale = .autoupdatingCurrent) -> String {
        let idle = PaneFormat.duration(minutes: idleMinutes, locale: locale)
        return String(localized: "Bright content that stays in one place for a long time, like the menu bar, can wear OLED panels unevenly. Overbright keeps extra brightness lower on OLED displays and pauses it after \(idle) without input.",
                      bundle: .module,
                      comment: "Settings ▸ Displays: text of the OLED question; the argument is a duration such as 5 minutes")
    }
}
