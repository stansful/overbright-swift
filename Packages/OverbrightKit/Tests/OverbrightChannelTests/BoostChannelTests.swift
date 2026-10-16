// OverbrightChannelTests/BoostChannelTests.swift — the control's state channel (ARCHITECTURE.md §7.7, D25): pack and
// unpack properties over 10 000 seeded states, the fixed bit layout (app and extension may come from different builds),
// garbled words, the snapshot and the token in a store, the liveness gate and the wait after a hand-off.
// No test writes the real preferences domain or posts the real notify name.
import Foundation
import OverbrightTestSupport
import Testing
@testable import OverbrightChannel

@Suite struct BoostChannelTests {
    private typealias State = BoostChannel.State

    @Test func everyValidStateSurvivesPackAndUnpack() {
        var generator = SeededGenerator(seed: 0x0B21_E7)
        for _ in 0..<10_000 {
            let state = State(isValid: true, isOn: Bool.random(using: &generator),
                              levelPermille: Int.random(in: 0...1000, using: &generator),
                              generation: UInt32.random(in: .min ... .max, using: &generator))
            let word = BoostChannel.pack(state)
            #expect(word != 0)
            #expect(BoostChannel.unpack(word) == state)
        }
    }

    @Test func theBitLayoutIsFixed() {
        // bit 0 on · bit 1 valid · bits 16–31 level · bits 32–63 generation: a newer app and an older extension agree.
        let state = State(isValid: true, isOn: true, levelPermille: 1000, generation: 0xDEAD_BEEF)
        #expect(BoostChannel.pack(state) == 0xDEAD_BEEF_03E8_0003)
        #expect(BoostChannel.pack(State(isValid: true, isOn: false, levelPermille: 0, generation: 0)) == 0b10)
        #expect(BoostChannel.unpack(0x0000_0007_01F4_0003) == State(isValid: true, isOn: true, levelPermille: 500, generation: 7))
    }

    @Test func statesThatAreNotValidPackToZero() {
        #expect(BoostChannel.pack(.invalid) == 0)
        #expect(BoostChannel.pack(State(isValid: false, isOn: true, levelPermille: 500, generation: 9)) == 0)
        #expect(BoostChannel.unpack(0) == .invalid)
    }

    @Test func garbledWordsReadAsNotValid() {
        var generator = SeededGenerator(seed: 7)
        for _ in 0..<10_000 {
            let word = UInt64.random(in: .min ... .max, using: &generator)
            let unpacked = BoostChannel.unpack(word)
            let validBit = word & 0b10 != 0
            let reserved = word & 0xFFFC != 0
            let level = (word >> 16) & 0xFFFF
            #expect(unpacked.isValid == (validBit && !reserved && level <= 1000))
            if !unpacked.isValid { #expect(unpacked == .invalid) }
        }
        #expect(BoostChannel.unpack(0x0000_0001_03E9_0003) == .invalid)   // level 1001
        #expect(BoostChannel.unpack(0x0000_0001_0000_0007) == .invalid)   // reserved bit 2
        #expect(BoostChannel.unpack(0x0000_0001_0000_0001) == .invalid)   // on without the valid bit
    }

    @Test func packingClampsTheLevel() {
        #expect(BoostChannel.unpack(BoostChannel.pack(State(isValid: true, isOn: true, levelPermille: -5, generation: 1))).levelPermille == 0)
        #expect(BoostChannel.unpack(BoostChannel.pack(State(isValid: true, isOn: true, levelPermille: 5000, generation: 1))).levelPermille == 1000)
    }

    @Test func theSnapshotRoundTripsThroughAStore() {
        let store = InMemoryChannelStore()
        #expect(BoostChannel.readSnapshot(from: store) == nil)
        let state = State(isValid: true, isOn: true, levelPermille: 250, generation: 42)
        BoostChannel.writeSnapshot(state, to: store)
        #expect(BoostChannel.readSnapshot(from: store) == state)
        #expect(store.contents[BoostChannel.snapshotKey] == String(BoostChannel.pack(state)))
        BoostChannel.writeSnapshot(.invalid, to: store)
        #expect(BoostChannel.readSnapshot(from: store) == .invalid)
        store.set("not a word", forKey: BoostChannel.snapshotKey)
        #expect(BoostChannel.readSnapshot(from: store) == nil)
    }

    @Test func theChannelKeysStayOutsideTheSettingsPrefix() {
        // Reset All removes every "overbright." key; the token must survive it, or the control could never turn on.
        #expect(!BoostChannel.snapshotKey.hasPrefix("overbright."))
        #expect(!BoostChannel.tokenKey.hasPrefix("overbright."))
        #expect(BoostChannel.snapshotKey != BoostChannel.tokenKey)
    }

    @Test func theTokenIsMadeOnceAndKept() {
        let store = InMemoryChannelStore()
        #expect(BoostChannel.token(in: store) == nil)
        let token = BoostChannel.ensureToken(in: store)
        #expect(BoostChannel.isWellFormedToken(token))
        #expect(BoostChannel.token(in: store) == token)
        #expect(BoostChannel.ensureToken(in: store) == token)
        store.set("short", forKey: BoostChannel.tokenKey)
        #expect(BoostChannel.token(in: store) == nil)
        let replacement = BoostChannel.ensureToken(in: store)
        #expect(replacement != "short" && BoostChannel.isWellFormedToken(replacement))
    }

    @Test func tokensAreRandomHex() {
        let a = BoostChannel.makeToken(), b = BoostChannel.makeToken()
        #expect(a != b)
        #expect(BoostChannel.isWellFormedToken(a) && BoostChannel.isWellFormedToken(b))
        var first = SeededGenerator(seed: 3), second = SeededGenerator(seed: 3)
        #expect(BoostChannel.makeToken(using: &first) == BoostChannel.makeToken(using: &second))
        #expect(!BoostChannel.isWellFormedToken(String(repeating: "G", count: 64)))
        #expect(!BoostChannel.isWellFormedToken(String(repeating: "A", count: 64)))      // lowercase only
        #expect(!BoostChannel.isWellFormedToken(String(repeating: "a", count: 63)))
    }

    @Test func theControlIsOffWheneverTheAppIsNotRunning() {
        let on = BoostChannel.pack(State(isValid: true, isOn: true, levelPermille: 500, generation: 2))
        let off = BoostChannel.pack(State(isValid: true, isOn: false, levelPermille: 0, generation: 3))
        let onSnapshot = State(isValid: true, isOn: true, levelPermille: 0, generation: 1)
        #expect(!BoostChannel.controlValue(word: on, snapshot: onSnapshot, appIsRunning: false))
        #expect(BoostChannel.controlValue(word: on, snapshot: nil, appIsRunning: true))
        #expect(!BoostChannel.controlValue(word: off, snapshot: onSnapshot, appIsRunning: true))      // the word wins
        #expect(BoostChannel.controlValue(word: 0, snapshot: onSnapshot, appIsRunning: true))         // snapshot fallback
        #expect(!BoostChannel.controlValue(word: 0, snapshot: .invalid, appIsRunning: true))
        #expect(!BoostChannel.controlValue(word: 0, snapshot: nil, appIsRunning: true))
    }

    @Test func theHandOffWaitEndsWhenTheStateFollows() async {
        var reads = 0
        var slept: [Duration] = []
        let followed = await BoostChannel.waitForState(on: true, read: {
            reads += 1
            return reads < 4 ? .invalid : State(isValid: true, isOn: true, levelPermille: 0, generation: 9)
        }, sleep: { slept.append($0) })
        #expect(followed)
        #expect(reads == 4)
        #expect(slept == Array(repeating: BoostChannel.handOffPollInterval, count: 3))
    }

    @Test func theHandOffWaitGivesUpAfterOneSecond() async {
        var slept = Duration.zero
        let off = State(isValid: true, isOn: false, levelPermille: 0, generation: 1)
        let followed = await BoostChannel.waitForState(on: true, read: { off }, sleep: { slept += $0 })
        #expect(!followed)
        #expect(slept == BoostChannel.handOffWait)
    }

    @Test func theHandOffWaitStopsWhenCancelled() async {
        let followed = await BoostChannel.waitForState(on: false, read: { .invalid },
                                                       sleep: { _ in throw CancellationError() })
        #expect(!followed)
    }

    @Test func theNotifyWordRoundTripsThroughNotifyd() {
        // A name of this test's own: the real `BoostChannel.notifyName` is never posted by a test.
        let word = NotifyStateWord(name: "app.overbright.Overbright.tests.\(UUID().uuidString)")
        #expect(word.name != BoostChannel.notifyName)
        #expect(word.read() == 0)
        let packed = BoostChannel.pack(State(isValid: true, isOn: true, levelPermille: 125, generation: 77))
        #expect(word.post(packed))
        #expect(word.read() == packed)
        #expect(BoostChannel.unpack(word.read()).levelPermille == 125)
    }
}
