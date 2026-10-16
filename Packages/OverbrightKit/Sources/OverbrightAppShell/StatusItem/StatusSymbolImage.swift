// OverbrightAppShell/StatusItem/StatusSymbolImage.swift — the menu bar symbol, a template image drawn in code (no
// asset). DESIGN.md §4.1; ARCHITECTURE.md §7.6; D13. Cranny's technique (`NSImage(size:flipped:drawingHandler:)`,
// `isTemplate`). Seeded by WP0a with the `off` drawing; WP10 owns `StatusItem/` and draws the other five states
// (on, preparing, dimming, paused and attention badges), each with its accessibility label (`StatusSymbolTests`).
import AppKit
import OverbrightCore

/// The 18 × 18 pt sun of the status item.
enum StatusSymbolImage {
    /// The canvas.
    static let size = CGSize(width: 18, height: 18)

    /// The image of `state`. WP0a draws every state as `off`.
    static func image(for state: StatusSymbolState) -> NSImage {
        _ = state
        return off
    }

    /// `off`: the disc outlined (1.5 pt, outer radius 3.5 pt), eight short round-capped rays (radius 5.5 → 7.0).
    static let off: NSImage = {
        let image = NSImage(size: size, flipped: false) { rect in
            let center = CGPoint(x: rect.midX, y: rect.midY)
            NSColor.black.setStroke()
            let discRadius = 3.5 - 0.75                              // the stroke's outer edge sits at 3.5 pt
            let disc = NSBezierPath(ovalIn: CGRect(x: center.x - discRadius, y: center.y - discRadius,
                                                   width: discRadius * 2, height: discRadius * 2))
            disc.lineWidth = 1.5
            disc.stroke()
            drawRays(around: center, from: 5.5, to: 7.0)
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Overbright"
        return image
    }()

    private static func drawRays(around center: CGPoint, from inner: CGFloat, to outer: CGFloat) {
        for index in 0..<8 {
            let angle = CGFloat(index) * .pi / 4
            let ray = NSBezierPath()
            ray.move(to: CGPoint(x: center.x + inner * cos(angle), y: center.y + inner * sin(angle)))
            ray.line(to: CGPoint(x: center.x + outer * cos(angle), y: center.y + outer * sin(angle)))
            ray.lineWidth = 1.5
            ray.lineCapStyle = .round
            ray.stroke()
        }
    }
}
