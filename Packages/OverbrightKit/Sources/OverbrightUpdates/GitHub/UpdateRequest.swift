// OverbrightUpdates/GitHub/UpdateRequest.swift — the one request Overbright ever sends. Ported from Cranny's
// UpdateChecker+GitHub.swift (the owner's MIT code); the User-Agent is "Overbright". D2.
import Foundation

/// Builds the update request.
nonisolated enum UpdateRequest {
    /// A GET with GitHub's media type, a fixed product User-Agent (GitHub requires one; it carries no version, machine
    /// or user identifier), the stored ETag when there is one, and no cookies or caches.
    ///
    /// Every header on the wire (captured with a local server on macOS 27 in Cranny): `User-Agent: Overbright`,
    /// `Accept: application/vnd.github+json`, `X-GitHub-Api-Version: 2022-11-28`, `If-None-Match` (only with a cached
    /// ETag), `Accept-Language: en`, plus the system's `Accept-Encoding` (compression) and, over HTTP/1.1,
    /// `Connection`. Accept-Language is pinned because CFNetwork would otherwise send the user's preferred language
    /// (a fingerprinting signal); an explicit value replaces the system's.
    static func make(url: URL, etag: String?) -> URLRequest {
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
        request.httpMethod = "GET"
        request.httpShouldHandleCookies = false
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        request.setValue("Overbright", forHTTPHeaderField: "User-Agent")
        request.setValue("en", forHTTPHeaderField: "Accept-Language")
        if let etag, !etag.isEmpty { request.setValue(etag, forHTTPHeaderField: "If-None-Match") }
        return request
    }
}
