// OverbrightSettingsUITests/AboutContentTests.swift — Settings ▸ About's GitHub link (DESIGN.md §7.9; D2): shown only
// while the update check is configured, to the page of the repository the check asks, so the link and the update rows
// never disagree.
import Foundation
import Observation
import OverbrightCore
import Testing
@testable import OverbrightSettingsUI

/// An update check with a chosen configuration and repository page.
@MainActor @Observable private final class LinkedUpdates: UpdateChecking {
    var isConfigured: Bool
    var repositoryURL: URL?
    var state: UpdateState = .idle
    init(isConfigured: Bool, repositoryURL: URL?) { self.isConfigured = isConfigured; self.repositoryURL = repositoryURL }
    func checkNow() {}
}

@MainActor @Suite struct AboutContentTests {
    @Test func theGitHubLinkFollowsTheUpdateCheck() throws {
        let page = try #require(URL(string: "https://github.com/octo/overbright"))
        #expect(AboutContent.repository(LinkedUpdates(isConfigured: true, repositoryURL: page)) == page)
        #expect(AboutContent.repository(LinkedUpdates(isConfigured: false, repositoryURL: page)) == nil)
        #expect(AboutContent.repository(LinkedUpdates(isConfigured: true, repositoryURL: nil)) == nil)
        #expect(AboutContent.repository(PreviewUpdateChecking(isConfigured: true)) == nil)    // the port's default
    }

    /// The update row is searchable only when configured, like the link.
    @Test func theUpdateRowIsListedOnlyWhenConfigured() throws {
        let services = OverbrightServices.preview()
        #expect(!AboutContent.rows(services: services).contains { $0.id == AboutContent.updates.id })
        try #require(services.updates as? PreviewUpdateChecking).isConfigured = true
        #expect(AboutContent.rows(services: services).contains { $0.id == AboutContent.updates.id })
    }
}
