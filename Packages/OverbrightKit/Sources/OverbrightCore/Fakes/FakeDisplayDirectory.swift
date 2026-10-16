// OverbrightCore/Fakes/FakeDisplayDirectory.swift — a DisplayDirectory over fixture facts. ARCHITECTURE.md §3.9.
import Observation

/// A `DisplayDirectory` whose displays tests set, add, remove and change (each change bumps `generation`, as the real
/// directory does after a reconfiguration pass or a removal).
@MainActor @Observable public final class FakeDisplayDirectory: DisplayDirectory {
    /// Online displays, built-in first, then by key.
    public private(set) var displays: [DisplayFacts] = []
    /// Increments on every change of `displays`.
    public private(set) var generation = 0

    /// A directory with `displays` online.
    public init(displays: [DisplayFacts] = []) { self.displays = Self.sorted(displays) }
    /// The displays of `fixture`.
    public convenience init(fixture: DisplayFixture) { self.init(displays: fixture.displays.map(\.facts)) }

    /// The facts of one online display.
    public func facts(for key: DisplayKey) -> DisplayFacts? { displays.first { $0.ref.key == key } }

    /// Replaces every display.
    public func setDisplays(_ newDisplays: [DisplayFacts]) {
        displays = Self.sorted(newDisplays)
        generation += 1
    }
    /// A display connects (or its facts are replaced).
    public func add(_ facts: DisplayFacts) {
        setDisplays(displays.filter { $0.ref.key != facts.ref.key } + [facts])
    }
    /// A display disconnects.
    public func remove(_ key: DisplayKey) { setDisplays(displays.filter { $0.ref.key != key }) }
    /// Changes the facts of one display (new ID after a reconfiguration, HDR switched, …).
    public func update(_ key: DisplayKey, _ change: (inout DisplayFacts) -> Void) {
        guard var facts = facts(for: key) else { return }
        change(&facts)
        add(facts)
    }

    private static func sorted(_ displays: [DisplayFacts]) -> [DisplayFacts] {
        displays.sorted { a, b in a.isBuiltIn != b.isBuiltIn ? a.isBuiltIn : a.ref.key < b.ref.key }
    }
}
