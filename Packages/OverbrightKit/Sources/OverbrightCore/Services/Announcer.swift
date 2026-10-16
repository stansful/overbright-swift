// OverbrightCore/Services/Announcer.swift — the app's VoiceOver announcements, through one rate limit (at most one
// alert or result per 10 s for the whole app). Ported from Cranny (the owner's MIT code); posts through the
// Accessibility framework, so Core imports no SwiftUI (D23). ARCHITECTURE.md §3.1, §3.9.
import Foundation
import Accessibility

/// Posts VoiceOver announcements (`services.announcer`). Alerts and results share ONE limit of one per
/// `interval`, whichever module posts them, so an automation stop, an intent result and a "Paused because…" banner
/// can never be announced back to back. Feedback the user just asked for (a level change from the keyboard, Settings'
/// Undo) bypasses the limit.
@MainActor public final class Announcer {
    /// What an announcement reports.
    public nonisolated enum Kind: Sendable {
        /// Something the user did not ask for happened ("Paused because…", an automation stopped the boost).
        case alert
        /// Work the user started elsewhere finished (an intent, a shortcut, the self-test).
        case result
        /// The direct answer to the user's own action, which VoiceOver users need every time: never rate-limited.
        case feedback
    }

    /// The shared limit for `.alert` and `.result`.
    public static let interval: TimeInterval = 10

    private let post: @MainActor (String) -> Void
    private let now: @MainActor () -> TimeInterval
    private var lastLimited: TimeInterval?

    /// `post` delivers the text (tests record it); `now` is a monotonic clock in seconds.
    public init(post: @escaping @MainActor (String) -> Void = { AccessibilityNotification.Announcement($0).post() },
                now: @escaping @MainActor () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }) {
        self.post = post
        self.now = now
    }

    /// Posts `text` unless it is empty or, for an alert or result, another alert or result was posted less than
    /// `interval` ago (it is dropped, not queued: the panel, banner or HUD still shows it). Returns whether it was posted.
    @discardableResult
    public func announce(_ text: String, kind: Kind) -> Bool {
        guard !text.isEmpty else { return false }
        if kind != .feedback {
            let time = now()
            if let lastLimited, time - lastLimited < Self.interval { return false }
            lastLimited = time
        }
        post(text)
        return true
    }
}
