// OverbrightChannel/BoostChannel.swift — the out-of-process state of the dormant control, without an App Group.
// ARCHITECTURE.md §7.7, §8.2, §10.0 (Channel seam), §10.10; D25. Foundation only, nonisolated: the extension links
// nothing else. The names are the WP0a seam; the bodies are WP8's.
//
// The notify word (64 bits): bit 0 on · bit 1 valid · bits 2–15 reserved (must be 0) · bits 16–31 level in per mille
// (0…1000) · bits 32–63 generation. Word 0 is "not valid": nobody published since login, the app quit, or the word is
// garbled; the control then shows off. A word with a reserved bit or a level above 1000 is garbled, so a future layout
// never reads as a wrong state in an older extension.
import Foundation

/// Pack and unpack of the notifyd state word, the preferences snapshot, the `set=on` token, and the extension's pure
/// decisions (the liveness gate and the wait after a URL hand-off).
public enum BoostChannel {
    /// The notifyd name the app posts and the extension reads.
    public static let notifyName = "app.overbright.Overbright.state"
    /// The app's bundle identifier (= its preferences domain; the extension's liveness gate looks for it).
    public static let appBundleID = "app.overbright.Overbright"
    /// The control's kind. A persisted identifier: never rename it.
    public static let controlKind = "app.overbright.Overbright.BoostToggle"
    /// The extension's bundle name inside `Contents/PlugIns` (present only in `CONTROLS=1` builds).
    public static let extensionBundleName = "OverbrightControls.appex"
    /// The preferences key of the snapshot (outside the `overbright.` settings prefix, so Reset All keeps it).
    public static let snapshotKey = "ControlCenterSnapshot"
    /// The preferences key of the `set=on` token (outside the settings prefix, like the snapshot).
    public static let tokenKey = "ControlCenterToken"
    /// The highest level the word carries (per mille).
    public static let maximumLevel = 1000
    /// How long the extension waits, after handing a request to the app, for the published state to follow (the
    /// system reads the control's value when the intent returns).
    public static let handOffWait: Duration = .seconds(1)
    /// How often the extension re-reads the word during that wait.
    public static let handOffPollInterval: Duration = .milliseconds(100)

    /// What the word carries: valid bit, on, level in per mille, generation.
    public struct State: Hashable, Sendable {
        /// False when no app wrote the word (or the app is not running): the control shows off.
        public var isValid: Bool
        /// The master switch.
        public var isOn: Bool
        /// The level shown by the control, 0 … 1000.
        public var levelPermille: Int
        /// Increases with every publish.
        public var generation: UInt32
        /// A state.
        public init(isValid: Bool, isOn: Bool, levelPermille: Int, generation: UInt32) {
            self.isValid = isValid; self.isOn = isOn; self.levelPermille = levelPermille; self.generation = generation
        }
        /// No state: the control shows off.
        public static let invalid = State(isValid: false, isOn: false, levelPermille: 0, generation: 0)
    }

    private static let onBit: UInt64 = 1
    private static let validBit: UInt64 = 1 << 1
    private static let reservedBits: UInt64 = 0xFFFC
    private static let levelShift: UInt64 = 16
    private static let generationShift: UInt64 = 32

    // MARK: The word

    /// The 64-bit notify word of `state`: 0 for any state that is not valid; the level is clamped to 0…1000.
    public static func pack(_ state: State) -> UInt64 {
        guard state.isValid else { return 0 }
        let level = UInt64(min(max(state.levelPermille, 0), maximumLevel))
        return UInt64(state.generation) << generationShift | level << levelShift | validBit | (state.isOn ? onBit : 0)
    }

    /// The state in a notify word; `.invalid` for 0, a cleared valid bit, a reserved bit or a level above 1000.
    public static func unpack(_ word: UInt64) -> State {
        guard word & validBit != 0, word & reservedBits == 0 else { return .invalid }
        let level = Int(truncatingIfNeeded: (word >> levelShift) & 0xFFFF)
        guard level <= maximumLevel else { return .invalid }
        return State(isValid: true, isOn: word & onBit != 0, levelPermille: level,
                     generation: UInt32(truncatingIfNeeded: word >> generationShift))
    }

    // MARK: The preferences snapshot

    /// The snapshot in the app's preferences domain (what the extension reads when the word is not valid).
    public static func readSnapshot() -> State? { readSnapshot(from: PreferencesChannelStore.app) }

    /// The snapshot in `store`; nil when there is none or it is not a word.
    public static func readSnapshot(from store: any ChannelStore) -> State? {
        guard let text = store.string(forKey: snapshotKey), let word = UInt64(text) else { return nil }
        return unpack(word)
    }

    /// Writes the snapshot to the app's own preferences domain (app only).
    public static func writeSnapshot(_ state: State) { writeSnapshot(state, to: PreferencesChannelStore.app) }

    /// Writes the snapshot (the packed word, as decimal text) to `store`.
    public static func writeSnapshot(_ state: State, to store: any ChannelStore) {
        store.set(String(pack(state)), forKey: snapshotKey)
    }

    // MARK: The token

    /// A new random token for `overbright://control?set=on` (32 random bytes as 64 lowercase hex digits).
    public static func makeToken() -> String {
        var generator = SystemRandomNumberGenerator()
        return makeToken(using: &generator)
    }

    /// A token from `generator` (tests pass a seeded one).
    public static func makeToken(using generator: inout some RandomNumberGenerator) -> String {
        (0..<32).map { _ in
            let byte = UInt8.random(in: .min ... .max, using: &generator)
            return String(byte, radix: 16).leftPadded(to: 2)
        }.joined()
    }

    /// The token kept in `store`, nil when there is none or it is not 64 hex digits.
    public static func token(in store: any ChannelStore) -> String? {
        guard let token = store.string(forKey: tokenKey), isWellFormedToken(token) else { return nil }
        return token
    }

    /// The token kept in `store`, made and stored first when there is none (the app, at start). Never rotated at
    /// launch: a hand-off URL that launches the app carries the token the extension read before.
    @discardableResult
    public static func ensureToken(in store: any ChannelStore) -> String {
        if let token = token(in: store) { return token }
        let token = makeToken()
        store.set(token, forKey: tokenKey)
        return token
    }

    /// Whether `token` has the shape `makeToken()` produces.
    public static func isWellFormedToken(_ token: String) -> Bool {
        token.utf8.count == 64 && token.utf8.allSatisfy { (0x30...0x39).contains($0) || (0x61...0x66).contains($0) }
    }

    // MARK: The extension's decisions

    /// The state the extension trusts: the notify word when valid, else the snapshot when valid, else `.invalid`.
    public static func currentState(word: UInt64, snapshot: State?) -> State {
        let fromWord = unpack(word)
        if fromWord.isValid { return fromWord }
        if let snapshot, snapshot.isValid { return snapshot }
        return .invalid
    }

    /// The control's value (the liveness gate of D25): off whenever the app is not running, because WindowServer
    /// restores every table when its process dies; otherwise the trusted state's switch.
    public static func controlValue(word: UInt64, snapshot: State?, appIsRunning: Bool) -> Bool {
        guard appIsRunning else { return false }
        let state = currentState(word: word, snapshot: snapshot)
        return state.isValid && state.isOn
    }

    /// After a hand-off, waits until `read()` reports a valid state whose switch is `on`, re-reading every `interval`
    /// for at most `timeout`. True when it did; false on timeout or cancellation.
    public static func waitForState(on: Bool, timeout: Duration = handOffWait, interval: Duration = handOffPollInterval,
                                    read: () -> State, sleep: (Duration) async throws -> Void) async -> Bool {
        var waited = Duration.zero
        while true {
            let state = read()
            if state.isValid && state.isOn == on { return true }
            guard interval > .zero, timeout > waited else { return false }
            do { try await sleep(interval) } catch { return false }
            waited += interval
        }
    }
}

private extension String {
    /// The string with leading zeros up to `width` characters.
    func leftPadded(to width: Int) -> String { count >= width ? self : String(repeating: "0", count: width - count) + self }
}
