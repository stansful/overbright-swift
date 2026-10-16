// OverbrightSettingsUI/Panes/DisplayLevelRow.swift — Displays ▸ ‹display› ▸ Level (DESIGN.md §7.4, §5.5): Design's
// `BoostSlider` between the `sun.min` and `sun.max.fill` glyphs, and the readout under it. The engine stores the level
// (`BoostControl.setLevel`, source Settings, which also turns Overbright on and ends a pause it set: moving the slider
// is intent); the row keeps the thumb under the pointer while it moves. Past the detent on a display whose extra
// brightness is off it turns extra brightness on, and an OLED display asks first while the thumb waits at Standard.
// While "Same level on all displays" is on, the slider moves the linked level.
import OverbrightCore
import OverbrightDesign
import OverbrightPolicy
import SwiftUI

/// The level slider and readout of one display.
struct DisplayLevelRow: View {
    let services: OverbrightServices
    let model: DisplaySectionModel
    let value: RowValue
    /// The level while the thumb moves (the engine stores the level; this keeps the thumb under the pointer).
    @State private var dragLevel: LevelPosition?
    /// A boost level that waits for the OLED question, asked when the drag ends.
    @State private var pendingBoost: LevelPosition?
    @State private var asksOLED = false

    /// The slider's track (DESIGN.md §5.4: 240 pt, the boost half 120 pt).
    static let trackWidth: CGFloat = 240

    private var editor: DisplayPreferencesEditor { DisplayPreferencesEditor(settings: services.settings) }
    private var target: DisplayKey? { model.isLinked ? nil : model.key }

    var body: some View {
        let idle = services.settings[AutomationSettings.oledIdleMinutes]
        LabeledContent {
            VStack(alignment: .leading, spacing: Space.xs) {
                HStack(spacing: Space.s) {
                    Image(symbol: .sunMin)
                        .font(.system(size: GlyphSize.sliderEnd))
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                    slider(idleMinutes: idle)
                        .frame(width: Self.trackWidth)
                    Image(symbol: .sunMaxFill)
                        .font(.system(size: GlyphSize.sliderEnd))
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                }
                ReadoutText(model.readout)
            }
        } label: {
            RowLabel(title: value.info.title)
        }
        .settingRow(value)
        .oledNotice(isPresented: $asksOLED, idleMinutes: idle) {
            guard let pending = pendingBoost else { return }
            pendingBoost = nil
            editor.update(model.key, name: model.name) { $0.boostEnabled = true; $0.oledNoticeAcknowledged = true }
            services.boost.setLevel(pending, for: target, source: .settings)
        }
        .onChange(of: asksOLED) { _, asking in
            if !asking { pendingBoost = nil }
        }
    }

    private func slider(idleMinutes: Int) -> some View {
        let dimReason: String? = model.verdict.allowsDim ? nil
            : VerdictText.make(model.verdict, advisories: [], lastGrant: nil).sentence
        return BoostSlider(level: levelBinding, top: model.top, allowedNow: model.allowedNow, presets: model.presets,
                           dimEnabled: model.verdict.allowsDim, boostHalf: model.boostHalf(oledIdleMinutes: idleMinutes),
                           accessibilityName: model.name, valueText: { model.valueText(at: $0) },
                           onCommit: commit)
            .spokenValue { model.spokenValue(at: $0) }
            .extraRange(model.allowedNow.map { ValueText.extraRange(allowed: $0, peak: model.peakTop) })
            .dimHalfReason(dimReason)
            .dimmedLevel(LevelMapping.position(forDimLight: services.settings[DisplaySettings.lastDimLight]))
    }

    private var levelBinding: Binding<LevelPosition> {
        Binding(get: { dragLevel ?? model.level }, set: { newValue in
            var level = newValue
            if level.isBoost, !model.boostEnabled, model.canBoost {
                if model.isOLED, !model.preferences.oledNoticeAcknowledged {
                    pendingBoost = level                           // the thumb waits at Standard until the question
                    level = .standard
                } else {
                    editor.update(model.key, name: model.name) { $0.boostEnabled = true }
                }
            }
            dragLevel = level
            services.boost.setLevel(level, for: target, source: .settings)
        })
    }

    private func commit(_ level: LevelPosition) {
        dragLevel = nil
        if pendingBoost != nil {
            asksOLED = true
            return
        }
        services.boost.setLevel(level, for: target, source: .settings)
    }
}
