// OverbrightUpdates/Transport/UpdateTransport.swift — the single network call, behind a protocol so tests answer with
// fixtures. Ported from Cranny's UpdateChecker+GitHub.swift (the owner's MIT code). D2.
import Foundation

/// Sends one request and returns the body and the HTTP response.
nonisolated protocol UpdateTransport: Sendable {
    /// Fetches `request`; throws for transport errors (the checker reports them as "offline").
    func fetch(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
}
