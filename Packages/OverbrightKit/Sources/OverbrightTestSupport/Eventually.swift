// OverbrightTestSupport/Eventually.swift — the one real-time wait tests may use. ARCHITECTURE.md §9.1 (Cranny's rule:
// never bound main-actor scheduling with a short real-time wait; use ManualTimeSource, or this with 30 s).
//
// The bound counts checks as well as time: a main actor busy with other tests' work (snapshot suites under the Thread
// Sanitizer on a loaded machine kept it busy for over a minute) checks the condition far less often than every 10 ms,
// and a clock alone then ran out while what the test waits for was still queued behind that work.

/// Waits until `condition` holds, checking it every 10 ms. Gives up only once `timeout` (30 s by default, a generous
/// bound that only a real failure reaches) has passed **and** the condition was checked as often as an idle main actor
/// checks it in that time, so a starved main actor waits longer instead of failing. Returns whether it held; pair it
/// with `#expect`.
@MainActor @discardableResult
public func eventually(timeout: Duration = .seconds(30), _ condition: @MainActor () -> Bool) async -> Bool {
    let interval = Duration.milliseconds(10)
    let clock = ContinuousClock()
    let deadline = clock.now.advanced(by: timeout)
    let minimumChecks = Int(timeout / interval)
    var checks = 0
    while !condition() {
        checks += 1
        guard clock.now < deadline || checks < minimumChecks else { return false }
        try? await Task.sleep(for: interval)
    }
    return true
}
