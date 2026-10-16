// OverbrightOnboardingTests/WelcomeKeyboardTests.swift — every step is reachable with the keyboard alone (DESIGN.md §8:
// "↩ continues, ⌘[ goes back, Esc asks 'Skip setup?'"; ARCHITECTURE.md §10.14 acceptance). The real window content is
// hosted in a titled window that is never ordered in, and key events go through the window's key-equivalent path, as
// AppKit delivers them: no step may take ↩, ⌘[ or Esc for itself, and no step blocks Continue.
import AppKit
import OverbrightCore
import OverbrightTestSupport
import SwiftUI
import Testing
@testable import OverbrightOnboarding

@MainActor @Suite struct WelcomeKeyboardTests {
    /// The window content of `session` in a titled window (never ordered in), laid out.
    static func window(_ session: WelcomeSession) -> NSWindow {
        let host = NSHostingView(rootView: WelcomeView(session: session).environment(\.isStaticSnapshot, true))
        host.sizingOptions = []
        let window = NSWindow(contentRect: CGRect(origin: .zero, size: WelcomeMetrics.window),
                              styleMask: [.titled, .closable, .fullSizeContentView], backing: .buffered, defer: true)
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        return window
    }

    /// Delivers a key-down as a key equivalent; true when something in the window handled it.
    @discardableResult
    static func press(_ characters: String, keyCode: UInt16, modifiers: NSEvent.ModifierFlags = [],
                      in window: NSWindow) throws -> Bool {
        let event = try #require(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: modifiers,
                                                  timestamp: 0, windowNumber: window.windowNumber, context: nil,
                                                  characters: characters, charactersIgnoringModifiers: characters,
                                                  isARepeat: false, keyCode: keyCode))
        let handled = window.performKeyEquivalent(with: event)
        window.contentView?.layoutSubtreeIfNeeded()
        return handled
    }

    static func returnKey(_ window: NSWindow) throws { try press("\r", keyCode: 36, in: window) }
    static func back(_ window: NSWindow) throws { try press("[", keyCode: 33, modifiers: .command, in: window) }
    static func escape(_ window: NSWindow) throws { try press("\u{1b}", keyCode: 53, in: window) }

    /// ↩ walks forward through every step, ⌘[ walks back to the first, and Esc asks before skipping, on every step.
    @Test func returnCommandBracketAndEscapeReachEveryStep() async throws {
        let harness = try WelcomeHarness(.russianNames, records: false)
        let session = harness.session
        let window = Self.window(session)
        var visited = [session.step]
        for _ in 1..<session.stepCount {
            let before = session.step
            try Self.returnKey(window)
            #expect(await eventually { session.step != before }, "↩ on \(before.rawValue)")
            visited.append(session.step)
        }
        #expect(visited == WelcomeStep.allCases)
        for _ in 1..<session.stepCount {
            let before = session.step
            try Self.back(window)
            #expect(await eventually { session.step != before }, "⌘[ on \(before.rawValue)")
        }
        #expect(session.step == .hello)
        for step in WelcomeStep.allCases {
            let session = try WelcomeHarness(.russianNames, step: step, records: false).session
            let window = Self.window(session)
            try Self.escape(window)
            #expect(await eventually { session.isConfirmingSkip }, "Esc on \(step.rawValue)")
            window.contentView = nil
        }
        window.contentView = nil
        #expect(harness.boost.calls.isEmpty)
    }

    /// On the last step ↩ is the primary button: Turn On Overbright when a display can boost, else Done.
    @Test func returnOnTheLastStepIsThePrimaryButton() async throws {
        let capable = try WelcomeHarness(step: .done, records: false)
        let window = Self.window(capable.session)
        #expect(await eventually { capable.session.offersTurnOn })
        window.contentView?.layoutSubtreeIfNeeded()
        try Self.returnKey(window)
        #expect(await eventually { capable.session.outcome == .done })
        #expect(capable.boost.calls == ["setOn(true,welcome)"])
        window.contentView = nil

        let none = try WelcomeHarness(.lcdOnly, step: .done, records: false)
        let other = Self.window(none.session)
        try Self.returnKey(other)
        #expect(await eventually { none.session.outcome == .done })
        #expect(none.boost.calls.isEmpty)
        other.contentView = nil
    }
}
