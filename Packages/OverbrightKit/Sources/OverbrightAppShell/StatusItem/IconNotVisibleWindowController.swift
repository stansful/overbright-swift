// OverbrightAppShell/StatusItem/IconNotVisibleWindowController.swift — "Overbright's icon isn't visible": a small
// window shown when the visibility check finds the icon hidden by macOS or the notch, at most once per app version
// (`OnboardingSettings.hiddenIconNoticeVersion`). DESIGN.md §4.4 (exact English; the shortcut clause only with a
// registered toggle shortcut; the last sentence on macOS 26 and later; [Open System Settings] [OK]), §16;
// ARCHITECTURE.md §7.6 (Cranny's alert-window recipe: a normal window that activates the app).
import AppKit
import Foundation
import OverbrightCore
import OverbrightDesign
import OverbrightPanelUI
import SwiftUI

/// Owns the icon-not-visible window.
final class IconNotVisibleWindowController {
    private let services: OverbrightServices
    private var window: NSWindow?

    /// A controller for the app's services. Constructing it opens nothing.
    init(services: OverbrightServices) { self.services = services }

    /// Whether the window is on screen.
    var isShown: Bool { window?.isVisible == true }

    /// Shows the window when `visibility` is `.notVisible` and it was not shown for this app version yet; returns
    /// whether it showed.
    @discardableResult
    func showIfNeeded(_ visibility: MenuBarIconVisibility, version: String = AppInfo.current().version) -> Bool {
        guard Self.shouldShow(visibility, shownForVersion: services.settings[OnboardingSettings.hiddenIconNoticeVersion],
                              version: version) else { return false }
        services.settings[OnboardingSettings.hiddenIconNoticeVersion] = version
        show()
        return true
    }

    /// At most once per app version, only for an icon macOS hides (never for one the user hid).
    static func shouldShow(_ visibility: MenuBarIconVisibility, shownForVersion: String?, version: String) -> Bool {
        visibility == .notVisible && shownForVersion != version
    }

    /// Shows the window (activating the app).
    func show() {
        let window = self.window ?? makeWindow()
        self.window = window
        window.center()
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }

    /// Closes the window.
    func close() { window?.orderOut(nil) }

    private func makeWindow() -> NSWindow {
        let view = IconNotVisibleView(message: Self.message(toggleKeys: services.shortcuts.displayString(.toggle),
                                                            namesMenuBarSetting: Self.hasAllowInMenuBar),
                                      openSettings: { [weak self] in
                                          if let url = SettingsLinks.systemMenuBar { NSWorkspace.shared.open(url) }
                                          self?.close()
                                      },
                                      dismiss: { [weak self] in self?.close() })
            .overbrightThemeRoot()
        let window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 420, height: 200),
                              styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.contentViewController = NSHostingController(rootView: view)
        window.title = ""
        window.isReleasedWhenClosed = false
        return window
    }

    /// "Allow in the Menu Bar" exists on macOS 26 and later.
    static var hasAllowInMenuBar: Bool {
        if #available(macOS 26, *) { return true }
        return false
    }

    /// The window's text: the shortcut clause only with `toggleKeys`, the Menu Bar sentence only when it applies.
    static func message(toggleKeys: String?, namesMenuBarSetting: Bool) -> String {
        let first: String
        if let toggleKeys {
            first = String(localized: "macOS may be hiding it, or the menu bar is too full to show it. You can still use \(toggleKeys), or open Overbright from Finder or Spotlight.",
                           table: "StatusMenu", bundle: .module,
                           comment: "Menu bar icon window: text; the placeholder is the live key caps of the on/off shortcut")
        } else {
            first = String(localized: "macOS may be hiding it, or the menu bar is too full to show it. You can still open Overbright from Finder or Spotlight.",
                           table: "StatusMenu", bundle: .module,
                           comment: "Menu bar icon window: text when the on/off shortcut is cleared")
        }
        guard namesMenuBarSetting else { return first }
        let second = String(localized: "To show it, turn on Overbright under Allow in the Menu Bar in Menu Bar settings.",
                            table: "StatusMenu", bundle: .module,
                            comment: "Menu bar icon window: second sentence on macOS 26 and later")
        return first + " " + second
    }
}

/// The window's content.
private struct IconNotVisibleView: View {
    let message: String
    let openSettings: () -> Void
    let dismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Space.l) {
            Text(verbatim: String(localized: "Overbright’s icon isn’t visible", table: "StatusMenu", bundle: .module,
                                  comment: "Menu bar icon window: title"))
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            Text(verbatim: message)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: Space.m) {
                Spacer()
                Button(action: openSettings) {
                    Text(verbatim: String(localized: "Open System Settings", table: "StatusMenu", bundle: .module,
                                          comment: "Menu bar icon window: opens Menu Bar settings in System Settings"))
                }
                Button(action: dismiss) {
                    Text(verbatim: String(localized: "OK", table: "StatusMenu", bundle: .module,
                                          comment: "Menu bar icon window: closes it"))
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(Space.xxl)
        .frame(width: 420)
    }
}
