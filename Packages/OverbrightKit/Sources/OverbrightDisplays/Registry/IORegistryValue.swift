// OverbrightDisplays/Registry/IORegistryValue.swift — decoders for the IORegistry property shapes Overbright reads.
// ARCHITECTURE.md §9.2 rule 6, §10.4; docs/research/display-facts.md §5. Pure: works on the values IOKit (or a saved
// `ioreg -a` fixture) hands out, touches no registry entry. Every key is undocumented, so every decoder is optional.
import Foundation

/// Decodes IORegistry property values: device-tree data blobs, CF numbers, booleans and dictionaries.
nonisolated enum IORegistryValue {
    /// A 16.16 fixed-point number stored as 4 little-endian bytes of device-tree data
    /// (`EDRPotentialHeadroom = <00001000>` is 16.0, `user-accessible-max-nits = <00005802>` is 600.0).
    static func fixedPointData(_ value: Any?) -> Double? {
        littleEndianWord(value).map { Double($0) / 65536 }
    }

    /// An IEEE 754 single stored as 4 little-endian bytes of device-tree data (`aurora-maximum-nits = <00007a44>`).
    static func floatData(_ value: Any?) -> Double? {
        littleEndianWord(value).map { Double(Float(bitPattern: $0)) }
    }

    /// A 16.16 fixed-point number stored as an integer (`DisplayAttributes.Luminance.Max = 30506349` is 465.49 nits).
    static func fixedPointInteger(_ value: Any?) -> Double? {
        integer(value).map { Double($0) / 65536 }
    }

    /// An integer property (CFNumber), nil for anything else (a boolean is not an integer).
    static func integer(_ value: Any?) -> Int64? {
        guard let number = value as? NSNumber, !isBoolean(number) else { return nil }
        return number.int64Value
    }

    /// An unsigned 32-bit integer property (EDID vendor, product and serial numbers).
    static func uint32(_ value: Any?) -> UInt32? {
        integer(value).flatMap { UInt32(exactly: $0) }
    }

    /// A boolean property (`SupportsPQEOTF = Yes`); a CFNumber counts as true when non-zero.
    static func bool(_ value: Any?) -> Bool? {
        (value as? NSNumber)?.boolValue
    }

    /// A string property.
    static func string(_ value: Any?) -> String? {
        value as? String
    }

    /// A dictionary property (`DisplayAttributes`, `IODisplayParameters`).
    static func dictionary(_ value: Any?) -> [String: Any]? {
        value as? [String: Any]
    }

    // MARK: Private

    private static func littleEndianWord(_ value: Any?) -> UInt32? {
        guard let data = value as? Data, data.count == 4 else { return nil }
        return data.reversed().reduce(UInt32(0)) { $0 << 8 | UInt32($1) }
    }

    private static func isBoolean(_ number: NSNumber) -> Bool {
        CFGetTypeID(number) == CFBooleanGetTypeID()
    }
}
