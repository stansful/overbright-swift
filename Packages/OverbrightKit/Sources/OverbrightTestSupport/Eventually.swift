// OverbrightTestSupport/Eventually.swift — the one real-time wait tests may use. ARCHITECTURE.md §9.1 (Cranny's rule:
// never bound main-actor scheduling with a short real-time wait; use ManualTimeSource, or this with 30 s).

/// Waits until `condition` holds, checking every 10 ms for at most `timeout` (30 s by default, a generous bound that
/// only a real failure reaches). Returns whether it held; pair it with `#expect`.
@MainActor @discardableResult
public func eventually(timeout: Duration = .seconds(30), _ condition: @MainActor () -> Bool) async -> Bool {
    let clock = ContinuousClock()
    let deadline = clock.now.advanced(by: timeout)
    while !condition() {
        guard clock.now < deadline else { return false }
        try? await Task.sleep(for: .milliseconds(10))
    }
    return true
}
