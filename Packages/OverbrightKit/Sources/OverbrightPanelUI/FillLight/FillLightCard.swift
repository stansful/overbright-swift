// OverbrightPanelUI/FillLight/FillLightCard.swift — the compact Fill Light card above the display cards while Fill
// Light is on: a Display pop-up, Brightness and Warmth (Cool ↔ Warm) sliders with Settings' ranges, and Turn off.
// DESIGN.md §5.3, §7.7 (ranges, the warmth slider's Cool and Warm ends), §11, §5.12 (Space or Return opens the
// pop-up, ← and → move a focused slider); ARCHITECTURE.md §3.8 (`FillLightSettings`). One grid: a label column in
// `.callout`, the controls, and a value column as wide as the widest value, so both sliders start and end at the same x
// whatever they show. The light itself is WP7's; the card edits its settings.
import Foundation
import OverbrightCore
import OverbrightDesign
import SwiftUI

/// The Fill Light card.
public struct FillLightCard: View {
    private let services: OverbrightServices
    private let focus: FocusState<PanelFocus?>.Binding?
    @Environment(\.panelMenuPresenter) private var menus
    @State private var displayAnchor = MenuAnchorReference()

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
    /// One ← / → press on the brightness slider: 5 % of light.
    static let brightnessStep = 0.05
    /// One ← / → press on the warmth slider: 100 K, Settings' step.
    static let warmthStep = 100.0 / 3500

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
            Grid(alignment: .leading, horizontalSpacing: Space.s, verticalSpacing: Space.s) {
                GridRow {
                    label(PanelText.display)
                    displayPicker
                        .gridCellColumns(2)
                }
                GridRow {
                    label(PanelText.brightness)
                    slider(PanelText.brightness, value: settings.binding(FillLightSettings.brightness),
                           in: Self.brightnessRange, step: Self.brightnessStep, focusValue: .fillLightBrightness,
                           valueText: Self.percentText(settings[FillLightSettings.brightness]))
                    valueColumn(Self.percentText(settings[FillLightSettings.brightness]))
                }
                GridRow {
                    label(PanelText.warmth)
                    slider(PanelText.warmth, value: settings.binding(FillLightSettings.warmth), in: Self.warmthRange,
                           step: Self.warmthStep, focusValue: .fillLightWarmth,
                           valueText: Self.kelvinText(warmth: settings[FillLightSettings.warmth]))
                    valueColumn(Self.kelvinText(warmth: settings[FillLightSettings.warmth]))
                }
                GridRow {                                               // the warmth slider's ends (Settings' words)
                    Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])
                    HStack {
                        Text(verbatim: PanelText.cool)
                        Spacer(minLength: Space.s)
                        Text(verbatim: PanelText.warm)
                    }
                    .font(OverbrightFont.caption.font)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                    Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])
                }
            }
        }
        .panelCard()
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(verbatim: PanelText.fillLight))
    }

    // MARK: Pieces

    private func label(_ text: String) -> some View {
        Text(verbatim: text)
            .font(.callout)
            .lineLimit(1)
            .gridColumnAlignment(.leading)
    }

    private var displayPicker: some View {
        let displays = services.displays.displays
        let binding = displayBinding
        return Picker(selection: binding) {
            ForEach(displays, id: \.ref.key) { facts in
                Text(verbatim: facts.name).tag(DisplayKey?.some(facts.ref.key))
            }
        } label: {
            Text(verbatim: PanelText.display)
        }
        .labelsHidden()
        .controlSize(.small)
        .background { MenuAnchor(reference: displayAnchor) }
        .panelFocus(focus, .fillLightDisplay) {
            menus.present(displayAnchor, KeyboardMenu.choices(displays.map { (value: $0.ref.key, title: $0.name) },
                                                              selected: binding.wrappedValue) { binding.wrappedValue = $0 })
        }
    }

    private func slider(_ title: String, value: Binding<Double>, in range: ClosedRange<Double>, step: Double,
                        focusValue: PanelFocus, valueText: String) -> some View {
        Slider(value: value, in: range)
            .controlSize(.small)
            .accessibilityLabel(Text(verbatim: title))
            .accessibilityValue(Text(verbatim: valueText))
            .panelFocus(focus, focusValue) { towardEnd in
                value.wrappedValue = Self.stepped(value.wrappedValue, in: range, by: step, towardEnd: towardEnd)
            }
    }

    /// The value column: as wide as the widest value it can show, so the sliders never change width.
    private func valueColumn(_ text: String) -> some View {
        ZStack(alignment: .trailing) {
            ForEach(Self.widestValues, id: \.self) { Text(verbatim: $0).hidden() }
            Text(verbatim: text)
        }
        .font(.callout.monospacedDigit())
        .foregroundStyle(.secondary)
        .accessibilityHidden(true)
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

    // MARK: Values

    /// The values that are the widest each column can show ("100 %", "6,500 K"), for its fixed width.
    static var widestValues: [String] { [percentText(1), kelvinText(warmth: 0), kelvinText(warmth: 1)] }

    /// The brightness as a percentage ("80 %").
    static func percentText(_ value: Double) -> String { value.formatted(.percent.precision(.fractionLength(0))) }

    /// The colour temperature of `warmth` (0 = 6,500 K … 1 = 3,000 K), for the value text.
    static func kelvin(warmth: Double) -> Double { 6500 - min(max(warmth, 0), 1) * 3500 }

    /// "5,100 K": always kelvin, never converted to the locale's temperature unit (DESIGN.md §12.5).
    static func kelvinText(warmth: Double) -> String {
        Measurement(value: kelvin(warmth: warmth), unit: UnitTemperature.kelvin)
            .formatted(.measurement(width: .abbreviated, usage: .asProvided,
                                    numberFormatStyle: .number.precision(.fractionLength(0))))
    }

    /// `value` moved one `step` toward the range's end (or its start), kept in `range`.
    static func stepped(_ value: Double, in range: ClosedRange<Double>, by step: Double, towardEnd: Bool) -> Double {
        min(max(value + (towardEnd ? step : -step), range.lowerBound), range.upperBound)
    }
}

#Preview("Fill Light card") {
    let services = ScriptedStatuses.services(named: "fill-light-card") ?? OverbrightServices.preview()
    FillLightCard(services: services)
        .padding()
        .overbrightThemeRoot()
}
