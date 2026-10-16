// OverbrightAppShell/Panel/PanelContainer.swift — the panel's background: Liquid Glass on macOS 26 and later, the
// popover material on 14/15, opaque `windowBackgroundColor` under Reduce Transparency and Increase Contrast; masked to
// `Radius.panel`. DESIGN.md §2.4 (glass on the panel container only, never on cards, never stacked), §2.1
// (`panelBackground`), §15.
import AppKit
import OverbrightDesign

/// Builds the panel's container view around its content.
enum PanelContainer {
    /// The background the container uses.
    enum Material: Equatable {
        /// `NSGlassEffectView` (macOS 26+).
        case glass
        /// `NSVisualEffectView` with the popover material (macOS 14/15).
        case popover
        /// Opaque `windowBackgroundColor` (Reduce Transparency, Increase Contrast).
        case opaque
    }

    /// The material for the accessibility options and the OS (DESIGN.md §2.4).
    static func material(reduceTransparency: Bool, increaseContrast: Bool, supportsGlass: Bool) -> Material {
        if reduceTransparency || increaseContrast { return .opaque }
        return supportsGlass ? .glass : .popover
    }

    /// The material now.
    static var currentMaterial: Material {
        let workspace = NSWorkspace.shared
        var supportsGlass = false
        if #available(macOS 26, *) { supportsGlass = true }
        return material(reduceTransparency: workspace.accessibilityDisplayShouldReduceTransparency,
                        increaseContrast: workspace.accessibilityDisplayShouldIncreaseContrast,
                        supportsGlass: supportsGlass)
    }

    /// A container of `material` holding `content`, pinned to its edges, with `cornerRadius` (the panel's by default;
    /// the HUD passes `Radius.hud` and the HUD material for macOS 14/15).
    static func make(around content: NSView, material: Material, cornerRadius: CGFloat = Radius.panel,
                     effect: NSVisualEffectView.Material = .popover) -> NSView {
        content.translatesAutoresizingMaskIntoConstraints = false
        let container: NSView
        switch material {
        case .glass:
            if #available(macOS 26, *) {
                let glass = NSGlassEffectView()
                glass.cornerRadius = cornerRadius
                glass.contentView = content
                return glass
            }
            container = visualEffect(effect)
        case .popover:
            container = visualEffect(effect)
        case .opaque:
            let view = NSView()
            view.wantsLayer = true
            view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
            container = view
        }
        container.wantsLayer = true
        container.layer?.cornerRadius = cornerRadius
        container.layer?.cornerCurve = .continuous
        container.layer?.masksToBounds = true
        container.addSubview(content)
        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            content.topAnchor.constraint(equalTo: container.topAnchor),
            content.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
        return container
    }

    private static func visualEffect(_ material: NSVisualEffectView.Material) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }
}
