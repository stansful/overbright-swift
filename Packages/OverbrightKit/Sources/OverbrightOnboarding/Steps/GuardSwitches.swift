// OverbrightOnboarding/Steps/GuardSwitches.swift — Welcome step 3's guard switches (DESIGN.md §8: "Pause on battery
// below 20 % (with the level pop-up), Pause in Low Power Mode, Pause for full-screen video; note: 'It also backs off
// when your Mac gets warm.'"; §7.2 conventions: switches, a pop-up for more than four options, percentages through
// `FormatStyle`). Each switch shows the stored setting until touched and records its choice in `WelcomeChoices`,
// which Done applies.
import Foundation
import OverbrightCore
import OverbrightDesign
import SwiftUI

/// The guard switches of step 3, in a grouped box.
struct GuardSwitches: View {
    let choices: WelcomeChoices
    let settings: SettingsStore
    let copy: DefaultsStep.Copy

    var body: some View {
        // Read here, so the view follows the choices and the stored settings (Observation).
        let pausesOnBattery = choices.pausesOnBattery(in: settings)
        let threshold = choices.batteryThreshold(in: settings)
        let lowPower = choices.pauseInLowPowerMode(in: settings)
        let fullScreenVideo = choices.pauseForFullScreenVideo(in: settings)
        VStack(alignment: .leading, spacing: Space.s) {
            VStack(spacing: 0) {
                row(copy.battery, isOn: Binding(get: { pausesOnBattery },
                                                set: { choices.setPausesOnBattery($0, in: settings) })) {
                    Picker(selection: Binding(get: { threshold },
                                              set: { choices.setBatteryThreshold($0, in: settings) })) {
                        ForEach(WelcomeChoices.batteryThresholds, id: \.self) { percent in
                            Text(verbatim: Self.percentText(percent)).tag(percent)
                        }
                    } label: {
                        Text(verbatim: copy.batteryLevel)
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .controlSize(.small)
                    .fixedSize()
                    .accessibilityLabel(Text(verbatim: copy.batteryLevel))
                }
                Divider()
                row(copy.lowPower, isOn: Binding(get: { lowPower },
                                                 set: { choices.pauseInLowPowerMode = $0 })) { EmptyView() }
                Divider()
                row(copy.fullScreenVideo, isOn: Binding(get: { fullScreenVideo },
                                                        set: { choices.pauseForFullScreenVideo = $0 })) { EmptyView() }
            }
            .padding(.horizontal, Space.m)
            .stepCard()
            Text(verbatim: copy.warmNote)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    /// One row: its label (wrapping when a translation is long), an optional accessory, then the switch.
    private func row(_ title: String, isOn: Binding<Bool>, @ViewBuilder accessory: () -> some View) -> some View {
        HStack(spacing: Space.m) {
            Text(verbatim: title)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityHidden(true)
            accessory()
            Toggle(isOn: isOn) { Text(verbatim: title) }
                .labelsHidden()
                .toggleStyle(.accentSwitch)
                .controlSize(.small)
                .accessibilityLabel(Text(verbatim: title))
        }
        .padding(.vertical, Space.s)
    }

    /// "20 %" in the person's locale (DESIGN.md §12.5: percentages through `FormatStyle`).
    static func percentText(_ percent: Int) -> String {
        percent.formatted(.percent)
    }
}

#Preview("Guard switches") {
    let services = WelcomePreview.services()
    GuardSwitches(choices: WelcomeChoices(), settings: services.settings, copy: DefaultsStep.Copy.localized)
        .padding(WelcomeMetrics.inset)
        .frame(width: WelcomeMetrics.window.width)
        .overbrightThemeRoot()
}
