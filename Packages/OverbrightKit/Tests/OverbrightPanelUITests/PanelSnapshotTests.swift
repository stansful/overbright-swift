// OverbrightPanelUITests/PanelSnapshotTests.swift — a snapshot of the panel for every scripted status of DESIGN.md §5.13,
// in Light, Dark and Increase Contrast (ARCHITECTURE.md §9.1: `NSHostingView.cacheDisplay`, in-process, never ordered
// in). Every render is checked (the panel's width, ink on the canvas, the appearances differ); the PNGs are written only
// with `OVERBRIGHT_SNAPSHOT_DIR=<dir>` (into `<dir>/PanelUI/`), for a person to review.
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

    /// The share of pixels that differ from the top-left one (the background).
    private func inkFraction(_ rep: NSBitmapImageRep) -> Double {
        guard let background = rep.colorAt(x: 2, y: 2) else { return 0 }
        var ink = 0
        var total = 0
        for x in stride(from: 0, to: rep.pixelsWide, by: 3) {
            for y in stride(from: 0, to: rep.pixelsHigh, by: 3) {
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
        for name in ScriptedStatuses.names {
            let rep = try render(name, appearance)
            #expect(CGFloat(rep.pixelsWide) >= PanelLayout.width, "\(name)")
            #expect(inkFraction(rep) > 0.01, "\(name) \(appearance.rawValue): nothing drawn")
            if let directory, let data = rep.representation(using: .png, properties: [:]) {
                try data.write(to: directory.appending(path: "\(name)-\(appearance.rawValue).png"))
            }
        }
    }

    @Test func darkAndLightDiffer() throws {
        let light = try render("boosting", .light)
        let dark = try render("boosting", .dark)
        let lightBackground = try #require(light.colorAt(x: 2, y: 2)).brightnessComponent
        let darkBackground = try #require(dark.colorAt(x: 2, y: 2)).brightnessComponent
        #expect(lightBackground > darkBackground + 0.3)
    }
}
