// OverbrightSettingsUI/Components/UpdateStatusRow.swift — the result of the last update check and Check Now, shared by
// General ▸ Updates and About (DESIGN.md §7.3, §7.9): "Overbright is up to date." / "Overbright 0.2.0 is available." +
// Download… / the error line. Shown only when this build has a repository (`UpdateChecking.isConfigured`). Ported from
// Cranny's UpdatesSection.swift (the owner's MIT code); it reads `services.updates` instead of `AppControl`.
import AppKit
import Foundation
import OverbrightCore
import OverbrightDesign
import SwiftUI

/// Check Now and the result of the last check.
struct UpdateStatusRow: View {
    let updates: any UpdateChecking
    let lastCheck: Date?

    var body: some View {
        let state = updates.state
        LabeledContent {
            HStack(spacing: Space.m) {
                if case .available(_, let url) = state {
                    Button {
                        NSWorkspace.shared.open(url)
                    } label: {
                        Text("Download…", bundle: .module,
                             comment: "Settings ▸ General: opens the release page of an available update in the browser (title case)")
                    }
                }
                Button {
                    updates.checkNow()
                } label: {
                    Text("Check Now", bundle: .module, comment: "Settings ▸ General: checks GitHub for updates now (title case)")
                }
                .disabled(state == .checking)
            }
        } label: {
            HStack(spacing: Space.s) {
                if state == .checking { ProgressView().controlSize(.small) }
                Text(verbatim: Self.status(state, lastCheck: lastCheck))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// The sentence for `state` (DESIGN.md §7.3).
    static func status(_ state: UpdateState, lastCheck: Date?) -> String {
        switch state {
        case .checking:
            String(localized: "Checking…", bundle: .module, comment: "Settings ▸ General: an update check is running")
        case .upToDate:
            String(localized: "Overbright is up to date.", bundle: .module,
                   comment: "Settings ▸ General: result of an update check")
        case .available(let version, _):
            String(localized: "Overbright \(version) is available.", bundle: .module,
                   comment: "Settings ▸ General: result of an update check; the argument is a version number (0.2.0)")
        case .failed(let message):
            message
        case .idle:
            lastCheck.map { date in
                String(localized: "Last checked \(date.formatted(.relative(presentation: .named)))", bundle: .module,
                       comment: "Settings ▸ General: when the last update check ran; the argument is a relative date (“yesterday”)")
            } ?? String(localized: "Not checked yet", bundle: .module,
                        comment: "Settings ▸ General: no update check has run yet")
        }
    }
}

#Preview("Update status") {
    Form {
        UpdateStatusRow(updates: PreviewUpdateChecking(isConfigured: true,
                                                        state: .available(version: "0.2.0",
                                                                          url: URL(fileURLWithPath: "/"))),
                        lastCheck: nil)
    }
    .formStyle(.grouped)
    .frame(width: 600, height: 100)
}
