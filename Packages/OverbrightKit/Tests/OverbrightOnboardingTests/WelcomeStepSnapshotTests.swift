// OverbrightOnboardingTests/WelcomeStepSnapshotTests.swift — every Welcome step in the whole window (DESIGN.md §8), in
// Light, Dark and the Increase Contrast appearance (ARCHITECTURE.md §9.1 UI row, §9.3 #5), plus step pages under an
// Increase Contrast theme (the window's own theme root reads the system setting, so only a page shows the theme): step
// 1 with its card, without a capable display and on a display without extra range while another has it, step 2 with
// two, three and five displays, with HDR off and in Russian (the switch on its own line), step 3, step 4 with US,
// German and French key caps (§10.14: "US, German and French key caps on step 4"; read from the layouts installed with
// macOS, nothing selected), step 5 with its summary, Turn On Overbright and the update switch. Rendered in-process in
// a window that is never ordered in; the card is the SDR stand-in. PNGs only with `OVERBRIGHT_SNAPSHOT_DIR=<dir>`
// (into `<dir>/Onboarding/`).
import AppKit
import Carbon
import OverbrightCore
import OverbrightDesign
import SwiftUI
import Testing
@testable import OverbrightOnboarding

@MainActor @Suite struct WelcomeStepSnapshotTests {
    /// A named state of the window.
    struct Shot {
        let name: String
        let session: WelcomeSession
    }

    /// A session over `services` at `step` that records nothing.
    static func session(_ services: OverbrightServices, _ step: WelcomeStep) -> WelcomeSession {
        WelcomeSession(services: services, initialStep: step, recordsOutcome: false) { _ in }
    }

    /// Every step, and the variants DESIGN.md §8 describes.
    static func shots() -> [Shot] {
        let done = session(WelcomePreview.services(updatesConfigured: true), .done)
        done.offersTurnOn = true
        return [
            Shot(name: "step-hello", session: session(WelcomePreview.services(), .hello)),
            Shot(name: "step-hello-none", session: session(WelcomePreview.services(.lcdOnly), .hello)),
            Shot(name: "step-displays", session: session(WelcomePreview.services(.russianNames), .displays)),
            Shot(name: "step-displays-three", session: session(WelcomePreview.threeDisplays, .displays)),
            Shot(name: "step-displays-five", session: session(WelcomePreview.services(
                .russianNames, adding: DisplayFixture.studioDisplayXDR.displays + DisplayFixture.proDisplayXDR.displays
                    + DisplayFixture.sidecar.displays.filter { !$0.facts.isBuiltIn }), .displays)),
            Shot(name: "step-displays-hdr-off", session: session(WelcomePreview.services(.mpg322uxHDROff), .displays)),
            Shot(name: "step-defaults", session: session(WelcomePreview.services(), .defaults)),
            Shot(name: "step-findIt", session: session(WelcomePreview.services(), .findIt)),
            Shot(name: "step-done", session: done),
        ]
    }

    /// The window as `session` shows it.
    static func window(_ session: WelcomeSession) -> some View {
        WelcomeView(session: session).environment(\.isStaticSnapshot, true)
    }

    @Test(arguments: ChromeAppearance.allCases)
    func everyStepRenders(_ appearance: ChromeAppearance) throws {
        for shot in Self.shots() {
            let rep = try ChromeSnapshot.render(Self.window(shot.session), appearance, size: WelcomeMetrics.window)
            #expect(CGFloat(rep.pixelsWide) >= WelcomeMetrics.window.width, "\(shot.name)")
            #expect(ChromeSnapshot.inkFraction(rep) > 0.01, "\(shot.name) \(appearance.rawValue): nothing drawn")
            try ChromeSnapshot.write(rep, shot.name, appearance)
        }
    }

    /// The steps differ from each other: each draws its own stage and copy.
    @Test func theStepsDifferFromEachOther() throws {
        let reps = try Self.shots().map {
            try ChromeSnapshot.render(Self.window($0.session), .light, size: WelcomeMetrics.window)
        }
        let data = reps.compactMap { $0.representation(using: .png, properties: [:]) }
        #expect(data.count == reps.count && Set(data).count == reps.count)
    }

    /// Step 4 with the key caps of three keyboard layouts: French puts other characters on the 0 and 9 keys, and a
    /// shortcut on the key where a US keyboard has Z reads Z, Y (German QWERTZ) or W (French AZERTY), so each layout
    /// is really the one named.
    @Test(arguments: ["US", "German", "French"])
    func stepFourShowsTheKeyCapsOfTheLayout(_ layout: String) throws {
        let center = try LayoutShortcutCenter.named(layout)
        let services = servicesWithShortcuts(center)
        let defaults = FindItShortcut.rows(services.shortcuts).map(\.keys)
        switch layout {
        case "French": #expect(defaults == ["⌃⌥⌘B", "⌃⌥⌘À", "⌃⌥⌘Ç"])
        default: #expect(defaults == ["⌃⌥⌘B", "⌃⌥⌘0", "⌃⌥⌘9"])
        }
        center.set(.dimToggle, KeyCombo(keyCode: UInt16(kVK_ANSI_Z), modifiers: [.control, .option, .command]))
        let keys = FindItShortcut.rows(services.shortcuts).map(\.keys)
        let letter = ["US": "Z", "German": "Y", "French": "W"][layout] ?? "?"
        #expect(keys == Array(defaults.dropLast()) + ["⌃⌥⌘" + letter], "\(layout): \(keys)")
        for appearance in ChromeAppearance.allCases {
            let rep = try ChromeSnapshot.render(Self.window(Self.session(services, .findIt)), appearance,
                                                size: WelcomeMetrics.window)
            #expect(ChromeSnapshot.inkFraction(rep) > 0.01, "\(layout) \(appearance.rawValue): nothing drawn")
            try ChromeSnapshot.write(rep, "step-findIt-\(layout.lowercased())", appearance)
        }
    }

    /// Increase Contrast is not Light: the step cards turn opaque with a full-strength hairline (DESIGN.md §2.1). The
    /// step is rendered under the theme root itself: the window's own root reads the system's contrast setting.
    @Test func increaseContrastDiffersFromLight() throws {
        for step in [WelcomeStep.displays, .defaults, .findIt] {
            let session = Self.session(WelcomePreview.services(.russianNames), step)
            let page = Self.page(session).environment(\.isStaticSnapshot, true)
            let light = try ChromeSnapshot.render(page, .light, size: WelcomeMetrics.window)
            let contrast = try ChromeSnapshot.render(page, .increaseContrast, size: WelcomeMetrics.window)
            #expect(light.representation(using: .png, properties: [:])
                    != contrast.representation(using: .png, properties: [:]), "\(step.rawValue)")
            let dark = try ChromeSnapshot.render(page, .dark, size: WelcomeMetrics.window)
            #expect(ChromeSnapshot.backgroundBrightness(light) > ChromeSnapshot.backgroundBrightness(dark) + 0.3)
            try ChromeSnapshot.write(contrast, "page-\(step.rawValue)", .increaseContrast)
        }
    }

    /// Step 1 on a display without extra range while another display has it (WP14 C-ONBOARD-4): the illustration and
    /// the sentence that asks to move the window, in the page's split.
    @Test(arguments: ChromeAppearance.allCases)
    func stepOneOnADisplayWithoutExtraRange(_ appearance: ChromeAppearance) throws {
        let page = StepLayout {
            StepStage { HelloStage(card: .otherDisplay, divider: .constant(0.5), simulated: true) }
        } content: {
            HelloLower(copy: .localized, card: .otherDisplay)
        }
        .environment(\.isStaticSnapshot, true)
        let rep = try ChromeSnapshot.render(page, appearance,
                                            size: CGSize(width: WelcomeMetrics.window.width,
                                                         height: WelcomeStepFitTests.pageHeight))
        #expect(ChromeSnapshot.inkFraction(rep) > 0.01, "\(appearance.rawValue): nothing drawn")
        try ChromeSnapshot.write(rep, "page-hello-other-display", appearance)
    }

    /// Step 2 in Russian with the owner's three displays (WP14 C-ONBOARD-1): a long name next to the long switch label
    /// puts the switch on its own line, and every row still shows at once.
    @Test(arguments: ChromeAppearance.allCases)
    func stepTwoInRussian(_ appearance: ChromeAppearance) throws {
        var copy = DisplaysStep.Copy.localized(in: onboardingBundle("ru"))
        copy.verdictLanguage = try #require(CopyLanguage.named("ru"))
        let session = Self.session(WelcomePreview.threeDisplays, .displays)
        let page = DisplaysStep(session: session, copy: copy).environment(\.isStaticSnapshot, true)
        let rep = try ChromeSnapshot.render(page, appearance,
                                            size: CGSize(width: WelcomeMetrics.window.width,
                                                         height: WelcomeStepFitTests.pageHeight))
        #expect(ChromeSnapshot.inkFraction(rep) > 0.01, "\(appearance.rawValue): nothing drawn")
        try ChromeSnapshot.write(rep, "page-displays-three-ru", appearance)
    }

    /// A step's page alone (no footer), under the snapshot's theme root.
    @ViewBuilder static func page(_ session: WelcomeSession) -> some View {
        switch session.step {
        case .hello: HelloStep(session: session, isWindowVisible: true)
        case .displays: DisplaysStep(session: session)
        case .defaults: DefaultsStep(session: session)
        case .findIt: FindItStep(session: session)
        case .done: DoneStep(session: session)
        }
    }
}
