// OverbrightSignalsTests/AssertionParsingTests.swift — display-sleep assertions by process. ARCHITECTURE.md §6.5, §7.1,
// §7.3. The fixture is the owner's Mac while locked with nothing playing (powerd, WindowServer and an Electron app held
// assertions, none of them display-sleep ones), plus players holding the modern and the legacy display-sleep types.
import Foundation
import IOKit.pwr_mgt
import Testing
@testable import OverbrightSignals

@Suite struct AssertionParsingTests {
    /// The shape `IOPMCopyAssertionsByProcess` returns: PIDs as numbers → arrays of assertion dictionaries.
    private func raw(_ entries: [(Int32, [String])]) -> NSDictionary {
        let dictionary = NSMutableDictionary()
        for (pid, types) in entries {
            dictionary[NSNumber(value: pid)] = types.map { ["AssertType": $0, "AssertName": "fixture"] as NSDictionary }
        }
        return dictionary
    }

    @Test func theOwnersIdleMacHoldsNoDisplaySleepAssertion() {
        let recorded = raw([(97, ["PreventUserIdleSystemSleep"]), (415, ["UserIsActive"]),
                            (41105, ["NoIdleSleepAssertion"])])
        let types = PlaybackAssertions.types(fromAssertionsByProcess: recorded)
        #expect(types[415] == ["UserIsActive"])
        #expect(PlaybackAssertions.holders(types).isEmpty)
    }

    @Test func playersHoldingEitherDisplaySleepTypeArePlaying() {
        let types = PlaybackAssertions.types(fromAssertionsByProcess: raw([
            (5000, ["PreventUserIdleSystemSleep", "PreventUserIdleDisplaySleep"]),
            (5001, ["NoDisplaySleepAssertion"]),
            (5002, ["PreventSystemSleep"]),
        ]))
        #expect(PlaybackAssertions.holders(types) == [5000, 5001])
    }

    @Test func malformedEntriesAreSkipped() {
        let dictionary = NSMutableDictionary()
        dictionary["not a pid"] = [["AssertType": "PreventUserIdleDisplaySleep"] as NSDictionary]
        dictionary[NSNumber(value: 7)] = "not an array"
        dictionary[NSNumber(value: 8)] = [["NoType": "x"] as NSDictionary]
        dictionary[NSNumber(value: 9)] = [["AssertType": "PreventUserIdleDisplaySleep"] as NSDictionary]
        let types = PlaybackAssertions.types(fromAssertionsByProcess: dictionary)
        #expect(types == [8: [], 9: ["PreventUserIdleDisplaySleep"]])
        #expect(PlaybackAssertions.holders(types) == [9])
    }

    @Test func theNamesMatchIOKitsConstants() {
        #expect(PlaybackAssertions.typeKey == kIOPMAssertionTypeKey)
        #expect(PlaybackAssertions.displaySleepTypes.contains(kIOPMAssertionTypePreventUserIdleDisplaySleep))
        #expect(PlaybackAssertions.displaySleepTypes.contains(kIOPMAssertionTypeNoDisplaySleep))
        #expect(PlaybackAssertions.displaySleepTypes.count == 2)
    }

    @Test func theLiveReadNeedsNoPermission() {
        // Read-only and permission-free: it must answer (with whatever this Mac holds right now).
        #expect(PlaybackAssertions.read() != nil)
    }
}
