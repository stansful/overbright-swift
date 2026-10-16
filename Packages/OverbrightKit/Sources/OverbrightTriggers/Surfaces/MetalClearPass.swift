// OverbrightTriggers/Surfaces/MetalClearPass.swift — the one GPU operation Overbright performs: a clear-only render
// pass. ARCHITECTURE.md D4, D22, §4.7 (T2/T3), §7.5 (the 14–25 overlay surface).
//
// A pass whose colour attachment uses `loadAction = .clear` and that encodes no draw call needs no pipeline state,
// hence no function and no library: no `.metal` file, no `default.metallib`, no Metal Toolchain [VERIFIED off screen:
// an rgba16Float texture cleared to 1.6 read back 1.5996 with `makeDefaultLibrary()` returning nil].
// `TriggerModuleLintTests.theModuleUsesNoShaderLibraryFunctionOrPipeline` (a source scan) and `CompiledSymbolTests`
// (the compiled module's symbols) keep every library, function and pipeline API out of this module.
import CoreGraphics
import Metal
import QuartzCore

/// The clear-only pass and the EDR configuration of a `CAMetalLayer`.
nonisolated enum MetalClearPass {
    /// Encodes one pass that clears `texture` to `(v, v, v, 1)` and stores it; false if Metal refused an encoder.
    static func encode(clearing texture: any MTLTexture, to value: Double,
                       in commandBuffer: any MTLCommandBuffer) -> Bool {
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = texture
        pass.colorAttachments[0].loadAction = .clear
        pass.colorAttachments[0].storeAction = .store
        pass.colorAttachments[0].clearColor = MTLClearColor(red: value, green: value, blue: value, alpha: 1)
        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: pass) else { return false }
        encoder.endEncoding()   // no pipeline, no draw: the clear happens at load time
        return true
    }

    /// Configures `layer` for EDR output (the documented steps: EDR flag, extended linear colour space, half-float
    /// format, then a presented drawable). `edrMetadata` stays nil: no tone mapping. Two drawables, the smallest
    /// pool (we present at most once per event), and `nextDrawable` gives up after 1 s instead of hanging.
    @MainActor
    static func configure(_ layer: CAMetalLayer, device: any MTLDevice, drawablePixels: Int, wantsEDR: Bool) {
        layer.device = device
        layer.pixelFormat = .rgba16Float
        layer.colorspace = CGColorSpace(name: CGColorSpace.extendedLinearSRGB)
        layer.wantsExtendedDynamicRangeContent = wantsEDR   // CAMetalLayer's own property, not deprecated
        layer.framebufferOnly = true
        layer.isOpaque = true
        layer.maximumDrawableCount = 2
        layer.allowsNextDrawableTimeout = true
        layer.drawableSize = CGSize(width: drawablePixels, height: drawablePixels)
    }

    /// macOS 26+: tags the layer's drawables (`contentsHeadroom`). A tagged layer is subject to
    /// `preferredDynamicRange` (default `.standard`, which tone-maps to SDR), so it also gets `.high`. A headroom of
    /// 1 or less (or nil) untags it. Off by default (tag policy A leaves T2/T3 untagged, §4.7).
    @MainActor
    static func applyTag(_ layer: CAMetalLayer, headroom: Double?) {
        guard #available(macOS 26.0, *) else { return }
        if let headroom, headroom.isFinite, headroom > 1 {
            layer.contentsHeadroom = CGFloat(headroom)
            layer.preferredDynamicRange = .high
        } else {
            layer.contentsHeadroom = 0
            layer.preferredDynamicRange = .standard
        }
    }
}
