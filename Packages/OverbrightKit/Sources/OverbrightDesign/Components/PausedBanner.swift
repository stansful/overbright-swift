// OverbrightDesign/Components/PausedBanner.swift — the panel's one banner. DESIGN.md §5.8, §12.3.
// Seam written by WP0a (ARCHITECTURE.md §10.0): the initializer is fixed; WP9 builds the real banner (tinted card,
// 14-pt glyph, up to three lines, text buttons, `bannerIn` / `bannerOut`).
import SwiftUI

/// A banner for a reason that applies to every display, with up to two text buttons (primary first).
public struct PausedBanner: View {
    private let model: BannerModel
    private let primary: (() -> Void)?
    private let secondary: (() -> Void)?

    /// A banner for `model`; `primary` and `secondary` run its buttons (a button shows only with its title and action).
    public init(_ model: BannerModel, primary: (() -> Void)?, secondary: (() -> Void)?) {
        self.model = model; self.primary = primary; self.secondary = secondary
    }

    /// WP0a placeholder: glyph, sentence and buttons in a row.
    public var body: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            Label { Text(verbatim: model.sentence) } icon: { Image(symbol: model.symbol).foregroundStyle(model.color.color) }
            HStack {
                Spacer()
                if let title = model.secondaryTitle, let secondary { Button(action: secondary) { Text(verbatim: title) } }
                if let title = model.primaryTitle, let primary { Button(action: primary) { Text(verbatim: title) } }
            }
        }
        .padding(Space.l)
        .background(model.color.tint, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
    }
}
