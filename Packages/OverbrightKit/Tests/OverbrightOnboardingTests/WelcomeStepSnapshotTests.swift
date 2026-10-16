// OverbrightOnboardingTests/WelcomeStepSnapshotTests.swift — every Welcome step in the whole window (DESIGN.md §8), in
// Light, Dark and the Increase Contrast appearance (ARCHITECTURE.md §9.1 UI row, §9.3 #5), plus step pages under an
// Increase Contrast theme (the window's own theme root reads the system setting, so only a page shows the theme): step
// 1 with its card and without a capable display, step 2 with two displays and with HDR off, step 3, step 4 with US,
// German and French key caps (§10.14: "US, German and French key caps on step 4"; read from the layouts installed
// with macOS, nothing selected), step 5 with Turn On Overbright and the update switch. Rendered in-process in a window
// that is never ordered in; the card is the SDR stand-in. PNGs only with `OVERBRIGHT_SNAPSHOT_DIR=<dir>` (into
// `<dir>/Onboarding/`).
import AppKit
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
        let reps = try Self.shots().map { try ChromeSnapshot.render(Self.window($0.session), .light, size: WelcomeMetrics.window) }
        let data = reps.compactMap { $0.representation(using: .png, properties: [:]) }
        #expect(data.count == reps.count && Set(data).count == reps.count)
    }

    /// Step 4 with the key caps of three keyboard layouts: French puts other characters on the 0 and 9 keys.
    @Test(arguments: ["US", "German", "French"])
    func stepFourShowsTheKeyCapsOfTheLayout(_ layout: String) throws {
        let center = try LayoutShortcutCenter.named(layout)
        let services = servicesWithShortcuts(center)
        let keys = FindItShortcut.rows(services.shortcuts).map(\.keys)
        switch layout {
        case "French": #expect(keys == ["⌃⌥⌘B", "⌃⌥⌘À", "⌃⌥⌘Ç"])
        default: #expect(keys == ["⌃⌥⌘B", "⌃⌥⌘0", "⌃⌥⌘9"])
        }
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
            let light = try ChromeSnapshot.render(Self.page(session).environment(\.isStaticSnapshot, true), .light, size: WelcomeMetrics.window)
            let contrast = try ChromeSnapshot.render(Self.page(session).environment(\.isStaticSnapshot, true), .increaseContrast, size: WelcomeMetrics.window)
            #expect(light.representation(using: .png, properties: [:])
                    != contrast.representation(using: .png, properties: [:]), "\(step.rawValue)")
            let dark = try ChromeSnapshot.render(Self.page(session).environment(\.isStaticSnapshot, true), .dark, size: WelcomeMetrics.window)
            #expect(ChromeSnapshot.backgroundBrightness(light) > ChromeSnapshot.backgroundBrightness(dark) + 0.3)
            try ChromeSnapshot.write(contrast, "page-\(step.rawValue)", .increaseContrast)
        }
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
