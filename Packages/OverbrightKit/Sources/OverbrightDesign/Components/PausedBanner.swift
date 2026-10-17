// OverbrightDesign/Components/PausedBanner.swift — the panel's one banner. DESIGN.md §2.2, §5.8, §12.3, §12.7.
// Seam written by WP0a (ARCHITECTURE.md §10.0): the initializer is fixed. The card fill tinted 10 % with the semantic
// colour, a 14-pt glyph, the sentence (`banner`) and up to two text buttons, primary first. The sentence is never cut:
// the banner grows in height for a long translation (the card list below scrolls), and only an app name in it is
// middle-truncated (`BannerModel.nameWidth`), with the full sentence in the help tag and VoiceOver. Banners reflect
// state, so they have no close button; they arrive with `bannerIn` and leave with `bannerOut`.
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
                .font(.system(size: GlyphSize.banner))
                .foregroundStyle(model.color.glyph(in: theme))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Space.s) {
                Text(verbatim: model.sentence)
                    .font(OverbrightFont.banner.font)
                    .fixedSize(horizontal: false, vertical: true)
                    .help(model.accessibilityLabel == model.sentence ? "" : model.accessibilityLabel)
                    .accessibilityLabel(Text(verbatim: model.accessibilityLabel))
                if hasButtons {
                    HStack(spacing: Space.l) {
                        Spacer(minLength: 0)
                        if let title = model.primaryTitle, let primary {
                            Button(action: primary) { Text(verbatim: title).font(OverbrightFont.banner.font.weight(.semibold)) }
                                .buttonStyle(OverbrightLinkButtonStyle())
                        }
                        if let title = model.secondaryTitle, let secondary {
                            Button(action: secondary) { Text(verbatim: title).font(OverbrightFont.banner.font) }
                                .buttonStyle(OverbrightLinkButtonStyle())
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
        PausedBanner(BannerModel.make(.foreignTableAtLaunch), primary: {}, secondary: nil)
        let app = ConflictingApp(entryID: "s1", severity: .booster, bundleID: nil, processID: 1,
                                 displayName: "A Very Long Brightness Utility Name That Goes On")
        PausedBanner(BannerModel.make(.conflict(app)), primary: {}, secondary: nil)
    }
    .padding()
    .frame(width: 320)
    .overbrightThemeRoot()
}
