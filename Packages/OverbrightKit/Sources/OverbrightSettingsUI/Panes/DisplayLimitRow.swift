// OverbrightSettingsUI/Panes/DisplayLimitRow.swift — Displays ▸ ‹display› ▸ Limit (DESIGN.md §7.4, §12.2, §12.4): Safe
// or Peak, segmented (a pop-up when a translation does not fit). The footnote is the display's own Safe sentence by
// class, then what Peak does. Switching from Safe to Peak asks first ("Use Peak on ‹Display›?"); §3.8 keeps no record
// of an earlier answer, so every switch to Peak asks.
import OverbrightCore
import OverbrightDesign
import SwiftUI

/// Safe or Peak, with the question before Peak.
struct DisplayLimitRow: View {
    let services: OverbrightServices
    let model: DisplaySectionModel
    let value: RowValue
    @State private var confirmingPeak = false

    private var editor: DisplayPreferencesEditor { DisplayPreferencesEditor(settings: services.settings) }

    var body: some View {
        let selection = Binding<CapMode>(get: { model.preferences.capMode }, set: { mode in
            if mode == .peak, model.preferences.capMode != .peak {
                confirmingPeak = true
            } else {
                editor.update(model.key, name: model.name) { $0.capMode = mode }
            }
        })
        ChoiceRow(info: value.info, selection: selection,
                  choices: CapMode.allCases.map { Choice(value: $0, label: $0.localizedName()) },
                  footnote: CopyFormat.sentences(model.safeSentence, Self.peakSentence), style: .segmented,
                  isDefault: value.isDefault(), reset: value.reset)
            .alert(Text(verbatim: Self.peakQuestion(name: model.name)), isPresented: $confirmingPeak) {
                Button {
                    editor.update(model.key, name: model.name) { $0.capMode = .peak }
                } label: {
                    Text("Use Peak", bundle: .module, comment: "Settings ▸ Displays: confirms switching the display to Peak (title case)")
                }
                Button(role: .cancel) {} label: { Text(verbatim: PaneWords.cancel) }
            } message: {
                Text("Peak lets the whole screen go above the level the display can hold for long. It uses noticeably more power and makes the display warmer; macOS lowers it when needed.",
                     bundle: .module, comment: "Settings ▸ Displays: text of the question before the display switches to Peak")
            }
    }

    /// "Peak goes up to what macOS allows; …" (the second sentence of the Limit footnote).
    static var peakSentence: String {
        String(localized: "Peak goes up to what macOS allows; it uses more power, and macOS may lower it when the display gets warm.",
               bundle: .module, comment: "Settings ▸ Displays: second sentence of the Limit footnote, after the Safe sentence")
    }

    /// "Use Peak on ‹Display›?"
    static func peakQuestion(name: String) -> String {
        String(localized: "Use Peak on \(name.overbrightIsolated)?", bundle: .module,
               comment: "Settings ▸ Displays: title of the question before the display switches to Peak; the argument is the display’s name")
    }
}

#Preview("Limit") {
    let services = OverbrightServices.preview(fixture: .mpg322uxHDROn)
    if let model = DisplaysPane.models(services: services).first {
        let value = RowValue(DisplaysRows.limit(model.key, name: model.name), isDefault: { true }, reset: {})
        Form { DisplayLimitRow(services: services, model: model, value: value) }
            .formStyle(.grouped)
            .environment(SettingsNavigator(target: "displays"))
            .frame(width: 640, height: 160)
            .overbrightThemeRoot()
    }
}
