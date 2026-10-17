// OverbrightAppShell/Panel/PanelContainer.swift — the background of the panel, the HUD and the Keep-this-level prompt:
// Design's `SurfaceMaterial` container (DESIGN.md §2.4: Liquid Glass on macOS 26 and later, the popover or HUD material
// on 14/15, opaque `windowBackgroundColor` under Reduce Transparency and Increase Contrast; masked to `Radius.panel` /
// `Radius.hud`), §2.1 (`panelBackground`), §15. One rule decides glass (`OverbrightTheme.usesMaterials` and
// `usesGlass`), and the opaque container follows a Light/Dark switch while the surface stays up. This type only keeps
// the shell's call sites as they were (`PanelController` is another package's file); new code calls
// `SurfaceMaterial.makeContainer(content:theme:)` directly.
import AppKit
import OverbrightDesign

/// Builds the container view of the panel and the HUD around their content.
enum PanelContainer {
    /// The background the container uses.
    enum Material: Equatable {
        /// Liquid Glass (macOS 26+).
        case glass
        /// A visual-effect material (macOS 14/15).
        case popover
        /// Opaque `windowBackgroundColor` (Reduce Transparency, Increase Contrast).
        case opaque
    }

    /// The material for the accessibility options and the OS (DESIGN.md §2.4): the theme's rule.
    static func material(reduceTransparency: Bool, increaseContrast: Bool, supportsGlass: Bool) -> Material {
        let theme = OverbrightTheme(reduceTransparency: reduceTransparency, increaseContrast: increaseContrast)
        guard theme.usesMaterials else { return .opaque }
        return supportsGlass ? .glass : .popover
    }

    /// The material now.
    static var currentMaterial: Material {
        var supportsGlass = false
        if #available(macOS 26, *) { supportsGlass = true }
        let theme = currentTheme
        return material(reduceTransparency: theme.reduceTransparency, increaseContrast: theme.increaseContrast,
                        supportsGlass: supportsGlass)
    }

    /// The accessibility state the container follows now.
    static var currentTheme: OverbrightTheme {
        let workspace = NSWorkspace.shared
        return OverbrightTheme(reduceTransparency: workspace.accessibilityDisplayShouldReduceTransparency,
                               increaseContrast: workspace.accessibilityDisplayShouldIncreaseContrast)
    }

    /// A container of `material` holding `content`, pinned to its edges: `SurfaceMaterial.hud` for the HUD's
    /// `effect` (`.hudWindow`), else `SurfaceMaterial.panel`. The surface's own radius applies (`Radius.panel` and
    /// `Radius.hud` are the same); `cornerRadius` stays for the call sites. Glass or a visual-effect view is the OS's
    /// choice (`OverbrightTheme.usesGlass`), so `.glass` and `.popover` both mean "a material".
    static func make(around content: NSView, material: Material, cornerRadius: CGFloat = Radius.panel,
                     effect: NSVisualEffectView.Material = .popover) -> NSView {
        let surface: SurfaceMaterial = effect == .hudWindow ? .hud : .panel
        return surface.makeContainer(content: content, theme: theme(for: material))
    }

    /// The theme whose container is `material`.
    static func theme(for material: Material) -> OverbrightTheme {
        material == .opaque ? OverbrightTheme(reduceTransparency: true) : OverbrightTheme()
    }
}
