// OverbrightSettingsUI/Panes/DisplaySection.swift — one connected display in Settings ▸ Displays (DESIGN.md §7.4): the
// header with the display's name and verdict badge; the verdict sentence with its advisories and fix (§12.1); "Use
// extra brightness on this display" (only where it can boost; an OLED asks first); the level; Safe or Peak; the method;
// the calibration with Calibrate…; the display type (externals); and the advisory about Automatically adjust
// brightness (built-in XDR on macOS 26 and later). `rows(_:)` and `values(_:services:)` list exactly what `body`
// draws, for the search index and the Reset to Default tests.
import OverbrightCore
import OverbrightDesign
import OverbrightPolicy
import SwiftUI

/// The section of one connected display.
struct DisplaySection: View {
    let services: OverbrightServices
    let model: DisplaySectionModel
    @Environment(SettingsNavigator.self) private var navigator: SettingsNavigator?

    var body: some View {
        let values = Dictionary(uniqueKeysWithValues: Self.values(model, services: services).map { ($0.info.id, $0) })
        Section {
            verdictRow
            if let value = values[DisplaysRows.extraBrightness(model.key, name: model.name).id] {
                DisplayBoostSwitchRow(services: services, model: model, value: value)
            }
            if let value = values[DisplaysRows.level(model.key, name: model.name).id] {
                DisplayLevelRow(services: services, model: model, value: value)
            }
            if let value = values[DisplaysRows.limit(model.key, name: model.name).id] {
                DisplayLimitRow(services: services, model: model, value: value)
            }
            if let value = values[DisplaysRows.method(model.key, name: model.name).id] {
                methodRow(value)
            }
            if let value = values[DisplaysRows.calibration(model.key, name: model.name).id] {
                calibrationRow(value)
            }
            if let value = values[DisplaysRows.displayType(model.key, name: model.name).id] {
                displayTypeRow(value)
            }
            if model.eligibility.advisories.contains(.autoBrightnessInteracts) {
                advisoryRow
            }
        } header: {
            header
        }
    }

    // MARK: Rows and values (what `body` draws)

    /// Every searchable row of the section.
    static func rows(_ model: DisplaySectionModel) -> [SettingsRowInfo] {
        var rows = [DisplaysRows.section(model.key, name: model.name)]
        rows += values(model, services: nil).map(\.info)
        if model.eligibility.advisories.contains(.autoBrightnessInteracts) {
            rows.append(DisplaysRows.autoBrightness(model.key, name: model.name))
        }
        return rows
    }

    /// The rows with a value and their Reset to Default, in the order the section draws them. Without `services` the
    /// entries only name their rows (for the search index).
    static func values(_ model: DisplaySectionModel, services: OverbrightServices?) -> [RowValue] {
        let key = model.key, name = model.name
        let editor = services.map { DisplayPreferencesEditor(settings: $0.settings) }
        func preferences() -> DisplayPreferences { editor?.preferences(of: key) ?? model.preferences }
        func value(_ info: SettingsRowInfo, isDefault: @escaping (DisplayPreferences) -> Bool,
                   reset: @escaping (inout DisplayPreferences) -> Void) -> RowValue {
            RowValue(info, isDefault: { isDefault(preferences()) }) { editor?.update(key, name: name, reset) }
        }
        let defaults = DisplayPreferences()
        var values: [RowValue] = []
        if model.canBoost {
            values.append(value(DisplaysRows.extraBrightness(key, name: name), isDefault: { $0.boostEnabled == nil },
                                reset: { $0.boostEnabled = nil }))
        }
        if model.canAdjust {
            values.append(levelValue(model, services: services))
        }
        if model.canBoost {
            values.append(value(DisplaysRows.limit(key, name: name), isDefault: { $0.capMode == defaults.capMode },
                                reset: { $0.capMode = defaults.capMode }))
        }
        if model.canAdjust {
            values.append(value(DisplaysRows.method(key, name: name), isDefault: { $0.mechanism == defaults.mechanism },
                                reset: { $0.mechanism = defaults.mechanism }))
        }
        if model.canBoost {
            values.append(value(DisplaysRows.calibration(key, name: name), isDefault: { $0.calibration == nil },
                                reset: { $0.calibration = nil }))
        }
        if model.isExternal {
            values.append(value(DisplaysRows.displayType(key, name: name), isDefault: { $0.oled == defaults.oled },
                                reset: { $0.oled = defaults.oled }))
        }
        return values
    }

    /// The level: the linked level while levels are linked, else the display's own.
    private static func levelValue(_ model: DisplaySectionModel, services: OverbrightServices?) -> RowValue {
        let info = DisplaysRows.level(model.key, name: model.name)
        guard let services else { return RowValue(info, isDefault: { true }, reset: {}) }
        let settings = services.settings
        if model.isLinked { return RowValue(info, settings: settings, key: DisplaySettings.linkedLevel) }
        let editor = DisplayPreferencesEditor(settings: settings)
        let standard = DisplayPreferences().level
        return RowValue(info, isDefault: { editor.preferences(of: model.key).level == standard }) {
            editor.update(model.key, name: model.name) { $0.level = standard }
        }
    }

    // MARK: Views

    private var verdictText: VerdictText {
        VerdictText.make(model.verdict, advisories: model.eligibility.advisories, lastGrant: nil,
                         capMode: model.preferences.capMode,
                         oledIdleMinutes: services.settings[AutomationSettings.oledIdleMinutes], in: .app)
    }

    private var header: some View {
        HStack(spacing: Space.m) {
            Text(verbatim: model.name)
                .lineLimit(2)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: Space.m)
            Text(verbatim: verdictText.badge)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, Space.s)
                .padding(.vertical, Space.xxs)
                .background(Capsule(style: .continuous).fill(.quaternary))
        }
        .accessibilityElement(children: .combine)
    }

    private var verdictRow: some View {
        let text = verdictText
        // The advisories shown here: not Automatically adjust brightness (its own row below) nor Not calibrated (the
        // Calibration row says it), so no reason is said twice (DESIGN.md §1 principle 7).
        let lines = zip(model.eligibility.advisories, text.advisories)
            .filter { $0.0 != .autoBrightnessInteracts && $0.0 != .notCalibrated }
            .map(\.1)
        return VStack(alignment: .leading, spacing: Space.xs) {
            HStack(alignment: .firstTextBaseline, spacing: Space.m) {
                Text(verbatim: text.sentence)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: Space.m)
                if let fix = text.fix {
                    Button { perform(fix) } label: { Text(verbatim: fix.menuTitle()) }
                }
            }
            ForEach(lines, id: \.self) { line in
                Text(verbatim: line)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .searchTarget(DisplaysRows.section(model.key, name: model.name))
    }

    private func methodRow(_ value: RowValue) -> some View {
        let editor = DisplayPreferencesEditor(settings: services.settings)
        let selection = Binding<MechanismPreference>(get: { model.preferences.mechanism }, set: { preference in
            editor.update(model.key, name: model.name) { $0.mechanism = preference }
        })
        return ChoiceRow(info: value.info, selection: selection,
                         choices: MechanismPreference.allCases.map { Choice(value: $0, label: $0.localizedName()) },
                         footnote: DisplayMethodText.footnote(preference: model.preferences.mechanism,
                                                              effective: model.mechanism),
                         style: .menu, isDefault: value.isDefault(), reset: value.reset)
    }

    private func calibrationRow(_ value: RowValue) -> some View {
        LabeledContent {
            HStack(spacing: Space.m) {
                Text(verbatim: CalibrationText.make(model.preferences.calibration, isValid: model.calibrationIsValid,
                                                    osVersion: model.osVersion))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.trailing)
                Button { services.app?.showCalibration(for: model.key) } label: {
                    Text("Calibrate…", bundle: .module, comment: "Settings ▸ Displays: opens the calibration window for this display (title case)")
                }
            }
        } label: {
            RowLabel(title: value.info.title,
                     footnote: String(localized: "A one-minute check that makes the numbers exact and lets Overbright use the right amount of range on this display.",
                                      bundle: .module, comment: "Settings ▸ Displays: footnote of Calibration"))
        }
        .settingRow(value)
    }

    private func displayTypeRow(_ value: RowValue) -> some View {
        let editor = DisplayPreferencesEditor(settings: services.settings)
        let selection = Binding<OLEDOverride>(get: { model.preferences.oled }, set: { override in
            editor.update(model.key, name: model.name) { $0.oled = override }
        })
        let choices: [OLEDOverride] = [.automatic, .oled, .notOLED]
        return ChoiceRow(info: value.info, selection: selection,
                         choices: choices.map { Choice(value: $0, label: $0.localizedName(detectedOLED: model.detectedOLED)) },
                         footnote: String(localized: "OLED displays get a lower Safe limit and pause extra brightness when idle.",
                                          bundle: .module, comment: "Settings ▸ Displays: footnote of Display type"),
                         style: .menu, isDefault: value.isDefault(), reset: value.reset)
    }

    private var advisoryRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: Space.m) {
            Image(symbol: .infoCircleFill)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text(verbatim: VerdictText.line(for: .autoBrightnessInteracts))
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
        .searchTarget(DisplaysRows.autoBrightness(model.key, name: model.name))
    }

    private func perform(_ fix: FixAction) {
        switch fix {
        case .choosePeak:
            navigator?.open("displays#\(model.key.rawValue).limit")
        default:
            SystemSettingsLink.open(SystemSettingsLink.displays)
        }
    }
}
