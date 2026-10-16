// OverbrightAppShellTests — placeholder until its owner (WP0a) adds the suites of ARCHITECTURE.md §2.1, §7.4, §7.6, §10.0.
import Testing
@testable import OverbrightAppShell

@Suite struct AppShellPlaceholderTests {
    @Test func moduleLinks() {
        #expect(OverbrightAppShellModule.name == "OverbrightAppShell")
    }
}
