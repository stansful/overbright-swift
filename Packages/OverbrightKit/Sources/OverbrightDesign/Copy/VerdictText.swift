// OverbrightDesign/Copy/VerdictText.swift — a display's verdict in words. DESIGN.md §12.1.
// Seam written by WP0a (ARCHITECTURE.md §10.0): the type and `make(_:advisories:lastGrant:)` are fixed; WP9 writes
// the copy (Safe-limit variants included).
import OverbrightCore

/// The badge, sentence, advisory lines and fix of a display verdict (Settings ▸ Displays, Welcome, "Why?" rows).
public struct VerdictText: Hashable, Sendable {
    /// The badge ("Supported", "HDR is off").
    public var badge: String
    /// The verdict sentence.
    public var sentence: String
    /// One line per advisory, in order.
    public var advisories: [String]
    /// The fix button's title ("Open System Settings", "Choose Peak…"), if the verdict has one.
    public var fixTitle: String?

    /// A verdict text.
    public init(badge: String, sentence: String, advisories: [String], fixTitle: String?) {
        self.badge = badge; self.sentence = sentence; self.advisories = advisories; self.fixTitle = fixTitle
    }

    /// The words for `verdict`. `lastGrant` is the largest grant macOS gave this display, once one was seen; the
    /// potential-derived figure never appears here (D8). WP0a stub: empty text.
    public static func make(_ verdict: DisplayVerdict, advisories: [Advisory], lastGrant: Double?) -> VerdictText {
        _ = (verdict, advisories, lastGrant)
        return VerdictText(badge: "", sentence: "", advisories: [], fixTitle: nil)
    }
}
