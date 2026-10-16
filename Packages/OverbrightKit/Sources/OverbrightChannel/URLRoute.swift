// OverbrightChannel/URLRoute.swift — the `overbright://` routes. ARCHITECTURE.md §7.7, §10.0 (Channel seam); D25.
// Seam written by WP0a: the cases and `parse(_:)` are fixed; WP8 writes the parser (token check, on/off, malformed
// URLs). The WP0a parser accepts nothing.
import Foundation

/// What an `overbright://` URL asks for. Nothing else is accepted.
public enum URLRoute: Hashable, Sendable {
    /// `overbright://control?set=on|off[&token=…]`: `off` is always accepted, `on` needs the app's token. Both still
    /// go through the policy.
    case control(on: Bool, token: String?)
    /// `overbright://settings[/<pane>]`: opens Settings (at a pane).
    case settings(pane: String?)

    /// The route of `url`, or nil when it is not one of ours or is malformed. WP0a seam: always nil.
    public static func parse(_ url: URL) -> URLRoute? { nil }
}
