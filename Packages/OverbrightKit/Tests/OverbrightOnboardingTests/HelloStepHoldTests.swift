// OverbrightOnboardingTests/HelloStepHoldTests.swift — step 1's card on display ports that are not the Core fakes
// (ARCHITECTURE.md D6: every EDR surface registers with `OwnEDRSurfaces`; DESIGN.md §8: "The card pauses while the
// window is hidden"): `HelloStep` itself, hosted in a borderless window that is never ordered in, reads the window's
// display for real (read-only: the screen's number and its CoreGraphics UUID) and holds it while the card could show
// extra range: once the display is known, never while the window is hidden, and never after the step went away. The
// card draws its SDR stand-in whenever nothing is held. Nothing reaches the screen: the window is never ordered in, so
// the card's EDR layer stays hidden and no extra range is requested.
import AppKit
import Observation
import OverbrightCore
import OverbrightDesign
import OverbrightTestSupport
import SwiftUI
import Testing
@testable import OverbrightOnboarding

/// What the test changes: the window's visibility and whether step 1 is on screen.
@MainActor @Observable private final class HelloHostState {
    var isWindowVisible = true
    var showsHello = true
}

/// Step 1 as the window shows it, or nothing once the step changed.
private struct HostedHello: View {
    let session: WelcomeSession
    let state: HelloHostState

    var body: some View {
        if state.showsHello {
            HelloStep(session: session, isWindowVisible: state.isWindowVisible)
        } else {
            Text(verbatim: "Step 2")
        }
    }
}

@MainActor @Suite struct HelloStepHoldTests {
    @Test func theCardHoldsTheWindowsDisplayOnlyWhileItCouldShowExtraRange() async throws {
        let services = servicesWithRealDirectory()
        #expect(!WelcomeCard.simulates(services, arguments: LaunchArguments(["Overbright"])))
        let session = WelcomeSession(services: services, recordsOutcome: false) { _ in }
        let state = HelloHostState()
        let host = NSHostingView(rootView: HostedHello(session: session, state: state)
            .environment(\.isStaticSnapshot, true)
            .overbrightThemeRoot())
        let frame = CGRect(origin: NSScreen.main?.frame.origin ?? .zero, size: WelcomeMetrics.window)
        let window = NSWindow(contentRect: frame, styleMask: [.borderless], backing: .buffered, defer: true)
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        #expect(!window.isVisible && !window.occlusionState.contains(.visible))   // nothing reaches the screen
        let display = try #require(window.screen.flatMap(WindowScreenReader.ReaderView.displayKey(of:)))
        let surfaces = services.ownEDRSurfaces
        func settled(_ condition: @escaping @MainActor () -> Bool) async -> Bool {
            await eventually(timeout: .seconds(10)) { host.layoutSubtreeIfNeeded(); return condition() }
        }

        #expect(await settled { surfaces.displays == [display: 1] }, "held once the window's display is known")
        state.isWindowVisible = false
        #expect(await settled { surfaces.displays.isEmpty }, "released while the window is hidden")
        state.isWindowVisible = true
        #expect(await settled { surfaces.displays == [display: 1] }, "held again when it shows")
        state.showsHello = false
        #expect(await settled { surfaces.displays.isEmpty }, "released when the step goes away")
        window.contentView = nil
        #expect(surfaces.displays.isEmpty)
    }

    /// The card draws its SDR stand-in whenever no display is held for it: before the window's display is known, while
    /// the window is hidden, and in a simulated run (so EDR content is never on screen unregistered).
    @Test func theCardDrawsItsStandInUntilADisplayIsHeld() {
        let card = WelcomeCard.preview(display: DisplayFixture.Keys.builtIn, gain: 1.29)
        let unknown = card.heldDisplay(windowDisplay: nil, isWindowVisible: true, simulated: false)
        #expect(unknown == nil && WelcomeCard.drawsStandIn(held: unknown))
        let hidden = card.heldDisplay(windowDisplay: DisplayFixture.Keys.builtIn, isWindowVisible: false, simulated: false)
        #expect(WelcomeCard.drawsStandIn(held: hidden))
        let simulated = card.heldDisplay(windowDisplay: DisplayFixture.Keys.builtIn, isWindowVisible: true, simulated: true)
        #expect(WelcomeCard.drawsStandIn(held: simulated))
        let shown = card.heldDisplay(windowDisplay: DisplayFixture.Keys.builtIn, isWindowVisible: true, simulated: false)
        #expect(shown == DisplayFixture.Keys.builtIn && !WelcomeCard.drawsStandIn(held: shown))
    }
}
