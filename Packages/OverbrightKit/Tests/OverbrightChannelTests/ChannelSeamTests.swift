// OverbrightChannelTests/ChannelSeamTests.swift — the Channel seam (ARCHITECTURE.md §7.7, §10.0, D25): the names WP8
// fills. Until then every word reads as "not valid" (the control shows off) and no URL is accepted.
import Foundation
import Testing
@testable import OverbrightChannel

@Suite struct ChannelSeamTests {
    @Test func theSeamIsNeutral() throws {
        #expect(BoostChannel.notifyName == "app.overbright.Overbright.state")
        let state = BoostChannel.State(isValid: true, isOn: true, levelPermille: 500, generation: 1)
        #expect(BoostChannel.unpack(BoostChannel.pack(state)) == .invalid)
        #expect(BoostChannel.readSnapshot() == nil)
        let url = try #require(URL(string: "overbright://control?set=off"))
        #expect(URLRoute.parse(url) == nil)
    }
}
