// OverbrightDisplays/Gamma/ProfileVCGT.swift — the `vcgt` tag of an ICC profile: the curve macOS loads into a display's
// transfer table, i.e. the display's expected base (D26). ARCHITECTURE.md §4.8, §10.4.
// Seeded by WP0a so that `--diagnostics` can judge every table against its profile base; owned by WP2 afterwards
// (`ProfileBaseTests` with real ICC fixtures). Pure: parses bytes, touches no display.
import Foundation
import OverbrightCore

/// A parsed `vcgt` tag: per-channel sampled curves or per-channel formulas, as the ICC data stores them.
public nonisolated struct ProfileVCGT: Hashable, Sendable {
    /// One channel's formula: `minimum + (maximum − minimum) · x^gamma`.
    public struct Formula: Hashable, Sendable {
        /// The exponent.
        public var gamma: Double
        /// The value at 0.
        public var minimum: Double
        /// The value at 1.
        public var maximum: Double
        /// A formula.
        public init(gamma: Double, minimum: Double, maximum: Double) {
            self.gamma = gamma; self.minimum = minimum; self.maximum = maximum
        }
    }

    /// The tag's content.
    public enum Curves: Hashable, Sendable {
        /// Red, green and blue samples in 0 … 1 (a one-channel tag is repeated for all three).
        case table(red: [Double], green: [Double], blue: [Double])
        /// Red, green and blue formulas.
        case formula(red: Formula, green: Formula, blue: Formula)
    }

    /// The curves.
    public var curves: Curves

    /// A tag with `curves`.
    public init(curves: Curves) { self.curves = curves }

    /// The `vcgt` tag of ICC profile `data`, or nil when the profile has none or it is malformed.
    public static func parse(iccData data: Data) -> ProfileVCGT? {
        let bytes = [UInt8](data)
        guard let tagCount = uint32(bytes, at: 128), tagCount < 1024 else { return nil }
        for index in 0..<Int(tagCount) {
            let entry = 132 + index * 12
            guard let signature = uint32(bytes, at: entry), let offset = uint32(bytes, at: entry + 4),
                  let size = uint32(bytes, at: entry + 8) else { return nil }
            guard signature == vcgtSignature else { continue }
            let start = Int(offset), end = start + Int(size)
            guard start >= 0, end <= bytes.count, size >= 12 else { return nil }
            return parseTag(Array(bytes[start..<end]))
        }
        return nil
    }

    /// The curves resampled to `count` entries per channel (the display's table length).
    public func table(count: Int) -> GammaTable {
        guard count > 0 else { return GammaTable(red: [], green: [], blue: []) }
        switch curves {
        case let .table(red, green, blue):
            return GammaTable(red: Self.resample(red, count: count), green: Self.resample(green, count: count),
                              blue: Self.resample(blue, count: count))
        case let .formula(red, green, blue):
            func channel(_ f: Formula) -> [Float] {
                (0..<count).map { i in
                    let x = Double(i) / Double(max(count - 1, 1))
                    return Float(f.minimum + (f.maximum - f.minimum) * pow(x, f.gamma))
                }
            }
            return GammaTable(red: channel(red), green: channel(green), blue: channel(blue))
        }
    }

    // MARK: Parsing

    /// 'vcgt'.
    static let vcgtSignature: UInt32 = 0x7663_6774

    private static func parseTag(_ tag: [UInt8]) -> ProfileVCGT? {
        guard uint32(tag, at: 0) == vcgtSignature, let kind = uint32(tag, at: 8) else { return nil }
        switch kind {
        case 0:
            guard let channels = uint16(tag, at: 12), let entries = uint16(tag, at: 14),
                  let entrySize = uint16(tag, at: 16), channels == 1 || channels == 3, entries >= 2,
                  entrySize == 1 || entrySize == 2 else { return nil }
            let width = Int(entrySize), length = Int(entries)
            guard tag.count >= 18 + Int(channels) * length * width else { return nil }
            let scale = entrySize == 1 ? 255.0 : 65535.0
            func channel(_ c: Int) -> [Double] {
                (0..<length).map { i in
                    let at = 18 + (c * length + i) * width
                    let raw = width == 1 ? Double(tag[at]) : Double(UInt16(tag[at]) << 8 | UInt16(tag[at + 1]))
                    return raw / scale
                }
            }
            let red = channel(0)
            return channels == 1 ? ProfileVCGT(curves: .table(red: red, green: red, blue: red))
                : ProfileVCGT(curves: .table(red: red, green: channel(1), blue: channel(2)))
        case 1:
            let values = (0..<9).compactMap { s15Fixed16(tag, at: 12 + $0 * 4) }
            guard values.count == 9 else { return nil }
            func formula(_ c: Int) -> Formula {
                Formula(gamma: values[c * 3], minimum: values[c * 3 + 1], maximum: values[c * 3 + 2])
            }
            return ProfileVCGT(curves: .formula(red: formula(0), green: formula(1), blue: formula(2)))
        default:
            return nil
        }
    }

    private static func uint32(_ bytes: [UInt8], at offset: Int) -> UInt32? {
        guard offset >= 0, offset + 4 <= bytes.count else { return nil }
        return bytes[offset..<offset + 4].reduce(0) { $0 << 8 | UInt32($1) }
    }

    private static func uint16(_ bytes: [UInt8], at offset: Int) -> UInt16? {
        guard offset >= 0, offset + 2 <= bytes.count else { return nil }
        return UInt16(bytes[offset]) << 8 | UInt16(bytes[offset + 1])
    }

    private static func s15Fixed16(_ bytes: [UInt8], at offset: Int) -> Double? {
        uint32(bytes, at: offset).map { Double(Int32(bitPattern: $0)) / 65536 }
    }

    private static func resample(_ samples: [Double], count: Int) -> [Float] {
        guard samples.count > 1 else { return GammaTable.identity(count: count).red }
        return (0..<count).map { i in
            let x = Double(i) / Double(max(count - 1, 1)) * Double(samples.count - 1)
            let lower = Int(x.rounded(.down)), upper = min(lower + 1, samples.count - 1)
            let t = x - Double(lower)
            return Float(samples[lower] + (samples[upper] - samples[lower]) * t)
        }
    }
}
