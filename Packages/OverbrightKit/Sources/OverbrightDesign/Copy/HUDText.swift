// OverbrightDesign/Copy/HUDText.swift — the HUD's value or reason line. DESIGN.md §6, §12.9.
// Seam written by WP0a (ARCHITECTURE.md §10.0): the type and `make(_:status:)` are fixed; WP9 writes the copy.
import OverbrightCore

/// What the HUD shows for one change: a level value with its bar, or a reason line instead of the bar.
public struct HUDText: Hashable, Sendable {
    /// The leading glyph.
    public var symbol: OverbrightSymbol
    /// The display name, shown only with two or more displays.
    public var displayName: String?
    /// The value in canonical units ("Bright room · ×1.29"), when the HUD shows a level.
    public var value: String?
    /// The reason line ("Off: timer ended"), when the HUD shows one instead of the bar.
    public var reason: String?
    /// The VoiceOver announcement ("Bright room, 1.29 times").
    public var announcement: String

    /// A HUD text.
    public init(symbol: OverbrightSymbol, displayName: String?, value: String?, reason: String?, announcement: String) {
        self.symbol = symbol; self.displayName = displayName; self.value = value; self.reason = reason
        self.announcement = announcement
    }

    /// The HUD for `change` against the engine's current `status`; nil when the HUD shows nothing for it.
    /// WP0a stub: nothing.
    public static func make(_ change: LevelChange, status: BoostStatus) -> HUDText? {
        _ = (change, status)
        return nil
    }
}
