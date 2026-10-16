// OverbrightDisplays/Monitor/DisplayMonitor.swift — the read-only `--monitor` loop. ARCHITECTURE.md §8.5, D20, D26.
// Seam written by WP0a (§10.0): the shell calls `DisplayMonitor.run(interval:duration:output:)` for `--monitor`; WP2
// writes the body (one JSON line per display every 250 ms: key, table class against the profile base and its ratio,
// table max, mid entry, H, potential, reference). It starts no service, opens no window and never writes.

/// Prints the state of every display until Ctrl-C or `duration`.
public enum DisplayMonitor {
    /// Writes one line per display through `output` every `interval`, for `duration` (nil: until the process is
    /// interrupted). WP0a seam: returns at once without output.
    public static func run(interval: Duration, duration: Duration?, output: (String) -> Void) async {}
}
