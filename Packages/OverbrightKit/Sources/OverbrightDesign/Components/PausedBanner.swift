// OverbrightDesign/Components/PausedBanner.swift — the panel's one banner. DESIGN.md §5.8, §12.3, §12.7.
// Seam written by WP0a (ARCHITECTURE.md §10.0): the initializer is fixed. The card fill tinted 10 % with the semantic
// colour, a 14-pt glyph, the sentence (`banner`, up to three lines) and up to two text buttons, primary first. Banners
// reflect state, so they have no close button; they arrive with `bannerIn` and leave with `bannerOut`.
import OverbrightCore
import SwiftUI

/// A banner for a reason that applies to every display, with up to two text buttons (primary first).
public struct PausedBanner: View {
    private let model: BannerModel
    private let primary: (() -> Void)?
    private let secondary: (() -> Void)?
    @Environment(\.overbright) private var theme

    /// A banner for `model`; `primary` and `secondary` run its buttons (a button shows only with its title and action).
    public init(_ model: BannerModel, primary: (() -> Void)?, secondary: (() -> Void)?) {
        self.model = model; self.primary = primary; self.secondary = secondary
    }

    /// The banner.
    public var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Space.m) {
            Image(symbol: model.symbol)
                .font(.system(size: 14))
                .foregroundStyle(model.color.glyph(in: theme))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Space.s) {
                Text(verbatim: model.sentence)
                    .font(OverbrightFont.banner.font)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                if hasButtons {
                    HStack(spacing: Space.l) {
                        Spacer(minLength: 0)
                        if let title = model.primaryTitle, let primary {
                            Button(action: primary) { Text(verbatim: title).font(OverbrightFont.banner.font.weight(.semibold)) }
                                .buttonStyle(LinkButtonStyle())
                        }
                        if let title = model.secondaryTitle, let secondary {
                            Button(action: secondary) { Text(verbatim: title).font(OverbrightFont.banner.font) }
                                .buttonStyle(LinkButtonStyle())
                        }
                    }
                }
            }
        }
        .padding(Space.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            let shape = RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
            shape.fill(theme.color(.card))
                .overlay(shape.fill(model.color.bannerTint))
                .overlay(shape.strokeBorder(theme.color(.cardStroke), lineWidth: StrokeWidth.regular))
        }
        // A group: VoiceOver reads the sentence once (its Text), then the buttons by their titles (DESIGN.md §12.7).
        .accessibilityElement(children: .contain)
        .transition(OverbrightMotion.bannerTransition(reduceMotion: theme.reduceMotion))
    }

    private var hasButtons: Bool {
        (model.primaryTitle != nil && primary != nil) || (model.secondaryTitle != nil && secondary != nil)
    }
}

#Preview("Banners") {
    VStack(spacing: Space.m) {
        PausedBanner(BannerModel.make(.lowPowerMode), primary: {}, secondary: nil)
        PausedBanner(BannerModel.make(.thermalCritical), primary: nil, secondary: nil)
        PausedBanner(BannerModel.make(.focusOff), primary: {}, secondary: nil)
    }
    .padding()
    .frame(width: 320)
    .overbrightThemeRoot()
}
