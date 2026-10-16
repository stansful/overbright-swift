// OverbrightPanelUI/Panel/CalibrationTipCard.swift — the one-time "Check that it works" tip after the first boost on a
// display that can be calibrated. DESIGN.md §5.3, §8 (the calibration check moved out of Welcome into this tip);
// `OnboardingSettings.calibrationTipShown` records that it was shown.
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
                    .keyboardShortcut(.defaultAction)
                    .panelFocus(focus, .tipCalibrate, activate: calibrate)
            }
        }
        .padding(PanelLayout.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .quaternarySystemFill), in: RoundedRectangle(cornerRadius: Radius.card,
                                                                                style: .continuous))
        .accessibilityElement(children: .contain)
    }

    private func dismiss() { commands.services.settings[OnboardingSettings.calibrationTipShown] = true }

    private func calibrate() {
        dismiss()
        commands.calibrate(display)
    }
}
