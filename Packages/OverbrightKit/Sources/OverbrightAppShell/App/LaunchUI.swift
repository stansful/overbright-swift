// OverbrightAppShell/App/LaunchUI.swift — what a launch or a reopen shows. ARCHITECTURE.md §7.6 ("Launch UI"),
// DESIGN.md §4.4; D13. Shared shell file. The decision is pure (`coldLaunchShowsUI`, `loginLaunchIsSilent`,
// `ReopenTests`).
//
// A login launch is read from the open-application Apple event (`keyAELaunchedAsLogInItem`), else from the session's
// login-done flag and the system uptime (fallback, [HW: H-L2]). The event is read first thing in
// `applicationDidFinishLaunching`: in `applicationWillFinishLaunching` AppKit has not dispatched it yet and the current
// event is nil [VERIFIED on macOS 27.0.1 with a probe app launched through LaunchServices, WP13 review]. The app logs
// and journals the event's class and ID with the result (`Reading`). A launch by a URL or an intent is a background
// launch: the first Apple event is a get-URL event, or a URL open or an intent request (`IntentRouter.requestCount`,
// never the launch-time Focus read) arrives before the launch UI decides. The decision waits for the status item to be
// placed (at most 1 s) and at least `backgroundLaunchGrace`, so an intent that launched the app is seen first
// [HW: H-AI-1 checks when Shortcuts' request arrives].
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

    /// What started this process, read from the first Apple event.
    enum Opening: Equatable {
        /// The user opened it (Finder, Spotlight, the Dock, `open`, a relaunch).
        case user
        /// macOS opened it at login.
        case login
        /// It was opened to handle an `overbright://` URL.
        case url
    }

    /// The least time the launch UI waits before it decides, so a request that launched the app arrives first.
    static let backgroundLaunchGrace: Duration = .milliseconds(500)

    /// The surface of a launch. Login launches and launches by an intent or a URL show nothing; every other launch
    /// shows Welcome until it is finished, else the panel under a visible icon, else Settings ▸ General.
    static func surface(isLoginLaunch: Bool, isBackgroundLaunch: Bool, welcomeFinished: Bool,
                        iconVisibility: MenuBarIconVisibility) -> Surface {
        if isLoginLaunch || isBackgroundLaunch { return .nothing }
        return reopenSurface(welcomeFinished: welcomeFinished, iconVisibility: iconVisibility)
    }

    /// The surface of a reopen while running (Finder, Spotlight, `open`, the Dock icon): always something.
    static func reopenSurface(welcomeFinished: Bool, iconVisibility: MenuBarIconVisibility) -> Surface {
        if !welcomeFinished { return .welcome }
        return iconVisibility == .visible ? .panel : .settingsGeneral
    }

    /// A launch made for a URL or an intent: the first event asked for a URL, or a URL or an intent request arrived
    /// before the launch UI decided.
    static func isBackgroundLaunch(opening: Opening, openedURLDuringLaunch: Bool, intentRequests: Int) -> Bool {
        opening == .url || openedURLDuringLaunch || intentRequests > 0
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

    /// What an Apple event of `eventClass` and `eventID` opened the app for (a missing event counts as the user's).
    static func opening(eventClass: AEEventClass?, eventID: AEEventID?, isLogin: Bool) -> Opening {
        if eventClass == AEEventClass(kInternetEventClass) && eventID == AEEventID(kAEGetURL) { return .url }
        return isLogin ? .login : .user
    }

    /// What a launch read: the opening and what it was decided from (logged and journaled for [HW: H-L2]).
    struct Reading: Equatable {
        /// What opened the app.
        var opening: Opening
        /// The current Apple event's class and ID (nil: no current event).
        var eventClass: AEEventClass?
        var eventID: AEEventID?
        /// The open-application event carried `keyAELaunchedAsLogInItem`.
        var launchedAsLoginItem: Bool
        /// `kCGSessionLoginDoneKey` (nil: missing).
        var sessionLoginDone: Bool?
        /// The system uptime, in seconds.
        var uptime: TimeInterval

        /// "login (event aevt/oapp, login-item flag true, login done true, uptime 42 s)".
        var logDescription: String {
            let loginDone = sessionLoginDone.map(String.init) ?? "-"
            return "\(opening) (event \(LaunchUI.code(eventClass))/\(LaunchUI.code(eventID)), login-item flag "
                + "\(launchedAsLoginItem), login done \(loginDone), uptime \(Int(uptime)) s)"
        }

        /// The journal's numbers: the event's class and ID as their 32-bit codes (absent without an event), the flag,
        /// the login-done flag (absent when missing) and the uptime.
        var journalValues: [String: Double] {
            var values = ["loginItemFlag": launchedAsLoginItem ? 1.0 : 0, "uptime": uptime.rounded()]
            if let eventClass { values["eventClass"] = Double(eventClass) }
            if let eventID { values["eventID"] = Double(eventID) }
            if let sessionLoginDone { values["sessionLoginDone"] = sessionLoginDone ? 1 : 0 }
            return values
        }
    }

    /// What `event` (the current Apple event, read first thing in `applicationDidFinishLaunching`), the session
    /// dictionary and the uptime say opened the app.
    static func reading(event: NSAppleEventDescriptor?, session: [String: Any]?, uptime: TimeInterval) -> Reading {
        let launchedAsLoginItem = event?.eventClass == AEEventClass(kCoreEventClass)
            && event?.eventID == AEEventID(kAEOpenApplication)
            && event?.paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue == keyAELaunchedAsLogInItem
        let loginDone = session?[kCGSessionLoginDoneKey as String] as? Bool
        let isLogin = isLoginLaunch(launchedAsLoginItem: launchedAsLoginItem, sessionLoginDone: loginDone,
                                    uptime: uptime)
        return Reading(opening: opening(eventClass: event?.eventClass, eventID: event?.eventID, isLogin: isLogin),
                       eventClass: event?.eventClass, eventID: event?.eventID, launchedAsLoginItem: launchedAsLoginItem,
                       sessionLoginDone: loginDone, uptime: uptime)
    }

    /// The reading of this launch from `event`, the current session dictionary and the system uptime. Read-only.
    static func currentReading(event: NSAppleEventDescriptor?) -> Reading {
        reading(event: event, session: CGSessionCopyCurrentDictionary() as? [String: Any],
                uptime: ProcessInfo.processInfo.systemUptime)
    }

    /// A four-character code as text ("aevt"); hexadecimal when it is not printable, "-" when missing.
    static func code(_ value: UInt32?) -> String {
        guard let value else { return "-" }
        let bytes = [24, 16, 8, 0].map { UInt8(truncatingIfNeeded: value >> $0) }
        guard bytes.allSatisfy({ (0x20...0x7E).contains($0) }) else { return "0x" + String(value, radix: 16) }
        return String(decoding: bytes, as: UTF8.self)
    }
}
