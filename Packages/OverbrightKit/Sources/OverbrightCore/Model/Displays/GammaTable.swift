// OverbrightCore/Model/Displays/GammaTable.swift — one display transfer table. ARCHITECTURE.md §3.2, §4.8, D26.

/// One display transfer table (`CGGet/SetDisplayTransferByTable`), all three channels the same length.
public nonisolated struct GammaTable: Hashable, Sendable, Codable {
    /// Red channel samples, 0 … 1 (and above 1 while scaled).
    public var red: [Float]
    /// Green channel samples.
    public var green: [Float]
    /// Blue channel samples.
    public var blue: [Float]
    /// A table from its three channels (same length).
    public init(red: [Float], green: [Float], blue: [Float]) { self.red = red; self.green = green; self.blue = blue }
    /// Number of samples per channel.
    public var count: Int { red.count }
    /// Largest entry over all channels. Diagnostics only: read-back may clamp at 1.0 (D26), so neutrality and
    /// residue are judged by `TableClassifier` against the profile base, never by this value.
    public var maximum: Float { max(red.max() ?? 0, green.max() ?? 0, blue.max() ?? 0) }
    /// A neutral (identity) ramp: the base of a display whose profile has no `vcgt`.
    public static func identity(count: Int) -> GammaTable {
        let ramp = (0..<count).map { Float($0) / Float(max(count - 1, 1)) }
        return GammaTable(red: ramp, green: ramp, blue: ramp)
    }
}
