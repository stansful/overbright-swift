// OverbrightCore/Fakes/Fixtures/FixtureDisplay.swift — one display of a fixture. ARCHITECTURE.md §3.9.

/// One display of a `DisplayFixture`: its facts, how macOS grants it headroom, and its profile base.
public nonisolated struct FixtureDisplay: Hashable, Sendable {
    /// What `FakeDisplayDirectory` lists.
    public var facts: DisplayFacts
    /// What `ScriptedHeadroom` reads.
    public var headroom: HeadroomScript
    /// The base `FakeGammaPort` holds (the profile's `vcgt`, identity when absent); nil = no transfer table.
    public var profileBase: GammaTable?
    /// A fixture display.
    public init(facts: DisplayFacts, headroom: HeadroomScript, profileBase: GammaTable?) {
        self.facts = facts; self.headroom = headroom; self.profileBase = profileBase
    }
    /// Its key.
    public var key: DisplayKey { facts.ref.key }
}
