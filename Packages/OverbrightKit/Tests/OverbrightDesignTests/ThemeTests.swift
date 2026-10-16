// OverbrightDesignTests/ThemeTests.swift — the theme and the tokens around it (DESIGN.md §2.2–§2.5, §15): palette
// precedence, glass and materials with the 14/15 fallback and Reduce Transparency, typography (nothing below 10 pt,
// rounded monospaced digits for live numbers), radii, hit targets, the concentric focus ring, the hatch.
import AppKit
import OverbrightCore
import SwiftUI
import Testing
@testable import OverbrightDesign

@MainActor @Suite struct ThemeTests {
    @Test func paletteFollowsIncreaseContrastThenReduceTransparency() {
        #expect(OverbrightTheme().palette == .standard)
        #expect(OverbrightTheme(reduceTransparency: true).palette == .opaque)
        #expect(OverbrightTheme(increaseContrast: true).palette == .highContrast)
        #expect(OverbrightTheme(reduceTransparency: true, increaseContrast: true).palette == .highContrast)
    }

    /// Glass on 26+ only with the standard palette; 14/15 get a visual-effect material; Reduce Transparency and
    /// Increase Contrast get an opaque `windowBackgroundColor` (DESIGN.md §2.4).
    @Test func surfacesChooseTheirMaterial() {
        let modern: Bool = { if #available(macOS 26, *) { return true } else { return false } }()
        let standard = OverbrightTheme()
        #expect(SurfaceMaterial.panel.background(for: standard) == (modern ? .glass : .visualEffect(.popover)))
        #expect(SurfaceMaterial.hud.background(for: standard) == (modern ? .glass : .visualEffect(.hudWindow)))
        #expect(SurfaceMaterial.panel.background(for: OverbrightTheme(reduceTransparency: true)) == .opaque)
        #expect(SurfaceMaterial.hud.background(for: OverbrightTheme(increaseContrast: true)) == .opaque)
        #expect(!OverbrightTheme(reduceTransparency: true).usesGlass)
        #expect(SurfaceMaterial.panel.cornerRadius == Radius.panel && SurfaceMaterial.hud.cornerRadius == Radius.hud)
    }

    /// The opaque container never shows a material behind content (built, never shown).
    @Test func theOpaqueContainerHostsItsContent() {
        let content = NSView()
        let container = SurfaceMaterial.panel.makeContainer(content: content, theme: OverbrightTheme(reduceTransparency: true))
        #expect(container is OpaqueSurfaceView)
        #expect(content.superview === container)
        #expect(container.layer?.cornerRadius == Radius.panel)
    }

    @Test func radiiAreConcentric() {
        let modern: Bool = { if #available(macOS 26, *) { return true } else { return false } }()
        #expect(Radius.panel == (modern ? 20 : 16) && Radius.card == (modern ? 12 : 8) && Radius.hud == Radius.panel)
        #expect(Radius.panel - Radius.card == Space.m, "the card is inset 8 pt, so inner = outer − inset")
        #expect(OverbrightFocusRing.ringRadius(for: Radius.control) == Radius.control + 3)
        #expect(StrokeWidth.focusRing == 2)
    }

    /// Nothing below 10 pt; live numbers in SF Pro Rounded with monospaced digits (DESIGN.md §2.2).
    @Test func typography() {
        for style in OverbrightFont.allCases { #expect(style.size >= 10, "\(style)") }
        #expect(Set(OverbrightFont.allCases.filter(\.isLiveNumber)) == [.readout, .valueTag, .hudValue])
        let readout = OverbrightFont.readout.nsFont
        #expect(readout.pointSize == 13)
        #expect(readout.fontName.localizedCaseInsensitiveContains("rounded"), "\(readout.fontName)")
        // Monospaced digits: every digit has the same advance.
        let widths = (0...9).map { OverbrightFont.readout.width(of: "\($0)\($0)\($0)") }
        #expect(Set(widths).count == 1, "\(widths)")
        #expect(OverbrightFont.hudValue.size == 15 && OverbrightFont.banner.size == 12 && OverbrightFont.chip.size == 11)
    }

    @Test func hitTargetsAndSpacing() {
        #expect(HitTarget.minimum.width >= 28 && HitTarget.minimum.height >= 24)
        #expect(HitTarget.sliderThumb == 28 && BoostSliderTrack.thumbSize == 20)
        #expect([Space.xxs, Space.xs, Space.s, Space.m, Space.l, Space.xl, Space.xxl, Space.xxxl, Space.huge]
                == [2, 4, 6, 8, 12, 16, 20, 24, 32])
        #expect(StrokeWidth.detent == CGSize(width: 1.5, height: 8))
        #expect(StrokeWidth.presetTick == CGSize(width: 1, height: 5))
        #expect(StrokeWidth.allowedMarker == CGSize(width: 2, height: 10))
        #expect(StrokeWidth.hairline(scale: 2) == 0.5)
    }

    /// The hatch: parallel 45° lines every 3 pt.
    @Test func theHatchIsFortyFiveDegreeLinesEveryThreePoints() {
        let rect = CGRect(x: 0, y: 0, width: 30, height: 4)
        var segments: [(CGPoint, CGPoint)] = []
        var start: CGPoint?
        HatchPattern().path(in: rect).forEach { element in
            switch element {
            case let .move(to: p): start = p
            case let .line(to: p): if let s = start { segments.append((s, p)) }
            default: break
            }
        }
        #expect(segments.count == 12)
        for (a, b) in segments { #expect(abs((b.x - a.x) - (a.y - b.y)) < 1e-9, "45°") }
        #expect(abs((segments[1].0.x - segments[0].0.x) - 3) < 1e-9)
    }

    /// The root merges a forced base with the environment; views read the theme, not raw flags.
    @Test func theRootPublishesTheMergedTheme() throws {
        let probe = ThemeProbe()
        _ = try render(ThemeProbeView(probe: probe), size: CGSize(width: 10, height: 10),
                       theme: OverbrightTheme(reduceMotion: true), scheme: .dark, direction: .rightToLeft)
        let theme = try #require(probe.theme)
        #expect(theme.reduceMotion && theme.colorScheme == .dark && theme.layoutDirection == .rightToLeft)
    }

    /// The ring shows only for keyboard focus (DESIGN.md §5.12).
    @Test func theFocusRingNeedsTheKeyboard() {
        #expect(OverbrightFocusRing.showsRing(isFocused: true, keyboardActive: true))
        #expect(!OverbrightFocusRing.showsRing(isFocused: true, keyboardActive: false), "focused by a click")
        #expect(!OverbrightFocusRing.showsRing(isFocused: false, keyboardActive: true))
    }

    @Test func keyboardInteractionFollowsTheLastEvent() {
        let keyboard = KeyboardInteraction()
        #expect(!keyboard.isActive)
        keyboard.record(isKey: true)
        #expect(keyboard.isActive)
        keyboard.record(isKey: false)
        #expect(!keyboard.isActive)
    }

    @Test func hapticFeedbackReachesItsPerformer() {
        let played = ThemeProbe()
        let feedback = HapticFeedback { pattern in played.patterns.append("\(pattern)") }
        feedback.play(.alignment)
        HapticFeedback.none.play(.levelChange)
        #expect(played.patterns == ["alignment"])
    }
}

/// Records the theme a view sees.
@MainActor final class ThemeProbe {
    var theme: OverbrightTheme?
    var patterns: [String] = []
}

private struct ThemeProbeView: View {
    let probe: ThemeProbe
    @Environment(\.overbright) private var theme

    var body: some View {
        probe.theme = theme
        return Color.clear
    }
}
