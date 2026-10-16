// OverbrightTriggers/Assets/HLGStillReport.swift — what a generated (or cached) HLG still really contains, read back
// with AVFoundation, and whether that is what we asked for. ARCHITECTURE.md §4.7 ("verified by reading frame 0
// back"). Thread: off the main actor (`@concurrent`).
import AVFoundation
import CoreMedia
import CoreVideo
import Foundation

/// The read-back facts of one still.
nonisolated struct HLGStillReport: Codable, Hashable, Sendable {
    /// The sample description's codec, e.g. "hvc1" or "apcn".
    var codecFourCC: String
    var width: Int32
    var height: Int32
    var colorPrimaries: String?
    var transferFunction: String?
    var yCbCrMatrix: String?
    var bitsPerComponent: Int?
    /// Extension atoms of the sample description ("hvcC"; a "dvvC" would mean Dolby Vision metadata slipped in).
    var sampleDescriptionAtoms: [String]
    /// The track's `containsHDRVideo` media characteristic.
    var containsHDRVideo: Bool
    var durationSeconds: Double
    var fileBytes: Int
    /// The centre luma code of frame 0, decoded to 10-bit 4:2:0 (nil when decoding failed).
    var decodedLumaCode: UInt16?
    var decodedTransferFunction: String?

    /// BT.2020 primaries, BT.2100 HLG transfer and BT.2020 matrix.
    var isHLGBT2020: Bool {
        colorPrimaries == (kCMFormatDescriptionColorPrimaries_ITU_R_2020 as String)
            && transferFunction == (kCMFormatDescriptionTransferFunction_ITU_R_2100_HLG as String)
            && yCbCrMatrix == (kCMFormatDescriptionYCbCrMatrix_ITU_R_2020 as String)
    }

    /// The file is the still `spec` describes: its codec, HLG BT.2020, HDR video, the exact size, no Dolby Vision
    /// box, and frame 0 decodes to the luma code written (±4: a lossy codec on a flat field).
    func satisfies(_ spec: HLGStillAsset.Spec) -> Bool {
        guard codecFourCC == spec.codec.fourCC, isHLGBT2020, containsHDRVideo,
              width == spec.edge, height == spec.edge, !sampleDescriptionAtoms.contains("dvvC"),
              let decodedLumaCode else { return false }
        return abs(Int(decodedLumaCode) - Int(spec.level.lumaCode)) <= 4
    }
}

nonisolated extension HLGStillAsset {
    /// Reads `url` back: the track's format description, characteristics and duration, the file size, and frame 0.
    @concurrent
    static func inspect(_ url: URL) async throws -> HLGStillReport {
        let asset = AVURLAsset(url: url)
        guard let track = try await asset.loadTracks(withMediaType: .video).first else { throw Failure.noVideoTrack }
        let (descriptions, characteristics, timeRange) = try await track.load(.formatDescriptions,
                                                                               .mediaCharacteristics, .timeRange)
        guard let description = descriptions.first else { throw Failure.noVideoTrack }
        let extensions = (CMFormatDescriptionGetExtensions(description) as? [String: Any]) ?? [:]
        let dimensions = CMVideoFormatDescriptionGetDimensions(description)
        let atomsKey = kCMFormatDescriptionExtension_SampleDescriptionExtensionAtoms as String
        let atoms = (extensions[atomsKey] as? [String: Any])?.keys.sorted() ?? []
        let bytes = ((try? FileManager.default.attributesOfItem(atPath: url.path))?[.size] as? NSNumber)?.intValue ?? -1
        let decoded = decodeFirstFrame(asset: asset, track: track)
        return HLGStillReport(
            codecFourCC: fourCC(CMFormatDescriptionGetMediaSubType(description)),
            width: dimensions.width, height: dimensions.height,
            colorPrimaries: extensions[kCMFormatDescriptionExtension_ColorPrimaries as String] as? String,
            transferFunction: extensions[kCMFormatDescriptionExtension_TransferFunction as String] as? String,
            yCbCrMatrix: extensions[kCMFormatDescriptionExtension_YCbCrMatrix as String] as? String,
            bitsPerComponent: (extensions[kCMFormatDescriptionExtension_BitsPerComponent as String] as? NSNumber)?.intValue,
            sampleDescriptionAtoms: atoms,
            containsHDRVideo: characteristics.contains(.containsHDRVideo),
            durationSeconds: timeRange.duration.seconds,
            fileBytes: bytes,
            decodedLumaCode: decoded.luma,
            decodedTransferFunction: decoded.transfer)
    }

    /// Decodes frame 0 to 10-bit 4:2:0: the centre luma code and the decoder's transfer attachment.
    private static func decodeFirstFrame(asset: AVAsset, track: AVAssetTrack) -> (luma: UInt16?, transfer: String?) {
        guard let reader = try? AVAssetReader(asset: asset) else { return (nil, nil) }
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange,
        ])
        guard reader.canAdd(output) else { return (nil, nil) }
        reader.add(output)
        guard reader.startReading() else { return (nil, nil) }
        defer { reader.cancelReading() }
        guard let sample = output.copyNextSampleBuffer(), let buffer = CMSampleBufferGetImageBuffer(sample) else {
            return (nil, nil)
        }
        let transfer = CVBufferCopyAttachment(buffer, kCVImageBufferTransferFunctionKey, nil) as? String
        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddressOfPlane(buffer, 0) else { return (nil, transfer) }
        let rowBytes = CVPixelBufferGetBytesPerRowOfPlane(buffer, 0)
        let middleRow = CVPixelBufferGetHeightOfPlane(buffer, 0) / 2
        let middleColumn = CVPixelBufferGetWidthOfPlane(buffer, 0) / 2
        let word = base.advanced(by: middleRow * rowBytes).assumingMemoryBound(to: UInt16.self)[middleColumn]
        return (word >> 6, transfer)
    }

    /// A FourCC as text ("hvc1").
    static func fourCC(_ code: FourCharCode) -> String {
        let bytes = [24, 16, 8, 0].map { UInt8((code >> $0) & 0xFF) }
        return String(bytes: bytes, encoding: .ascii) ?? String(code)
    }
}
