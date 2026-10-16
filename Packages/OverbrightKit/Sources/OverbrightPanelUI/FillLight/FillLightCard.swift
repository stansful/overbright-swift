// OverbrightPanelUI/FillLight/FillLightCard.swift — the compact Fill Light card above the display cards while Fill
// Light is on: a Display pop-up, Brightness and Warmth sliders (Settings' ranges) and Turn off. DESIGN.md §5.3, §7.7
// (ranges), §11; ARCHITECTURE.md §3.8 (`FillLightSettings`). The light itself is WP7's; the card edits its settings.
import Foundation
import OverbrightCore
import OverbrightDesign
import SwiftUI

/// The Fill Light card.
public struct FillLightCard: View {
    private let services: OverbrightServices
    private let focus: FocusState<PanelFocus?>.Binding?

    /// The card over `services` (no panel focus outside the panel).
    public init(services: OverbrightServices) { self.init(services: services, focus: nil) }

    init(services: OverbrightServices, focus: FocusState<PanelFocus?>.Binding?) {
        self.services = services
        self.focus = focus
    }

    /// The brightness range (Settings ▸ Fill Light: 20–100 %).
    static let brightnessRange: ClosedRange<Double> = 0.2...1
    /// The warmth range (0 = 6,500 K … 1 = 3,000 K).
    static let warmthRange: ClosedRange<Double> = 0...1

    public var body: some View {
        let settings = services.settings
        VStack(alignment: .leading, spacing: Space.s) {
            HStack {
                Label { Text(verbatim: PanelText.fillLight) } icon: { Image(symbol: .personCropRectangle) }
                    .font(.headline)
                Spacer()
                Button(action: turnOff) { Text(verbatim: PanelText.turnOff) }
                    .controlSize(.small)
                    .panelFocus(focus, .fillLightTurnOff, activate: turnOff)
            }
            Picker(selection: displayBinding) {
                ForEach(services.displays.displays, id: \.ref.key) { facts in
                    Text(verbatim: facts.name).tag(DisplayKey?.some(facts.ref.key))
                }
            } label: {
                Text(verbatim: PanelText.display)
            }
            .controlSize(.small)
            .panelFocus(focus, .fillLightDisplay)
            slider(PanelText.brightness, value: settings.binding(FillLightSettings.brightness),
                   in: Self.brightnessRange, focusValue: .fillLightBrightness,
                   valueText: settings[FillLightSettings.brightness].formatted(.percent.precision(.fractionLength(0))))
            slider(PanelText.warmth, value: settings.binding(FillLightSettings.warmth), in: Self.warmthRange,
                   focusValue: .fillLightWarmth,
                   valueText: Measurement(value: Self.kelvin(warmth: settings[FillLightSettings.warmth]),
                                          unit: UnitTemperature.kelvin)
                       .formatted(.measurement(width: .abbreviated, numberFormatStyle: .number.precision(.fractionLength(0)))))
        }
        .padding(PanelLayout.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .quaternarySystemFill), in: RoundedRectangle(cornerRadius: Radius.card,
                                                                                style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(verbatim: PanelText.fillLight))
    }

    private func slider(_ title: String, value: Binding<Double>, in range: ClosedRange<Double>, focusValue: PanelFocus,
                        valueText: String) -> some View {
        HStack(spacing: Space.s) {
            Text(verbatim: title)
                .font(.callout)
                .frame(minWidth: PanelLayout.fillLightLabelWidth, alignment: .leading)
            Slider(value: value, in: range)
                .controlSize(.small)
                .accessibilityLabel(Text(verbatim: title))
                .accessibilityValue(Text(verbatim: valueText))
                .panelFocus(focus, focusValue)
            Text(verbatim: valueText)
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
        }
    }

    /// The chosen display; nil in the settings means the built-in display, else the main one (the key's default).
    private var displayBinding: Binding<DisplayKey?> {
        let settings = services.settings
        let fallback = services.displays.displays.first(where: \.isBuiltIn)?.ref.key
            ?? services.displays.displays.first?.ref.key
        return Binding(get: { settings[FillLightSettings.display] ?? fallback },
                       set: { settings[FillLightSettings.display] = $0 == fallback ? nil : $0 })
    }

    private func turnOff() { services.fillLight.setOn(false, source: .panel) }

    /// The colour temperature of `warmth` (0 = 6,500 K … 1 = 3,000 K), for the value text.
    static func kelvin(warmth: Double) -> Double { 6500 - min(max(warmth, 0), 1) * 3500 }
}
