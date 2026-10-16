// OverbrightAppShell/App/LaunchUI.swift — what a launch or a reopen shows. ARCHITECTURE.md §7.6 ("Launch UI"),
// DESIGN.md §4.4; D13. Shared shell file (contract owner). The decision is pure (`coldLaunchShowsUI`,
// `loginLaunchIsSilent`); the login detection reads the open-application Apple event first, then the session's
// login-done flag and the system uptime (fallback, [HW: H-L2]).
import AppKit
import CoreGraphics
import CoreServices
import Foundation
import OverbrightCore

/// The surface a launch shows.
enum LaunchUI {
    /// What to show.
    enum Surface: Equatable {
        /// A login launch, or a launch by an intent or a URL.
        case nothing
        /// Welcome is not finished yet.
        case welcome
        /// The panel under the icon.
        case panel
        /// The icon is hidden or not visible: Settings ▸ General.
        case settingsGeneral
    }

    /// The surface of a launch. Login launches and launches by an intent or a URL show nothing; every other launch
    /// shows Welcome until it is finished, else the panel under a visible icon, else Settings ▸ General.
    static func surface(isLoginLaunch: Bool, isBackgroundLaunch: Bool, welcomeFinished: Bool,
                        iconVisibility: MenuBarIconVisibility) -> Surface {
        if isLoginLaunch || isBackgroundLaunch { return .nothing }
        return reopenSurface(welcomeFinished: welcomeFinished, iconVisibility: iconVisibility)
    }

    /// The surface of a reopen while running (Finder, Spotlight, `open`): always something.
    static func reopenSurface(welcomeFinished: Bool, iconVisibility: MenuBarIconVisibility) -> Surface {
        if !welcomeFinished { return .welcome }
        return iconVisibility == .visible ? .panel : .settingsGeneral
    }

    /// Whether this launch is a login launch: the open-application event carries `keyAELaunchedAsLogInItem`; else the
    /// session has not finished logging in, or the system has been up for less than `recentBoot`.
    static func isLoginLaunch(launchedAsLoginItem: Bool, sessionLoginDone: Bool?, uptime: TimeInterval) -> Bool {
        if launchedAsLoginItem { return true }
        if sessionLoginDone == false { return true }
        return uptime < recentBoot
    }

    /// The uptime under which a launch counts as part of logging in.
    static let recentBoot: TimeInterval = 120

    /// Reads the current open-application event, the session dictionary and the uptime (call it in
    /// `applicationWillFinishLaunching`, while the event is current). Read-only.
    static func currentLaunchIsLogin() -> Bool {
        let event = NSAppleEventManager.shared().currentAppleEvent
        let launchedAsLoginItem = event?.eventID == kAEOpenApplication
            && event?.paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue == keyAELaunchedAsLogInItem
        let session = CGSessionCopyCurrentDictionary() as? [String: Any]
        let loginDone = session?[kCGSessionLoginDoneKey as String] as? Bool
        return isLoginLaunch(launchedAsLoginItem: launchedAsLoginItem, sessionLoginDone: loginDone,
                             uptime: ProcessInfo.processInfo.systemUptime)
    }
}
