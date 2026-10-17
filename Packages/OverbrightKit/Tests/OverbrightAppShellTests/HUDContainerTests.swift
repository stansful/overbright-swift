// OverbrightAppShellTests/HUDContainerTests.swift — the HUD's, the prompt's and the panel's container is Design's
// `SurfaceMaterial` container (DESIGN.md §2.4, C-PANEL-24): one rule decides glass or a material, and the opaque one
// (Reduce Transparency, Increase Contrast) follows a Light/Dark switch while the surface stays up, as the panel's
// background must. No window is ordered in.
import AppKit
import OverbrightDesign
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
}
