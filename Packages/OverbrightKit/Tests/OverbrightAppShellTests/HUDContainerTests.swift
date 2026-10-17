// OverbrightAppShellTests/HUDContainerTests.swift — the HUD's, the prompt's and the panel's container is Design's
// `SurfaceMaterial` container (DESIGN.md §2.4, C-PANEL-24): one rule decides glass or a material, and the opaque one
// (Reduce Transparency, Increase Contrast) follows a Light/Dark switch while the surface stays up, as the panel's
// background must. The HUD window keeps one hosting view and container across redraws and showings (a new one only
// when the material changes). No window is ordered in: `preparedWindow` builds what `present` fades in.
import AppKit
import OverbrightCore
import OverbrightDesign
import SwiftUI
import Testing
@testable import OverbrightAppShell

@MainActor @Suite struct HUDContainerTests {
    /// The background colour the container's layer draws in `appearance` (AppKit updates a layer with the view's
    /// appearance as the drawing appearance, as here).
    private func background(of container: NSView, in appearance: NSAppearance.Name) throws -> NSColor {
        let named = try #require(NSAppearance(named: appearance))
        container.appearance = named
        named.performAsCurrentDrawingAppearance { container.updateLayer() }
        let cgColor = try #require(container.layer?.backgroundColor)
        return try #require(NSColor(cgColor: cgColor)?.usingColorSpace(.sRGB))
    }

    @Test func theOpaqueContainerFollowsTheAppearance() throws {
        for effect in [NSVisualEffectView.Material.popover, .hudWindow] {
            let content = NSView()
            let container = PanelContainer.make(around: content, material: .opaque, cornerRadius: Radius.hud,
                                                effect: effect)
            #expect(content.superview === container && (container.layer?.cornerRadius ?? 0) > 0)
            #expect(container.wantsUpdateLayer)
            let light = try background(of: container, in: .aqua)
            let dark = try background(of: container, in: .darkAqua)
            #expect(light.brightnessComponent > dark.brightnessComponent + 0.3, "\(effect.rawValue)")
        }
    }

    @Test func oneRuleDecidesTheMaterial() {
        #expect(PanelContainer.material(reduceTransparency: true, increaseContrast: false, supportsGlass: true) == .opaque)
        #expect(PanelContainer.material(reduceTransparency: false, increaseContrast: true, supportsGlass: true) == .opaque)
        #expect(PanelContainer.theme(for: .opaque).usesMaterials == false)
        #expect(PanelContainer.theme(for: .glass).usesMaterials && PanelContainer.theme(for: .popover).usesMaterials)
        #expect(SurfaceMaterial.panel.background(for: PanelContainer.theme(for: .opaque)) == .opaque)
    }

    /// The first hosting view of the HUD under `view` (breadth first).
    private func hudHost(in view: NSView?) -> NSHostingView<HUDRoot>? {
        var queue = view.map { [$0] } ?? []
        while !queue.isEmpty {
            let next = queue.removeFirst()
            if let host = next as? NSHostingView<HUDRoot> { return host }
            queue += next.subviews
        }
        return nil
    }

    private func drawing(_ value: String, level: Double) -> HUDController.Drawing {
        HUDController.Drawing(text: HUDText(symbol: .sunMax, displayName: nil, value: value, reason: nil,
                                            announcement: value),
                              level: LevelPosition(level), isBoosting: level > 0.5)
    }

    /// Redraws, changes while the HUD shows and later showings hand the window's one hosting view a new root (no new
    /// view or container, the frame set only when it moved); hidden, the window keeps it for the next showing; a change
    /// of the material (Reduce Transparency, Increase Contrast) makes a new container.
    @Test func theHUDKeepsOneHostingViewAcrossShowings() throws {
        _ = NSApplication.shared
        let hud = HUDController(services: .preview(), slot: HUDSlot()) { _, _ in nil }
        let frame = CGRect(origin: CGPoint(x: 100, y: 100), size: HUDPlacement.size)
        let window = hud.preparedWindow(drawing("Standard", level: 0.5), frame: frame, material: .glass)
        let container = try #require(window.contentView)
        let host = try #require(hudHost(in: container))
        let moved = frame.offsetBy(dx: 400, dy: 0)                              // a change on another display
        #expect(hud.preparedWindow(drawing("Bright room", level: 0.7), frame: frame, material: .glass) === window)
        #expect(hud.preparedWindow(drawing("Max", level: 1), frame: moved, material: .glass) === window)
        #expect(hud.hostingViewsMade == 1 && window.contentView === container && hudHost(in: container) === host)
        #expect(host.rootView.drawing == drawing("Max", level: 1) && window.frame == moved)
        window.alphaValue = 0                                                   // hudOut faded it out
        _ = hud.preparedWindow(drawing("Standard", level: 0.5), frame: moved, material: .glass)  // the next showing
        #expect(hud.hostingViewsMade == 1 && window.contentView === container)
        #expect(host.rootView.drawing == drawing("Standard", level: 0.5))
        _ = hud.preparedWindow(drawing("Standard", level: 0.5), frame: moved, material: .opaque)  // Reduce Transparency
        #expect(hud.hostingViewsMade == 2 && window.contentView !== container)
    }
}
