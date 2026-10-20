// OverbrightTriggers/Surfaces/MetalClearSurface.swift — the real `ClearFrameSurface`: a `CAMetalLayer` on the GPU that
// drives the display. ARCHITECTURE.md §4.7 (T2/T3), §8.6 (`NSSupportsAutomaticGraphicsSwitching`). Thread: main.
import CoreGraphics
import Metal
import QuartzCore

/// A `CAMetalLayer` (rgba16Float, extended linear sRGB, EDR, two drawables) with its own command queue.
final class MetalClearSurface: ClearFrameSurface {
    private let metalLayer: CAMetalLayer
    private var queue: (any MTLCommandQueue)?

    /// A surface on `display`'s own GPU (`CGDirectDisplayCopyCurrentMetalDevice`, never the system default, so a
    /// dual-GPU Intel Mac does not wake its discrete GPU); nil without a device or a queue. `drawablePixels` is the
    /// drawable's edge.
    init?(display: CGDirectDisplayID, drawablePixels: Int, wantsEDR: Bool) {
        guard let device = CGDirectDisplayCopyCurrentMetalDevice(display), let queue = device.makeCommandQueue() else {
            return nil
        }
        let layer = CAMetalLayer()
        MetalClearPass.configure(layer, device: device, drawablePixels: drawablePixels, wantsEDR: wantsEDR)
        self.metalLayer = layer
        self.queue = queue
    }

    /// The `CAMetalLayer`.
    var layer: CALayer { metalLayer }

    /// One tiny command buffer: a clear-only pass into the next drawable, presented.
    func presentFrame(_ value: Double) -> Bool {
        guard let queue, let commandBuffer = queue.makeCommandBuffer(), let drawable = metalLayer.nextDrawable() else {
            return false
        }
        guard MetalClearPass.encode(clearing: drawable.texture, to: value, in: commandBuffer) else { return false }
        commandBuffer.present(drawable)
        commandBuffer.commit()
        return true
    }

    /// `MetalClearPass.applyTag(_:headroom:)`.
    func applyTag(_ headroom: Double?) { MetalClearPass.applyTag(metalLayer, headroom: headroom) }

    /// Drops the queue and the layer's device (and with it the drawable pool).
    func release() {
        queue = nil
        metalLayer.device = nil
    }
}
