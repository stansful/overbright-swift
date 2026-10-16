// OverbrightDesign/Tokens/SurfaceMaterial.swift — the container of the floating surfaces. DESIGN.md §2.4, §15.
// Liquid Glass (`NSGlassEffectView`, macOS 26+) on the panel container and the HUD only; on macOS 14/15 a visual-effect
// material; under Reduce Transparency or Increase Contrast an opaque `windowBackgroundColor`. Cards are content: never
// glass, and glass is never stacked on glass. Window corner radii come from `Radius`, never a literal.
import AppKit

/// A floating surface that gets a material container (the shell hosts its SwiftUI content inside it).
public nonisolated enum SurfaceMaterial: String, CaseIterable, Sendable {
    /// The panel under the status item.
    case panel
    /// The HUD and the Keep-this-level prompt.
    case hud

    /// What the container draws.
    public enum Background: Hashable, Sendable {
        /// Liquid Glass (`NSGlassEffectView`, `.regular` style), macOS 26+.
        case glass
        /// `NSVisualEffectView` with this material (macOS 14/15).
        case visualEffect(NSVisualEffectView.Material)
        /// Opaque `windowBackgroundColor` (Reduce Transparency, Increase Contrast).
        case opaque
    }

    /// The background for `theme` (its accessibility state and the running macOS).
    public func background(for theme: OverbrightTheme) -> Background {
        guard theme.usesMaterials else { return .opaque }
        if theme.usesGlass { return .glass }
        return .visualEffect(self == .panel ? .popover : .hudWindow)
    }

    /// The container's corner radius (`Radius.panel` or `Radius.hud`).
    public var cornerRadius: CGFloat { self == .panel ? Radius.panel : Radius.hud }

    /// A container for `theme` with `content` pinned to its edges.
    @MainActor public func makeContainer(content: NSView, theme: OverbrightTheme) -> NSView {
        switch background(for: theme) {
        case .glass:
            if #available(macOS 26, *) {
                let glass = NSGlassEffectView()
                glass.style = .regular
                glass.cornerRadius = cornerRadius
                glass.contentView = content
                return glass
            }
            return pinned(content, in: OpaqueSurfaceView(cornerRadius: cornerRadius))
        case let .visualEffect(material):
            let effect = NSVisualEffectView()
            effect.material = material
            effect.blendingMode = .behindWindow
            effect.state = .active
            effect.wantsLayer = true
            effect.layer?.cornerRadius = cornerRadius
            effect.layer?.cornerCurve = .continuous
            effect.layer?.masksToBounds = true
            return pinned(content, in: effect)
        case .opaque:
            return pinned(content, in: OpaqueSurfaceView(cornerRadius: cornerRadius))
        }
    }

    @MainActor private func pinned(_ content: NSView, in container: NSView) -> NSView {
        content.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(content)
        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            content.topAnchor.constraint(equalTo: container.topAnchor),
            content.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
        return container
    }
}

/// An opaque `windowBackgroundColor` container with continuous corners; it follows Light and Dark.
final class OpaqueSurfaceView: NSView {
    init(cornerRadius: CGFloat) {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = cornerRadius
        layer?.cornerCurve = .continuous
        layer?.masksToBounds = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    override var wantsUpdateLayer: Bool { true }

    /// Resolves the dynamic colour in the view's effective appearance.
    override func updateLayer() {
        layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
    }
}
