// OverbrightOnboardingTests/Support/ChromeSnapshot.swift — renders chrome for the snapshot suites (ARCHITECTURE.md §9.1,
// UI row): in-process `NSHostingView.cacheDisplay` in a borderless window that is never ordered in, in Light, Dark and
// Increase Contrast. Every render is checked for ink; PNGs are written only with `OVERBRIGHT_SNAPSHOT_DIR=<dir>` (into
// `<dir>/Onboarding/`).
import AppKit
import OverbrightCore
import OverbrightDesign
import SwiftUI
import Testing

/// The appearances every chrome snapshot is taken in.
enum ChromeAppearance: String, CaseIterable, Sendable {
    case light, dark, increaseContrast

    /// The AppKit appearance.
    var nsAppearance: NSAppearance? {
        switch self {
        case .light: NSAppearance(named: .aqua)
        case .dark: NSAppearance(named: .darkAqua)
        case .increaseContrast: NSAppearance(named: .accessibilityHighContrastAqua)
        }
    }

    /// The theme the surface root gets (Increase Contrast forced, as the system setting would).
    var theme: OverbrightTheme { OverbrightTheme(increaseContrast: self == .increaseContrast) }
}

/// Rendering and checking.
@MainActor enum ChromeSnapshot {
    /// `view` on the window background, at `size` (or its fitting size), in `appearance`.
    static func render(_ view: some View, _ appearance: ChromeAppearance, size: CGSize? = nil) throws -> NSBitmapImageRep {
        let root = view.background(Color(nsColor: .windowBackgroundColor)).overbrightThemeRoot(appearance.theme)
        let host = NSHostingView(rootView: root)
        host.appearance = appearance.nsAppearance
        host.frame = CGRect(origin: .zero, size: size ?? host.fittingSize)
        return try cache(host)
    }

    /// An alert with `title`, `message` and `buttons` (first = default), laid out as AppKit draws it, never shown.
    static func renderAlert(title: String, message: String, buttons: [String],
                            _ appearance: ChromeAppearance) throws -> NSBitmapImageRep {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        for button in buttons { alert.addButton(withTitle: button) }
        alert.window.appearance = appearance.nsAppearance
        alert.layout()
        let content = try #require(alert.window.contentView)
        content.layoutSubtreeIfNeeded()
        let rep = try #require(content.bitmapImageRepForCachingDisplay(in: content.bounds))
        content.cacheDisplay(in: content.bounds, to: rep)
        return try flattened(rep, on: .windowBackgroundColor, appearance)
    }

    /// `rep` drawn over `color` as `appearance` resolves it: the alert's material does not draw outside a shown window,
    /// so without this its dark text would sit on nothing.
    private static func flattened(_ rep: NSBitmapImageRep, on color: NSColor,
                                  _ appearance: ChromeAppearance) throws -> NSBitmapImageRep {
        let canvas = try #require(NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: rep.pixelsWide, pixelsHigh: rep.pixelsHigh, bitsPerSample: 8,
            samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0,
            bitsPerPixel: 0))
        canvas.size = rep.size
        let context = try #require(NSGraphicsContext(bitmapImageRep: canvas))
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        let bounds = CGRect(origin: .zero, size: rep.size)
        (appearance.nsAppearance ?? NSAppearance.currentDrawing()).performAsCurrentDrawingAppearance {
            color.setFill()
            bounds.fill()
        }
        rep.draw(in: bounds, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: false, hints: nil)
        NSGraphicsContext.restoreGraphicsState()
        return canvas
    }

    /// Draws `host` in a borderless window that is never ordered in.
    private static func cache(_ host: NSView) throws -> NSBitmapImageRep {
        let window = NSWindow(contentRect: host.frame, styleMask: [.borderless], backing: .buffered, defer: true)
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        let rep = try #require(host.bitmapImageRepForCachingDisplay(in: host.bounds))
        host.cacheDisplay(in: host.bounds, to: rep)
        window.contentView = nil
        return rep
    }

    /// The share of sampled pixels that differ from the top-left one (the background).
    static func inkFraction(_ rep: NSBitmapImageRep) -> Double {
        guard let background = rep.colorAt(x: 2, y: 2) else { return 0 }
        var ink = 0
        var total = 0
        for x in stride(from: 0, to: rep.pixelsWide, by: 2) {
            for y in stride(from: 0, to: rep.pixelsHigh, by: 2) {
                total += 1
                guard let color = rep.colorAt(x: x, y: y) else { continue }
                if abs(color.brightnessComponent - background.brightnessComponent) > 0.08 { ink += 1 }
            }
        }
        return Double(ink) / Double(max(total, 1))
    }

    /// The background's brightness (top-left pixel).
    static func backgroundBrightness(_ rep: NSBitmapImageRep) -> CGFloat {
        rep.colorAt(x: 2, y: 2)?.brightnessComponent ?? 0
    }

    /// Writes `<name>-<appearance>.png` when `OVERBRIGHT_SNAPSHOT_DIR` is set.
    static func write(_ rep: NSBitmapImageRep, _ name: String, _ appearance: ChromeAppearance) throws {
        guard let directory = SnapshotOutput.directory("Onboarding") else { return }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        guard let data = rep.representation(using: .png, properties: [:]) else { return }
        try data.write(to: directory.appending(path: "\(name)-\(appearance.rawValue).png"))
    }
}
