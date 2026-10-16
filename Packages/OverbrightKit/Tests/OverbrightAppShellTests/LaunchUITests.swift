// OverbrightAppShellTests/LaunchUITests.swift — what a launch and a reopen show (ARCHITECTURE.md §7.6 "Launch UI",
// DESIGN.md §4.4, D13): every launch that is not a login launch shows UI; a login launch shows nothing.
import OverbrightCore
import Testing
@testable import OverbrightAppShell

@Suite struct LaunchUITests {
    /// A cold launch shows Welcome until it is finished, else the panel under a visible icon, else Settings ▸ General.
    @Test func coldLaunchShowsUI() {
        func surface(_ welcomeFinished: Bool, _ icon: MenuBarIconVisibility) -> LaunchUI.Surface {
            LaunchUI.surface(isLoginLaunch: false, isBackgroundLaunch: false, welcomeFinished: welcomeFinished,
                             iconVisibility: icon)
        }
        #expect(surface(false, .visible) == .welcome)
        #expect(surface(false, .hiddenByUser) == .welcome)
        #expect(surface(true, .visible) == .panel)
        #expect(surface(true, .hiddenByUser) == .settingsGeneral)
        #expect(surface(true, .notVisible) == .settingsGeneral)
    }

    /// A login launch (and a launch by an intent or a URL) shows nothing, whatever else holds.
    @Test func loginLaunchIsSilent() {
        for welcomeFinished in [false, true] {
            for icon in [MenuBarIconVisibility.visible, .hiddenByUser, .notVisible] {
                #expect(LaunchUI.surface(isLoginLaunch: true, isBackgroundLaunch: false, welcomeFinished: welcomeFinished,
                                         iconVisibility: icon) == .nothing)
                #expect(LaunchUI.surface(isLoginLaunch: false, isBackgroundLaunch: true,
                                         welcomeFinished: welcomeFinished, iconVisibility: icon) == .nothing)
            }
        }
    }

    /// Login detection: the open-application event's login-item flag first, then the session's login-done flag and
    /// the uptime (fallback, [HW: H-L2]).
    @Test func loginLaunchDetection() {
        #expect(LaunchUI.isLoginLaunch(launchedAsLoginItem: true, sessionLoginDone: true, uptime: 86_400))
        #expect(LaunchUI.isLoginLaunch(launchedAsLoginItem: false, sessionLoginDone: false, uptime: 86_400))
        #expect(LaunchUI.isLoginLaunch(launchedAsLoginItem: false, sessionLoginDone: nil, uptime: 30))
        #expect(!LaunchUI.isLoginLaunch(launchedAsLoginItem: false, sessionLoginDone: true, uptime: 86_400))
        #expect(!LaunchUI.isLoginLaunch(launchedAsLoginItem: false, sessionLoginDone: nil, uptime: 600))
    }

    /// A reopen while running always shows something, so a hidden icon never locks anyone out.
    @Test func reopenAlwaysShowsSomething() {
        for welcomeFinished in [false, true] {
            for icon in [MenuBarIconVisibility.visible, .hiddenByUser, .notVisible] {
                #expect(LaunchUI.reopenSurface(welcomeFinished: welcomeFinished, iconVisibility: icon) != .nothing)
            }
        }
    }
}
