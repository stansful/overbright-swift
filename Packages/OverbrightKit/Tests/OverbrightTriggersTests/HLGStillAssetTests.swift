// OverbrightTriggersTests/HLGStillAssetTests.swift — the T4 still: generated at run time and verified by read-back
// (ProRes always, HEVC Main10 when an HEVC encoder exists), reused from the cache, a corrupt file replaced, no
// temporary file left behind (and those a crash left swept); one generation shared by two triggers. ARCHITECTURE.md §4.7 ("HLG still asset"),
// §10.5. Files go to a fresh temporary folder only; nothing is shown.
import CoreMedia
import CoreVideo
import Foundation
import OverbrightCore
import Testing
import VideoToolbox
@testable import OverbrightTriggers

@Suite struct HLGStillAssetTests {
    /// Whether this Mac has an HEVC encoder (all Apple silicon; Intel Macs may not).
    nonisolated static let hasHEVCEncoder: Bool = {
        var list: CFArray?
        guard VTCopyVideoEncoderList(nil, &list) == noErr, let encoders = list as? [[String: Any]] else { return false }
        return encoders.contains { ($0[kVTVideoEncoderList_CodecType as String] as? NSNumber)?.uint32Value
                                   == kCMVideoCodecType_HEVC }
    }()

    private func temporaryFolder() -> URL {
        FileManager.default.temporaryDirectory.appending(path: "overbright-hlg-\(UUID().uuidString)",
                                                         directoryHint: .isDirectory)
    }

    private func contents(of folder: URL) -> [String] {
        ((try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []).sorted()
    }

    @Test(arguments: HLGStillAsset.Level.allCases)
    func proResStillIsHLGAndDecodesToTheLumaWritten(level: HLGStillAsset.Level) async throws {
        let folder = temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let (url, report) = try await HLGStillAsset.ensureCached(level: level, codecs: [.proRes422], in: folder)
        #expect(url.lastPathComponent == "hlg-still-v1-proRes422-\(level.rawValue)-16.mov")
        #expect(report.codecFourCC == "apcn")
        #expect(report.isHLGBT2020)
        #expect(report.containsHDRVideo)
        #expect(report.width == 16 && report.height == 16)
        let luma = try #require(report.decodedLumaCode)
        #expect(abs(Int(luma) - Int(level.lumaCode)) <= 4)
        #expect(report.fileBytes > 0 && report.fileBytes < 64 * 1024)
        #expect(contents(of: folder) == [url.lastPathComponent], "no temporary file is left behind")
    }

    @Test(.enabled(if: HLGStillAssetTests.hasHEVCEncoder, "needs an HEVC encoder"))
    func hevcStillIsPlainHLGWithoutDolbyVisionMetadata() async throws {
        let folder = temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let (url, report) = try await HLGStillAsset.ensureCached(level: .black, in: folder)
        #expect(url.lastPathComponent == "hlg-still-v1-hevcMain10-black-16.mov")
        #expect(report.codecFourCC == "hvc1")
        #expect(report.isHLGBT2020)
        #expect(report.sampleDescriptionAtoms.contains("hvcC"))
        #expect(!report.sampleDescriptionAtoms.contains("dvvC"))
        #expect(report.satisfies(HLGStillAsset.Spec(codec: .hevcMain10, level: .black)))
    }

    @Test func aVerifiedCachedStillIsReusedWithoutEncodingAgain() async throws {
        let folder = temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let first = try await HLGStillAsset.ensureCached(level: .peak, codecs: [.proRes422], in: folder)
        let identity = try fileIdentity(first.url)
        let second = try await HLGStillAsset.ensureCached(level: .peak, codecs: [.proRes422], in: folder)
        #expect(second.url == first.url)
        #expect(try fileIdentity(second.url) == identity, "the same file, not a re-encoded one")
        #expect(second.report == first.report)
    }

    @Test func aCorruptCachedStillIsReplacedByAVerifiedOne() async throws {
        let folder = temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let spec = HLGStillAsset.Spec(codec: .proRes422, level: .black)
        let destination = folder.appending(path: spec.fileName)
        let garbage = Data(repeating: 0x5A, count: 512)
        try garbage.write(to: destination)
        let (url, report) = try await HLGStillAsset.ensureCached(level: .black, codecs: [.proRes422], in: folder)
        #expect(url == destination)
        #expect(report.satisfies(spec))
        #expect(try Data(contentsOf: url) != garbage)
        #expect(contents(of: folder) == [spec.fileName])
    }

    @Test func aStillOfAnotherLevelUnderTheNameIsNotTrusted() async throws {
        // A file that decodes but shows the wrong level (or codec) fails verification and is replaced.
        let folder = temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let peak = try await HLGStillAsset.ensureCached(level: .peak, codecs: [.proRes422], in: folder)
        let blackSpec = HLGStillAsset.Spec(codec: .proRes422, level: .black)
        #expect(!peak.report.satisfies(blackSpec))
        #expect(!peak.report.satisfies(HLGStillAsset.Spec(codec: .hevcMain10, level: .peak)))
        try FileManager.default.copyItem(at: peak.url, to: folder.appending(path: blackSpec.fileName))
        let black = try await HLGStillAsset.ensureCached(level: .black, codecs: [.proRes422], in: folder)
        #expect(black.report.satisfies(blackSpec))
    }

    @Test func noCodecMeansAnErrorAndNoFile() async {
        let folder = temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        await #expect(throws: HLGStillAsset.Failure.self) {
            _ = try await HLGStillAsset.ensureCached(level: .black, codecs: [], in: folder)
        }
        #expect(contents(of: folder).isEmpty)
    }

    @Test func temporariesACrashLeftAreSweptAndEverythingElseIsKept() async throws {
        let fm = FileManager.default
        let folder = temporaryFolder()
        defer { try? fm.removeItem(at: folder) }
        try fm.createDirectory(at: folder, withIntermediateDirectories: true)
        let stale = HLGStillAsset.temporaryName(), fresh = HLGStillAsset.temporaryName()
        let other = ".notes.mov", still = HLGStillAsset.Spec(codec: .proRes422, level: .black).fileName
        for name in [stale, fresh, other, still] { try Data([1]).write(to: folder.appending(path: name)) }
        let old = Date().addingTimeInterval(-(HLGStillAsset.staleTemporaryAge + 60))
        for name in [stale, other, still] {
            try fm.setAttributes([.modificationDate: old], ofItemAtPath: folder.appending(path: name).path)
        }
        // No codec: nothing is encoded, so the folder shows only what the sweep did.
        await #expect(throws: HLGStillAsset.Failure.self) {
            _ = try await HLGStillAsset.ensureCached(level: .black, codecs: [], in: folder)
        }
        #expect(contents(of: folder) == [fresh, other, still].sorted(), "a fresh temporary may be another generation's")
        #expect(HLGStillAsset.isTemporaryName(fresh))
        #expect(!HLGStillAsset.isTemporaryName(other))
        #expect(!HLGStillAsset.isTemporaryName(still))
        #expect(!HLGStillAsset.isTemporaryName(".\(UUID().uuidString).mp4"))
        HLGStillAsset.sweepStaleTemporaries(in: folder, now: Date().addingTimeInterval(HLGStillAsset.staleTemporaryAge + 60))
        #expect(contents(of: folder) == [other, still].sorted())
    }

    @Test func atomicMoveReplacesTheDestination() throws {
        let folder = temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let source = folder.appending(path: ".new.mov"), destination = folder.appending(path: "final.mov")
        try Data([1, 2, 3]).write(to: source)
        try Data([9]).write(to: destination)
        try HLGStillAsset.moveAtomically(source, over: destination)
        #expect(try Data(contentsOf: destination) == Data([1, 2, 3]))
        #expect(!FileManager.default.fileExists(atPath: source.path))
        #expect(throws: HLGStillAsset.Failure.self) { try HLGStillAsset.moveAtomically(source, over: destination) }
    }

    @Test func namesAreVersionedAndLevelsFollowThePixel() {
        #expect(HLGStillAsset.Spec(codec: .hevcMain10, level: .peak, edge: 16).fileName
                == "hlg-still-v1-hevcMain10-peak-16.mov")
        #expect(HLGStillAsset.Level(TriggerPixel.black) == .black)
        #expect(HLGStillAsset.Level(TriggerPixel.sdrWhite) == .sdrWhite)
        #expect(HLGStillAsset.Level(TriggerPixel.bright) == .peak)
        #expect(HLGStillAsset.Level.black.lumaCode == 64)
        #expect(HLGStillAsset.Level.sdrWhite.lumaCode == 721)
        #expect(HLGStillAsset.Level.peak.lumaCode == 940)
    }

    @Test func theInMemoryFrameIsTaggedHLGWithTheLevelsLuma() throws {
        let buffer = try #require(HLGStillAsset.makePixelBuffer(edge: 16, lumaCode: 940))
        #expect(CVPixelBufferGetPixelFormatType(buffer) == kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange)
        #expect(CVBufferCopyAttachment(buffer, kCVImageBufferTransferFunctionKey, nil) as? String
                == kCVImageBufferTransferFunction_ITU_R_2100_HLG as String)
        #expect(CVBufferCopyAttachment(buffer, kCVImageBufferColorPrimariesKey, nil) as? String
                == kCVImageBufferColorPrimaries_ITU_R_2020 as String)
        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
        let luma = try #require(CVPixelBufferGetBaseAddressOfPlane(buffer, 0)).assumingMemoryBound(to: UInt16.self)
        let chroma = try #require(CVPixelBufferGetBaseAddressOfPlane(buffer, 1)).assumingMemoryBound(to: UInt16.self)
        #expect(luma[0] >> 6 == 940)
        #expect(chroma[0] >> 6 == 512)
        let sample = try #require(HLGSampleBufferTrigger.makeSampleBuffer(level: .black))
        let format = try #require(CMSampleBufferGetFormatDescription(sample))
        #expect(CMVideoFormatDescriptionGetDimensions(format).width == 16)
        let attachments = try #require(CMSampleBufferGetSampleAttachmentsArray(sample, createIfNecessary: false)
                                       as? [[CFString: Any]])
        #expect(attachments.first?[kCMSampleAttachmentKey_DisplayImmediately] as? Bool == true)
    }

    // MARK: HLGStillCache

    @Test func twoTriggersAskingAtOnceShareOneGeneration() async throws {
        let folder = temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let cache = HLGStillCache(directory: folder, codecs: [.proRes422])
        async let first = cache.url(for: .black)
        async let second = cache.url(for: .black)
        let (a, b) = await (first, second)
        let url = try #require(a)
        #expect(b == url)
        #expect(cache.generations == 1)
        #expect(contents(of: folder) == [url.lastPathComponent])
        let again = await cache.url(for: .black)
        #expect(again == url)
        #expect(cache.generations == 1, "a verified still is not checked again in the same launch")
    }

    @Test func aStillDeletedFromTheCacheIsMadeAgain() async throws {
        let folder = temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let cache = HLGStillCache(directory: folder, codecs: [.proRes422])
        let url = try #require(await cache.url(for: .sdrWhite))
        try FileManager.default.removeItem(at: url)
        let again = try #require(await cache.url(for: .sdrWhite))
        #expect(FileManager.default.fileExists(atPath: again.path))
    }

    @Test func aCacheWithoutCodecsAnswersNil() async {
        let folder = temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let cache = HLGStillCache(directory: folder, codecs: [])
        #expect(await cache.url(for: .black) == nil)
    }

    private func fileIdentity(_ url: URL) throws -> [String] {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        let number = (attributes[.systemFileNumber] as? NSNumber)?.stringValue ?? "?"
        let modified = (attributes[.modificationDate] as? Date)?.timeIntervalSinceReferenceDate ?? 0
        return [number, String(modified)]
    }
}
