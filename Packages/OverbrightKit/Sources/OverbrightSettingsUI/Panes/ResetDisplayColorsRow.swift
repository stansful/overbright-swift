// OverbrightSettingsUI/Panes/ResetDisplayColorsRow.swift — Advanced ▸ Reset Display Colors… (DESIGN.md §7.8, §12.4;
// ARCHITECTURE.md D7): confirms first ("Reset display colors?"), then asks the engine for the dirty-then-restore of
// every display (`BoostControl.rescueDisplayColors`) and shows its result inline in Design's words
// (`RescueOutcome.localizedResult`).
import OverbrightCore
import OverbrightDesign
import SwiftUI

/// Reset Display Colors… with its question and inline result.
struct ResetDisplayColorsRow: View {
    let services: OverbrightServices
    @State private var confirming = false
    @State private var isResetting = false
    @State private var result: String?

    var body: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            HStack(spacing: Space.m) {
                Button { confirming = true } label: { Text(verbatim: AdvancedRows.resetDisplayColors.title) }
                    .disabled(isResetting)
                if isResetting { ProgressView().controlSize(.small) }
            }
            Text(verbatim: result ?? String(localized: "Use this if colors look wrong after another app quit.", bundle: .module,
                                            comment: "Settings ▸ Advanced: footnote of Reset Display Colors"))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .searchTarget(AdvancedRows.resetDisplayColors)
        .alert(Text("Reset display colors?", bundle: .module, comment: "Settings ▸ Advanced: title of the question before Reset Display Colors"),
               isPresented: $confirming) {
            Button(role: .destructive) { reset() } label: {
                Text("Reset Colors", bundle: .module, comment: "Settings ▸ Advanced: confirms Reset Display Colors (title case)")
            }
            Button(role: .cancel) {} label: { Text(verbatim: PaneWords.cancel) }
        } message: {
            Text("Every display goes back to its color profile. This also clears changes made by other color apps.", bundle: .module,
                 comment: "Settings ▸ Advanced: text of the question before Reset Display Colors")
        }
    }

    private func reset() {
        isResetting = true
        result = nil
        Task {
            let outcome = await services.boost.rescueDisplayColors()
            result = outcome.localizedResult()
            isResetting = false
            AccessibilityNotification.Announcement(outcome.localizedResult()).post()
        }
    }
}

#Preview("Reset Display Colors") {
    Form { ResetDisplayColorsRow(services: .preview()) }
        .formStyle(.grouped)
        .environment(SettingsNavigator(target: "advanced"))
        .frame(width: 600, height: 120)
}
