// OverbrightPanelUITests/PanelSnapshotTests.swift — a snapshot of the panel for every panel state of DESIGN.md §5.13
// (the HUD states are the shell's HUD snapshots, and the window-only states its window snapshots), in Light, Dark and
// Increase Contrast (ARCHITECTURE.md §9.1: `NSHostingView.cacheDisplay`, in-process, never ordered in). Every render
// is checked (the panel's width, ink on the canvas, the appearances differ), and key renders against their layout: a
// header and a footer that both draw, the panel's 320 pt, the master switch drawn as in a key window. The PNGs are
// written only with `OVERBRIGHT_SNAPSHOT_DIR=<dir>` (into `<dir>/PanelUI/`), for a person to review.
import AppKit
import OverbrightCore
import OverbrightDesign
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

    /// Renders the panel of `name` in `appearance` (a borderless window that is never ordered in).
    private func render(_ name: String, _ appearance: Appearance) throws -> NSBitmapImageRep {
        let services = try #require(ScriptedStatuses.services(named: name))
        let root = PanelView(services: services, expandsWhy: ScriptedStatuses.expandsWhy(named: name))
            .background(Color(nsColor: .windowBackgroundColor))
            .overbrightThemeRoot(appearance.theme)
        let host = NSHostingView(rootView: root)
        host.appearance = appearance.nsAppearance
        host.frame = CGRect(origin: .zero, size: host.fittingSize)
        let window = NSWindow(contentRect: host.frame, styleMask: [.borderless], backing: .buffered, defer: true)
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        let rep = try #require(host.bitmapImageRepForCachingDisplay(in: host.bounds))
        host.cacheDisplay(in: host.bounds, to: rep)
        window.contentView = nil
        return rep
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
    func everyScriptedStatusRenders(_ appearance: Appearance) throws {
        let directory = SnapshotOutput.directory("PanelUI")
        if let directory { try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true) }
        #expect(Self.panelNames.count == ScriptedStatuses.names.count - ScriptedStatuses.hudNames.count - 2)
        for name in Self.panelNames {
            let rep = try render(name, appearance)
            #expect(CGFloat(rep.pixelsWide) >= PanelLayout.width, "\(name)")
            #expect(inkFraction(rep) > 0.01, "\(name) \(appearance.rawValue): nothing drawn")
            if let directory, let data = rep.representation(using: .png, properties: [:]) {
                try data.write(to: directory.appending(path: "\(name)-\(appearance.rawValue).png"))
            }
        }
    }

    /// Key states draw what their layout says: 320 pt wide, a header and a footer with ink in their 44-pt bands, and
    /// at least the content between them.
    @Test(arguments: ["boosting", "off", "banner-battery", "nothing-capable", "four-displays", "fill-light-card"])
    func keyStatesDrawTheirHeaderAndFooter(_ name: String) throws {
        let rep = try render(name, .light)
        let scale = Double(rep.pixelsWide) / Double(rep.size.width)
        #expect(rep.size.width == PanelLayout.width, "\(name)")
        #expect(rep.size.height > PanelLayout.barHeight * 2 + PanelLayout.cardHeight / 2, "\(name)")
        let bar = Int(PanelLayout.barHeight * scale)
        #expect(inkFraction(rep, rows: 0..<bar) > 0.01, "\(name): no header")
        #expect(inkFraction(rep, rows: (rep.pixelsHigh - bar)..<rep.pixelsHigh) > 0.01, "\(name): no footer")
    }

    /// The master switch of an "on" panel draws in the accent colour although the panel is not key when clicked open
    /// (C-PANEL-10); the "off" panel's switch has no accent. (With a grey accent there is no hue to look for.)
    @Test func theMasterSwitchDrawsItsOnStateInTheAccentColour() throws {
        let accent = NSColor.controlAccentColor.usingColorSpace(.sRGB)?.saturationComponent ?? 0
        guard accent > 0.3 else { return }
        let on = try render("boosting", .light)
        let off = try render("off", .light)
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

    @Test func darkAndLightDiffer() throws {
        let light = try render("boosting", .light)
        let dark = try render("boosting", .dark)
        let lightBackground = try #require(light.colorAt(x: 2, y: 2)).brightnessComponent
        let darkBackground = try #require(dark.colorAt(x: 2, y: 2)).brightnessComponent
        #expect(lightBackground > darkBackground + 0.3)
    }
}
