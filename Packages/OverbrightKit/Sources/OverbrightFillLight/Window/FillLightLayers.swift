// OverbrightFillLight/Window/FillLightLayers.swift — the frame's layer tree: one colour layer masked by the even-odd
// frame shape. ARCHITECTURE.md §7.6 ("frame-shaped CAShapeLayer, even-odd, rounded inner corners"; EDR colour when
// headroom allows), §2.1 rule 6; DESIGN.md §11. Thread: main.
import CoreGraphics
import QuartzCore

/// The layers of one frame: `root` (the window's hosting layer) holds `content`, whose colour is the light, masked by
/// `mask`, a `CAShapeLayer` filled even-odd with `FrameGeometry.path`. The colour sits on a plain layer (macOS 26+,
/// the same headroom-tagged background colour as the T1 trigger) or a clear-only `CAMetalLayer` (14–25), so only the
/// frame's pixels are lit and nothing is redrawn until the style or the display changes.
@MainActor final class FillLightLayers {
    /// The window's hosting layer.
    let root = CALayer()
    /// The coloured layer (a `CAMetalLayer` on the Metal path).
    let content: CALayer
    /// The frame shape (even-odd), the mask of `content`.
    let mask = CAShapeLayer()
    /// The colour path actually used (a requested path the system cannot provide falls back: tagged → Metal → SDR).
    let rendering: FillLightRendering
    private let metal: MetalFrameContent?
    /// The style shown last.
    private(set) var style: FillLightStyle?

    /// The layers for `display`, rendering with `requested` where this Mac supports it.
    init(rendering requested: FillLightRendering, display: CGDirectDisplayID) {
        var rendering = requested
        if rendering == .taggedLayer {
            if #unavailable(macOS 26.0) { rendering = .metalClear }
        }
        var metal: MetalFrameContent?
        if rendering == .metalClear {
            metal = MetalFrameContent(display: display)
            if metal == nil { rendering = .sdr }
        }
        self.rendering = rendering
        self.metal = metal
        content = metal?.layer ?? CALayer()
        root.isOpaque = false
        mask.fillRule = .evenOdd
        mask.fillColor = CGColor(gray: 0, alpha: 1)   // a mask uses alpha only
        content.mask = mask
        root.addSublayer(content)
    }

    /// Lays the frame out as `geometry` and shows `style`. False only when the Metal path found no drawable yet.
    @discardableResult
    func apply(_ style: FillLightStyle, geometry: FrameGeometry, scale: CGFloat) -> Bool {
        self.style = style
        CATransaction.begin()
        CATransaction.setDisableActions(true)   // a static light: no implicit fades
        root.frame = geometry.bounds
        content.frame = geometry.bounds
        mask.frame = geometry.bounds
        mask.contentsScale = scale
        mask.path = geometry.path
        let shown = showColor()
        CATransaction.commit()
        return shown
    }

    /// Shows the current style's colour again (the Metal path presents a new drawable). False only when the Metal path
    /// found no drawable yet.
    @discardableResult
    func showColor() -> Bool {
        guard let style else { return true }
        let rgb = style.displayedColor
        switch rendering {
        case .taggedLayer:
            if #available(macOS 26.0, *) {
                if let request = style.headroomRequest {
                    content.backgroundColor = EDRColor.tagged(rgb, headroom: request)
                    content.preferredDynamicRange = .high
                } else {
                    content.backgroundColor = EDRColor.untagged(rgb)
                    content.preferredDynamicRange = .standard
                }
            }
            return true
        case .metalClear:
            return metal?.present(rgb, wantsEDR: style.headroomRequest != nil) ?? true
        case .sdr:
            content.backgroundColor = EDRColor.untagged(rgb)
            return true
        }
    }
}
