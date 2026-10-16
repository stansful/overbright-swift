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
    /// The Metal path's present: clears one drawable to the colour (`wantsEDR`: the layer asks for EDR) and presents
    /// it, `MetalFrameContent.present`; false when no drawable was free.
    typealias MetalPresent = @MainActor (_ rgb: LinearRGB, _ wantsEDR: Bool) -> Bool

    /// The window's hosting layer.
    let root = CALayer()
    /// The coloured layer (a `CAMetalLayer` on the Metal path).
    let content: CALayer
    /// The frame shape (even-odd), the mask of `content`.
    let mask = CAShapeLayer()
    /// The colour path actually used (a requested path the system cannot provide falls back: tagged → Metal → SDR).
    let rendering: FillLightRendering
    /// The Metal path's present (it owns the `MetalFrameContent`); nil on the other paths.
    private let present: MetalPresent?
    /// The style shown last.
    private(set) var style: FillLightStyle?

    /// The layers for `display`, rendering with `requested` where this Mac supports it.
    convenience init(rendering requested: FillLightRendering, display: CGDirectDisplayID) {
        var rendering = requested
        if rendering == .taggedLayer {
            if #unavailable(macOS 26.0) { rendering = .metalClear }
        }
        var metal: MetalFrameContent?
        if rendering == .metalClear {
            metal = MetalFrameContent(display: display)
            if metal == nil { rendering = .sdr }
        }
        var present: MetalPresent?
        if let metal { present = { rgb, wantsEDR in metal.present(rgb, wantsEDR: wantsEDR) } }
        self.init(rendering: rendering, content: metal?.layer ?? CALayer(), present: present)
    }

    /// The Metal path over `content` with `present` standing in for the drawable (tests: no device, no window).
    convenience init(metalContent content: CALayer, present: @escaping MetalPresent) {
        self.init(rendering: .metalClear, content: content, present: present)
    }

    private init(rendering: FillLightRendering, content: CALayer, present: MetalPresent?) {
        self.rendering = rendering
        self.content = content
        self.present = present
        root.isOpaque = false
        mask.fillRule = .evenOdd
        mask.fillColor = CGColor(gray: 0, alpha: 1)   // a mask uses alpha only
        content.mask = mask
        root.addSublayer(content)
    }

    /// Lays the frame out as `geometry` and shows `style`. `presentsDrawable` false: the Metal path keeps its drawable
    /// for now (the window is hidden or not ordered in yet; a colour layer is set either way). False only when the
    /// Metal path tried and found no drawable.
    @discardableResult
    func apply(_ style: FillLightStyle, geometry: FrameGeometry, scale: CGFloat,
               presentsDrawable: Bool = true) -> Bool {
        self.style = style
        CATransaction.begin()
        CATransaction.setDisableActions(true)   // a static light: no implicit fades
        root.frame = geometry.bounds
        content.frame = geometry.bounds
        mask.frame = geometry.bounds
        mask.contentsScale = scale
        mask.path = geometry.path
        let shown = showColor(presentsDrawable: presentsDrawable)
        CATransaction.commit()
        return shown
    }

    /// Shows the current style's colour again (the Metal path presents a new drawable unless `presentsDrawable` is
    /// false). False only when the Metal path tried and found no drawable.
    @discardableResult
    func showColor(presentsDrawable: Bool = true) -> Bool {
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
            // nextDrawable() can wait up to 1 s on the main thread when no drawable is free (a hidden window's are
            // not released), so the caller presents only while the window is visible.
            guard presentsDrawable else { return true }
            return present?(rgb, style.headroomRequest != nil) ?? true
        case .sdr:
            content.backgroundColor = EDRColor.untagged(rgb)
            return true
        }
    }
}
