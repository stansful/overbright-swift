// OverbrightSettingsUI/Panes/PausedAppsEditor.swift — Automations ▸ Pause for these apps (DESIGN.md §7.5; D10): the
// list's switch (`automations.pauseForListedApps`; turning it off keeps every rule) with the + menu (VoiceOver and its
// help tag: "Add App"; WP14 C-SETTINGS-11), then one row
// per app with its icon, Finder's name, its mode (While in front · While playing (beta)) and a remove button. Ported
// from Cranny's excluded-apps editor (the owner's MIT code): apps come from the running apps, an Open panel in
// /Applications (the user's own choice, so it raises no prompt) or the suggestions; rows name their app with Core's
// `AppIdentityResolver` and never show a bundle identifier, and an app that is no longer installed reads "App not
// installed" and can still be removed. Reset to Default restores the switch and the twelve default apps.
import AppKit
import OverbrightCore
import OverbrightDesign
import SwiftUI
import UniformTypeIdentifiers

/// The per-app pause list.
struct PausedAppsEditor: View {
    let services: OverbrightServices
    let value: RowValue

    var body: some View {
        let settings = services.settings
        let rules = settings[AutomationSettings.pausedApps]
        LabeledContent {
            HStack(spacing: Space.m) {
                AddPausedAppMenu(rules: rules) { ids in
                    settings[AutomationSettings.pausedApps] = PausedAppsList.adding(ids, to: settings[AutomationSettings.pausedApps])
                }
                Toggle(isOn: settings.binding(AutomationSettings.pauseForListedApps)) { Text(verbatim: value.info.title) }
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
            }
        } label: {
            RowLabel(title: value.info.title,
                     footnote: String(localized: "Only the display that shows the app pauses.", bundle: .module,
                                      comment: "Settings ▸ Automations: footnote of Pause for these apps"))
        }
        .settingRow(value)
        .onAppear { AppIdentityResolver.shared.refresh() }      // an app may have been installed or removed meanwhile
        ForEach(rules, id: \.bundleID) { rule in
            PausedAppRow(rule: rule, identity: AppIdentityResolver.shared.identity(of: rule.bundleID)) { mode in
                settings[AutomationSettings.pausedApps] = PausedAppsList.setting(mode, for: rule.bundleID,
                                                                                 in: settings[AutomationSettings.pausedApps])
            } remove: {
                settings[AutomationSettings.pausedApps] = PausedAppsList.removing(rule.bundleID,
                                                                                  from: settings[AutomationSettings.pausedApps])
            }
        }
        Text("“While playing” pauses while the app keeps your Mac awake for video.", bundle: .module,
             comment: "Settings ▸ Automations: note under the app list about the While playing mode")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// One app of the list: icon, Finder's name, mode, remove.
private struct PausedAppRow: View {
    let rule: PausedAppRule
    let identity: AppIdentity
    let setMode: @MainActor (PausedAppRule.Mode) -> Void
    let remove: @MainActor () -> Void

    var body: some View {
        let modes: [PausedAppRule.Mode] = [.whileFrontmost, .whilePlaying]
        HStack(spacing: Space.m) {
            AppIconView(icon: identity.icon)
            if let name = identity.name {
                Text(verbatim: name).lineLimit(1).truncationMode(.middle)
            } else if identity.isNotInstalled {
                Text(verbatim: PausedAppsEditor.notInstalled)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: Space.m)
            Picker(selection: Binding(get: { rule.mode }, set: setMode)) {
                ForEach(modes, id: \.self) { mode in Text(verbatim: mode.localizedName()).tag(mode) }
            } label: {
                Text(verbatim: PausedAppsEditor.spokenName(identity))   // VoiceOver: the app's name, then its mode
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .fixedSize()
            Button(action: remove) {
                Image(symbol: .xmark).foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(Text(verbatim: PausedAppsEditor.removeLabel(identity)))
        }
        .padding(.leading, Space.xl)
        .accessibilityElement(children: .contain)
    }
}

extension PausedAppsEditor {
    /// "App not installed": the row of an app on the list that is no longer installed.
    static var notInstalled: String {
        String(localized: "App not installed", bundle: .module,
               comment: "Settings ▸ Automations: row of an app on the pause list that is no longer installed")
    }

    /// What VoiceOver calls a row's app (the label of its mode pop-up): Finder's name, "App not installed", or, for the
    /// moment its lookup runs, the bundle identifier (spoken only, never shown), so the pop-up is never unnamed.
    static func spokenName(_ identity: AppIdentity) -> String {
        identity.name ?? (identity.isNotInstalled ? notInstalled : identity.bundleID)
    }

    /// The remove button's VoiceOver label, the app's name bidi-isolated inside the sentence (ARCHITECTURE.md §8.8).
    static func removeLabel(_ identity: AppIdentity) -> String {
        guard let name = identity.name else {
            return String(localized: "Remove app", bundle: .module,
                          comment: "VoiceOver: remove button of an app on the pause list that is not installed or not looked up yet")
        }
        return String(localized: "Remove \(name.overbrightIsolated)", bundle: .module,
                      comment: "VoiceOver: remove button of an app on the pause list; the argument is the app’s name")
    }
}

/// The + menu ("Add App" to VoiceOver and in its help tag): the running apps, Choose…, and the suggested video apps
/// that are installed.
struct AddPausedAppMenu: View {
    let rules: [PausedAppRule]
    let add: @MainActor ([String]) -> Void

    /// The menu's glyph (DESIGN.md §7.5: a **+** menu, as wide in every language).
    static let symbol = OverbrightSymbol.plus

    /// "Add App": the menu's VoiceOver label and help tag.
    static var title: String {
        String(localized: "Add App", bundle: .module,
               comment: "Settings ▸ Automations: VoiceOver label and help tag of the + menu that adds an app to the pause list (title case)")
    }

    var body: some View {
        Menu {
            let running = Self.runningApps(excluding: rules)
            ForEach(running, id: \.bundleID) { app in
                Button { add([app.bundleID]) } label: { Text(verbatim: app.name) }
            }
            if !running.isEmpty { Divider() }
            Button { chooseApps() } label: {
                Text("Choose…", bundle: .module,
                     comment: "Settings ▸ Automations ▸ Add App: opens a file panel in Applications (title case)")
            }
            let suggestions = PausedAppsList.suggestions(for: rules) { id in
                AppIdentityResolver.shared.identity(of: id).isInstalled     // an installed app always has its name
            }
            if !suggestions.isEmpty {
                Menu {
                    ForEach(suggestions, id: \.bundleID) { rule in
                        Button { add([rule.bundleID]) } label: {
                            Text(verbatim: AppIdentityResolver.shared.identity(of: rule.bundleID).name ?? "")
                        }
                    }
                } label: {
                    Text("Suggested", bundle: .module,
                         comment: "Settings ▸ Automations ▸ Add App: submenu of installed video apps worth adding (title case)")
                }
            }
        } label: {
            Label { Text(verbatim: Self.title) } icon: { Image(symbol: Self.symbol) }
                .labelStyle(.iconOnly)
        }
        .help(Self.title)
        .fixedSize()
    }

    /// Regular running apps (not Overbright, not on the list), sorted by name.
    private static func runningApps(excluding rules: [PausedAppRule]) -> [(bundleID: String, name: String)] {
        let own = Bundle.main.bundleIdentifier
        return NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .compactMap { app in app.bundleIdentifier.flatMap { id in app.localizedName.map { (id, $0) } } }   // named only
            .filter { $0.0 != own && !PausedAppsList.contains($0.0, in: rules) }
            .sorted { $0.1.localizedStandardCompare($1.1) == .orderedAscending }
            .map { (bundleID: $0.0, name: $0.1) }
    }

    private func chooseApps() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.directoryURL = URL(fileURLWithPath: "/Applications", isDirectory: true)
        panel.prompt = String(localized: "Add", bundle: .module,
                              comment: "Settings ▸ Automations ▸ Add App: confirm button of the file panel (title case)")
        panel.begin { response in
            guard response == .OK else { return }
            let ids = panel.urls.compactMap { Bundle(url: $0)?.bundleIdentifier }
            MainActor.assumeIsolated { add(ids) }                     // NSOpenPanel completes on the main thread
        }
    }
}

#Preview("Paused apps") {
    let services = OverbrightServices.preview()
    return Form { PausedAppsEditor(services: services, value: AutomationsPane.pausedAppsValue(services)) }
        .formStyle(.grouped)
        .environment(SettingsNavigator(target: "automations"))
        .frame(width: 600, height: 700)
}
