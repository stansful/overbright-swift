// OverbrightAppShell/HUD/LowLevelPromptView.swift — the Keep-this-level prompt's content and words. DESIGN.md §6,
// §12.9 (exact English; "Keep this level?" / "Going back in 10 s" [Go Back] [Keep]; VoiceOver "Keep this level? Going
// back in 10 seconds."), §12.4 (title-case buttons).
import Foundation
import Observation
import OverbrightDesign
import SwiftUI

/// The prompt's live countdown.
@Observable final class LowLevelPromptModel {
    /// Seconds until the previous level returns.
    var secondsLeft = 0
}

/// The prompt's words (StatusMenu table).
enum LowLevelPromptText {
    static var title: String {
        String(localized: "Keep this level?", table: "StatusMenu", bundle: .module,
               comment: "HUD: Keep-this-level prompt after a very dark level was set")
    }
    /// "Going back in 10 s".
    static func countdown(_ seconds: Int) -> String {
        String(localized: "Going back in \(seconds) s", table: "StatusMenu", bundle: .module,
               comment: "HUD: Keep-this-level prompt, the countdown before the previous level returns")
    }
    static var goBack: String {
        String(localized: "Go Back", table: "StatusMenu", bundle: .module,
               comment: "HUD: Keep-this-level prompt button that returns to the previous level now")
    }
    static var keep: String {
        String(localized: "Keep", table: "StatusMenu", bundle: .module,
               comment: "HUD: Keep-this-level prompt button that keeps the dark level")
    }
    /// "Keep this level? Going back in 10 seconds." (plural forms in the catalog).
    static func announcement(_ seconds: Int) -> String {
        String(localized: "Keep this level? Going back in \(seconds) seconds.", table: "StatusMenu", bundle: .module,
               comment: "VoiceOver: announced when the Keep-this-level prompt appears")
    }
}

/// The prompt.
struct LowLevelPromptView: View {
    let model: LowLevelPromptModel
    let keep: () -> Void
    let goBack: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            VStack(alignment: .leading, spacing: Space.xxs) {
                Text(verbatim: LowLevelPromptText.title)
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                Text(verbatim: LowLevelPromptText.countdown(model.secondsLeft))
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: Space.m) {
                Spacer()
                Button(action: goBack) { Text(verbatim: LowLevelPromptText.goBack) }
                    .keyboardShortcut(.cancelAction)
                Button(action: keep) { Text(verbatim: LowLevelPromptText.keep) }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(Space.l)
        .frame(width: HUDPlacement.promptSize.width, height: HUDPlacement.promptSize.height)
        .accessibilityElement(children: .contain)
    }
}

#Preview("Keep this level?") {
    let model = LowLevelPromptModel()
    model.secondsLeft = 10
    return LowLevelPromptView(model: model, keep: {}, goBack: {})
        .overbrightThemeRoot()
}
