// OverbrightSettingsUI/Panes/LaunchBehaviorRow.swift — General ▸ When you log in (DESIGN.md §7.3): a radio group of
// the three launch behaviours (ARCHITECTURE.md §3.8 `general.launchBehavior`, default "Open Overbright, keep it off"),
// stored through `AppControl.setLaunchBehavior`, which keeps the login item in step. While macOS waits for the user's
// approval of the login item, the row says so and offers Login Items in System Settings.
import OverbrightCore
import OverbrightDesign
import SwiftUI

/// When you log in.
struct LaunchBehaviorRow: View {
    let services: OverbrightServices

    var body: some View {
        let settings = services.settings
        let selection = Binding<LaunchBehavior>(get: { settings[GeneralSettings.launchBehavior] },
                                                set: { GeneralPane.setLaunchBehavior($0, services: services) })
        VStack(alignment: .leading, spacing: Space.s) {
            Picker(selection: selection) {
                ForEach(LaunchBehavior.allCases, id: \.self) { behavior in
                    Text(verbatim: behavior.localizedName()).tag(behavior)
                }
            } label: {
                RowLabel(title: GeneralRows.launchBehavior.title,
                         footnote: String(localized: "After a restart, nothing gets brighter until you turn Overbright on, unless you choose the first option.",
                                          bundle: .module, comment: "Settings ▸ General: footnote of When you log in"))
            }
            .pickerStyle(.radioGroup)
            if services.app?.loginItem == .requiresApproval {
                HStack(spacing: Space.m) {
                    Text("macOS needs your approval in Login Items settings.", bundle: .module,
                         comment: "Settings ▸ General: the login item waits for approval; “Login Items” is macOS’s own name")
                        .font(.footnote)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    Button { SystemSettingsLink.open(SystemSettingsLink.loginItems) } label: {
                        Text(verbatim: SystemSettingsLink.openSystemSettings)
                    }
                }
            }
        }
    }
}

#Preview("When you log in · approval") {
    let services = OverbrightServices.preview()
    (services.app as? PreviewAppControl)?.loginItem = .requiresApproval
    return Form { LaunchBehaviorRow(services: services) }
        .formStyle(.grouped)
        .frame(width: 600, height: 220)
}
