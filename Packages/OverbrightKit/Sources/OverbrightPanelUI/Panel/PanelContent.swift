// OverbrightPanelUI/Panel/PanelContent.swift — what the panel lists, derived without a view: which displays get a
// card, which collapse into the "can't be adjusted · Why?" row, whether the empty-state sentence, the calibration tip,
// the Fill Light card and the battery chip show. DESIGN.md §5.2, §5.3, §5.9–§5.11.
import OverbrightCore

/// The panel's sections for one status.
public struct PanelContent: Hashable {
    /// Displays that can boost or dim (a full card each), built-in first as the engine publishes them.
    public var cards: [DisplayStatus]
    /// Displays that can neither boost nor dim (virtual displays, reference presets): one collapsed row.
    public var nonCapable: [DisplayStatus]
    /// No display can show extra brightness ("None of your displays can show extra brightness right now.").
    public var showsNothingCapable: Bool
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
    public init(status: BoostStatus, tipShown: Bool, calibrated: Set<DisplayKey>, fillLightOn: Bool, hasBattery: Bool) {
        cards = status.displays.filter { !Self.isNonCapable($0) }
        nonCapable = status.displays.filter(Self.isNonCapable)
        let verdicts = status.displays.compactMap { $0.decision?.eligibility.verdict }
        showsNothingCapable = !verdicts.isEmpty && verdicts.count == status.displays.count
            && !verdicts.contains { $0.allowsBoost || $0 == .checking }
        calibrationTip = tipShown ? nil : status.displays.first { display in
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
}
