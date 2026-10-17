// OverbrightAppShell/HUD/HUDView.swift — the HUD's content: a 20-pt glyph; the display name on its own line (only with
// two or more displays, the full text width, middle-truncated only beyond it) above the value in canonical units and a
// 150-pt level bar drawn like the slider (the track, the Standard detent, the dim fill left, the warm fill right, no
// thumb, in the theme's palette, so Increase Contrast draws it as the slider does) or, for reasons, one line instead of
// the value and the bar. DESIGN.md §6, §2.1 (the warm colour only while extra light is on screen), §2.2 (`hudValue`,
// `hudLabel`), §12.9, §15. The words are Design's (`HUDText`).
import OverbrightCore
import OverbrightDesign
import SwiftUI

/// The HUD's content.
struct HUDView: View {
    /// What it says.
    let text: HUDText
    /// The level the bar shows (nil: no bar).
    let level: LevelPosition?
    /// Extra light is on screen (the bar's boost fill is warm only then).
    let isBoosting: Bool
    /// Receives the frames of the name, the value and the bar (layout tests; nil in the app, where nothing is measured).
    var layoutReport: (@MainActor (LayoutPart, CGRect) -> Void)? = nil

    /// A line whose frame `layoutReport` receives, in the HUD's 280 × 56-pt coordinate space.
    enum LayoutPart: Hashable { case name, value, bar }
    /// The name of the HUD's coordinate space.
    nonisolated static let coordinateSpace = "HUDView"

    /// The level bar's width.
    static let barWidth: CGFloat = 150
    /// The widest text (DESIGN.md §16: HUD text ≤ 200 pt).
    static let textWidth: CGFloat = 200
    /// The leading glyph's column.
    static let glyphColumn: CGFloat = 24

    var body: some View {
        HStack(spacing: Space.m) {
            Image(symbol: text.symbol)
                .font(.system(size: GlyphSize.hud))
                .frame(width: Self.glyphColumn)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Space.xs) {
                if let name = text.displayName { nameLabel(name) }
                if let reason = text.reason {
                    Text(verbatim: reason)
                        .font(OverbrightFont.hudLabel.font)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: Self.textWidth, alignment: .leading)
                } else {
                    if let value = text.value {
                        Text(verbatim: value)
                            .font(OverbrightFont.hudValue.font)
                            .lineLimit(1)
                            .modifier(HUDLayoutReporting(part: .value, report: layoutReport))
                            .frame(maxWidth: Self.textWidth, alignment: .leading)
                    }
                    if let level {
                        HUDLevelBar(level: level, isBoosting: isBoosting)
                            .frame(width: Self.barWidth, height: StrokeWidth.trackDragging)
                            .modifier(HUDLayoutReporting(part: .bar, report: layoutReport))
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, Space.l)
        .frame(width: HUDPlacement.size.width, height: HUDPlacement.size.height)
        .coordinateSpace(.named(Self.coordinateSpace))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: text.announcement))
    }

    private func nameLabel(_ name: String) -> some View {
        Text(verbatim: name)
            .font(OverbrightFont.hudLabel.font)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .truncationMode(.middle)
            .modifier(HUDLayoutReporting(part: .name, report: layoutReport))
            .frame(maxWidth: Self.textWidth, alignment: .leading)
    }
}

/// Sends a line's frame in the HUD to `report`, only when there is one (layout tests).
private struct HUDLayoutReporting: ViewModifier {
    let part: HUDView.LayoutPart
    let report: (@MainActor (HUDView.LayoutPart, CGRect) -> Void)?

    func body(content: Content) -> some View {
        if let report {
            content.onGeometryChange(for: CGRect.self) { proxy in
                proxy.frame(in: .named(HUDView.coordinateSpace))
            } action: { report(part, $0) }
        } else {
            content
        }
    }
}

/// The level bar, drawn like the slider (`BoostSliderTrack`'s tokens): the track, the dim fill left of the detent,
/// the warm fill right of it while extra light is on screen (else the dim fill's neutral mark), the Standard detent.
struct HUDLevelBar: View {
    let level: LevelPosition
    let isBoosting: Bool
    @Environment(\.overbright) private var theme

    var body: some View {
        GeometryReader { proxy in
            let half = proxy.size.width / 2
            let height = proxy.size.height
            ZStack(alignment: .leading) {
                ZStack(alignment: .leading) {
                    Rectangle().fill(theme.color(.track))
                    if level.isDim {
                        Rectangle().fill(theme.color(.dimFill))
                            .frame(width: half * CGFloat(-level.value), height: height)
                            .offset(x: half * CGFloat(1 + level.value))
                    } else if level.isBoost {
                        Rectangle().fill(isBoosting ? theme.color(.boostWarm) : theme.color(.dimFill))
                            .frame(width: half * CGFloat(level.value), height: height)
                            .offset(x: half)
                    }
                }
                .clipShape(Capsule(style: .continuous))
                Rectangle().fill(theme.color(.detentMark))
                    .frame(width: StrokeWidth.detent.width, height: StrokeWidth.detent.height)
                    .offset(x: half - StrokeWidth.detent.width / 2)
            }
        }
        .accessibilityHidden(true)
    }
}

/// The HUD window's root: `HUDView` of a drawing under the theme root. One type for every drawing, so a showing keeps
/// one hosting view and redraws only hand it a new root (`HUDController`).
struct HUDRoot: View {
    /// What the HUD draws.
    let drawing: HUDController.Drawing

    var body: some View {
        HUDView(text: drawing.text, level: drawing.level, isBoosting: drawing.isBoosting).overbrightThemeRoot()
    }
}

#Preview("HUD · boosting, two displays") {
    HUDView(text: HUDText(symbol: .sunMaxFill, displayName: "Built-in Liquid Retina XDR Display",
                          value: "Bright room · ≈ ×1.29", reason: nil, announcement: "Bright room, about 1.29 times"),
            level: LevelPreset.brightRoom.position, isBoosting: true)
        .overbrightThemeRoot()
}

#Preview("HUD · dimmed") {
    HUDView(text: HUDText(symbol: .sunMin, displayName: nil, value: "Dimmed · 25 %", reason: nil,
                          announcement: "Dimmed, 25 percent"),
            level: LevelPosition(-0.5), isBoosting: false)
        .overbrightThemeRoot()
}

#Preview("HUD · a reason") {
    HUDView(text: HUDText(symbol: .pauseFill, displayName: nil, value: nil, reason: "Paused: battery below 20 %",
                          announcement: "Paused: battery below 20 %"),
            level: nil, isBoosting: false)
        .overbrightThemeRoot()
}
