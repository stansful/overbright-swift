// OverbrightDesign/Theme/RightToLeft.swift — the right-to-left rules every surface follows. DESIGN.md §2.0 rule 4,
// §5.5 ("Right to left"), §16; ARCHITECTURE.md §8.8. Ported from Cranny's RightToLeft.swift (the owner's MIT code).
//
// In a right-to-left language (Arabic, Hebrew) AppKit hands every hosting view a right-to-left layout and SwiftUI
// mirrors it: stacks run from the right, `.leading` is the right edge, `offset(x:)` counts from the right and custom
// `Shape`s are drawn mirrored. Input is NOT mirrored: a gesture's location and translation, scroll deltas and every
// AppKit coordinate stay physical (left to right), so code that turns a pointer position into a layout position
// converts it here. The panel, the cards, the slider and the footer mirror; the status symbol does not (a sun has no
// direction).
import Foundation
import SwiftUI

public extension LayoutDirection {
    /// A physical horizontal distance (pointer travel, a gesture's translation, left to right) as a distance along
    /// this layout (leading to trailing), and back again: the same number left to right, negated right to left.
    nonisolated func alongLayout(_ physical: CGFloat) -> CGFloat { self == .rightToLeft ? -physical : physical }

    /// The fraction (0…1) of a `width`-wide control at physical `x` (a gesture's location: 0 = the left edge),
    /// measured from the layout's leading edge (where the slider's dim end is).
    nonisolated func fraction(atPhysicalX x: CGFloat, width: CGFloat) -> Double {
        let f = Double(min(max(x / max(width, 1), 0), 1))
        return self == .rightToLeft ? 1 - f : f
    }

    /// The step along the layout of ← (`-1` left to right) or → (`+1`), so the arrow keys move toward the side they
    /// point at: in a right-to-left slider (boost on the left) ← raises the level. Nil for any other key.
    nonisolated func step(for key: KeyEquivalent) -> Int? {
        let physical: Int
        switch key {
        case .leftArrow: physical = -1
        case .rightArrow: physical = 1
        default: return nil
        }
        return self == .rightToLeft ? -physical : physical
    }
}

/// Unicode bidirectional isolation for a name put into a sentence (a display, an app, a key combination): between
/// FIRST STRONG ISOLATE and POP DIRECTIONAL ISOLATE (Unicode TR9) the inserted text takes its direction from its own
/// first letter and cannot reorder the sentence around it. Both marks are invisible and take no width; VoiceOver skips
/// them.
public nonisolated enum BidiIsolation {
    /// U+2068 FIRST STRONG ISOLATE.
    public static let firstStrongIsolate: Character = "\u{2068}"
    /// U+2069 POP DIRECTIONAL ISOLATE.
    public static let popDirectionalIsolate: Character = "\u{2069}"

    /// `text` isolated (empty text stays empty; text that is already isolated is returned as it is).
    public static func isolate(_ text: String) -> String {
        guard !text.isEmpty, text.first != firstStrongIsolate else { return text }
        return String(firstStrongIsolate) + text + String(popDirectionalIsolate)
    }
}

public extension String {
    /// This text as one bidirectional isolate, for putting into a localized sentence (`BidiIsolation`).
    nonisolated var overbrightIsolated: String { BidiIsolation.isolate(self) }
}
