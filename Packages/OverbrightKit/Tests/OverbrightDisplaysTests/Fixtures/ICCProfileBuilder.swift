// OverbrightDisplaysTests/Fixtures/ICCProfileBuilder.swift — builds small, valid ICC v2 display profiles (our own
// bytes: sRGB-like primaries, a 2.2 tone curve) carrying a given `vcgt` tag, so the `vcgt` parser is checked against
// real profile data that ColorSync itself accepts and decodes (ProfileBaseTests). In memory only.
import Foundation

/// ICC profile and `vcgt` tag bytes.
enum ICCProfileBuilder {
    /// A display-class RGB profile with `desc`, `cprt`, `wtpt`, `r/g/bXYZ`, `r/g/bTRC` and, when given, `vcgt`.
    static func displayProfile(vcgt: [UInt8]?) -> Data {
        var tags: [(signature: String, data: [UInt8])] = [
            ("desc", textDescription("Overbright test display")),
            ("cprt", text("No copyright, test data")),
            ("wtpt", xyz(0.9642, 1.0, 0.8249)),
            ("rXYZ", xyz(0.4361, 0.2225, 0.0139)),
            ("gXYZ", xyz(0.3851, 0.7169, 0.0971)),
            ("bXYZ", xyz(0.1431, 0.0606, 0.7141)),
            ("rTRC", gammaCurve(2.2)), ("gTRC", gammaCurve(2.2)), ("bTRC", gammaCurve(2.2)),
        ]
        if let vcgt { tags.append(("vcgt", vcgt)) }

        let tableSize = 4 + 12 * tags.count
        var offset = 128 + tableSize
        var table = be32(UInt32(tags.count))
        var payload: [UInt8] = []
        for tag in tags {
            let padded = tag.data + [UInt8](repeating: 0, count: (4 - tag.data.count % 4) % 4)
            table += ascii(tag.signature) + be32(UInt32(offset)) + be32(UInt32(tag.data.count))
            payload += padded
            offset += padded.count
        }
        var header = be32(UInt32(128 + tableSize + payload.count))     // profile size
        header += [UInt8](repeating: 0, count: 4)                         // preferred CMM
        header += be32(0x0210_0000)                                       // version 2.1
        header += ascii("mntr") + ascii("RGB ") + ascii("XYZ ")
        header += [2026, 10, 16, 0, 0, 0].flatMap { be16(UInt16($0)) } // date
        header += ascii("acsp") + ascii("APPL")
        header += [UInt8](repeating: 0, count: 4 + 4 + 4 + 8 + 4)        // flags, manufacturer, model, attributes, intent
        header += s15Fixed16(0.9642) + s15Fixed16(1.0) + s15Fixed16(0.8249)   // PCS illuminant (D50)
        header += [UInt8](repeating: 0, count: 128 - header.count)
        return Data(header + table + payload)
    }

    /// A `vcgt` table tag (type 0) with 16-bit entries: one channel or three.
    static func vcgtTable16(_ channels: [[UInt16]]) -> [UInt8] {
        let entries = channels.first?.count ?? 0
        return ascii("vcgt") + [0, 0, 0, 0] + be32(0) + be16(UInt16(channels.count)) + be16(UInt16(entries)) + be16(2)
            + channels.flatMap { $0.flatMap(be16) }
    }

    /// A `vcgt` table tag (type 0) with 8-bit entries.
    static func vcgtTable8(_ channels: [[UInt8]]) -> [UInt8] {
        let entries = channels.first?.count ?? 0
        return ascii("vcgt") + [0, 0, 0, 0] + be32(0) + be16(UInt16(channels.count)) + be16(UInt16(entries)) + be16(1)
            + channels.flatMap { $0 }
    }

    /// A `vcgt` formula tag (type 1): per channel gamma, minimum, maximum.
    static func vcgtFormula(_ channels: [(gamma: Double, minimum: Double, maximum: Double)]) -> [UInt8] {
        ascii("vcgt") + [0, 0, 0, 0] + be32(1)
            + channels.flatMap { s15Fixed16($0.gamma) + s15Fixed16($0.minimum) + s15Fixed16($0.maximum) }
    }

    // MARK: Tag types

    private static func textDescription(_ value: String) -> [UInt8] {
        let bytes = Array(value.utf8) + [0]
        return ascii("desc") + [0, 0, 0, 0] + be32(UInt32(bytes.count)) + bytes
            + be32(0) + be32(0)                     // Unicode language code and count
            + be16(0) + [0] + [UInt8](repeating: 0, count: 67)   // ScriptCode code, count, string
    }

    private static func text(_ value: String) -> [UInt8] {
        ascii("text") + [0, 0, 0, 0] + Array(value.utf8) + [0]
    }

    private static func xyz(_ x: Double, _ y: Double, _ z: Double) -> [UInt8] {
        ascii("XYZ ") + [0, 0, 0, 0] + s15Fixed16(x) + s15Fixed16(y) + s15Fixed16(z)
    }

    private static func gammaCurve(_ gamma: Double) -> [UInt8] {
        ascii("curv") + [0, 0, 0, 0] + be32(1) + be16(UInt16((gamma * 256).rounded()))
    }

    // MARK: Encoding

    static func be32(_ value: UInt32) -> [UInt8] { [24, 16, 8, 0].map { UInt8(truncatingIfNeeded: value >> $0) } }
    static func be16(_ value: UInt16) -> [UInt8] { [UInt8(value >> 8), UInt8(value & 0xFF)] }
    static func s15Fixed16(_ value: Double) -> [UInt8] { be32(UInt32(bitPattern: Int32((value * 65536).rounded()))) }
    static func ascii(_ value: String) -> [UInt8] { Array(value.utf8.prefix(4)) }
}
