// OverbrightChannel/NotifyStateWord.swift — the notifyd state word of one name. ARCHITECTURE.md §7.7; D25.
// Nonisolated and lock-protected: the app posts from the main actor, the extension reads from its intent and value
// provider (any thread). The sandbox allows the notifyd lookup (`system.sb`, the controls study); no IPC to the app.
import Foundation
import notify

/// The 64-bit state of a notifyd name: the app sets it and posts the name, the extension reads it synchronously.
/// The publishing side keeps one registration for the life of the object (`@unchecked Sendable`: `token` is only
/// touched under `lock`).
public nonisolated final class NotifyStateWord: @unchecked Sendable {
    /// The notifyd name.
    public let name: String
    private let lock = NSLock()
    private var token: Int32 = NOTIFY_TOKEN_INVALID

    /// A word for `name` (the app's is `BoostChannel.notifyName`; tests use a name of their own).
    public init(name: String = BoostChannel.notifyName) { self.name = name }

    deinit {
        if token != NOTIFY_TOKEN_INVALID { notify_cancel(token) }
    }

    /// Sets the name's state to `word`, then posts the name. False when notifyd refused either step.
    @discardableResult
    public func post(_ word: UInt64) -> Bool {
        lock.withLock {
            if token == NOTIFY_TOKEN_INVALID {
                var registered: Int32 = NOTIFY_TOKEN_INVALID
                guard notify_register_check(name, &registered) == NOTIFY_STATUS_OK else { return false }
                token = registered
            }
            guard notify_set_state(token, word) == NOTIFY_STATUS_OK else { return false }
            return notify_post(name) == NOTIFY_STATUS_OK
        }
    }

    /// The name's state now; 0 (= not valid) when nobody set it or notifyd cannot be reached.
    public func read() -> UInt64 {
        var reader: Int32 = NOTIFY_TOKEN_INVALID
        guard notify_register_check(name, &reader) == NOTIFY_STATUS_OK else { return 0 }
        defer { notify_cancel(reader) }
        var state: UInt64 = 0
        guard notify_get_state(reader, &state) == NOTIFY_STATUS_OK else { return 0 }
        return state
    }
}
