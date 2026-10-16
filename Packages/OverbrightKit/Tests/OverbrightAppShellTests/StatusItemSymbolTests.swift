// OverbrightAppShellTests/StatusItemSymbolTests.swift — the code-drawn status symbol (DESIGN.md §4.1, D13): six states,
// each an 18 × 18 pt template that differs in SHAPE (Differentiate Without Color, §15): the outlined or filled disc,
// short or long rays, dotted rays, the small disc with dots, and the pause and exclamation badges in the lower trailing
// corner cut free from the sun; each with its VoiceOver label (§12.7). Rendered off screen at 4×.
import AppKit
import OverbrightCore
import Testing
@testable import OverbrightAppShell

@MainActor @Suite struct StatusSymbolTests {
    private static let scale: CGFloat = 4

    /// The symbol of `state` drawn into a 72 × 72 px bitmap.
    private func render(_ state: StatusSymbolState) throws -> NSBitmapImageRep {
        let side = Int(18 * Self.scale)
        let rep = try #require(NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: side, pixelsHigh: side, bitsPerSample: 8,
                                                samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                                colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0))
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        StatusSymbolImage.image(for: state).draw(in: CGRect(x: 0, y: 0, width: side, height: side))
        NSGraphicsContext.restoreGraphicsState()
        return rep
    }

    /// Whether the point (in symbol points, origin bottom-left as drawn) has ink.
    private func inked(_ rep: NSBitmapImageRep, _ x: CGFloat, _ y: CGFloat) -> Bool {
        let px = Int((x * Self.scale).rounded(.down))
        let py = Int(((18 - y) * Self.scale).rounded(.down))       // bitmap rows run top-down
        return (rep.colorAt(x: px, y: py)?.alphaComponent ?? 0) > 0.5
    }

    /// The point at `radius` from the centre, `degrees` counter-clockwise from east.
    private func polar(_ radius: CGFloat, _ degrees: CGFloat) -> (CGFloat, CGFloat) {
        let angle = degrees * .pi / 180
        return (9 + radius * cos(angle), 9 + radius * sin(angle))
    }

    private func inked(_ rep: NSBitmapImageRep, radius: CGFloat, degrees: CGFloat) -> Bool {
        let (x, y) = polar(radius, degrees)
        return inked(rep, x, y)
    }

    @Test func everyStateIsAnEighteenPointTemplate() {
        for state in StatusSymbolState.allCases {
            let image = StatusSymbolImage.image(for: state)
            #expect(image.isTemplate, "\(state)")
            #expect(image.size == CGSize(width: 18, height: 18), "\(state)")
        }
    }

    @Test func everyStateLooksDifferent() throws {
        let images = try StatusSymbolState.allCases.map { try render($0).representation(using: .png, properties: [:]) }
        #expect(Set(images.compactMap { $0 }).count == StatusSymbolState.allCases.count)
    }

    @Test func theDiscIsOutlinedOffFilledOnAndSmallWhileDimming() throws {
        let off = try render(.off), on = try render(.on), preparing = try render(.preparing), dimming = try render(.dimming)
        #expect(!inked(off, 9, 9))                                      // hollow
        #expect(inked(on, 9, 9) && inked(preparing, 9, 9) && inked(dimming, 9, 9))
        #expect(inked(off, radius: 3, degrees: 22.5))                   // the outline (2.0 … 3.5 pt)
        #expect(inked(on, radius: 3, degrees: 22.5))                    // a 3.5-pt disc
        #expect(!inked(dimming, radius: 3, degrees: 22.5))              // a 2.5-pt disc
    }

    @Test func raysAreShortOffLongOnDottedPreparingAndDotsDimming() throws {
        let off = try render(.off), on = try render(.on), preparing = try render(.preparing), dimming = try render(.dimming)
        #expect(inked(on, radius: 8.4, degrees: 0) && !inked(off, radius: 8.4, degrees: 0))      // long vs short rays
        #expect(inked(off, radius: 6.25, degrees: 90))
        #expect(inked(preparing, radius: 6, degrees: 0) && inked(preparing, radius: 7.5, degrees: 0))
        #expect(!inked(preparing, radius: 5, degrees: 0) && inked(on, radius: 5, degrees: 0))   // dots, not a ray
        #expect(inked(dimming, radius: 6.5, degrees: 45) && !inked(dimming, radius: 7.6, degrees: 45))
        #expect(!inked(dimming, radius: 5.4, degrees: 45))
    }

    @Test func badgesSitInTheLowerTrailingCornerCutFreeFromTheSun() throws {
        let off = try render(.off), paused = try render(.paused), attention = try render(.attention)
        // The lower trailing ray of the off sun runs through the badge's clearance; the badges cut it away.
        #expect(inked(off, radius: 6.25, degrees: -45))
        #expect(!inked(paused, radius: 6.25, degrees: -45) && !inked(attention, radius: 6.25, degrees: -45))
        // Pause: two bars with a gap; attention: one bar in the middle.
        #expect(inked(paused, 14.4, 3.5) && inked(paused, 16.6, 3.5) && !inked(paused, 15.5, 3.5))
        #expect(inked(attention, 15.5, 3.5) && inked(attention, 15.5, 0.75) && !inked(attention, 14, 3.5))
        // No badge ink outside the states that have one.
        for state in [StatusSymbolState.off, .on, .preparing, .dimming] {
            let rep = try render(state)
            #expect(!inked(rep, 15.5, 1) && !inked(rep, 17, 3.5), "\(state)")
        }
        // The rest of the sun is the off sun.
        #expect(!inked(paused, 9, 9) && inked(paused, radius: 6.25, degrees: 90))
    }

    @Test func everyStateHasItsVoiceOverLabel() {
        let labels = StatusSymbolState.allCases.map(StatusSymbolImage.accessibilityLabel(for:))
        #expect(Set(labels).count == labels.count)
        for (state, label) in zip(StatusSymbolState.allCases, labels) {
            #expect(label.hasPrefix("Overbright, "), "\(state)")
            #expect(StatusSymbolImage.image(for: state).accessibilityDescription == label, "\(state)")
        }
        #expect(labels == ["Overbright, off", "Overbright, on", "Overbright, preparing", "Overbright, dimmed",
                           "Overbright, paused", "Overbright, needs attention"])     // DESIGN.md §4.1
    }

    @Test func drawingIsSafeOffTheMainThread() async throws {
        // AppKit may draw template images on any thread (§8.1 rule 2): the drawing code is nonisolated.
        let size = 72
        let drawn = await Task.detached { () -> Bool in
            guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8,
                                             samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                             colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
                  let context = NSGraphicsContext(bitmapImageRep: rep) else { return false }
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = context
            context.cgContext.scaleBy(x: 4, y: 4)
            StatusSymbolImage.render(.attention, in: CGRect(x: 0, y: 0, width: 18, height: 18))
            NSGraphicsContext.restoreGraphicsState()
            return (rep.colorAt(x: 36, y: 36)?.alphaComponent ?? 1) < 0.5   // the off sun's hollow centre
        }.value
        #expect(drawn)
    }
}
