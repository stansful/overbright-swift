// OverbrightSettingsUI/Components/UpdatesSection.swift — General ▸ Updates (DESIGN.md §7.3), only when this build has a
// repository: Check for updates automatically (off, or the Welcome choice), Include pre-releases, Check Now with the
// result inline. The update check is GitHub Releases, never a download (D2). Ported from Cranny's UpdatesSection (the
// owner's MIT code).
import Foundation
import OverbrightCore
import OverbrightDesign
import SwiftUI

/// General's Updates section.
struct UpdatesSection: View {
    let services: OverbrightServices

    /// "Check for updates automatically".
    static var automatic: SettingsRowInfo {
        SettingsRowInfo(.general, "automaticUpdates",
                        title: String(localized: "Check for updates automatically", bundle: .module,
                                      comment: "Settings ▸ General: switch for the daily update check"),
                        keywords: [AboutContent.gitHub])
    }

    /// "Include pre-releases".
    static var prereleases: SettingsRowInfo {
        SettingsRowInfo(.general, "prereleases",
                        title: String(localized: "Include pre-releases", bundle: .module,
                                      comment: "Settings ▸ General: switch, the update check also reports beta releases"),
                        keywords: [String(localized: "beta", bundle: .module, comment: "Settings search: keyword for Include pre-releases")])
    }

    /// "Check Now" and its result.
    static var checkNow: SettingsRowInfo {
        SettingsRowInfo(.general, "checkNow",
                        title: String(localized: "Check for Updates", bundle: .module,
                                      comment: "Settings ▸ General and About: the update check row (title case: it names the button’s action)"),
                        keywords: [AboutContent.versionKeyword])
    }

    /// The searchable rows (none when the build has no repository).
    static func rows(services: OverbrightServices) -> [SettingsRowInfo] {
        services.updates.isConfigured ? [automatic, prereleases, checkNow] : []
    }

    var body: some View {
        if services.updates.isConfigured {
            Section {
                ToggleRow(info: Self.automatic, settings: services.settings, key: UpdateSettings.automatic,
                          footnote: String(localized: "Overbright asks GitHub once a day. Nothing else is sent.", bundle: .module,
                                           comment: "Settings ▸ General: footnote of Check for updates automatically"))
                ToggleRow(info: Self.prereleases, settings: services.settings, key: UpdateSettings.prereleases)
                UpdateStatusRow(updates: services.updates, lastCheck: services.settings[UpdateSettings.lastCheck])
                    .searchTarget(Self.checkNow)
            } header: {
                Text("Updates", bundle: .module, comment: "Settings ▸ General and About: section header")
            }
        }
    }
}

#Preview("Updates") {
    let services = OverbrightServices.preview()
    if let updates = services.updates as? PreviewUpdateChecking { updates.isConfigured = true }
    return Form { UpdatesSection(services: services) }
        .formStyle(.grouped)
        .frame(width: 600, height: 260)
}
