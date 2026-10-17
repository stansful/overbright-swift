// OverbrightSettingsUI/Components/SliderRow.swift — a slider row that always shows its value with its unit (DESIGN.md
// §7.2: "sliders always show their value with its unit"). Ported from Cranny's SettingControls.swift (the owner's MIT
// code). As built (WP14): the track draws no tick marks (one per step put 27 dots under Fill Light's Width); the value
// settles on whole steps in the binding instead, and words for the two ends ("Cool", "Warm") sit under the track, so
// every slider row has the same track and the tracks of a pane line up.
import OverbrightCore
import OverbrightDesign
import SwiftUI

/// Words under the two ends of a slider's track.
struct SliderCaptions {
    /// Under the minimum ("Cool").
    let minimum: String
    /// Under the maximum ("Warm").
    let maximum: String
}

/// A slider row: label on the leading side, the slider and its formatted value.
struct SliderRow: View {
    let info: SettingsRowInfo
    let value: Binding<Double>
    let range: ClosedRange<Double>
    /// Settles a value on a whole step.
    let snap: (Double) -> Double
    /// "48 pt", "5,100 K", "80 %": the value with its unit, always shown.
    let format: (Double) -> String
    var captions: SliderCaptions?
    var footnote: String?
    let isDefault: Bool
    let reset: @MainActor () -> Void
    var onEditingChanged: @MainActor (Bool) -> Void = { _ in }

    var body: some View {
        LabeledContent {
            SliderControl(title: info.title, value: value, range: range, snap: snap, format: format, captions: captions,
                          onEditingChanged: onEditingChanged)
        } label: {
            RowLabel(title: info.title, footnote: footnote)
        }
        .settingRow(info, isDefault: isDefault, reset: reset)
    }

    /// `value` at the nearest whole multiple of `step`, inside `range` (whose ends are multiples of `step`). A multiple
    /// is computed from zero, so the default comes back exactly (16 × 0.05 is 0.8; 0.2 + 12 × 0.05 is not).
    static func snapped(_ value: Double, step: Double, in range: ClosedRange<Double>) -> Double {
        guard value.isFinite, step > 0 else { return range.lowerBound }
        return min(max((value / step).rounded() * step, range.lowerBound), range.upperBound)
    }
}

extension SliderRow {
    /// A slider bound to a Double key, settling on whole `step`s.
    init(_ info: SettingsRowInfo, settings: SettingsStore, key: SettingKey<Double>, range: ClosedRange<Double>,
         step: Double, footnote: String? = nil, format: @escaping (Double) -> String) {
        self.init(info, settings: settings, key: key, range: range,
                  snap: { Self.snapped($0, step: step, in: range) }, footnote: footnote, format: format)
    }

    /// A slider bound to a Double key, settling where `snap` says, with optional words under the track's ends.
    init(_ info: SettingsRowInfo, settings: SettingsStore, key: SettingKey<Double>, range: ClosedRange<Double>,
         snap: @escaping (Double) -> Double, captions: SliderCaptions? = nil, footnote: String? = nil,
         format: @escaping (Double) -> String) {
        self.init(info: info, value: settings.binding(key), range: range, snap: snap, format: format, captions: captions,
                  footnote: footnote, isDefault: settings.isDefault(key), reset: { settings.reset(key) })
    }
}

/// The track (with its captions) and the value: one size in every slider row, so the tracks line up.
struct SliderControl: View {
    let title: String
    let value: Binding<Double>
    let range: ClosedRange<Double>
    let snap: (Double) -> Double
    let format: (Double) -> String
    var captions: SliderCaptions?
    var onEditingChanged: @MainActor (Bool) -> Void = { _ in }

    var body: some View {
        // No `step:` (it draws a tick per step); the binding settles the value on a whole step instead.
        let settling = Binding<Double>(get: { value.wrappedValue }, set: { value.wrappedValue = snap($0) })
        HStack(alignment: .sliderTrack, spacing: Space.m) {
            VStack(spacing: Space.xxs) {
                Slider(value: settling, in: range) {
                    Text(verbatim: title)
                } onEditingChanged: { editing in
                    onEditingChanged(editing)
                }
                .labelsHidden()
                .alignmentGuide(.sliderTrack) { $0[VerticalAlignment.center] }
                .anchorPreference(key: SliderTrackBounds.self, value: .bounds) { [title: $0] }
                .accessibilityValue(Text(verbatim: format(value.wrappedValue)))
                if let captions {
                    HStack {
                        Text(verbatim: captions.minimum)
                        Spacer(minLength: Space.m)
                        Text(verbatim: captions.maximum)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)                                 // the value says where it is
                }
            }
            .frame(minWidth: SettingsMetrics.sliderWidth.min, idealWidth: SettingsMetrics.sliderWidth.ideal,
                   maxWidth: SettingsMetrics.sliderWidth.max)
            Text(verbatim: format(value.wrappedValue))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(minWidth: SettingsMetrics.sliderValueMinWidth, alignment: .trailing)
                .alignmentGuide(.sliderTrack) { $0[VerticalAlignment.center] }
                .accessibilityHidden(true)
        }
    }
}

/// Where each slider's track is, by the row's title: what a layout check reads (the app reads none).
nonisolated struct SliderTrackBounds: PreferenceKey {
    static var defaultValue: [String: Anchor<CGRect>] { [:] }
    static func reduce(value: inout [String: Anchor<CGRect>], nextValue: () -> [String: Anchor<CGRect>]) {
        value.merge(nextValue()) { _, next in next }
    }
}

/// The middle of a slider's track (its value sits there; captions hang below).
private nonisolated enum SliderTrackAlignment: AlignmentID {
    static func defaultValue(in context: ViewDimensions) -> CGFloat { context[VerticalAlignment.center] }
}

extension VerticalAlignment {
    /// The middle of a slider's track.
    nonisolated static let sliderTrack = VerticalAlignment(SliderTrackAlignment.self)
}

#Preview("Slider rows") {
    let services = OverbrightServices.preview()
    Form {
        SliderRow(SettingsRowInfo(.fillLight, "width", title: "Width"), settings: services.settings,
                  key: FillLightSettings.width, range: 16...120, step: 4) { SettingsFormat.points($0) }
        SliderRow(SettingsRowInfo(.fillLight, "warmth", title: "Warmth"), settings: services.settings,
                  key: FillLightSettings.warmth, range: 0...1, snap: { $0 },
                  captions: SliderCaptions(minimum: "Cool", maximum: "Warm")) { "\(Int($0 * 100))" }
    }
    .formStyle(.grouped)
    .frame(width: 560, height: 180)
}
