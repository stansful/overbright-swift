// OverbrightDisplaysTests/ProfileBaseTests.swift — the expected base of a display from real ICC profile data (D26,
// ARCHITECTURE.md §4.8, §10.4 acceptance "an ICC fixture with a vcgt parses exactly"). Profiles are built in memory
// (`ICCProfileBuilder`) and must be accepted by ColorSync; ColorSync's own `vcgt` decoders are the reference the parser
// is compared with. The MSI's real `vcgt` (a formula) is one fixture. No display is touched.
import ColorSync
import Foundation
import OverbrightCore
import Testing
@testable import OverbrightDisplays

@Suite struct ProfileBaseTests {
    /// A calibration-loader-like curve per channel (white point and gamma tweaks), quantized to 16 bits.
    private static let calibratedSamples: [[UInt16]] = [(0.985, 1.02), (1.0, 0.99), (0.96, 0.98)].map { scale, exponent in
        (0..<256).map { UInt16((scale * pow(Double($0) / 255, exponent) * 65535).rounded()) }
    }

    // MARK: Real profiles

    @Test func theMSIsFormulaVCGTParsesExactlyAndIsIdentity() throws {
        let icc = ICCProfileBuilder.displayProfile(vcgt: OwnerIORegistry.msiProfileVCGT)
        let profile = try #require(Self.colorSyncProfile(icc))
        let vcgt = try #require(ProfileVCGT.parse(iccData: icc))
        let identity = ProfileVCGT.Formula(gamma: 1, minimum: 0, maximum: 1)
        #expect(vcgt.curves == .formula(red: identity, green: identity, blue: identity))
        // ColorSync reads the same formula.
        let reference = try #require(Self.colorSyncFormula(profile))
        #expect(reference == [0, 1, 1, 0, 1, 1, 0, 1, 1])               // min, max, gamma per channel
        // An identity base, at the display's table length (the MSI's capacity is 1024).
        let base = ProfileBase.table(iccData: icc, count: 1024)
        #expect(base.count == 1024)
        #expect(maxDifference(base, .identity(count: 1024)) < 1e-6)
    }

    @Test func aCalibratedTableVCGTParsesExactly() throws {
        let icc = ICCProfileBuilder.displayProfile(vcgt: ICCProfileBuilder.vcgtTable16(Self.calibratedSamples))
        let profile = try #require(Self.colorSyncProfile(icc))
        let vcgt = try #require(ProfileVCGT.parse(iccData: icc))
        guard case let .table(red, green, blue) = vcgt.curves else {
            Issue.record("expected a table vcgt, got \(vcgt.curves)")
            return
        }
        let expected = Self.calibratedSamples.map { $0.map { Double($0) / 65535 } }
        #expect(red == expected[0] && green == expected[1] && blue == expected[2])
        // ColorSync's own decoding of the same tag, at its sample count.
        let (samples, reference) = try #require(Self.colorSyncTables(profile))
        let ours = vcgt.table(count: samples)
        #expect(maxDifference(ours, reference) < 1e-4)
        // Per-channel, not identity: the base a calibration loader leaves (§4.8).
        #expect(ours.red != ours.green && ours.blue[samples - 1] < 0.97)
    }

    @Test func anEightBitOneChannelVCGTIsAppliedToEveryChannel() throws {
        let ramp = (0..<16).map { UInt8($0 * 17) }                      // 0 … 255
        let icc = ICCProfileBuilder.displayProfile(vcgt: ICCProfileBuilder.vcgtTable8([ramp]))
        #expect(Self.colorSyncProfile(icc) != nil)
        let base = ProfileBase.table(iccData: icc, count: 256)
        #expect(base.red == base.green && base.green == base.blue)
        #expect(maxDifference(base, .identity(count: 256)) < 1e-6)
    }

    @Test func aGammaFormulaMatchesColorSync() throws {
        let channels: [(gamma: Double, minimum: Double, maximum: Double)] = [(1.1, 0, 0.98), (1.0, 0.01, 1), (0.9, 0, 0.95)]
        let icc = ICCProfileBuilder.displayProfile(vcgt: ICCProfileBuilder.vcgtFormula(channels))
        let profile = try #require(Self.colorSyncProfile(icc))
        let reference = try #require(Self.colorSyncFormula(profile))
        let expected = channels.flatMap { [$0.minimum, $0.maximum, $0.gamma] }
        #expect(zip(reference, expected).allSatisfy { abs($0 - $1) < 1e-4 })
        let base = ProfileBase.table(iccData: icc, count: 3)
        #expect(abs(Double(base.red[2]) - 0.98) < 1e-4 && abs(Double(base.green[0]) - 0.01) < 1e-4)
        #expect(abs(Double(base.blue[1]) - 0.95 * pow(0.5, 0.9)) < 1e-4)
    }

    // MARK: Identity when absent

    @Test func noVCGTMeansIdentity() throws {
        let icc = ICCProfileBuilder.displayProfile(vcgt: nil)
        #expect(Self.colorSyncProfile(icc) != nil)
        #expect(ProfileVCGT.parse(iccData: icc) == nil)
        #expect(ProfileBase.table(iccData: icc, count: 1024) == .identity(count: 1024))
        #expect(ProfileBase.table(iccData: nil, count: 256) == .identity(count: 256))
    }

    @Test func aMalformedVCGTMeansIdentity() {
        let truncated = Array(ICCProfileBuilder.vcgtTable16(Self.calibratedSamples).prefix(400))
        let unknownType = ICCProfileBuilder.ascii("vcgt") + [0, 0, 0, 0] + ICCProfileBuilder.be32(2) + [0, 0, 0, 0]
        for tag in [truncated, unknownType] {
            let icc = ICCProfileBuilder.displayProfile(vcgt: tag)
            #expect(ProfileBase.table(iccData: icc, count: 512) == .identity(count: 512))
        }
        #expect(ProfileBase.table(iccData: Data([0x00, 0x01]), count: 8) == .identity(count: 8))
    }

    @Test func theBaseIsResampledToTheTableLength() throws {
        let icc = ICCProfileBuilder.displayProfile(vcgt: ICCProfileBuilder.vcgtTable16(Self.calibratedSamples))
        for count in [256, 1024, 4096] {
            let base = ProfileBase.table(iccData: icc, count: count)
            #expect(base.count == count && base.green.count == count && base.blue.count == count)
            #expect(base.red.first == 0)
            #expect(abs(Double(try #require(base.red.last)) - Double(Self.calibratedSamples[0][255]) / 65535) < 1e-6)
            #expect(zip(base.green, base.green.dropFirst()).allSatisfy { $0 <= $1 })      // monotonic
        }
    }

    // MARK: ColorSync reference

    private static func colorSyncProfile(_ icc: Data) -> ColorSyncProfile? {
        ColorSyncProfileCreate(icc as CFData, nil)?.takeRetainedValue()
    }

    /// ColorSync's table decoding of the profile's `vcgt`: the sample count and the three channels.
    private static func colorSyncTables(_ profile: ColorSyncProfile) -> (Int, GammaTable)? {
        var samples = 0
        guard let data = ColorSyncProfileCreateDisplayTransferTablesFromVCGT(profile, &samples)?.takeRetainedValue()
            as Data?, samples > 1 else { return nil }
        let floats = data.withUnsafeBytes { Array($0.bindMemory(to: Float.self)) }
        guard floats.count >= 3 * samples else { return nil }
        return (samples, GammaTable(red: Array(floats[0..<samples]), green: Array(floats[samples..<2 * samples]),
                                    blue: Array(floats[2 * samples..<3 * samples])))
    }

    /// ColorSync's formula reading: red min, max, gamma, then green, then blue.
    private static func colorSyncFormula(_ profile: ColorSyncProfile) -> [Double]? {
        var redMin: Float = 0, redMax: Float = 0, redGamma: Float = 0
        var greenMin: Float = 0, greenMax: Float = 0, greenGamma: Float = 0
        var blueMin: Float = 0, blueMax: Float = 0, blueGamma: Float = 0
        guard ColorSyncProfileGetDisplayTransferFormulaFromVCGT(profile, &redMin, &redMax, &redGamma,
                                                                &greenMin, &greenMax, &greenGamma,
                                                                &blueMin, &blueMax, &blueGamma) else { return nil }
        return [redMin, redMax, redGamma, greenMin, greenMax, greenGamma, blueMin, blueMax, blueGamma].map(Double.init)
    }
}

/// The largest per-entry difference over all channels (∞ for different lengths).
func maxDifference(_ a: GammaTable, _ b: GammaTable) -> Double {
    guard a.count == b.count else { return .infinity }
    let pairs = [(a.red, b.red), (a.green, b.green), (a.blue, b.blue)]
    return pairs.flatMap { zip($0, $1).map { Double(abs($0 - $1)) } }.max() ?? 0
}
