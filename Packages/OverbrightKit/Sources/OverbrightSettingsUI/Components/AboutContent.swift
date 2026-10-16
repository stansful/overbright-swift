// OverbrightSettingsUI/Components/AboutContent.swift — Settings ▸ About (DESIGN.md §7.9): the compiled icon as the system
// renders it (`NSApp.applicationIconImage`, so Tinted and Clear apply), "Overbright", version and build; Check for
// Updates with the result inline (only when configured); "Free and open source under the MIT License."; Acknowledgments…;
// the privacy statement; Show Welcome…; Help; a GitHub link (only when configured). Ported from Cranny's AboutPane (the
// owner's MIT code) without the tutorial. WP11's About pane shows it.
import AppKit
import Foundation
import OverbrightCore
import OverbrightDesign
import SwiftUI

/// The content of Settings ▸ About.
struct AboutContent: View {
    let services: OverbrightServices
    @State private var showsAcknowledgments = false

    /// The searchable rows of About.
    static func rows(services: OverbrightServices) -> [SettingsRowInfo] {
        var rows = [acknowledgments, privacy, welcome, help]
        if services.updates.isConfigured { rows.insert(updates, at: 0) }
        return rows
    }

    static var updates: SettingsRowInfo {
        SettingsRowInfo(.about, "updates", title: UpdatesSection.checkNow.title, keywords: UpdatesSection.checkNow.keywords)
    }
    static var acknowledgments: SettingsRowInfo {
        SettingsRowInfo(.about, "acknowledgments",
                        title: String(localized: "Acknowledgments…", bundle: .module,
                                      comment: "Settings ▸ About: button that lists the projects Overbright credits (title case)"),
                        keywords: [String(localized: "credits", bundle: .module, comment: "Settings search: keyword for Acknowledgments")])
    }
    static var privacy: SettingsRowInfo {
        SettingsRowInfo(.about, "privacy",
                        title: String(localized: "Privacy", bundle: .module, comment: "Settings ▸ About: section header of the privacy statement"),
                        keywords: [String(localized: "permissions", bundle: .module, comment: "Settings search: keyword for the privacy statement"),
                                   String(localized: "network", bundle: .module, comment: "Settings search: keyword for the privacy statement")])
    }
    static var welcome: SettingsRowInfo {
        SettingsRowInfo(.about, "welcome",
                        title: String(localized: "Show Welcome…", bundle: .module,
                                      comment: "Settings ▸ About: button that opens the Welcome window again (title case)"),
                        keywords: [String(localized: "setup", bundle: .module, comment: "Settings search: keyword for Show Welcome")])
    }
    static var help: SettingsRowInfo {
        SettingsRowInfo(.about, "help",
                        title: String(localized: "Help", bundle: .module, comment: "Settings ▸ About: button that opens Overbright’s Help window (title case)"))
    }

    /// "GitHub": the link to the source code and a search keyword of the update check (one key, one comment).
    static var gitHub: String {
        String(localized: "GitHub", bundle: .module,
               comment: "Settings ▸ About: the website’s name, as a link to the source code and as a search keyword for updates (keep the name)")
    }

    /// "version": a search keyword of About and of the update check (one key, one comment).
    static var versionKeyword: String {
        String(localized: "version", bundle: .module,
               comment: "Settings search: keyword that finds the About pane and the update check")
    }

    /// "owner/repo" from Info.plist (`OverbrightGitHubRepository`); empty or missing = no link and no update check.
    static var repository: URL? {
        guard let slug = Bundle.main.object(forInfoDictionaryKey: "OverbrightGitHubRepository") as? String,
              !slug.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        return URL(string: "https://github.com/\(slug.trimmingCharacters(in: .whitespaces))")
    }

    var body: some View {
        Section {
            AboutHeader()
        }
        if services.updates.isConfigured {
            Section {
                UpdateStatusRow(updates: services.updates, lastCheck: services.settings[UpdateSettings.lastCheck])
                    .searchTarget(Self.updates)
            } header: {
                Text("Updates", bundle: .module, comment: "Settings ▸ General and About: section header")
            }
        }
        Section {
            Text("Overbright collects nothing and needs no permissions. It connects to the internet only to check GitHub for updates, and only if you turn that on.",
                 bundle: .module, comment: "Settings ▸ About: the privacy statement")
                .fixedSize(horizontal: false, vertical: true)
                .searchTarget(Self.privacy)
        } header: {
            Text(verbatim: Self.privacy.title)
        }
        Section {
            HStack(spacing: Space.m) {
                Button { showsAcknowledgments = true } label: { Text(verbatim: Self.acknowledgments.title) }
                    .searchTarget(Self.acknowledgments)
                Button { services.app?.showWelcome() } label: { Text(verbatim: Self.welcome.title) }
                    .searchTarget(Self.welcome)
                Button { services.app?.showHelp(anchor: nil) } label: { Text(verbatim: Self.help.title) }
                    .searchTarget(Self.help)
                Spacer(minLength: 0)
                if let repository = Self.repository {
                    Link(destination: repository) { Text(verbatim: Self.gitHub) }
                }
            }
        }
        .sheet(isPresented: $showsAcknowledgments) { AcknowledgmentsSheet() }
    }
}

/// Icon, name, version and the license line.
private struct AboutHeader: View {
    var body: some View {
        let info = AppInfo.current()
        VStack(spacing: Space.s) {
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .interpolation(.high)
                .frame(width: SettingsMetrics.aboutIcon, height: SettingsMetrics.aboutIcon)
                .accessibilityHidden(true)
            Text(verbatim: "Overbright").font(.title.weight(.semibold))
            Text("Version \(info.version) (\(info.build))", bundle: .module,
                 comment: "Settings ▸ About: marketing version and build number")
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
            Text("Free and open source under the MIT License.", bundle: .module, comment: "Settings ▸ About: license line")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Space.m)
        .accessibilityElement(children: .combine)
    }
}

#Preview("About") {
    Form { AboutContent(services: .preview()) }
        .formStyle(.grouped)
        .frame(width: 650, height: 620)
}
