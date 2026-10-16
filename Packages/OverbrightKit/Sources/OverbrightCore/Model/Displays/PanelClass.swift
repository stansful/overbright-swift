// OverbrightCore/Model/Displays/PanelClass.swift — coarse hardware class of a display. ARCHITECTURE.md §3.2, D8.

/// Coarse hardware class, derived from public facts only (built-in flag, vendor, IORegistry), never from names.
public nonisolated enum PanelClass: String, Codable, Sendable, CaseIterable {
    /// Built-in, potential > 2.
    case builtInXDR
    /// Built-in, potential ≤ 2.
    case builtInLCD
    /// Apple vendor ID, external, panel peak ≥ 1000 nits.
    case appleXDRExternal
    /// Other external with PQ support.
    case hdrExternal
    /// External whose minimum luminance is ≤ 0.005 nits (self-emissive), or user override.
    case oledExternal
    /// External without PQ support.
    case sdrExternal
    /// Sidecar, AirPlay, placeholder vendor, no gamma table.
    case virtualDisplay
}
