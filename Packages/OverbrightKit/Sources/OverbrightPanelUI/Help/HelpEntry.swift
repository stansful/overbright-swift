// OverbrightPanelUI/Help/HelpEntry.swift — the answers of the local Help window, each with its anchor. DESIGN.md
// §12.6 (exact English), §16 (key caps come from the live binding; the variant without a shortcut when it is cleared).
// No network: Help is local (DESIGN.md §0 #15).
import Foundation
import OverbrightCore

/// One Help answer.
public struct HelpEntry: Identifiable, Hashable {
    /// The anchors "Learn more" links and `AppControl.showHelp(anchor:)` use.
    public nonisolated enum Anchor {
        /// The screen didn't get brighter.
        public static let noExtraRange = "no-extra-range"
        /// Colors look washed out, or HDR video looks flat.
        public static let washedOut = "washed-out"
        /// How do I get back to normal right away?
        public static let backToStandard = "back-to-standard"
        /// The display looks wrong even after quitting.
        public static let looksWrong = "looks-wrong"
        /// Why is extra brightness limited?
        public static let limited = "limited"
        /// Why does extra brightness fade when I lower the brightness?
        public static let brightnessKeys = "brightness-keys"
        /// Does it use more battery?
        public static let battery = "battery"
        /// Where is the menu bar icon?
        public static let menuBarIcon = "menu-bar-icon"
        /// Add Overbright to Control Center.
        public static let controlCenter = "control-center"
        /// Every anchor, in the window's order.
        public static let all = [noExtraRange, washedOut, backToStandard, looksWrong, limited, brightnessKeys, battery,
                                 menuBarIcon, controlCenter]
    }

    /// The anchor.
    public let id: String
    /// The question.
    public let question: String
    /// The answer.
    public let answer: String

    /// Every answer in order. `backToStandardKeys` is the live key caps of the Back to Standard shortcut, nil when it
    /// is cleared or not registered (the answer then leaves the shortcut out).
    public static func all(backToStandardKeys: String?) -> [HelpEntry] {
        [
            HelpEntry(id: Anchor.noExtraRange,
                      question: String(localized: "The screen didn’t get brighter", bundle: .module,
                                       comment: "Help: question"),
                      answer: String(localized: "Turn the display brightness all the way up; Overbright adds to it. Check the display’s verdict in Settings ▸ Displays. On a MacBook Pro, use the 1600-nit preset. On some Macs, macOS ignores color table changes: choose Calibrate… to check, or try Compatibility mode. Run Self-Test… shows what macOS reports.",
                                     bundle: .module, comment: "Help: answer to “The screen didn’t get brighter”")),
            HelpEntry(id: Anchor.washedOut,
                      question: String(localized: "Colors look washed out, or HDR video looks flat", bundle: .module,
                                       comment: "Help: question"),
                      answer: String(localized: "While extra brightness is on, HDR highlights can’t go above the brightened white. In Settings ▸ Automations, Overbright can pause for full-screen video and for the apps you choose.",
                                     bundle: .module,
                                     comment: "Help: answer about washed-out colors (Settings ▸ Automations is Overbright’s Settings window and pane; both rules are off until the user turns them on)")),
            HelpEntry(id: Anchor.backToStandard,
                      question: String(localized: "How do I get back to normal right away?", bundle: .module,
                                       comment: "Help: question"),
                      answer: backToStandardAnswer(keys: backToStandardKeys)),
            HelpEntry(id: Anchor.looksWrong,
                      question: String(localized: "The display looks wrong even after quitting", bundle: .module,
                                       comment: "Help: question"),
                      answer: String(localized: "Change the display preset in Displays settings and back, or log out. If another color app was running, quit it. Settings ▸ Advanced ▸ Reset Display Colors can also help.",
                                     bundle: .module, comment: "Help: answer about a display that looks wrong")),
            HelpEntry(id: Anchor.limited,
                      question: String(localized: "Why is extra brightness limited?", bundle: .module,
                                       comment: "Help: question"),
                      answer: String(localized: "macOS decides how much extra range a display gets. It gives less when the surroundings are already bright, the display is warm or the battery is low. The chip on each display says what limits it.",
                                     bundle: .module, comment: "Help: answer about limits")),
            HelpEntry(id: Anchor.brightnessKeys,
                      question: String(localized: "Why does extra brightness fade when I lower the brightness?",
                                       bundle: .module, comment: "Help: question"),
                      answer: String(localized: "With Add extra brightness only near full brightness on, Overbright adds light only when the display is near full brightness, so the brightness keys keep their normal range. Turn it off in Settings ▸ Displays to multiply any brightness.",
                                     bundle: .module, comment: "Help: answer about the brightness keys")),
            HelpEntry(id: Anchor.battery,
                      question: String(localized: "Does it use more battery?", bundle: .module, comment: "Help: question"),
                      answer: batteryAnswer),
            HelpEntry(id: Anchor.menuBarIcon,
                      question: String(localized: "Where is the menu bar icon?", bundle: .module,
                                       comment: "Help: question"),
                      answer: String(localized: "If the menu bar is full or macOS hides the icon, open Overbright from Finder or Spotlight to see Settings. In Menu Bar settings, check that Overbright is turned on under Allow in the Menu Bar.",
                                     bundle: .module, comment: "Help: answer about a hidden menu bar icon")),
            HelpEntry(id: Anchor.controlCenter,
                      question: String(localized: "Add Overbright to Control Center", bundle: .module,
                                       comment: "Help: question"),
                      answer: String(localized: "To put Overbright in Control Center or the menu bar, make a shortcut with Turn Overbright On or Off, then add Control Center’s Run Shortcut control.",
                                     bundle: .module, comment: "Help: the Run Shortcut recipe")),
        ]
    }

    /// Answer 7 with the default battery level through FormatStyle ("20%", "20 %").
    static var batteryAnswer: String {
        let level = (Double(AutomationSettings.batteryThreshold.defaultValue) / 100).formatted(.percent)
        return String(localized: "Yes. More light takes more power, roughly in proportion. By default Overbright pauses below \(level) battery and in Low Power Mode.",
                      bundle: .module,
                      comment: "Help: answer about battery use; the placeholder is the default battery level, e.g. “20%”")
    }

    /// Answer 3 with the live Back to Standard key caps, or without them (DESIGN.md §12.6, §16).
    static func backToStandardAnswer(keys: String?) -> String {
        guard let keys else {
            return String(localized: "Choose Turn Off Overbright in the menu or the panel. If Overbright stops responding, Force Quit it: macOS restores your displays at once.",
                          bundle: .module, comment: "Help: answer about Back to Standard when its shortcut is cleared")
        }
        return String(localized: "Press \(keys), or choose Turn Off Overbright. If Overbright stops responding, Force Quit it: macOS restores your displays at once.",
                      bundle: .module,
                      comment: "Help: answer about Back to Standard; the placeholder is the live key caps of its shortcut")
    }
}
