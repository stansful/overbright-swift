// OverbrightPanelUI/Panel/CalibrationTipCard.swift — the one-time "Check that it works" tip after the first boost on a
// display that can be calibrated. DESIGN.md §5.3, §8 (the calibration check moved out of Welcome into this tip);
// `OnboardingSettings.calibrationTipShown` records that it was shown. Neither button is the panel's default button:
// Return runs only the focused one (§5.12), so a Return meant for a slider never opens calibration.
import OverbrightCore
import OverbrightDesign
import SwiftUI

/// The dismissible calibration tip.
struct CalibrationTipCard: View {
    let display: DisplayKey
    let title: String
    let commands: PanelCommands
    let focus: FocusState<PanelFocus?>.Binding

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            Text(verbatim: PanelText.tipTitle)
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            Text(verbatim: PanelText.tipMessage(title))
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: Space.m) {
                Spacer()
                Button(action: dismiss) { Text(verbatim: PanelText.notNow) }
                    .controlSize(.small)
                    .panelFocus(focus, .tipNotNow, activate: dismiss)
                Button(action: calibrate) { Text(verbatim: PanelText.calibrate) }
                    .controlSize(.small)
                    .panelFocus(focus, .tipCalibrate, activate: calibrate)
            }
        }
        .panelCard()
        .accessibilityElement(children: .contain)
    }

    private func dismiss() { commands.services.settings[OnboardingSettings.calibrationTipShown] = true }

    private func calibrate() {
        dismiss()
        commands.calibrate(display)
    }
}

#Preview("Calibration tip") {
    @Previewable @FocusState var focus: PanelFocus?
    let services = ScriptedStatuses.services(named: "calibration-tip") ?? OverbrightServices.preview()
    CalibrationTipCard(display: DisplayFixture.Keys.builtIn, title: "Built-in Display",
                       commands: PanelCommands(services: services, source: .panel), focus: $focus)
        .padding(PanelLayout.outerPadding)
        .frame(width: PanelLayout.width)
        .overbrightThemeRoot()
}
