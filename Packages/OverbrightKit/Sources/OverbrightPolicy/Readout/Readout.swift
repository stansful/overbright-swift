// OverbrightPolicy/Readout/Readout.swift — builds a card's readout numbers. ARCHITECTURE.md §3.10; DESIGN.md §5.6.
// Stub until WP1.
import OverbrightCore

/// Builds `ReadoutValues` from a display's status.
public nonisolated enum Readout {
    /// The readout numbers of one display.
    public static func values(for status: DisplayStatus, isMasterOn: Bool) -> ReadoutValues {
        _ = (status, isMasterOn)
        return ReadoutValues(state: .off, appliedGain: 1, requestedGain: nil, nits: nil, preset: nil, isEstimate: true,
                             dimPercent: nil)   // WP1
    }
}
