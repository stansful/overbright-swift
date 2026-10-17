// OverbrightDesignTests/Support/HostedWindow.swift — a SwiftUI view in a real window that is never ordered in, and key
// events made for that window and handed to it, never posted. Nothing appears on screen; the window may become key so
// that SwiftUI's focus and key handlers run. Waits go through TestSupport's `eventually` (ARCHITECTURE.md §9.1), never
// a fixed run-loop delay.
import AppKit
import SwiftUI
import Testing
@testable import OverbrightDesign

/// A view hosted off screen: its window and its hosting view.
@MainActor struct HostedView {
    let window: NSWindow
    let host: NSView

    /// `view` (themed, in `direction`) in an off-screen borderless window of `size` that may become key, laid out.
    init(_ view: some View, size: CGSize = CGSize(width: 320, height: 80), direction: LayoutDirection = .leftToRight) {
        _ = NSApplication.shared
        let host = NSHostingView(rootView: view.environment(\.layoutDirection, direction).overbrightThemeRoot())
        let window = KeyableWindow(contentRect: NSRect(origin: CGPoint(x: -30_000, y: -30_000), size: size),
                                   styleMask: .borderless, backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        self.window = window
        self.host = host
    }

    /// Whether the window's first responder is the hosting view or inside it, so SwiftUI's focus takes the keys (a
    /// window that is never ordered in does not report itself key, but `makeKey()` lets it route keys all the same).
    var hostIsFirstResponder: Bool {
        guard let responder = window.firstResponder as? NSView else { return false }
        return responder === host || responder.isDescendant(of: host)
    }

    /// Hands the window a press of `key` (← → Home End), a key-down and its key-up, as AppKit would deliver them.
    func press(_ key: KeyEquivalent) throws {
        let (function, code): (Int, UInt16) = switch key {
        case .leftArrow: (NSLeftArrowFunctionKey, 123)
        case .rightArrow: (NSRightArrowFunctionKey, 124)
        case .home: (NSHomeFunctionKey, 115)
        default: (NSEndFunctionKey, 119)
        }
        let characters = String(Character(try #require(UnicodeScalar(UInt32(function)))))
        for type in [NSEvent.EventType.keyDown, .keyUp] {
            let event = try #require(NSEvent.keyEvent(with: type, location: .zero,
                                                      modifierFlags: [.function, .numericPad],
                                                      timestamp: ProcessInfo.processInfo.systemUptime,
                                                      windowNumber: window.windowNumber, context: nil,
                                                      characters: characters, charactersIgnoringModifiers: characters,
                                                      isARepeat: false, keyCode: code))
            window.sendEvent(event)
        }
    }

    /// Takes the view out of its window and closes it.
    func close() {
        window.contentView = nil
        window.close()
    }
}

/// A borderless window that may become key while it stays off screen.
final class KeyableWindow: NSWindow {
    override var canBecomeKey: Bool { true }
}
