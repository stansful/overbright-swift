// OverbrightDesign/Copy/MiddleTruncation.swift — an app name cut in the middle to fit a width, for a sentence that may
// grow in height but must not grow without bound for one long name. DESIGN.md §5.7, §5.8: app names are
// middle-truncated, with the full name in the help tag and VoiceOver. Measured in the sentence's own font, never
// counted (ARCHITECTURE.md §8.8).
import Foundation

extension String {
    /// This name cut in the middle with "…" so that it takes at most `width` points in `font` on one line; a name that
    /// fits comes back as it is. Cuts fall between characters (grapheme clusters), never inside one, and drop the
    /// spaces next to the ellipsis. Bidi-isolate the result (`overbrightIsolated`) before putting it into a sentence.
    nonisolated func overbrightMiddleTruncated(toFit width: CGFloat, in font: OverbrightFont) -> String {
        guard font.width(of: self) > width else { return self }
        let characters = Array(self)
        func cut(keeping count: Int) -> String {
            var head = characters.prefix((count + 1) / 2)
            var tail = characters.suffix(count / 2)
            while head.last?.isWhitespace == true { head = head.dropLast() }
            while tail.first?.isWhitespace == true { tail = tail.dropFirst() }
            return String(head) + "…" + String(tail)
        }
        // The most characters that still fit (widths grow with every character kept).
        var (low, high) = (0, characters.count - 1)
        while low < high {
            let middle = (low + high + 1) / 2
            if font.width(of: cut(keeping: middle)) <= width { low = middle } else { high = middle - 1 }
        }
        return cut(keeping: low)
    }
}
