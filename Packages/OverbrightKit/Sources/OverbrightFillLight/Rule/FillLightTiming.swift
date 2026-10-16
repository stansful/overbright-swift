// OverbrightFillLight/Rule/FillLightTiming.swift — every Fill Light time constant, named. ARCHITECTURE.md §7.1, §10.9;
// DESIGN.md §11 (camera rule), §17 (energy: no redraw unless something changes).

/// The Fill Light's time constants. Nothing here repeats: each is a one-shot deadline (§8.1 rule 5).
public nonisolated enum FillLightTiming {
    /// The camera rule turns the light on this long after a matching camera starts (DESIGN.md §11).
    public static let cameraOnDelay: Duration = .seconds(1)
    /// … and off this long after the last one stops ("Turns off a few seconds after the camera stops").
    public static let cameraOffDelay: Duration = .seconds(3)
    /// After the frame starts asking for EDR headroom (shown, or a new request), headroom is re-read at these offsets
    /// from that moment, so the value follows macOS's up-ramp (median 1.14 s, at most 4.75 s on the owner's Mac, D6)
    /// even where no screen-parameters notification arrives. Four reads, then nothing until the next event.
    public static let headroomSettleReads: [Duration] = [.milliseconds(500), .milliseconds(1_500), .seconds(3),
                                                         .seconds(5)]
}
