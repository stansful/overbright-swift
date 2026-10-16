// OverbrightTestSupport/SeededGenerator.swift — reproducible randomness for property tests. ARCHITECTURE.md §9.1.

/// A seeded random number generator (SplitMix64): the same seed always gives the same sequence, so a property test
/// that fails names a seed that reproduces it. `var g = SeededGenerator(seed: 42); Double.random(in: 1...16, using: &g)`.
public nonisolated struct SeededGenerator: RandomNumberGenerator, Sendable {
    private var state: UInt64

    /// A generator starting from `seed`.
    public init(seed: UInt64) { state = seed }

    /// The next 64 random bits.
    public mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
