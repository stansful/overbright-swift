// OverbrightAppShell/HUD/HUDView.swift — the HUD's content: a 20-pt glyph; the display name (only with two or more
// displays) above a 150-pt level bar drawn like the slider (detent mark, dim fill left, the warm fill right, no
// thumb) or, for reasons, one line instead of the bar; the value in canonical units. DESIGN.md §6, §2.1 (the warm
// colour only while extra light is on screen), §2.2 (`hudValue`, `hudLabel`), §12.9. The words are Design's
// (`HUDText`).
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

    /// The level bar's width.
    static let barWidth: CGFloat = 150
    /// The widest text (DESIGN.md §16: HUD text ≤ 200 pt).
    static let textWidth: CGFloat = 200

    var body: some View {
        HStack(spacing: Space.m) {
            Image(symbol: text.symbol)
                .font(.system(size: 20))
                .frame(width: 24)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Space.xs) {
                if let name = text.displayName {
                    Text(verbatim: name)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                if let reason = text.reason {
                    Text(verbatim: reason)
                        .font(.system(size: 11))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                } else if let level {
                    HUDLevelBar(level: level, isBoosting: isBoosting)
                        .frame(width: Self.barWidth, height: StrokeWidth.trackDragging)
                }
            }
            .frame(maxWidth: Self.textWidth, alignment: .leading)
            Spacer(minLength: 0)
            if text.reason == nil, let value = text.value {
                Text(verbatim: value)
                    .font(.system(size: 15, weight: .semibold, design: .rounded).monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .padding(.horizontal, Space.l)
        .frame(width: HUDPlacement.size.width, height: HUDPlacement.size.height)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: text.announcement))
    }
}

/// The level bar: the track, the Standard detent, the dim fill left of it and the boost fill right of it.
struct HUDLevelBar: View {
    let level: LevelPosition
    let isBoosting: Bool

    var body: some View {
        GeometryReader { proxy in
            let half = proxy.size.width / 2
            let height = proxy.size.height
            ZStack(alignment: .leading) {
                ZStack(alignment: .leading) {
                    Capsule().fill(BoostColor.track)
                    if level.isDim {
                        Rectangle().fill(BoostColor.mark)
                            .frame(width: half * CGFloat(-level.value), height: height)
                            .offset(x: half * CGFloat(1 + level.value))
                    } else if level.isBoost {
                        Rectangle().fill(isBoosting ? BoostColor.warm : BoostColor.mark)
                            .frame(width: half * CGFloat(level.value), height: height)
                            .offset(x: half)
                    }
                }
                .clipShape(Capsule())
                Rectangle().fill(BoostColor.mark)
                    .frame(width: StrokeWidth.detent.width, height: StrokeWidth.detent.height)
                    .offset(x: half - StrokeWidth.detent.width / 2)
            }
        }
        .accessibilityHidden(true)
    }
}
