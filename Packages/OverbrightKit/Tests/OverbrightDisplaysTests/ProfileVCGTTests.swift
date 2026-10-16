// OverbrightDisplaysTests/ProfileVCGTTests.swift — the `vcgt` parser behind `profileBase` (D26), on minimal synthetic
// ICC data (ARCHITECTURE.md §4.8). Real, ColorSync-validated profiles are in `ProfileBaseTests`. No test constructs a
// real port.
import Foundation
import OverbrightCore
import Testing
@testable import OverbrightDisplays

@Suite struct ProfileVCGTTests {
    /// A minimal ICC profile: a 128-byte header, a tag table with one entry, and `tag` at the end.
    private func profile(signature: UInt32 = ProfileVCGT.vcgtSignature, tag: [UInt8]) -> Data {
        var bytes = [UInt8](repeating: 0, count: 128)
        func append32(_ value: UInt32) { bytes += [24, 16, 8, 0].map { UInt8(truncatingIfNeeded: value >> $0) } }
        append32(1)                                    // tag count
        append32(signature)
        append32(UInt32(128 + 4 + 12))                 // offset
        append32(UInt32(tag.count))
        return Data(bytes + tag)
    }

    private func header(kind: UInt32) -> [UInt8] {
        [0x76, 0x63, 0x67, 0x74, 0, 0, 0, 0] + [24, 16, 8, 0].map { UInt8(truncatingIfNeeded: kind >> $0) }
    }

    @Test func parsesASixteenBitTable() throws {
        // 3 channels × 3 entries × 2 bytes: red 0, ½, 1; green 0, ¼, ½; blue 0, 1, 1.
        let samples: [[UInt16]] = [[0, 32768, 65535], [0, 16384, 32768], [0, 65535, 65535]]
        let data = samples.flatMap { $0.flatMap { [UInt8($0 >> 8), UInt8($0 & 0xFF)] } }
        let tag = header(kind: 0) + [0, 3, 0, 3, 0, 2] + data
        let vcgt = try #require(ProfileVCGT.parse(iccData: profile(tag: tag)))
        let table = vcgt.table(count: 5)
        #expect(table.count == 5)
        #expect(abs(Double(table.red[2]) - 0.5) < 0.001 && table.red[4] == 1)
        #expect(abs(Double(table.green[4]) - 0.5) < 0.001)
        #expect(table.blue[2] == 1)
    }

    @Test func parsesAOneChannelEightBitTable() throws {
        let tag = header(kind: 0) + [0, 1, 0, 2, 0, 1] + [0, 255]
        let table = try #require(ProfileVCGT.parse(iccData: profile(tag: tag))).table(count: 3)
        #expect(table == GammaTable.identity(count: 3))
    }

    @Test func parsesAFormula() throws {
        func fixed(_ value: Double) -> [UInt8] {
            let raw = UInt32(bitPattern: Int32(value * 65536))
            return [24, 16, 8, 0].map { UInt8(truncatingIfNeeded: raw >> $0) }
        }
        let channel = fixed(2) + fixed(0) + fixed(1)                     // x²
        let tag = header(kind: 1) + channel + channel + channel
        let table = try #require(ProfileVCGT.parse(iccData: profile(tag: tag))).table(count: 3)
        #expect(table.red == [0, 0.25, 1] && table.green == table.red && table.blue == table.red)
    }

    @Test func noTagOrBrokenDataIsNil() {
        #expect(ProfileVCGT.parse(iccData: profile(signature: 0x7258_595A, tag: [0, 0, 0, 0])) == nil)   // 'rXYZ'
        #expect(ProfileVCGT.parse(iccData: Data(repeating: 0, count: 64)) == nil)
        let truncated = header(kind: 0) + [0, 3, 0, 255, 0, 2] + [0, 1]
        #expect(ProfileVCGT.parse(iccData: profile(tag: truncated)) == nil)
    }
}
