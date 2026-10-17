// OverbrightPanelUITests/PanelSnapshotTests.swift — a snapshot of the panel for every panel state of DESIGN.md §5.13
// (the HUD states are the shell's HUD snapshots, and the window-only states its window snapshots), in Light, Dark and
// Increase Contrast (ARCHITECTURE.md §9.1: `NSHostingView.cacheDisplay`, in-process, never ordered in). Every render
// is checked (the panel's width, ink on the canvas, the appearances differ), and key renders against their layout: a
// header and a footer that both draw, at the panel's edges, the panel's 320 pt, the master switch drawn as in a key
// window. A render is taken at the size the panel settles on. The PNGs are written only with
// `OVERBRIGHT_SNAPSHOT_DIR=<dir>` (into `<dir>/PanelUI/`), for a person to review.
import AppKit
import OverbrightCore
import OverbrightDesign
import OverbrightTestSupport
import SwiftUI
import Testing
@testable import OverbrightPanelUI

@MainActor @Suite struct PanelSnapshotTests {
    /// The three appearances of the gallery.
    enum Appearance: String, CaseIterable {
        case light, dark, increaseContrast

        var nsAppearance: NSAppearance? {
            switch self {
            case .light: NSAppearance(named: .aqua)
            case .dark: NSAppearance(named: .darkAqua)
            case .increaseContrast: NSAppearance(named: .accessibilityHighContrastAqua)
            }
        }

        var theme: OverbrightTheme { OverbrightTheme(increaseContrast: self == .increaseContrast) }
    }

    /// The states that are windows, not the panel (`menubar-hidden`: the icon-not-visible window and the Settings row;
    /// `move-to-applications`: the alert). `ScriptedStatuses` is another package's file, so the list lives here.
    static let windowOnlyNames: Set<String> = ["menubar-hidden", "move-to-applications"]

    /// The states the panel snapshots: every scripted name but the HUD and window-only ones.
    static var panelNames: [String] {
        let hud = Set(ScriptedStatuses.hudNames)
        return ScriptedStatuses.names.filter { !hud.contains($0) && !windowOnlyNames.contains($0) }
    }

    /// Renders the panel of `name` in `appearance` (a borderless window that is never ordered in) at the size it
    /// settles on. The card list first lays out with the default card height and then takes the measured heights
    /// (C-PANEL-13), so a host sized once from the first `fittingSize` drew the panel centred between blank bands
    /// (four-displays: about 24 pt above the header and below the footer, C-PANEL-31). The host follows `fittingSize`
    /// until it holds for two checks in a row, as the panel window does through `onIdealSizeChange` (a window keeps
    /// whole points, so within a point is held: a 428.5-pt panel gets 428 or 429).
    private func render(_ name: String, _ appearance: Appearance) async throws -> NSBitmapImageRep {
        let services = try #require(ScriptedStatuses.services(named: name))
        let root = PanelView(services: services, expandsWhy: ScriptedStatuses.expandsWhy(named: name))
            .background(Color(nsColor: .windowBackgroundColor))
            .overbrightThemeRoot(appearance.theme)
        let host = NSHostingView(rootView: root)
        host.appearance = appearance.nsAppearance
        let window = NSWindow(contentRect: CGRect(origin: .zero, size: host.fittingSize), styleMask: [.borderless],
                              backing: .buffered, defer: true)
        window.contentView = host
        var steady = 0
        let settled = await eventually {
            host.layoutSubtreeIfNeeded()
            let size = host.fittingSize
            guard abs(size.width - host.frame.width) < 1, abs(size.height - host.frame.height) < 1 else {
                window.setContentSize(size)
                steady = 0
                return false
            }
            steady += 1
            return steady >= 2
        }
        #expect(settled, "\(name): the panel never settled on a size (\(host.fittingSize))")
        let rep = try #require(host.bitmapImageRepForCachingDisplay(in: host.bounds))
        host.cacheDisplay(in: host.bounds, to: rep)
        window.contentView = nil
        return rep
    }

    /// The first and the last row (pixels from the top) with a pixel that differs from the top-left one (the
    /// background).
    private func inkRows(_ rep: NSBitmapImageRep) -> (first: Int, last: Int)? {
        guard let background = rep.colorAt(x: 2, y: 2) else { return nil }
        func hasInk(_ y: Int) -> Bool {
            stride(from: 0, to: rep.pixelsWide, by: 1).contains { x in
                rep.colorAt(x: x, y: y).map { abs($0.brightnessComponent - background.brightnessComponent) > 0.08 }
                    ?? false
            }
        }
        guard let first = (0..<rep.pixelsHigh).first(where: hasInk),
              let last = (0..<rep.pixelsHigh).reversed().first(where: hasInk) else { return nil }
        return (first, last)
    }

    /// The share of pixels that differ from the top-left one (the background), in the band of rows `rows` (pixels from
    /// the top; all rows by default).
    private func inkFraction(_ rep: NSBitmapImageRep, rows: Range<Int>? = nil) -> Double {
        guard let background = rep.colorAt(x: 2, y: 2) else { return 0 }
        var ink = 0
        var total = 0
        let band = rows ?? 0..<rep.pixelsHigh
        for x in stride(from: 0, to: rep.pixelsWide, by: 3) {
            for y in stride(from: band.lowerBound, to: band.upperBound, by: 3) {
                total += 1
                guard let color = rep.colorAt(x: x, y: y) else { continue }
                if abs(color.brightnessComponent - background.brightnessComponent) > 0.08 { ink += 1 }
            }
        }
        return Double(ink) / Double(max(total, 1))
    }

    @Test(arguments: Appearance.allCases)
    func everyScriptedStatusRenders(_ appearance: Appearance) async throws {
        let directory = SnapshotOutput.directory("PanelUI")
        if let directory { try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true) }
        #expect(Self.panelNames.count == ScriptedStatuses.names.count - ScriptedStatuses.hudNames.count - 2)
        for name in Self.panelNames {
            let rep = try await render(name, appearance)
            #expect(CGFloat(rep.pixelsWide) >= PanelLayout.width, "\(name)")
            #expect(inkFraction(rep) > 0.01, "\(name) \(appearance.rawValue): nothing drawn")
            if let directory, let data = rep.representation(using: .png, properties: [:]) {
                try data.write(to: directory.appending(path: "\(name)-\(appearance.rawValue).png"))
            }
        }
    }

    /// Key states draw what their layout says: 320 pt wide, a header and a footer with ink in their 44-pt bands, and
    /// at least the content between them. The header's ink starts and the footer's ends as far from the edges as in
    /// the two-display panel: no blank band above the header or below the footer (C-PANEL-31).
    @Test(arguments: ["boosting", "off", "banner-battery", "nothing-capable", "four-displays", "fill-light-card"])
    func keyStatesDrawTheirHeaderAndFooter(_ name: String) async throws {
        let rep = try await render(name, .light)
        let scale = Double(rep.pixelsWide) / Double(rep.size.width)
        #expect(rep.size.width == PanelLayout.width, "\(name)")
        #expect(rep.size.height > PanelLayout.barHeight * 2 + PanelLayout.cardHeight / 2, "\(name)")
        let bar = Int(PanelLayout.barHeight * scale)
        #expect(inkFraction(rep, rows: 0..<bar) > 0.01, "\(name): no header")
        #expect(inkFraction(rep, rows: (rep.pixelsHigh - bar)..<rep.pixelsHigh) > 0.01, "\(name): no footer")
        let boosting = try await render("boosting", .light)
        let (ink, reference) = (try #require(inkRows(rep)), try #require(inkRows(boosting)))
        let (top, referenceTop) = (Double(ink.first) / scale, Double(reference.first) / scale)
        let bottom = Double(rep.pixelsHigh - 1 - ink.last) / scale
        let referenceBottom = Double(boosting.pixelsHigh - 1 - reference.last) / scale
        #expect(top <= referenceTop + 2, "\(name): the header's ink starts \(top) pt down, \(referenceTop) pt in boosting")
        #expect(bottom <= referenceBottom + 2,
                "\(name): the footer's ink ends \(bottom) pt above the bottom, \(referenceBottom) pt in boosting")
    }

    /// The master switch of an "on" panel draws in the accent colour although the panel is not key when clicked open
    /// (C-PANEL-10); the "off" panel's switch has no accent. (With a grey accent there is no hue to look for.)
    @Test func theMasterSwitchDrawsItsOnStateInTheAccentColour() async throws {
        let accent = NSColor.controlAccentColor.usingColorSpace(.sRGB)?.saturationComponent ?? 0
        guard accent > 0.3 else { return }
        let on = try await render("boosting", .light)
        let off = try await render("off", .light)
        let scale = Double(on.pixelsWide) / Double(on.size.width)
        // The switch sits in the header's trailing third, before the "⋯" button and the 12-pt inset.
        let y = Int(PanelLayout.barHeight / 2 * scale)
        let xs = stride(from: Int((PanelLayout.width - 110) * scale), to: Int((PanelLayout.width - 30) * scale), by: 1)
        func saturation(_ rep: NSBitmapImageRep) -> CGFloat {
            xs.compactMap { rep.colorAt(x: $0, y: y)?.usingColorSpace(.sRGB)?.saturationComponent }.max() ?? 0
        }
        #expect(saturation(on) > 0.3, "the on switch has no accent: \(saturation(on))")
        #expect(saturation(off) < 0.2, "the off switch shows a hue: \(saturation(off))")
    }

    @Test func darkAndLightDiffer() async throws {
        let light = try await render("boosting", .light)
        let dark = try await render("boosting", .dark)
        let lightBackground = try #require(light.colorAt(x: 2, y: 2)).brightnessComponent
        let darkBackground = try #require(dark.colorAt(x: 2, y: 2)).brightnessComponent
        #expect(lightBackground > darkBackground + 0.3)
    }
}
