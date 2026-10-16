// OverbrightPanelUI/Card/LevelText.swift — the canonical value text of any slider position (the value tag, VoiceOver
// and the menu's "Dimmed · 25 %"). DESIGN.md §1 principle 4 (one value text everywhere), §5.5 (value tag), §12.5;
// ARCHITECTURE.md §5.3. The words and number formats are Design's (`ValueText.make`); this file builds the numbers
// for a position the way Policy's `Readout` does for the applied level.
import Foundation
import OverbrightCore
import OverbrightDesign
import OverbrightPolicy

/// Value texts of slider positions.
public enum LevelText {
    /// The numbers of `position` on a display whose boost half tops out at `top`. `base` is the display's readout now
    /// (it decides the estimate mark and carries the trusted SDR white as nits per gain).
    public static func values(at position: LevelPosition, top: Double, presets: [LevelPreset],
                              base: ReadoutValues) -> ReadoutValues {
        if position.isDim {
            let light = LevelMapping.dimLight(for: position)
            return ReadoutValues(state: .dim, appliedGain: light, requestedGain: nil, nits: nil, preset: nil,
                                 isEstimate: base.isEstimate, dimPercent: dimPercent(light))
        }
        guard position.isBoost else {
            return ReadoutValues(state: .standard, appliedGain: 1, requestedGain: nil, nits: nil, preset: nil,
                                 isEstimate: base.isEstimate, dimPercent: nil)
        }
        let gain = LevelMapping.requestedGain(for: position, top: top)
        let preset = LevelMapping.preset(at: position).flatMap { presets.contains($0) ? $0 : nil }
        let nitsPerGain = base.nits.map { $0 / max(base.appliedGain, 1) }
        return ReadoutValues(state: .boost, appliedGain: gain, requestedGain: nil, nits: nitsPerGain.map { $0 * gain },
                             preset: preset, isEstimate: base.isEstimate, dimPercent: nil)
    }

    /// The value tag of `position`: the canonical text, "· small gain on this display" when Max is below ×1.3, and
    /// the guard's own words while a guard holds the boost half (DESIGN.md §5.5).
    public static func valueTag(at position: LevelPosition, card: DisplayCardModel, guardText: String?) -> String {
        if position.isBoost, let guardText, !guardText.isEmpty { return guardText }
        let text = ValueText.make(values(at: position, top: card.top, presets: card.presets, base: card.readout)).text
        guard position.isBoost, card.hasSmallGain, !text.isEmpty else { return text }
        return String(localized: "\(text) · small gain on this display", bundle: .module,
                      comment: "Panel ▸ Display card: value tag suffix when Max is below ×1.3; the placeholder is the level")
    }

    /// The VoiceOver value of `position` (Design's spelled-out form: "Bright room, 1.29 times").
    public static func accessibilityValue(at position: LevelPosition, card: DisplayCardModel) -> String {
        ValueText.make(values(at: position, top: card.top, presets: card.presets, base: card.readout)).accessibilityText
    }

    /// The dim percentage of `light` (2 … 99 % of Standard light).
    public static func dimPercent(_ light: Double) -> Int { min(max(Int((light * 100).rounded()), 2), 99) }

    /// The named dim stops of the dim half, as light (50, 25, 10, 5 and 2 % of Standard, ARCHITECTURE.md §5.3).
    public static let namedDimLights: [Double] = [0.5, 0.25, 0.1, 0.05, 0.02]
}
