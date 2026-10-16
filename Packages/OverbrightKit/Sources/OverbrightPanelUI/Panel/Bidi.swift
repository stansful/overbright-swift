// OverbrightPanelUI/Panel/Bidi.swift — names inside sentences are bidi-isolated, so a Hebrew display name does not
// reorder an English sentence (or the reverse). DESIGN.md §2.0 rule 4, §16; ARCHITECTURE.md §8.8. (Design's shared
// helper arrives with WP9; PanelUI keeps its own two-line version so its strings do not wait for it.)

/// Bidi isolation of names placed inside localized sentences.
nonisolated enum Bidi {
    /// `text` between FIRST STRONG ISOLATE (U+2068) and POP DIRECTIONAL ISOLATE (U+2069).
    static func isolated(_ text: String) -> String { "\u{2068}\(text)\u{2069}" }
}
