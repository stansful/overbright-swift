// OverbrightSettingsUI/Panes/FillLightPane.swift — Settings ▸ Fill Light (DESIGN.md §7.7, §11): the miniature, the
// switch (Fill Light's own state through `FillLightControl`, not a setting), the display (the built-in display by
// default, else the main one), width 16–120 pt, warmth 6,500–3,000 K, brightness 20–100 %, the camera rule and its
// cameras, and the screenshot note. Fill Light follows these settings live. Seeded empty by WP0b behind the
// `SettingsPaneView` seam (ARCHITECTURE.md §10.2); WP11 owns it (§10.13).
import CoreGraphics
import OverbrightCore
import OverbrightDesign
import SwiftUI

/// Settings ▸ Fill Light.
struct FillLightPane: SettingsPaneView {
    let services: OverbrightServices

    /// The pane for `services`.
    init(services: OverbrightServices) { self.services = services }

    /// Width range and step, in points (ARCHITECTURE.md §3.8).
    static let widthRange: ClosedRange<Double> = 16...120
    static let widthStep = 4.0
    /// Warmth range and step (0 = 6,500 K … 1 = 3,000 K; a step is 100 K).
    static let warmthRange: ClosedRange<Double> = 0...1
    static let warmthStep = 100 / (PaneFormat.coolKelvin - PaneFormat.warmKelvin)
    /// Brightness range and step.
    static let brightnessRange: ClosedRange<Double> = 0.2...1
    static let brightnessStep = 0.05

    /// The searchable rows.
    static func rows(services: OverbrightServices) -> [SettingsRowInfo] {
        [FillLightRows.fillLight, FillLightRows.display, FillLightRows.width, FillLightRows.warmth, FillLightRows.brightness,
         FillLightRows.camera, FillLightRows.cameras, FillLightRows.note]
    }

    /// The rows with a value and their Reset to Default.
    static func values(services: OverbrightServices) -> [RowValue] {
        let settings = services.settings
        return [RowValue(FillLightRows.display, settings: settings, key: FillLightSettings.display),
                RowValue(FillLightRows.width, settings: settings, key: FillLightSettings.width),
                RowValue(FillLightRows.warmth, settings: settings, key: FillLightSettings.warmth),
                RowValue(FillLightRows.brightness, settings: settings, key: FillLightSettings.brightness),
                RowValue(FillLightRows.camera, settings: settings, key: FillLightSettings.autoWithCamera),
                RowValue(FillLightRows.cameras, settings: settings, key: FillLightSettings.cameraFilter)]
    }

    /// Rows that show no value of their own: the switch is Fill Light's state, the note is text.
    static let actionRows: Set<String> = [FillLightRows.fillLight.id, FillLightRows.note.id]

    /// The display Fill Light uses when none is chosen: the built-in display, else the first (main) one.
    static func defaultDisplay(_ displays: [DisplayFacts]) -> DisplayKey? {
        (displays.first(where: \.isBuiltIn) ?? displays.first)?.ref.key
    }

    var body: some View {
        let settings = services.settings
        let displays = services.displays.displays
        let chosen = settings[FillLightSettings.display] ?? Self.defaultDisplay(displays)
        SettingsForm(.fillLight) {
            Section {
                HStack {
                    Spacer()
                    FillLightPreview(width: settings[FillLightSettings.width],
                                     kelvin: PaneFormat.kelvin(warmth: settings[FillLightSettings.warmth]),
                                     brightness: settings[FillLightSettings.brightness],
                                     displayWidth: Self.width(of: displays.first { $0.ref.key == chosen },
                                                              simulated: services.displays is FakeDisplayDirectory))
                    Spacer()
                }
                Toggle(isOn: Binding(get: { services.fillLight.isOn },
                                     set: { services.fillLight.setOn($0, source: .settings) })) {
                    RowLabel(title: FillLightRows.fillLight.title,
                             footnote: String(localized: "Lights your face on video calls with a glowing frame around the screen.",
                                              bundle: .module, comment: "Settings ▸ Fill Light: footnote of the Fill Light switch"))
                }
                .toggleStyle(.accentSwitch)
                .controlSize(.small)
                .searchTarget(FillLightRows.fillLight)
            }
            Section {
                displayRow(displays: displays, chosen: chosen)
                SliderRow(FillLightRows.width, settings: settings, key: FillLightSettings.width, range: Self.widthRange,
                          step: Self.widthStep) { SettingsFormat.points($0) }
                FillLightWarmthRow(settings: settings)
                SliderRow(FillLightRows.brightness, settings: settings, key: FillLightSettings.brightness,
                          range: Self.brightnessRange, step: Self.brightnessStep,
                          footnote: String(localized: "Uses the display’s extra range when it has one, so the light can be brighter than white.",
                                           bundle: .module, comment: "Settings ▸ Fill Light: footnote of Brightness")) {
                    SettingsFormat.percent($0)
                }
            }
            Section {
                ToggleRow(info: FillLightRows.camera, settings: settings, key: FillLightSettings.autoWithCamera,
                          footnote: String(localized: "Turns off a few seconds after the camera stops.", bundle: .module,
                                           comment: "Settings ▸ Fill Light: footnote of Turn on while a camera is in use"))
                ChoiceRow(FillLightRows.cameras, settings: settings, key: FillLightSettings.cameraFilter,
                          choices: [CameraFilter.anyCamera, .builtInAndUSB].map { Choice(value: $0, label: $0.localizedName()) },
                          footnote: String(localized: "Virtual cameras and iPhone cameras count as Any camera.", bundle: .module,
                                           comment: "Settings ▸ Fill Light: footnote of Cameras; “Any camera” is the first choice"),
                          style: .menu)
            }
            Section {
                Text(verbatim: FillLightRows.note.title)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .searchTarget(FillLightRows.note)
            }
        }
    }

    private func displayRow(displays: [DisplayFacts], chosen: DisplayKey?) -> some View {
        let settings = services.settings
        let fallback = Self.defaultDisplay(displays)
        let selection = Binding<DisplayKey?>(get: { chosen }, set: { key in
            settings[FillLightSettings.display] = key == fallback ? nil : key
        })
        return ChoiceRow(info: FillLightRows.display, selection: selection,
                         choices: displays.map { Choice(value: Optional($0.ref.key), label: $0.name) }, style: .menu,
                         isDefault: settings.isDefault(FillLightSettings.display),
                         reset: { settings.reset(FillLightSettings.display) })
            .disabled(displays.isEmpty)
    }

    /// The display's width in points (a read of its bounds), or a 14-inch laptop's when it cannot be read. A simulated
    /// display is never looked up: its fixture ID (1–6) can be a real display's (WP14). The directory port has no
    /// bounds yet; reading them through it is a contract-lane change.
    static func width(of display: DisplayFacts?, simulated: Bool) -> Double {
        guard let display, !simulated else { return fallbackDisplayWidth }
        let bounds = CGDisplayBounds(display.ref.id)
        return bounds.width > 0 ? bounds.width : fallbackDisplayWidth
    }

    /// 1,512 pt: a 14-inch MacBook Pro's default resolution.
    static let fallbackDisplayWidth = 1512.0
}

#Preview("Fill Light") {
    FillLightPane(services: .preview())
        .environment(SettingsNavigator(target: "fillLight"))
        .frame(width: 650, height: 800)
        .overbrightThemeRoot()
}
