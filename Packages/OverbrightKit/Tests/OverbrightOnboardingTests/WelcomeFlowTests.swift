// OverbrightOnboardingTests/WelcomeFlowTests.swift — what the five steps show and do (DESIGN.md §8, §12.1, §12.4;
// ARCHITECTURE.md §10.14): the before/after card at Bright room of a display that can boost (or the illustration),
// its `OwnEDRSurfaces` registration, the per-display rows with their verdicts, fixes and switches (re-evaluated when the
// displays change), the OLED notice, the shortcut rows of step 4, Turn On Overbright only when a display would boost,
// and that walking Welcome never asks the engine for anything before Turn On Overbright (nothing writes a table, and
// nothing turns on). Against the Core fakes; nothing is ordered in.
import AppKit
import Foundation
import Observation
import OverbrightCore
import OverbrightDesign
import OverbrightPanelUI
import OverbrightTestSupport
import SwiftUI
import Testing
@testable import OverbrightOnboarding

private typealias Keys = DisplayFixture.Keys

/// A display directory that is not the Core fake (what the real app wires).
@MainActor @Observable private final class StaticDirectory: DisplayDirectory {
    var displays: [DisplayFacts] = []
    var generation = 0
    func facts(for key: DisplayKey) -> DisplayFacts? { displays.first { $0.ref.key == key } }
}

@MainActor @Suite struct WelcomeFlowTests {
    // MARK: Walking the steps

    /// ↩ through every step: nothing reaches the engine, the settings, the login item or `OwnEDRSurfaces` (the card is
    /// a stand-in in a simulated run) until Done; Done alone applies the launch behaviour and never turns anything on.
    @Test func walkingWelcomeChangesNothingBeforeDone() throws {
        let harness = try WelcomeHarness(.russianNames)
        let before = harness.services.settings[DisplaySettings.perDisplay]
        var visited = [harness.session.step]
        while !harness.session.isLastStep {
            harness.session.goForward()
            visited.append(harness.session.step)
        }
        #expect(visited == [.hello, .displays, .defaults, .findIt, .done])
        #expect(harness.boost.calls.isEmpty && harness.app.calls.isEmpty)
        #expect(harness.services.settings[DisplaySettings.perDisplay] == before)
        #expect(harness.services.ownEDRSurfaces.displays.isEmpty)
        harness.session.finish()
        #expect(harness.outcomes.values == [.done])
        #expect(harness.boost.calls.isEmpty && !harness.boost.status.isOn)
        #expect(harness.app.calls == ["setLaunchBehavior(launchOnly)"])
    }

    /// Turn On Overbright is the one engine call Welcome makes, after the choices applied.
    @Test func turnOnOverbrightIsTheOnlyEngineCall() throws {
        let harness = try WelcomeHarness(step: .done)
        harness.session.choices.launchBehavior = .launchAndEnable
        harness.session.finish(turningOn: true)
        #expect(harness.app.calls == ["setLaunchBehavior(launchAndEnable)"])
        #expect(harness.boost.calls == ["setOn(true,welcome)"] && harness.boost.status.isOn)
    }

    /// The steps and their model only read the engine (`boost.status`) and never touch a display: no table, gamma or
    /// EDR API, no engine request (Turn On Overbright is the chrome's one call, `WelcomeSession.finish`). The card's EDR
    /// content is Design's, in this window only (ARCHITECTURE.md §2.1 rule 6, D24).
    @Test func theStepsOnlyReadTheEngine() throws {
        let root = URL(filePath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().appending(path: "Sources/OverbrightOnboarding")
        let requests = "setOn|toggle|setLevel|setExtraBrightness|setDimLight|step|toggleDim|returnToStandard|pause|resume"
        let forbidden = [#"\bboost\.(?!status\b)"#, #"\.("# + requests + #"|retry)\(.*source:"#,
                         "CGSet" + "DisplayTransfer|CGDisplay" + "RestoreColorSyncSettings|GammaPort|TableWriter",
                         "preferred" + "DynamicRange|wantsExtended" + "DynamicRangeContent|contents" + "Headroom|"
                            + "AVPlayer" + "Layer|CAMetal" + "Layer"]
        var scanned = 0
        for folder in ["Steps", "Model"] {
            let files = try FileManager.default.contentsOfDirectory(at: root.appending(path: folder),
                                                                    includingPropertiesForKeys: nil)
            for file in files where file.pathExtension == "swift" {
                scanned += 1
                let code = try String(contentsOf: file, encoding: .utf8).split(separator: "\n")
                    .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
                for (number, line) in code.enumerated() {
                    for pattern in forbidden {
                        #expect(line.range(of: pattern, options: .regularExpression) == nil,
                                "\(file.lastPathComponent): \(line.trimmingCharacters(in: .whitespaces)) [\(number)]")
                    }
                }
            }
        }
        #expect(scanned >= 15)
    }

    // MARK: Step 1 · the card

    /// Bright room of the built-in in Safe: ×1.29 (ARCHITECTURE.md §5.3: top ×1.667, half way in stops).
    @Test func theCardShowsBrightRoomOfADisplayThatCanBoost() throws {
        let harness = try WelcomeHarness()
        let card = WelcomeCard.make(rows: harness.rows, windowDisplay: nil)
        guard case let .preview(display, gain) = card else { Issue.record("no card: \(card)"); return }
        #expect(display == Keys.builtIn)
        #expect(abs(gain - (1000.0 / 600).squareRoot()) < 0.001 && abs(gain - 1.291) < 0.001)
    }

    /// The window's display wins when it can boost; a display that cannot (Sidecar) falls back to one that can.
    @Test func theCardFollowsTheWindowsDisplay() throws {
        let both = try WelcomeHarness(.russianNames)
        guard case let .preview(display, gain) = WelcomeCard.make(rows: both.rows, windowDisplay: Keys.mpg322ux) else {
            Issue.record("no card"); return
        }
        #expect(display == Keys.mpg322ux && abs(gain - 1.3.squareRoot()) < 0.001)          // OLED Safe ×1.3
        let sidecar = try WelcomeHarness(.sidecar)
        #expect(WelcomeCard.make(rows: sidecar.rows, windowDisplay: Keys.sidecar)
                == .preview(display: Keys.builtIn, gain: WelcomeCard.gain(top: 1000.0 / 600)))
    }

    /// Without a display that can show extra brightness: the illustration and "The next step shows why"; while the
    /// engine has not read the displays yet: the illustration alone.
    @Test func withoutACapableDisplayTheStageShowsTheIllustration() throws {
        #expect(WelcomeCard.make(rows: try WelcomeHarness(.lcdOnly).rows, windowDisplay: nil) == .noneCapable)
        #expect(WelcomeCard.make(rows: try WelcomeHarness(.mpg322uxHDROff).rows, windowDisplay: nil) == .noneCapable)
        #expect(WelcomeCard.make(rows: try WelcomeHarness(.studioDisplayXDR).rows, windowDisplay: nil) == .noneCapable)
        let unread = OverbrightServices.preview()                                 // the preview engine has no verdicts
        #expect(WelcomeCard.make(rows: WelcomeDisplayRow.rows(in: unread), windowDisplay: nil) == .checking)
        #expect(HelloLower(copy: .localized(in: englishBundle), card: .noneCapable).caption
                == "None of your displays has extra range right now. The next step shows why.")
        #expect(HelloLower(copy: .localized(in: englishBundle), card: .checking).caption == nil)
        #expect(HelloLower(copy: .localized(in: englishBundle), card: .preview(display: Keys.builtIn, gain: 1.29)).caption
                == "Only this card is brighter. It’s a preview: the real result depends on your display.")
    }

    /// The card registers with `OwnEDRSurfaces` on the window's display only while it shows EDR content for real and
    /// the window can be seen; the hold moves with the window and ends when released.
    @Test func theCardHoldsItsDisplayOnlyWhileItShowsExtraRange() {
        let card = WelcomeCard.preview(display: Keys.builtIn, gain: 1.29)
        #expect(card.heldDisplay(windowDisplay: Keys.mpg322ux, isWindowVisible: true, simulated: false) == Keys.mpg322ux)
        #expect(card.heldDisplay(windowDisplay: Keys.builtIn, isWindowVisible: false, simulated: false) == nil)
        #expect(card.heldDisplay(windowDisplay: Keys.builtIn, isWindowVisible: true, simulated: true) == nil)
        #expect(WelcomeCard.noneCapable.heldDisplay(windowDisplay: Keys.builtIn, isWindowVisible: true,
                                                    simulated: false) == nil)

        let surfaces = OwnEDRSurfaces()
        let hold = EDRCardHold(surfaces: surfaces)
        hold.hold(Keys.builtIn)
        hold.hold(Keys.builtIn)                                                   // once per display
        #expect(surfaces.displays == [Keys.builtIn: 1])
        hold.hold(Keys.mpg322ux)                                                  // the window moved
        #expect(surfaces.displays == [Keys.mpg322ux: 1] && hold.display == Keys.mpg322ux)
        hold.release()
        #expect(surfaces.displays.isEmpty && hold.display == nil)
    }

    /// Previews, tests and `--qa-simulate` draw the SDR stand-in; only real display ports get EDR content (D24).
    @Test func onlyRealDisplayPortsGetEDRContent() {
        #expect(WelcomeCard.simulates(OverbrightServices.preview(), arguments: LaunchArguments(["Overbright"])))
        let base = OverbrightServices.preview()
        let real = OverbrightServices(settings: base.settings, paths: base.paths, machine: base.machine, time: base.time,
                                      journal: base.journal, announcer: base.announcer,
                                      ownEDRSurfaces: base.ownEDRSurfaces, displays: StaticDirectory(),
                                      signals: base.signals, boost: base.boost, fillLight: base.fillLight,
                                      shortcuts: base.shortcuts, updates: base.updates)
        #expect(!WelcomeCard.simulates(real, arguments: LaunchArguments(["Overbright"])))
        #expect(WelcomeCard.simulates(real, arguments: LaunchArguments(["Overbright", "--qa-simulate"])))
    }

    // MARK: Step 2 · displays

    /// One row per display, built-in first, with the classifier's verdict, the class default of the switch (D8) and
    /// the fix of DESIGN.md §12.1; names never decide anything.
    @Test func everyDisplayHasARowWithItsVerdict() throws {
        let rows = try WelcomeHarness(.russianNames).rows
        try #require(rows.map(\.key) == [Keys.builtIn, Keys.mpg322ux])
        let builtIn = rows[0], msi = rows[1]
        #expect(builtIn.isBuiltIn && builtIn.canBoost && builtIn.boostEnabled && !builtIn.isOLED && builtIn.fix == nil)
        #expect(builtIn.name == "Встроенный дисплей Retina")
        guard case .supported = builtIn.verdict else { Issue.record("\(builtIn.verdict)"); return }
        #expect(!msi.isBuiltIn && msi.canBoost && !msi.boostEnabled && msi.isOLED)        // OLED: opt-in
        #expect(msi.advisories.contains(.oledCare))

        let hdrOff = try WelcomeHarness(.mpg322uxHDROff).row(Keys.mpg322ux)
        #expect(hdrOff.verdict == .turnOnHDR && !hdrOff.canBoost && hdrOff.fix == .openSystemSettings)
        let sidecar = try WelcomeHarness(.sidecar).row(Keys.sidecar)
        #expect(sidecar.verdict == .virtualDisplay && !sidecar.canBoost && sidecar.fix == nil)
        let mirror = try WelcomeHarness(.hardwareMirror).row(Keys.projector)
        #expect(mirror.verdict == .mirrored && !mirror.canBoost)
        let studio = try WelcomeHarness(.studioDisplayXDR).row(Keys.studioDisplayXDR)
        #expect(!studio.canBoost && studio.fix == .choosePeak)                    // Safe adds nothing there
        let lcd = try WelcomeHarness(.lcdOnly).row(Keys.builtIn)
        #expect(lcd.verdict == .lcdClass && !lcd.canBoost && lcd.fix == nil)
    }

    /// The rows follow the directory and the engine: HDR turned on in System Settings turns "HDR is off" into a
    /// supported display; a new display reads "Checking…" until the engine classified it; a removed one goes away.
    @Test func theRowsReEvaluateWhenTheDisplaysChange() throws {
        let harness = try WelcomeHarness(.mpg322uxHDROff)
        #expect(try harness.row(Keys.mpg322ux).verdict == .turnOnHDR)
        WelcomePreview.classify(harness.services, machine: DisplayFixture.mpg322uxHDROn.machine,
                                scripts: DisplayFixture.mpg322uxHDROn.displays)
        let on = try harness.row(Keys.mpg322ux)
        #expect(on.canBoost && on.fix == nil)
        guard case .supported = on.verdict else { Issue.record("\(on.verdict)"); return }

        let directory = try #require(harness.services.displays as? FakeDisplayDirectory)
        let pro = DisplayFixture.proDisplayXDR.displays[0]
        directory.add(pro.facts)
        #expect(try harness.row(Keys.proDisplayXDR).verdict == .checking)
        #expect(try !harness.row(Keys.proDisplayXDR).canBoost)
        harness.boost.status.displays.append(WelcomePreview.status(pro, preferences: DisplayPreferences(),
                                                                   machine: DisplayFixture.ownerMachine))
        #expect(try harness.row(Keys.proDisplayXDR).canBoost)
        directory.remove(Keys.mpg322ux)
        #expect(harness.rows.map(\.key) == [Keys.proDisplayXDR])
    }

    /// "Use extra brightness" writes the display's preference at once; turning it on for an OLED asks first (once),
    /// and a cancelled notice changes nothing. The engine is never asked for anything.
    @Test func theSwitchWritesThePreferenceAndAsksOLEDDisplaysFirst() throws {
        let harness = try WelcomeHarness(.russianNames)
        var asked: [String] = []
        var answer = false
        let actions = WelcomeDisplayActions(services: harness.services, confirmOLED: { asked.append($0); return answer },
                                            openURL: { _ in })
        let msi = try harness.row(Keys.mpg322ux)
        #expect(!actions.setExtraBrightness(true, for: msi))                       // Cancel
        #expect(asked == ["MPG322UX OLED"] && harness.services.settings[DisplaySettings.perDisplay][Keys.mpg322ux] == nil)
        #expect(try !harness.row(Keys.mpg322ux).boostEnabled)
        answer = true
        #expect(actions.setExtraBrightness(true, for: msi))
        #expect(try harness.row(Keys.mpg322ux).boostEnabled)
        let stored = try #require(harness.services.settings[DisplaySettings.perDisplay][Keys.mpg322ux])
        #expect(stored.boostEnabled == true && stored.oledNoticeAcknowledged)
        #expect(actions.setExtraBrightness(false, for: msi) && actions.setExtraBrightness(true, for: msi))
        #expect(asked.count == 2)                                                 // accepted once: not asked again

        #expect(actions.setExtraBrightness(false, for: try harness.row(Keys.builtIn)))    // not OLED: no question
        #expect(try !harness.row(Keys.builtIn).boostEnabled && asked.count == 2)
        #expect(harness.boost.calls.isEmpty)
    }

    /// A verdict's fix opens Displays settings in System Settings, or Settings ▸ Displays at the Limit row.
    @Test func fixesOpenTheirDestinations() throws {
        var opened: [URL] = []
        let hdrOff = try WelcomeHarness(.mpg322uxHDROff)
        WelcomeDisplayActions(services: hdrOff.services, confirmOLED: { _ in false }, openURL: { opened.append($0) })
            .performFix(for: try hdrOff.row(Keys.mpg322ux))
        #expect(opened == [try #require(SettingsLinks.systemDisplays)] && hdrOff.app.calls.isEmpty)

        let studio = try WelcomeHarness(.studioDisplayXDR)
        WelcomeDisplayActions(services: studio.services, confirmOLED: { _ in false }, openURL: { opened.append($0) })
            .performFix(for: try studio.row(Keys.studioDisplayXDR))
        #expect(studio.app.calls == ["openSettings(\(SettingsLinks.limit(of: Keys.studioDisplayXDR)))"])
        #expect(opened.count == 1)
        let row = try studio.row(Keys.studioDisplayXDR)
        let view = DisplayRowView(row: row, switchTitle: "", actions: WelcomeDisplayActions(services: studio.services))
        #expect(view.fixTitle(VerdictTextStub.empty) == CardAction.choosePeak.title)
        #expect(view.fixTitle(VerdictTextStub.with(fix: "Choose Peak…")) == "Choose Peak…")
    }

    // MARK: Step 4 · shortcuts

    /// Turn on or off, Back to Standard and Dim Below Minimum On or Off, in that order, with their live key caps; a
    /// cleared or conflicting shortcut is left out.
    @Test func stepFourShowsTheLiveShortcuts() {
        let center = PreviewShortcutCenter()
        #expect(FindItShortcut.rows(center) == [FindItShortcut(id: .toggle, keys: "⌃⌥⌘B"),
                                                FindItShortcut(id: .standard, keys: "⌃⌥⌘0"),
                                                FindItShortcut(id: .dimToggle, keys: "⌃⌥⌘9")])
        center.set(.standard, nil)
        center.conflicting = [.dimToggle]
        #expect(FindItShortcut.rows(center).map(\.id) == [.toggle])
        let copy = FindItStep.Copy.localized(in: englishBundle)
        #expect([ShortcutID.toggle, .standard, .dimToggle].map(copy.title(of:))
                == ["Turn on or off", "Back to Standard", "Dim Below Minimum On or Off"])
    }

    // MARK: Step 5 · Turn On Overbright

    /// Offered only while some display would show extra brightness once Overbright is on (verdict, limit and switch).
    @Test func turnOnIsOfferedOnlyWhenADisplayWouldBoost() throws {
        #expect(try WelcomeHarness().rows.offersTurnOn)
        #expect(try !WelcomeHarness(.lcdOnly).rows.offersTurnOn)
        #expect(try !WelcomeHarness(.studioDisplayXDR).rows.offersTurnOn)         // Safe adds nothing there
        let oled = try WelcomeHarness(.mpg322uxHDROn)
        #expect(!oled.rows.offersTurnOn)                                          // OLED: extra brightness is opt-in
        WelcomeDisplayActions(services: oled.services, confirmOLED: { _ in true }, openURL: { _ in })
            .setExtraBrightness(true, for: try oled.row(Keys.mpg322ux))
        #expect(oled.rows.offersTurnOn)
    }

    /// The Done step tells the footer whether to offer Turn On Overbright as soon as it appears.
    @Test func theDoneStepSetsTheFootersTurnOn() async throws {
        let capable = try WelcomeHarness(step: .done, records: false)
        let window = try Self.host(capable.session)
        #expect(await eventually { capable.session.offersTurnOn })
        let none = try WelcomeHarness(.lcdOnly, step: .done, records: false)
        none.session.offersTurnOn = true
        let other = try Self.host(none.session)
        #expect(await eventually { !none.session.offersTurnOn })
        window.contentView = nil
        other.contentView = nil
    }

    /// `session`'s window content laid out and drawn in a borderless window that is never ordered in.
    static func host(_ session: WelcomeSession) throws -> NSWindow {
        let host = NSHostingView(rootView: WelcomeView(session: session).environment(\.isStaticSnapshot, true))
        host.frame = CGRect(origin: .zero, size: WelcomeMetrics.window)
        let window = NSWindow(contentRect: host.frame, styleMask: [.borderless], backing: .buffered, defer: true)
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        let rep = try #require(host.bitmapImageRepForCachingDisplay(in: host.bounds))
        host.cacheDisplay(in: host.bounds, to: rep)
        return window
    }
}

/// Verdict texts as Design builds them, for the fix-title fallback.
private enum VerdictTextStub {
    static let empty = VerdictText(badge: "", sentence: "", advisories: [], fixTitle: nil)
    static func with(fix: String) -> VerdictText { VerdictText(badge: "B", sentence: "S", advisories: [], fixTitle: fix) }
}
