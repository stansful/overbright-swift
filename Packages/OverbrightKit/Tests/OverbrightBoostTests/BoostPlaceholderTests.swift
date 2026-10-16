// OverbrightBoostTests — placeholder until its owner (WP4 and WP5) adds the suites of ARCHITECTURE.md §4, §10.6, §10.7.
import Testing
@testable import OverbrightBoost

@Suite struct BoostPlaceholderTests {
    @Test func moduleLinks() {
        #expect(OverbrightBoostModule.name == "OverbrightBoost")
    }
}
