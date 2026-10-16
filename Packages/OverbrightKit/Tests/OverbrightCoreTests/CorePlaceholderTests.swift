// OverbrightCoreTests — placeholder until its owner (WP0a) adds the suites of ARCHITECTURE.md §2.1, §3.
import Testing
@testable import OverbrightCore

@Suite struct CorePlaceholderTests {
    @Test func moduleLinks() {
        #expect(OverbrightCoreModule.name == "OverbrightCore")
    }
}
