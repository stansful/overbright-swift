// OverbrightAppShellTests/StatusItemVisibilityTests.swift — is the icon really on screen (ARCHITECTURE.md §7.6,
// DESIGN.md §4.4): its window exists, is visible, is not occluded, lies on a screen and, on a notched screen, beside
// the notch; hidden by the user is its own state; the icon-not-visible window shows at most once per app version and
// never for an icon the user hid; its text uses the live toggle shortcut or leaves it out, and names Allow in the Menu
// Bar only where it exists.
import CoreGraphics
import OverbrightCore
import Testing
@testable import OverbrightAppShell

@MainActor @Suite struct IconVisibilityTests {
    /// A 14" MacBook Pro screen with a notch: the menu bar areas left and right of it.
    private let notched = IconVisibilityCheck.Screen(frame: CGRect(x: 0, y: 0, width: 1512, height: 982),
                                                     auxiliaryTopLeft: CGRect(x: 0, y: 950, width: 662, height: 32),
                                                     auxiliaryTopRight: CGRect(x: 850, y: 950, width: 662, height: 32))
    private let external = IconVisibilityCheck.Screen(frame: CGRect(x: 1512, y: 0, width: 2560, height: 1440))

    private func window(_ frame: CGRect, visible: Bool = true, unoccluded: Bool = true) -> IconVisibilityCheck.Window {
        IconVisibilityCheck.Window(isVisible: visible, isUnoccluded: unoccluded, frame: frame)
    }

    @Test func anIconBesideTheNotchIsVisible() {
        let right = window(CGRect(x: 1300, y: 950, width: 38, height: 32))
        #expect(IconVisibilityCheck.evaluate(window: right, screens: [notched], showsIcon: true) == .visible)
        let onExternal = window(CGRect(x: 3800, y: 1408, width: 38, height: 32))
        #expect(IconVisibilityCheck.evaluate(window: onExternal, screens: [notched, external], showsIcon: true) == .visible)
    }

    @Test func anIconBehindTheNotchIsNotVisible() {
        let behind = window(CGRect(x: 700, y: 950, width: 38, height: 32))
        #expect(IconVisibilityCheck.evaluate(window: behind, screens: [notched], showsIcon: true) == .notVisible)
        let straddling = window(CGRect(x: 840, y: 950, width: 38, height: 32))
        #expect(IconVisibilityCheck.evaluate(window: straddling, screens: [notched], showsIcon: true) == .notVisible)
    }

    @Test func aMissingHiddenOccludedOrOffScreenIconIsNotVisible() {
        let frame = CGRect(x: 1300, y: 950, width: 38, height: 32)
        #expect(IconVisibilityCheck.evaluate(window: nil, screens: [notched], showsIcon: true) == .notVisible)
        #expect(IconVisibilityCheck.evaluate(window: window(frame, visible: false), screens: [notched], showsIcon: true)
            == .notVisible)
        #expect(IconVisibilityCheck.evaluate(window: window(frame, unoccluded: false), screens: [notched], showsIcon: true)
            == .notVisible)
        // The frames MenuBarAgent reports before it places the item (macOS 27.0.1).
        for unplaced in [CGRect(x: 0, y: -33, width: 38, height: 33), CGRect(x: 0, y: 1440, width: 38, height: 33),
                         CGRect(x: 0, y: 0, width: 38, height: 0)] {
            #expect(IconVisibilityCheck.evaluate(window: window(unplaced), screens: [external], showsIcon: true)
                == .notVisible)
        }
    }

    @Test func anIconTheUserHidIsHiddenByTheUser() {
        let frame = CGRect(x: 1300, y: 950, width: 38, height: 32)
        #expect(IconVisibilityCheck.evaluate(window: window(frame), screens: [notched], showsIcon: false) == .hiddenByUser)
        #expect(IconVisibilityCheck.evaluate(window: nil, screens: [], showsIcon: false) == .hiddenByUser)
    }

    @Test func theWindowShowsOncePerVersionAndNeverForAHiddenIcon() {
        #expect(IconNotVisibleWindowController.shouldShow(.notVisible, shownForVersion: nil, version: "0.1.0"))
        #expect(!IconNotVisibleWindowController.shouldShow(.notVisible, shownForVersion: "0.1.0", version: "0.1.0"))
        #expect(IconNotVisibleWindowController.shouldShow(.notVisible, shownForVersion: "0.1.0", version: "0.2.0"))
        #expect(!IconNotVisibleWindowController.shouldShow(.hiddenByUser, shownForVersion: nil, version: "0.1.0"))
        #expect(!IconNotVisibleWindowController.shouldShow(.visible, shownForVersion: nil, version: "0.1.0"))
    }

    @Test func theWindowRemembersTheVersionItShowedFor() {
        let services = OverbrightServices.preview()
        let controller = IconNotVisibleWindowController(services: services)
        #expect(!controller.showIfNeeded(.visible, version: "0.1.0"))
        #expect(services.settings[OnboardingSettings.hiddenIconNoticeVersion] == nil)
        services.settings[OnboardingSettings.hiddenIconNoticeVersion] = "0.1.0"
        #expect(!controller.showIfNeeded(.notVisible, version: "0.1.0"))      // already shown for this version
        #expect(!controller.isShown)
    }

    @Test func theTextUsesTheLiveShortcutOrLeavesItOut() {
        let with = IconNotVisibleWindowController.message(toggleKeys: "⌃⌥⌘B", namesMenuBarSetting: true)
        let without = IconNotVisibleWindowController.message(toggleKeys: nil, namesMenuBarSetting: true)
        let old = IconNotVisibleWindowController.message(toggleKeys: "⌃⌥⌘B", namesMenuBarSetting: false)
        #expect(with.contains("⌃⌥⌘B") && !without.contains("⌃⌥⌘"))
        #expect(with.contains("Allow in the Menu Bar") && !old.contains("Allow in the Menu Bar"))
        #expect(without.hasSuffix("Menu Bar settings."))
    }
}
