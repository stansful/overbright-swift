// OverbrightTriggers/Strategies/HLGSampleBufferTrigger.swift — T4-alt: one in-memory 10-bit HLG frame in an
// `AVSampleBufferDisplayLayer`: no file, no encoder, no decoder, no player. ARCHITECTURE.md D4, §4.7 (rung 6 if
// hardware test H-T4d passes). Thread: main.
import AVFoundation
import CoreGraphics
import CoreMedia
import OverbrightCore
import os
import QuartzCore

private let log = Log.logger(.trigger)

/// T4-alt (`TriggerStrategy.hlgSampleBuffer`).
final class HLGSampleBufferTrigger: TriggerHandle, RegisteredWindowOwner {
    /// The rung.
    let request: TriggerRequest
    /// `remove()` ran.
    private(set) var isRemoved = false
    /// The layer, once presented.
    private(set) var displayLayer: AVSampleBufferDisplayLayer?

    private let host: TriggerHost
    private let time: any TimeSource
    private weak var registry: TriggerWindowRegistry?
    private var sample: CMSampleBuffer?
    private var generation: UInt64 = 0

    init(request: TriggerRequest, host: TriggerHost, time: any TimeSource, registry: TriggerWindowRegistry?) {
        self.request = request
        self.host = host
        self.time = time
        self.registry = registry
        registry?.register(self)
    }

    /// A handle dropped without `remove()` flushes its renderer (the host closes the window).
    isolated deinit { displayLayer?.sampleBufferRenderer.flush() }

    /// One HLG frame of `level`, marked "display immediately" so no timebase is needed; nil if CoreMedia refuses it.
    nonisolated static func makeSampleBuffer(level: HLGStillAsset.Level, edge: Int = 16) -> CMSampleBuffer? {
        guard let pixels = HLGStillAsset.makePixelBuffer(edge: edge, lumaCode: level.lumaCode) else { return nil }
        var format: CMVideoFormatDescription?
        guard CMVideoFormatDescriptionCreateForImageBuffer(allocator: nil, imageBuffer: pixels,
                                                           formatDescriptionOut: &format) == noErr,
              let format else { return nil }
        var timing = CMSampleTimingInfo(duration: .invalid, presentationTimeStamp: .zero, decodeTimeStamp: .invalid)
        var sample: CMSampleBuffer?
        guard CMSampleBufferCreateReadyWithImageBuffer(allocator: nil, imageBuffer: pixels, formatDescription: format,
                                                       sampleTiming: &timing, sampleBufferOut: &sample) == noErr,
              let sample else { return nil }
        if let attachments = CMSampleBufferGetSampleAttachmentsArray(sample, createIfNecessary: true),
           CFArrayGetCount(attachments) > 0 {
            let dictionary = unsafeBitCast(CFArrayGetValueAtIndex(attachments, 0), to: CFMutableDictionary.self)
            CFDictionarySetValue(dictionary,
                                 Unmanaged.passUnretained(kCMSampleAttachmentKey_DisplayImmediately).toOpaque(),
                                 Unmanaged.passUnretained(kCFBooleanTrue).toOpaque())
        }
        return sample
    }

    // MARK: TriggerHandle

    /// Hidden by the lock shield or another window.
    var isOccluded: Bool { host.isOccluded }
    /// Forwarded to the window.
    var onOcclusionChange: ((Bool) -> Void)? {
        get { host.onOcclusionChange }
        set { host.onOcclusionChange = newValue }
    }
    /// Forwarded to the window.
    var onScreenChange: ((CGDirectDisplayID?) -> Void)? {
        get { host.onScreenChange }
        set { host.onScreenChange = newValue }
    }

    /// Shows one frame for `pixel` (ordering the window in on the first call) and waits up to 2 s until the layer
    /// reports it ready for display (macOS 14.4+; before, a renderer that did not fail counts). False when no frame
    /// could be built, the window could not be placed, the renderer failed, or after `remove()`.
    func present(_ pixel: TriggerPixel) async -> Bool {
        guard !isRemoved else { return false }
        generation &+= 1
        let current = generation
        let level = HLGStillAsset.Level(pixel)
        guard let frame = Self.makeSampleBuffer(level: level) else {
            log.error("T4-alt frame unavailable on display \(self.host.display.id)")
            return false
        }
        let layer: AVSampleBufferDisplayLayer
        if let displayLayer {
            layer = displayLayer
            layer.sampleBufferRenderer.flush()
        } else {
            layer = AVSampleBufferDisplayLayer()
            layer.videoGravity = .resizeAspectFill
            do {
                try host.show(layer: layer, blend: request.blend)
            } catch {
                log.error("T4-alt window failed on display \(self.host.display.id): \(LoggedError.publicSummary(error), privacy: .public)")
                return false
            }
            displayLayer = layer
        }
        layer.sampleBufferRenderer.enqueue(frame)
        sample = frame
        return await waitUntilReady(layer, generation: current)
    }

    /// Follows the screen geometry and enqueues the frame again.
    func represent() {
        guard !isRemoved, let displayLayer, let sample else { return }
        host.reposition()
        displayLayer.sampleBufferRenderer.flush()
        displayLayer.sampleBufferRenderer.enqueue(sample)
    }

    /// HLG content carries its own implied headroom; there is no tag to change.
    func requestHeadroom(_ headroom: Double) { _ = headroom }

    /// Flushes the renderer and orders the window out. Idempotent.
    func remove() {
        guard !isRemoved else { return }
        isRemoved = true
        generation &+= 1
        displayLayer?.sampleBufferRenderer.flush()
        displayLayer = nil
        sample = nil
        host.tearDown()
        registry?.unregister(self)
    }

    // MARK: RegisteredWindowOwner

    /// Whether the window exists.
    var hasOpenWindow: Bool { host.hasWindow }

    // MARK: Private

    private func waitUntilReady(_ layer: AVSampleBufferDisplayLayer, generation current: UInt64) async -> Bool {
        for poll in 0...TriggerTiming.readinessPolls {
            if poll > 0 {
                do { try await time.sleep(for: TriggerTiming.readinessPollInterval) } catch { return false }
            }
            guard current == generation, !isRemoved else { return false }
            if layer.sampleBufferRenderer.status == .failed {
                log.error("T4-alt renderer failed on display \(self.host.display.id)")
                return false
            }
            if #available(macOS 14.4, *) {
                if layer.isReadyForDisplay { return true }
            } else {
                return true
            }
        }
        log.error("T4-alt frame never became ready on display \(self.host.display.id)")
        return false
    }
}
