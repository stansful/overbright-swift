// OverbrightSettingsUI/Panes/OtherAppsSection.swift — Advanced ▸ Other apps (DESIGN.md §7.8; ARCHITECTURE.md §7.2): the
// running apps that also change display colors or brightness, live from `SystemSignals` (its catalogue matches;
// diagnostics-only matches are left out), each with its icon, its own name (`NSRunningApplication.localizedName`, the
// only way another app's name reaches the UI, D3), its kind, and for color apps and apps that may change brightness an
// Always continue switch (`advanced.alwaysContinue`). Next to a brightness app it says why Overbright cannot run on the
// color table and what to do. "None running." when empty.
import OverbrightCore
import OverbrightDesign
import SwiftUI

/// The other apps that change display colors or brightness.
struct OtherAppsSection: View {
    let services: OverbrightServices
    let value: RowValue

    /// The apps the list shows: every catalogue match that has a kind (S1–S3), each once.
    static func apps(_ conflicts: [ConflictingApp]) -> [ConflictingApp] {
        var seen: Set<String> = []
        return conflicts.filter { $0.severity.localizedKind() != nil && seen.insert("\($0.entryID)/\($0.processID)").inserted }
    }

    /// Color apps and apps that may change brightness can be continued with; brightness apps cannot (§7.2).
    static func offersAlwaysContinue(_ app: ConflictingApp) -> Bool {
        app.severity == .gammaWriter || app.severity == .conditional
    }

    var body: some View {
        let apps = Self.apps(services.signals.snapshot.conflicts)
        Section {
            LabeledContent {
                if apps.isEmpty {
                    Text("None running.", bundle: .module, comment: "Settings ▸ Advanced: no other app that changes display colors runs")
                        .foregroundStyle(.secondary)
                }
            } label: {
                RowLabel(title: value.info.title)
            }
            .settingRow(value)
            ForEach(apps, id: \.processID) { app in
                OtherAppRow(app: app, settings: services.settings)
            }
            if apps.contains(where: { $0.severity == .booster }) {
                Text("Overbright can’t run next to another brightness app on the color table. Use Compatibility mode on a display to run alongside it.",
                     bundle: .module, comment: "Settings ▸ Advanced: note under a running brightness app")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } header: {
            Text("Other apps", bundle: .module, comment: "Settings ▸ Advanced: section header")
        }
    }
}

/// One running app: icon, name, kind and, where it applies, Always continue.
private struct OtherAppRow: View {
    let app: ConflictingApp
    let settings: SettingsStore

    var body: some View {
        let identity = app.bundleID.map { AppIdentityResolver.shared.identity(of: $0) }
        HStack(spacing: Space.m) {
            AppIconView(icon: identity?.icon)
            VStack(alignment: .leading, spacing: Space.xxs) {
                Text(verbatim: app.displayName).lineLimit(1).truncationMode(.middle)
                Text(verbatim: app.severity.localizedKind() ?? "")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: Space.m)
            if OtherAppsSection.offersAlwaysContinue(app) {
                Toggle(isOn: alwaysContinue) {
                    Text("Always continue", bundle: .module,
                         comment: "Settings ▸ Advanced: switch that lets Overbright keep working next to this app")
                }
                .toggleStyle(.switch)
                .controlSize(.small)
            }
        }
        .padding(.leading, Space.xl)
        .accessibilityElement(children: .contain)
    }

    private var alwaysContinue: Binding<Bool> {
        let entry = app.entryID
        return Binding(get: { settings[AdvancedSettings.alwaysContinue].contains(entry) }, set: { on in
            if on { settings[AdvancedSettings.alwaysContinue].insert(entry) } else { settings[AdvancedSettings.alwaysContinue].remove(entry) }
        })
    }
}
