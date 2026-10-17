// OverbrightDisplaysTests/OnlineIDsTests.swift — `CoreGraphicsDisplayReader.onlineIDs(list:)` over a scripted
// `CGGetOnlineDisplayList` (ARCHITECTURE.md §10.4 as built; energy D1): one call while fewer displays are online than
// the first call has room for, every display however many there are, nothing on an error. Each call is a WindowServer
// round trip, made on every screen-parameters notification and before every table read or write.
import CoreGraphics
import Testing
@testable import OverbrightDisplays

@Suite struct OnlineIDsTests {
    /// `CGGetOnlineDisplayList` over `online`: a nil buffer asks for the count; otherwise it fills as many IDs as fit.
    private final class ScriptedList {
        let online: [CGDirectDisplayID]
        var error: CGError = .success
        private(set) var calls = 0
        init(count: Int) { online = (0..<count).map { CGDirectDisplayID(0x100 + $0) } }

        func list(_ max: UInt32, _ buffer: UnsafeMutablePointer<CGDirectDisplayID>?,
                  _ count: UnsafeMutablePointer<UInt32>?) -> CGError {
            calls += 1
            guard error == .success else { return error }
            guard let buffer else {
                count?.pointee = UInt32(online.count)
                return .success
            }
            let filled = min(Int(max), online.count)
            for index in 0..<filled { buffer[index] = online[index] }
            count?.pointee = UInt32(filled)
            return .success
        }
    }

    private func read(_ scripted: ScriptedList) -> [CGDirectDisplayID] {
        CoreGraphicsDisplayReader.onlineIDs(list: scripted.list)
    }

    @Test(arguments: [0, 1, 2, CoreGraphicsDisplayReader.onlineListCapacity - 1])
    func fewDisplaysTakeOneCall(count: Int) {
        let scripted = ScriptedList(count: count)
        #expect(read(scripted) == scripted.online)
        #expect(scripted.calls == 1)
    }

    @Test(arguments: [CoreGraphicsDisplayReader.onlineListCapacity, CoreGraphicsDisplayReader.onlineListCapacity + 5])
    func aFullFirstCallCountsAndListsThemAll(count: Int) {
        let scripted = ScriptedList(count: count)
        #expect(read(scripted) == scripted.online)
        #expect(scripted.calls == 3)
    }

    @Test func anErrorListsNothing() {
        let scripted = ScriptedList(count: 2)
        scripted.error = .failure
        #expect(read(scripted).isEmpty)
        #expect(scripted.calls == 1)
    }
}
