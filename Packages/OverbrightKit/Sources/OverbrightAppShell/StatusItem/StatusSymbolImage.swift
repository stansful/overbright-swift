// OverbrightAppShell/StatusItem/StatusSymbolImage.swift — the menu bar symbol, a template image drawn in code (no
// asset). DESIGN.md §4.1 (six states, 18 × 18 pt, badges 5 × 5 pt in the lower trailing corner cut free with 1 pt of
// clearance, never mirrored), §12.7 (VoiceOver); ARCHITECTURE.md §7.6; D13. Cranny's technique
// (`NSImage(size:flipped:drawingHandler:)`, `isTemplate`). Fallback if drawing fails: `sun.max`.
import AppKit
import Foundation
import OverbrightCore

/// The 18 × 18 pt sun of the status item.
enum StatusSymbolImage {
    /// The canvas.
    static let size = CGSize(width: 18, height: 18)
    /// The badge square in the lower trailing corner (AppKit coordinates, origin bottom-left; not mirrored in RTL).
    nonisolated static let badge = CGRect(x: 13, y: 0, width: 5, height: 5)
    /// The clearance cut around the badge.
    nonisolated static let badgeClearance: CGFloat = 1
    /// Ray width and the outlined disc's stroke.
    nonisolated static let stroke: CGFloat = 1.5

    /// The image of `state` (cached: one image per state).
    static func image(for state: StatusSymbolState) -> NSImage {
        if let image = cache[state] { return image }
        let image = draw(state)
        cache[state] = image
        return image
    }

    /// "Overbright, on": the label VoiceOver reads for the status item in `state`.
    static func accessibilityLabel(for state: StatusSymbolState) -> String {
        StatusMenuText.symbolLabel(state)
    }

    /// `off`, kept for the WP0a callers.
    static var off: NSImage { image(for: .off) }

    // MARK: Drawing

    private static var cache: [StatusSymbolState: NSImage] = [:]

    private static func draw(_ state: StatusSymbolState) -> NSImage {
        // AppKit may draw the image on any thread: the handler and everything it calls are nonisolated (§8.1 rule 2).
        let image = NSImage(size: size, flipped: false) { @Sendable rect in
            render(state, in: rect)
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = accessibilityLabel(for: state)
        return image
    }

    /// Draws `state` into the current graphics context.
    nonisolated static func render(_ state: StatusSymbolState, in rect: CGRect) {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        NSColor.black.setStroke()
        NSColor.black.setFill()
        switch state {
        case .off:
            outlinedSun(center)
        case .on:
            filledDisc(center, radius: 3.5)
            rays(center, from: 5.5, to: 8.0)
        case .preparing:
            filledDisc(center, radius: 3.5)
            dots(center, radii: [6.0, 7.5])
        case .dimming:
            filledDisc(center, radius: 2.5)
            dots(center, radii: [6.5])
        case .paused:
            outlinedSun(center)
            cutBadgeArea()
            pauseBadge()
        case .attention:
            outlinedSun(center)
            cutBadgeArea()
            exclamationBadge()
        }
    }

    /// The `off` sun: the disc outlined (outer radius 3.5 pt), eight short rays (5.5 → 7.0).
    nonisolated private static func outlinedSun(_ center: CGPoint) {
        let radius = 3.5 - stroke / 2                                 // the stroke's outer edge sits at 3.5 pt
        let disc = NSBezierPath(ovalIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2,
                                               height: radius * 2))
        disc.lineWidth = stroke
        disc.stroke()
        rays(center, from: 5.5, to: 7.0)
    }

    nonisolated private static func filledDisc(_ center: CGPoint, radius: CGFloat) {
        NSBezierPath(ovalIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
            .fill()
    }

    nonisolated private static func rays(_ center: CGPoint, from inner: CGFloat, to outer: CGFloat) {
        for index in 0..<8 {
            let angle = CGFloat(index) * .pi / 4
            let ray = NSBezierPath()
            ray.move(to: CGPoint(x: center.x + inner * cos(angle), y: center.y + inner * sin(angle)))
            ray.line(to: CGPoint(x: center.x + outer * cos(angle), y: center.y + outer * sin(angle)))
            ray.lineWidth = stroke
            ray.lineCapStyle = .round
            ray.stroke()
        }
    }

    /// Dots of the ray width at each radius, on the eight ray directions.
    nonisolated private static func dots(_ center: CGPoint, radii: [CGFloat]) {
        let dot = stroke / 2
        for index in 0..<8 {
            let angle = CGFloat(index) * .pi / 4
            for radius in radii {
                let point = CGPoint(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle))
                NSBezierPath(ovalIn: CGRect(x: point.x - dot, y: point.y - dot, width: dot * 2, height: dot * 2)).fill()
            }
        }
    }

    /// Clears the badge square and its clearance, cutting the rays under it.
    nonisolated private static func cutBadgeArea() {
        guard let context = NSGraphicsContext.current else { return }
        context.saveGraphicsState()
        context.compositingOperation = .clear
        NSBezierPath(rect: badge.insetBy(dx: -badgeClearance, dy: -badgeClearance)).fill()
        context.restoreGraphicsState()
    }

    /// Two 1.25-pt bars.
    nonisolated private static func pauseBadge() {
        let bar: CGFloat = 1.25
        for x in [badge.minX + 0.75, badge.maxX - 0.75 - bar] {
            NSBezierPath(roundedRect: CGRect(x: x, y: badge.minY, width: bar, height: badge.height), xRadius: bar / 2,
                         yRadius: bar / 2).fill()
        }
    }

    /// A 1.5-pt bar and a dot.
    nonisolated private static func exclamationBadge() {
        let width: CGFloat = 1.5
        let x = badge.midX - width / 2
        NSBezierPath(roundedRect: CGRect(x: x, y: badge.minY + 1.75, width: width, height: badge.height - 1.75),
                     xRadius: width / 2, yRadius: width / 2).fill()
        NSBezierPath(ovalIn: CGRect(x: x, y: badge.minY, width: width, height: width)).fill()
    }
}
