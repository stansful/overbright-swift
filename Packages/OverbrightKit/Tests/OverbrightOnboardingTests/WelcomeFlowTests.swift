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

    /// The card shows the window's own display: its Bright room when it can boost. On a display that cannot (Sidecar,
    /// an XDR on Safe) while another can, the illustration and "Move this window to another display", never another
    /// display's light drawn where Overbright adds nothing (WP14 C-ONBOARD-4); while the window's display is not read
    /// yet, the illustration alone. Before the window's display is known (and in a simulated run) the first display
    /// that can boost, as the stand-in: nothing is held without the window's display.
    @Test func theCardFollowsTheWindowsDisplay() throws {
        let both = try WelcomeHarness(.russianNames)
        guard case let .preview(display, gain) = WelcomeCard.make(rows: both.rows, windowDisplay: Keys.mpg322ux) else {
            Issue.record("no card"); return
        }
        #expect(display == Keys.mpg322ux && abs(gain - 1.3.squareRoot()) < 0.001)          // OLED Safe ×1.3
        let sidecar = try WelcomeHarness(.sidecar)
        let onTheIPad = WelcomeCard.make(rows: sidecar.rows, windowDisplay: Keys.sidecar)
        #expect(onTheIPad == .otherDisplay)
        #expect(onTheIPad.heldDisplay(windowDisplay: Keys.sidecar, isWindowVisible: true, simulated: false) == nil)
        let unknown = WelcomeCard.make(rows: sidecar.rows, windowDisplay: nil)
        #expect(unknown == .preview(display: Keys.builtIn, gain: WelcomeCard.gain(top: 1000.0 / 600)))
        #expect(unknown.heldDisplay(windowDisplay: nil, isWindowVisible: true, simulated: false) == nil)

        let studio = try WelcomeHarness(.studioDisplayXDR)                     // Safe adds nothing there
        #expect(WelcomeCard.make(rows: studio.rows, windowDisplay: Keys.studioDisplayXDR) == .noneCapable)
        let lcd = try WelcomeHarness(.lcdOnly)
        #expect(WelcomeCard.make(rows: lcd.rows, windowDisplay: Keys.builtIn) == .noneCapable)

        let directory = try #require(both.services.displays as? FakeDisplayDirectory)
        let pro = DisplayFixture.proDisplayXDR.displays[0]
        directory.add(pro.facts)                                                  // not classified yet
        #expect(WelcomeCard.make(rows: both.rows, windowDisplay: Keys.proDisplayXDR) == .checking)
        #expect(WelcomeCard.make(rows: both.rows, windowDisplay: DisplayKey(rawValue: "NOT-LISTED")) == .checking)
        #expect(HelloLower(copy: .localized(in: englishBundle), card: .otherDisplay).caption
                == "This display has no extra range right now. Move this window to another display to compare.")
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

    /// "Keep Automatically adjust brightness…" is Settings only (DESIGN.md §12.1, §7.4) and calibration is not part of
    /// Welcome (§8): the built-in XDR row shows neither, though the classifier advises both; an OLED keeps its care line.
    @Test func stepTwoLeavesOutSettingsOnlyAdvisories() throws {
        let harness = try WelcomeHarness(.russianNames)
        let published = try #require(harness.boost.status.displays.first { $0.key == Keys.builtIn }?.decision?
            .eligibility.advisories)
        #expect(published.contains(.autoBrightnessInteracts))
        let builtIn = try harness.row(Keys.builtIn)
        #expect(!builtIn.advisories.contains(.autoBrightnessInteracts) && builtIn.text.advisories.isEmpty)
        let settingsOnly = VerdictText.line(for: .autoBrightnessInteracts, in: .english())
        #expect(!harness.rows.flatMap(\.text.advisories).contains(settingsOnly))
        let msi = try harness.row(Keys.mpg322ux)
        #expect(msi.text.advisories == [VerdictText.line(for: .oledCare, in: .english())])
        #expect(Advisory.allCases.filter(WelcomeDisplayRow.showsInWelcome) == [.compatibilityModeAdvised, .oledCare])
    }

    /// The sentence quotes the display's own limit and the fix comes with those words (Design's `VerdictText`):
    /// Studio Display XDR on Safe says Safe adds nothing and offers Choose Peak…; on Peak (Welcome reopened from
    /// Settings ▸ About) it says what Peak gives and offers no fix.
    @Test func theVerdictFollowsTheDisplaysLimit() throws {
        let safe = try WelcomeHarness(.studioDisplayXDR).row(Keys.studioDisplayXDR)
        #expect(safe.capMode == .safe && !safe.canBoost && safe.fix == .choosePeak && safe.text.fix == .choosePeak)
        #expect(safe.text.sentence.hasPrefix(SafeLimitText.addsNothing(in: .english())))
        #expect(safe.text.fixTitle == FixAction.choosePeak.title(in: .english()))
        let peak = try WelcomeHarness(.studioDisplayXDR) { services in
            services.settings[DisplaySettings.perDisplay] = [Keys.studioDisplayXDR: DisplayPreferences(capMode: .peak)]
        }.row(Keys.studioDisplayXDR)
        #expect(peak.capMode == .peak && peak.canBoost && peak.fix == nil && peak.text.fixTitle == nil)
        #expect(peak.text.sentence.hasPrefix("With Peak") && !peak.text.sentence.contains("Safe"))
    }

    /// The fix the verdict's words come with agrees with the panel's card in every fixture: Open System Settings for
    /// the verdicts System Settings fixes, Choose Peak… where Safe adds nothing, nothing else.
    @Test(arguments: DisplayFixture.allCases)
    func theFixAgreesWithTheCard(_ fixture: DisplayFixture) throws {
        let harness = try WelcomeHarness(fixture)
        for row in harness.rows {
            let status = try #require(harness.boost.status.displays.first { $0.key == row.key })
            let card = DisplayCardModel(status: status, isMasterOn: false, services: harness.services)
            let expected: WelcomeDisplayRow.Fix? = if case .unavailable(.safeLimitReached) = card.boostHalf {
                .choosePeak
            } else if card.verdict.flatMap(CardChip.verdictFix) == .openDisplaySettings {
                .openSystemSettings
            } else {
                nil
            }
            #expect(row.fix == expected, "\(fixture.rawValue) \(row.name)")
            #expect(row.canBoost == card.canBoost && row.capMode == card.capMode)
        }
    }

    /// "Use extra brightness" records a choice that Done writes (Skip drops it, `SkipAppliesDefaultsTests`); turning
    /// it on for an OLED asks first, once, and a cancelled notice changes nothing. Turning a switch back leaves no
    /// choice. The engine is never asked for anything.
    @Test func theSwitchRecordsAChoiceAndAsksOLEDDisplaysFirst() throws {
        let harness = try WelcomeHarness(.russianNames)
        var asked: [String] = []
        let answer = Answer(false)
        let actions = harness.actions(confirmOLED: { asked.append($0); return answer.value })
        let msi = try harness.row(Keys.mpg322ux)
        #expect(!actions.setExtraBrightness(true, for: msi))                       // Cancel
        #expect(asked == ["MPG322UX OLED"] && harness.session.choices.extraBrightness.isEmpty)
        #expect(try !harness.row(Keys.mpg322ux).boostEnabled)
        answer.value = true
        #expect(actions.setExtraBrightness(true, for: msi))
        #expect(try harness.row(Keys.mpg322ux).boostEnabled && !harness.row(Keys.mpg322ux).storedBoostEnabled)
        #expect(harness.session.choices.extraBrightness == [Keys.mpg322ux: true])
        #expect(harness.services.settings[DisplaySettings.perDisplay][Keys.mpg322ux] == nil)      // not before Done
        #expect(actions.setExtraBrightness(false, for: msi) && actions.setExtraBrightness(true, for: msi))
        #expect(asked.count == 2)                                                 // accepted once: not asked again

        #expect(actions.setExtraBrightness(false, for: try harness.row(Keys.builtIn)))    // not OLED: no question
        #expect(try !harness.row(Keys.builtIn).boostEnabled && asked.count == 2)
        #expect(actions.setExtraBrightness(true, for: try harness.row(Keys.builtIn)))     // back to what is stored
        #expect(harness.session.choices.extraBrightness == [Keys.mpg322ux: true])

        harness.session.finish()
        let stored = try #require(harness.services.settings[DisplaySettings.perDisplay][Keys.mpg322ux])
        #expect(stored.boostEnabled == true && stored.oledNoticeAcknowledged && stored.lastKnownName == "MPG322UX OLED")
        #expect(harness.services.settings[DisplaySettings.perDisplay][Keys.builtIn] == nil)
        #expect(harness.boost.calls.isEmpty)
    }

    /// A verdict's fix opens Displays settings in System Settings, or Settings ▸ Displays at the Limit row; its title
    /// is the verdict's own.
    @Test func fixesOpenTheirDestinations() throws {
        var opened: [URL] = []
        let hdrOff = try WelcomeHarness(.mpg322uxHDROff)
        hdrOff.actions(confirmOLED: { _ in false }, openURL: { opened.append($0) })
            .performFix(for: try hdrOff.row(Keys.mpg322ux))
        #expect(opened == [try #require(SettingsLinks.systemDisplays)] && hdrOff.app.calls.isEmpty)
        #expect(try hdrOff.row(Keys.mpg322ux).text.fixTitle == FixAction.openSystemSettings.title(in: .english()))

        let studio = try WelcomeHarness(.studioDisplayXDR)
        studio.actions(confirmOLED: { _ in false }, openURL: { opened.append($0) })
            .performFix(for: try studio.row(Keys.studioDisplayXDR))
        #expect(studio.app.calls == ["openSettings(\(SettingsLinks.limit(of: Keys.studioDisplayXDR)))"])
        #expect(opened.count == 1)
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

    /// Offered only while some display would show extra brightness once Overbright is on (verdict, limit and switch,
    /// step 2's pending choice included).
    @Test func turnOnIsOfferedOnlyWhenADisplayWouldBoost() throws {
        #expect(try WelcomeHarness().rows.offersTurnOn)
        #expect(try !WelcomeHarness(.lcdOnly).rows.offersTurnOn)
        #expect(try !WelcomeHarness(.studioDisplayXDR).rows.offersTurnOn)         // Safe adds nothing there
        let oled = try WelcomeHarness(.mpg322uxHDROn)
        #expect(!oled.rows.offersTurnOn)                                          // OLED: extra brightness is opt-in
        oled.actions().setExtraBrightness(true, for: try oled.row(Keys.mpg322ux))
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
