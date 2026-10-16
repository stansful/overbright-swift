// OverbrightTriggers/Assets/HLGStillAsset+Encoding.swift — the HLG frame and its one-frame QuickTime file.
// ARCHITECTURE.md §4.7 ("HLG still asset"). Thread: off the main actor (`@concurrent`); the pixel buffer is also
// built on the main actor by T4-alt (`HLGSampleBufferTrigger`), which shows it without any file.
import AVFoundation
import CoreMedia
import CoreVideo
import Foundation
import VideoToolbox

nonisolated extension HLGStillAsset {
    /// A 10-bit 4:2:0 video-range buffer (`x420`) filled with one luma code and neutral chroma (512), tagged
    /// BT.2020 / BT.2100 HLG / BT.2020. Nil if CoreVideo refuses the buffer.
    static func makePixelBuffer(edge: Int, lumaCode: UInt16) -> CVPixelBuffer? {
        let attributes: [String: Any] = [
            kCVPixelBufferIOSurfacePropertiesKey as String: [String: Any](),
            kCVPixelBufferWidthKey as String: edge,
            kCVPixelBufferHeightKey as String: edge,
        ]
        var out: CVPixelBuffer?
        guard CVPixelBufferCreate(nil, edge, edge, kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange,
                                  attributes as CFDictionary, &out) == kCVReturnSuccess, let buffer = out else {
            return nil
        }
        CVPixelBufferLockBaseAddress(buffer, [])
        for plane in 0..<CVPixelBufferGetPlaneCount(buffer) {
            guard let base = CVPixelBufferGetBaseAddressOfPlane(buffer, plane) else { continue }
            let rowBytes = CVPixelBufferGetBytesPerRowOfPlane(buffer, plane)
            let rows = CVPixelBufferGetHeightOfPlane(buffer, plane)
            // 16-bit words with the 10 significant bits high. Plane 1 interleaves Cb and Cr, both neutral (512).
            let word: UInt16 = (plane == 0 ? lumaCode : 512) << 6
            for row in 0..<rows {
                let words = base.advanced(by: row * rowBytes).assumingMemoryBound(to: UInt16.self)
                for index in 0..<(rowBytes / 2) { words[index] = word }
            }
        }
        CVPixelBufferUnlockBaseAddress(buffer, [])
        CVBufferSetAttachment(buffer, kCVImageBufferColorPrimariesKey, kCVImageBufferColorPrimaries_ITU_R_2020,
                              .shouldPropagate)
        CVBufferSetAttachment(buffer, kCVImageBufferTransferFunctionKey, kCVImageBufferTransferFunction_ITU_R_2100_HLG,
                              .shouldPropagate)
        CVBufferSetAttachment(buffer, kCVImageBufferYCbCrMatrixKey, kCVImageBufferYCbCrMatrix_ITU_R_2020,
                              .shouldPropagate)
        return buffer
    }

    /// The writer's video settings for `spec`. HEVC gets plain HLG: no encoder-added Dolby Vision configuration
    /// (`dvvC`) or other HDR side metadata.
    static func outputSettings(for spec: Spec) -> [String: Any] {
        let color: [String: Any] = [
            AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_2020,
            AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_2100_HLG,
            AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_2020,
        ]
        var settings: [String: Any] = [
            AVVideoWidthKey: spec.edge,
            AVVideoHeightKey: spec.edge,
            AVVideoColorPropertiesKey: color,
        ]
        switch spec.codec {
        case .hevcMain10:
            settings[AVVideoCodecKey] = AVVideoCodecType.hevc
            settings[AVVideoCompressionPropertiesKey] = [
                AVVideoProfileLevelKey: kVTProfileLevel_HEVC_Main10_AutoLevel as String,
                kVTCompressionPropertyKey_HDRMetadataInsertionMode as String: kVTHDRMetadataInsertionMode_None as String,
            ]
        case .proRes422:
            settings[AVVideoCodecKey] = AVVideoCodecType.proRes422
        }
        return settings
    }

    /// Encodes a one-frame, one-second, video-only QuickTime file at `url` (replacing a file there). No audio track,
    /// no metadata.
    @concurrent
    static func encode(_ spec: Spec, into url: URL) async throws {
        try? FileManager.default.removeItem(at: url)
        let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        writer.shouldOptimizeForNetworkUse = false
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: outputSettings(for: spec))
        input.expectsMediaDataInRealTime = false
        guard writer.canAdd(input) else { throw Failure.cannotAddInput }
        writer.add(input)
        // The adaptor must exist before startWriting (AVFoundation raises otherwise).
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: nil)
        guard writer.startWriting() else { throw Failure.startFailed(String(describing: writer.error)) }
        writer.startSession(atSourceTime: .zero)
        guard let buffer = makePixelBuffer(edge: spec.edge, lumaCode: spec.level.lumaCode) else {
            writer.cancelWriting()
            throw Failure.pixelBuffer
        }
        // A bounded wait inside one encoding job (≤ 1 s), not a periodic activity.
        var waited = 0
        while !input.isReadyForMoreMediaData && waited < 500 {
            try await Task.sleep(for: .milliseconds(2))
            waited += 1
        }
        guard adaptor.append(buffer, withPresentationTime: .zero) else {
            writer.cancelWriting()
            throw Failure.appendFailed(String(describing: writer.error))
        }
        input.markAsFinished()
        writer.endSession(atSourceTime: CMTime(value: 1, timescale: 1))
        await writer.finishWriting()
        guard writer.status == .completed else { throw Failure.finishFailed(String(describing: writer.error)) }
    }
}
