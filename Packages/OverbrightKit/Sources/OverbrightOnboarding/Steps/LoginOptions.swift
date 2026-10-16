// OverbrightOnboarding/Steps/LoginOptions.swift — Welcome step 3's login option cards (DESIGN.md §8: "three option cards
// for login: Open and turn on · Open, keep off (selected, 'Recommended') · Don't open at login"; §7.3 When you log
// in). A card is a button in the chrome's `SelectableCardStyle` (an accent ring, a ✓ and the selected trait, so colour
// is never the only cue); picking one only records the choice (`WelcomeChoices`), which Done applies.
import OverbrightCore
import OverbrightDesign
import SwiftUI

/// The three login option cards (the order of `LaunchBehavior`; the default is recommended).
struct LoginOptions: View {
    let choices: WelcomeChoices
    let settings: SettingsStore
    let copy: DefaultsStep.Copy

    var body: some View {
        let selected = choices.launchBehavior(in: settings)
        HStack(alignment: .top, spacing: Space.m) {
            ForEach(LaunchBehavior.allCases, id: \.self) { behavior in
                let isRecommended = behavior == GeneralSettings.launchBehavior.defaultValue
                Button { choices.launchBehavior = behavior } label: {
                    VStack(alignment: .leading, spacing: Space.xxs) {
                        Text(verbatim: copy.title(of: behavior))
                            .font(.callout.weight(.medium))
                            .fixedSize(horizontal: false, vertical: true)
                        if isRecommended {
                            Text(verbatim: copy.recommended)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(Space.m)
                    .padding(.trailing, Space.l)                       // room for the ✓ of the selected card
                }
                .buttonStyle(SelectableCardStyle(isSelected: behavior == selected))
                .frame(minHeight: StepMetrics.optionCardHeight)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(verbatim: copy.title(of: behavior)))
                .accessibilityValue(Text(verbatim: isRecommended ? copy.recommended : ""))
                .accessibilityAddTraits(behavior == selected ? [.isButton, .isSelected] : .isButton)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(verbatim: copy.loginGroup))
    }
}

#Preview("Login options") {
    LoginOptions(choices: WelcomeChoices(), settings: SettingsStore(defaults: InMemoryDefaults()),
                 copy: DefaultsStep.Copy.localized)
        .padding(WelcomeMetrics.inset)
        .frame(width: WelcomeMetrics.window.width)
}
