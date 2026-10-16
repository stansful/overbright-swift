// OverbrightOnboardingTests/HelloStepHoldTests.swift — step 1's card on display ports that are not the Core fakes
// (ARCHITECTURE.md D6: every EDR surface registers with `OwnEDRSurfaces`; DESIGN.md §8: "The card pauses while the
// window is hidden"): `HelloStep` itself, hosted in a borderless window that is never ordered in, reads the window's
// display for real (read-only: the screen's number and its CoreGraphics UUID) and holds it while the card could show
// extra range: once the display is known, never while the window is hidden, and never after the step went away. The
// card draws its SDR stand-in whenever nothing is held: the hosted step has EDR content (Design's `EDRWhiteView`)
// exactly while a display is held, so EDR content is never on screen unregistered (WP14 C-ONBOARD-6). Nothing reaches
// the screen: the window is never ordered in, so the card's EDR layer stays hidden and no extra range is requested.
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

/// The card's EDR views under `view`: Design's `EDRWhiteView` (internal to Design, so found by its class name).
@MainActor private func edrViews(in view: NSView) -> [NSView] {
    let own = NSStringFromClass(type(of: view)).hasSuffix("EDRWhiteView") ? [view] : []
    return own + view.subviews.flatMap { edrViews(in: $0) }
}

/// The stage of `host` shows the before/after card: the card's white "after" side fills a band near the bottom of its
/// right half (the illustration leaves the stage's own background there).
@MainActor private func stageShowsTheCard(_ host: NSView) -> Bool {
    guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { return false }
    host.cacheDisplay(in: host.bounds, to: rep)
    let scale = CGFloat(rep.pixelsWide) / max(host.bounds.width, 1)
    let middle = host.bounds.width / 2
    let bottom = StepMetrics.titleBarInset + StepMetrics.stageContentHeight
    var white = 0, total = 0
    for x in stride(from: middle + StepMetrics.cardWidth * 0.2, to: middle + StepMetrics.cardWidth * 0.4, by: 4) {
        for y in stride(from: bottom - Space.xl, to: bottom - Space.xs, by: 2) {
            total += 1
            guard let color = rep.colorAt(x: Int(x * scale), y: Int(y * scale))?.usingColorSpace(.deviceRGB) else { continue }
            if color.redComponent > 0.97 && color.greenComponent > 0.97 && color.blueComponent > 0.97 { white += 1 }
        }
    }
    return total > 0 && white * 10 >= total * 9
}

@MainActor @Suite struct HelloStepHoldTests {
    @Test(.enabled(if: NSScreen.main != nil, "needs a screen (CI runners are headless)"))
    func theCardHoldsTheWindowsDisplayOnlyWhileItCouldShowExtraRange() async throws {
        let frame = CGRect(origin: NSScreen.main?.frame.origin ?? .zero, size: WelcomeMetrics.window)
        let window = NSWindow(contentRect: frame, styleMask: [.borderless], backing: .buffered, defer: true)
        let display = try #require(window.screen.flatMap(WindowScreenReader.ReaderView.displayKey(of:)))
        let services = servicesWithRealDirectory(keys: [DisplayFixture.Keys.builtIn: display])   // it can boost
        #expect(!WelcomeCard.simulates(services, arguments: LaunchArguments(["Overbright"])))
        let session = WelcomeSession(services: services, recordsOutcome: false) { _ in }
        let state = HelloHostState()
        let host = NSHostingView(rootView: HostedHello(session: session, state: state)
            .environment(\.isStaticSnapshot, true)
            .overbrightThemeRoot())
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        #expect(!window.isVisible && !window.occlusionState.contains(.visible))   // nothing reaches the screen
        let surfaces = services.ownEDRSurfaces
        func settled(_ condition: @escaping @MainActor () -> Bool) async -> Bool {
            await eventually(timeout: .seconds(10)) { host.layoutSubtreeIfNeeded(); return condition() }
        }

        // Before the window's display is known: nothing held, and the stage draws the stand-in, not EDR content.
        #expect(surfaces.displays.isEmpty && edrViews(in: host).isEmpty, "no EDR content before the display is held")

        #expect(await settled { surfaces.displays == [display: 1] }, "held once the window's display is known")
        #expect(await settled { edrViews(in: host).count == 1 }, "EDR content once the display is held")
        state.isWindowVisible = false
        #expect(await settled { surfaces.displays.isEmpty }, "released while the window is hidden")
        #expect(await settled { edrViews(in: host).isEmpty }, "the stand-in while the window is hidden")
        state.isWindowVisible = true
        #expect(await settled { surfaces.displays == [display: 1] }, "held again when it shows")
        #expect(await settled { edrViews(in: host).count == 1 })
        state.showsHello = false
        #expect(await settled { surfaces.displays.isEmpty }, "released when the step goes away")
        #expect(edrViews(in: host).isEmpty)
        window.contentView = nil
        #expect(surfaces.displays.isEmpty)
    }

    /// A window on a display that cannot show extra brightness, while another can (WP14 C-ONBOARD-4): once the
    /// window's display is read, the stage shows the illustration, holds nothing and draws no EDR content, rather than
    /// another display's light on this one.
    @Test(.enabled(if: NSScreen.main != nil, "needs a screen (CI runners are headless)"))
    func aWindowOnADisplayWithoutExtraRangeShowsTheIllustration() async throws {
        let frame = CGRect(origin: NSScreen.main?.frame.origin ?? .zero, size: WelcomeMetrics.window)
        let window = NSWindow(contentRect: frame, styleMask: [.borderless], backing: .buffered, defer: true)
        let display = try #require(window.screen.flatMap(WindowScreenReader.ReaderView.displayKey(of:)))
        let services = servicesWithRealDirectory(.sidecar, keys: [DisplayFixture.Keys.sidecar: display])
        let rows = WelcomeDisplayRow.rows(in: services)
        #expect(rows.map(\.canBoost) == [true, false])                            // the built-in XDR, the iPad
        #expect(WelcomeCard.make(rows: rows, windowDisplay: display) == .otherDisplay)

        let session = WelcomeSession(services: services, recordsOutcome: false) { _ in }
        let host = NSHostingView(rootView: HostedHello(session: session, state: HelloHostState())
            .environment(\.isStaticSnapshot, true)
            .overbrightThemeRoot())
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        // Until the window's display is read, the first display that can boost, as the stand-in; then the illustration.
        #expect(stageShowsTheCard(host), "the stand-in before the window's display is read")
        #expect(await eventually(timeout: .seconds(10)) { host.layoutSubtreeIfNeeded(); return !stageShowsTheCard(host) },
                "the illustration once the window's display is read")
        #expect(edrViews(in: host).isEmpty && services.ownEDRSurfaces.displays.isEmpty)
        window.contentView = nil
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
