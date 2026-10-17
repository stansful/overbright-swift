// OverbrightPanelUITests/Support/FitMeasure.swift — measured widths for the fit tests (ARCHITECTURE.md §8.8: width rules
// are measured, never counted) and the pseudo-long locale of phase B (+40 %); WP15 measures every shipped language too.
// Nothing is ordered in: views are measured in an `NSHostingView` that has no window.
import AppKit
import SwiftUI

/// Width measurement of rendered SwiftUI content.
@MainActor enum FitMeasure {
    /// The width `view` asks for when unconstrained (its ideal width).
    static func idealWidth(_ view: some View) -> CGFloat {
        NSHostingView(rootView: view.fixedSize()).fittingSize.width
    }

    /// The height `view` asks for when unconstrained (its ideal height).
    static func idealHeight(_ view: some View) -> CGFloat {
        NSHostingView(rootView: view.fixedSize()).fittingSize.height
    }

    /// The width `view` takes when offered `width` (what a layout with that budget draws).
    static func width(_ view: some View, offered width: CGFloat) -> CGFloat {
        let host = NSHostingView(rootView: view.frame(maxWidth: width, alignment: .leading).fixedSize(horizontal: false,
                                                                                                    vertical: true))
        host.frame = CGRect(x: 0, y: 0, width: width, height: 200)
        host.layoutSubtreeIfNeeded()
        return host.fittingSize.width
    }

    /// The text width of `text` in `font`.
    static func textWidth(_ text: String, _ font: Font) -> CGFloat {
        idealWidth(Text(verbatim: text).font(font).lineLimit(1))
    }
}

/// The pseudo-long locale: every letter accented (so glyph coverage is exercised) and the text lengthened by 40 %,
/// the margin a translation may need (DESIGN.md §16: Russian runs 15–35 % longer).
enum PseudoLocale {
    /// The growth of the pseudo-long locale.
    static let growth = 0.4

    /// `text` in the pseudo-long locale; numbers, the multiplication sign and separators stay as they are.
    static func lengthen(_ text: String) -> String {
        guard !text.isEmpty else { return text }
        let accented = String(text.map { accents[$0] ?? $0 })
        let letters = text.filter(\.isLetter).count
        let padding = Int((Double(max(letters, 1)) * growth).rounded(.up))
        return accented + String(repeating: "ŵ", count: padding / 2) + String(repeating: "é", count: padding - padding / 2)
    }

    private static let accents: [Character: Character] = [
        "a": "á", "e": "ë", "i": "ï", "o": "ö", "u": "ü", "y": "ÿ", "c": "ç", "n": "ñ",
        "A": "Å", "E": "É", "I": "Î", "O": "Ø", "U": "Ü", "C": "Ç", "N": "Ñ",
    ]
}
