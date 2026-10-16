// OverbrightUpdates/Transport/URLSessionUpdateTransport.swift — the real transport: an ephemeral session with no
// cookies, no URL cache and no credential storage; nothing persists between checks except the ETag Overbright stores
// itself. Ported from Cranny's UpdateChecker+GitHub.swift (the owner's MIT code). ARCHITECTURE.md §2.1 rule 7, D2.
//
// Thread: `fetch` is `@concurrent` (off the main actor); the session is a thread-safe `static let`.
import Foundation

/// `URLSession`, created on the first request, not with the transport (which exists at every launch, also in builds
/// that have no update check).
nonisolated final class URLSessionUpdateTransport: UpdateTransport {
    /// Built once, lazily and thread-safely, on the first `fetch`.
    private static let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        configuration.urlCache = nil
        configuration.urlCredentialStorage = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = 15
        configuration.timeoutIntervalForResource = 30
        configuration.waitsForConnectivity = false
        return URLSession(configuration: configuration)
    }()

    init() {}

    @concurrent func fetch(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await Self.session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw UpdateFailure.unreadable }
        return (data, http)
    }
}
