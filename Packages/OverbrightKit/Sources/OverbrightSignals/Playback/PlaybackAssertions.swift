// OverbrightSignals/Playback/PlaybackAssertions.swift — "is this process playing video or presenting?"
// ARCHITECTURE.md §6.5 (`whilePlaying` rules), §7.1 ("Playing video"), §7.3 (full-screen video, OLED idle).
// `IOPMCopyAssertionsByProcess` lists every power assertion by PID in ≈ 1.2 ms with no permission [VERIFIED]. Players and
// browsers hold `PreventUserIdleDisplaySleep` (or the legacy `NoDisplaySleepAssertion`) while playing; which ones do is
// hardware question H-P1, so the rules that use it are marked beta. There is no per-process change notification: the
// full-screen check reads it on its own triggers (events and the 2 s re-check while boosted).
// Thread: any (the read is a synchronous IOKit call; the parsing is pure).
import Foundation
import IOKit.pwr_mgt

/// Parses and reads display-sleep assertions.
nonisolated enum PlaybackAssertions {
    /// `kIOPMAssertionTypeKey` in each assertion dictionary.
    static let typeKey = "AssertType"
    /// `kIOPMAssertionTypePreventUserIdleDisplaySleep` and the legacy `kIOPMAssertionTypeNoDisplaySleep`: "keeps the
    /// display awake" = playing video or presenting.
    static let displaySleepTypes: Set<String> = ["PreventUserIdleDisplaySleep", "NoDisplaySleepAssertion"]

    /// The PIDs that hold a display-sleep assertion.
    static func holders(_ typesByProcess: [Int32: [String]]) -> Set<Int32> {
        Set(typesByProcess.filter { !displaySleepTypes.isDisjoint(with: $0.value) }.keys)
    }

    /// The assertion types per PID from `IOPMCopyAssertionsByProcess`'s dictionary (keys: PIDs as numbers; values:
    /// arrays of assertion dictionaries). Entries of any other shape are skipped.
    static func types(fromAssertionsByProcess raw: NSDictionary) -> [Int32: [String]] {
        var result: [Int32: [String]] = [:]
        for (key, value) in raw {
            guard let number = key as? NSNumber, let assertions = value as? [NSDictionary] else { continue }
            let types = assertions.compactMap { $0[typeKey] as? String }
            result[number.int32Value, default: []].append(contentsOf: types)
        }
        return result
    }

    /// The display-sleep holders now; nil when the read fails (a `whilePlaying` rule then behaves as
    /// `whileFrontmost`, §6.5).
    static func read() -> Set<Int32>? {
        var byProcess: Unmanaged<CFDictionary>?
        guard IOPMCopyAssertionsByProcess(&byProcess) == kIOReturnSuccess,
              let dictionary = byProcess?.takeRetainedValue() as NSDictionary? else { return nil }
        return holders(types(fromAssertionsByProcess: dictionary))
    }
}
