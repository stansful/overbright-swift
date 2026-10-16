// OverbrightChannel/URLRoute.swift — the `overbright://` routes. ARCHITECTURE.md §7.7, §10.0 (Channel seam); D25.
// The cases and `parse(_:)` are the WP0a seam; the parser, its inverse and the token check are WP8's.
//
// Any web page can try a custom scheme (the browser asks first), so the parser is strict: exactly the two routes,
// no user, password, port or fragment, and no query item it does not know. `set=off` is always accepted; `set=on`
// only with the token the app keeps in its own preferences (`accepts(token:)`). Both still go through the policy.
import Foundation

/// What an `overbright://` URL asks for. Nothing else is accepted.
public enum URLRoute: Hashable, Sendable {
    /// `overbright://control?set=on|off[&token=…]`: `off` is always accepted, `on` needs the app's token. Both still
    /// go through the policy.
    case control(on: Bool, token: String?)
    /// `overbright://settings[/<pane>]`: opens Settings (at a pane).
    case settings(pane: String?)

    /// The URL scheme (registered in every build, `App/Info.plist`).
    public static let scheme = "overbright"

    /// The route of `url`, or nil when it is not one of ours or is malformed.
    public static func parse(_ url: URL) -> URLRoute? {
        guard url.scheme?.lowercased() == scheme,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.user == nil, components.password == nil, components.port == nil, components.fragment == nil,
              let host = components.host?.lowercased()
        else { return nil }
        switch host {
        case "control": return control(components)
        case "settings": return settings(components)
        default: return nil
        }
    }

    /// The URL of this route (the inverse of `parse(_:)`; the extension opens it to hand a request to the app).
    public var url: URL? {
        var components = URLComponents()
        components.scheme = Self.scheme
        switch self {
        case .control(let on, let token):
            components.host = "control"
            components.queryItems = [URLQueryItem(name: "set", value: on ? "on" : "off")]
                + (token.map { [URLQueryItem(name: "token", value: $0)] } ?? [])
        case .settings(let pane):
            components.host = "settings"
            if let pane { components.path = "/" + pane }
        }
        return components.url
    }

    /// Whether the app may act on this route when its own token is `expected`: settings and `set=off` always;
    /// `set=on` only when the URL carries exactly `expected` (compared in constant time).
    public func accepts(token expected: String?) -> Bool {
        switch self {
        case .settings, .control(on: false, _): return true
        case .control(on: true, let token):
            guard let token, let expected, !expected.isEmpty else { return false }
            return Self.constantTimeEqual(Array(token.utf8), Array(expected.utf8))
        }
    }

    // MARK: Private

    private static func control(_ components: URLComponents) -> URLRoute? {
        guard components.path.isEmpty || components.path == "/", let items = components.queryItems else { return nil }
        var on: Bool?
        var token: String?
        for item in items {
            switch item.name {
            case "set":
                guard on == nil else { return nil }
                switch item.value {
                case "on": on = true
                case "off": on = false
                default: return nil
                }
            case "token":
                guard token == nil, let value = item.value, !value.isEmpty else { return nil }
                token = value
            default:
                return nil
            }
        }
        guard let on else { return nil }
        return .control(on: on, token: token)
    }

    private static func settings(_ components: URLComponents) -> URLRoute? {
        guard components.query == nil else { return nil }
        let parts = components.path.split(separator: "/", omittingEmptySubsequences: true)
        switch parts.count {
        case 0: return .settings(pane: nil)
        case 1:
            let pane = String(parts[0])
            return isPaneName(pane) ? .settings(pane: pane) : nil
        default: return nil
        }
    }

    /// A Settings pane name: lowercase ASCII letters, digits and hyphens, starting with a letter, at most 32.
    private static func isPaneName(_ name: String) -> Bool {
        let bytes = Array(name.utf8)
        guard let first = bytes.first, (0x61...0x7A).contains(first), bytes.count <= 32 else { return false }
        return bytes.allSatisfy { (0x61...0x7A).contains($0) || (0x30...0x39).contains($0) || $0 == 0x2D }
    }

    private static func constantTimeEqual(_ a: [UInt8], _ b: [UInt8]) -> Bool {
        guard a.count == b.count else { return false }
        return zip(a, b).reduce(UInt8(0)) { $0 | ($1.0 ^ $1.1) } == 0
    }
}
