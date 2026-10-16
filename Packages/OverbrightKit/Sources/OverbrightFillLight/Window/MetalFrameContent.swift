// OverbrightFillLight/Window/MetalFrameContent.swift — the macOS 14–25 EDR colour: a clear-only CAMetalLayer.
// ARCHITECTURE.md §7.6, D4 (T2's clear pass), D22 (no shader, no library, no pipeline: the clear happens at load time).
// Thread: main (CAMetalLayer is not annotated; kept on main by convention, §8.1 rule 1).
import CoreGraphics
import Metal
import QuartzCore

/// A tiny `rgba16Float` drawable in extended linear sRGB, cleared once to the colour and stretched over the frame by
/// Core Animation. One command buffer per change; nothing runs between changes (DESIGN.md §17).
@MainActor final class MetalFrameContent {
    /// The drawable's edge in pixels (a solid colour needs no more).
    static let drawablePixels = 4

    /// The layer to mask with the frame shape.
    let layer = CAMetalLayer()
    private let queue: any MTLCommandQueue

    /// Content on the GPU that drives `display` (never the system default device: no discrete-GPU wake-up); nil when
    /// the display has no Metal device.
    init?(display: CGDirectDisplayID) {
        guard let device = CGDirectDisplayCopyCurrentMetalDevice(display), let queue = device.makeCommandQueue() else {
            return nil
        }
        self.queue = queue
        layer.device = device
        layer.pixelFormat = .rgba16Float
        layer.colorspace = CGColorSpace(name: CGColorSpace.extendedLinearSRGB)
        layer.framebufferOnly = true
        layer.isOpaque = true
        layer.maximumDrawableCount = 2
        layer.allowsNextDrawableTimeout = true   // nextDrawable returns nil after 1 s instead of hanging
        layer.drawableSize = CGSize(width: Self.drawablePixels, height: Self.drawablePixels)
        layer.magnificationFilter = .nearest
    }

    /// Clears one drawable to `rgb` and presents it. False when no drawable is available yet (the window is not in
    /// the render tree): the caller retries.
    func present(_ rgb: LinearRGB, wantsEDR: Bool) -> Bool {
        layer.wantsExtendedDynamicRangeContent = wantsEDR   // CAMetalLayer's own flag (not CALayer's deprecated one)
        guard let buffer = queue.makeCommandBuffer(), let drawable = layer.nextDrawable() else { return false }
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = drawable.texture
        pass.colorAttachments[0].loadAction = .clear
        pass.colorAttachments[0].storeAction = .store
        pass.colorAttachments[0].clearColor = MTLClearColor(red: rgb.red, green: rgb.green, blue: rgb.blue, alpha: 1)
        guard let encoder = buffer.makeRenderCommandEncoder(descriptor: pass) else { return false }
        encoder.endEncoding()
        buffer.present(drawable)
        buffer.commit()
        return true
    }
}
