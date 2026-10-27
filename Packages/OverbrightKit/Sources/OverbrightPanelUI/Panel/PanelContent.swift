// OverbrightPanelUI/Panel/PanelContent.swift — what the panel lists, derived without a view: which displays get a card
// (every display, or only the built-in one while external displays are hidden), which collapse into the "can't be
// adjusted · Why?" row, whether the empty-state sentence, the "external displays are hidden" line, the calibration tip,
// the Fill Light card and the battery chip show. DESIGN.md §5.2, §5.3, §5.4, §5.9–§5.11.
import OverbrightCore

/// The panel's sections for one status.
public struct PanelContent: Hashable {
    /// Displays that can boost or dim (a full card each), built-in first as the engine publishes them.
    public var cards: [DisplayStatus]
    /// Displays that can neither boost nor dim (virtual displays, reference presets): one collapsed row.
    public var nonCapable: [DisplayStatus]
    /// No display can show extra brightness ("None of your displays can show extra brightness right now."), judged
    /// over every display, hidden ones too: the sentence speaks of all of them.
    public var showsNothingCapable: Bool
    /// External displays are hidden and no built-in display is in use, so no display is listed ("The built-in display
    /// isn’t in use, and external displays are hidden." · "Show external displays…").
    public var showsExternalsHidden: Bool
    /// The display the one-time calibration tip names, nil when the tip does not show.
    public var calibrationTip: DisplayKey?
    /// Fill Light is on: its card shows above the display cards.
    public var showsFillLightCard: Bool
    /// The Mac has a battery: the Battery footer chip shows.
    public var showsBatteryChip: Bool

    /// The sections of `status`.
    /// - Parameters:
    ///   - tipShown: the calibration tip was shown (or dismissed) before.
    ///   - calibrated: displays that have a calibration record.
    ///   - fillLightOn: Fill Light is on.
    ///   - hasBattery: the Mac has a battery.
    ///   - builtInOnly: the built-in displays while external displays are hidden (`builtInOnly(services:)`), nil while
    ///     the panel lists every display.
    public init(status: BoostStatus, tipShown: Bool, calibrated: Set<DisplayKey>, fillLightOn: Bool, hasBattery: Bool,
                builtInOnly: Set<DisplayKey>? = nil) {
        let listed = builtInOnly.map { keys in status.displays.filter { keys.contains($0.key) } } ?? status.displays
        cards = listed.filter { !Self.isNonCapable($0) }
        nonCapable = listed.filter(Self.isNonCapable)
        showsExternalsHidden = listed.isEmpty && !status.displays.isEmpty
        let verdicts = status.displays.compactMap { $0.decision?.eligibility.verdict }
        showsNothingCapable = !showsExternalsHidden && !verdicts.isEmpty && verdicts.count == status.displays.count
            && !verdicts.contains { $0.allowsBoost || $0 == .checking }
        calibrationTip = tipShown ? nil : listed.first { display in
            display.phase == .boosted && !calibrated.contains(display.key)
                && display.decision?.eligibility.verdict.allowsBoost == true
        }?.key
        showsFillLightCard = fillLightOn
        showsBatteryChip = hasBattery
    }

    /// A display that can neither boost nor dim, by its verdict (a display without a verdict yet gets a card).
    public static func isNonCapable(_ display: DisplayStatus) -> Bool {
        guard let verdict = display.decision?.eligibility.verdict else { return false }
        return !verdict.allowsBoost && !verdict.allowsDim && verdict != .checking
    }

    /// The built-in displays online now while the panel hides external displays (Show external displays in the panel
    /// off, on a Mac with a built-in display); nil while it lists every display. A display the directory does not know
    /// yet counts as external.
    public static func builtInOnly(services: OverbrightServices) -> Set<DisplayKey>? {
        guard !services.settings[DisplaySettings.showsExternalDisplaysInPanel], services.hasBuiltInDisplay else { return nil }
        return Set(services.displays.displays.filter(\.isBuiltIn).map(\.ref.key))
    }
}
