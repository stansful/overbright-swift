// OverbrightCore/Model/Displays/DisplayPreferences.swift — per-display preferences, keyed by DisplayKey.
// ARCHITECTURE.md §3.2, §3.8.

/// Per-display preferences, stored in `DisplaySettings.perDisplay` by `DisplayKey`.
public nonisolated struct DisplayPreferences: Hashable, Codable, Sendable {
    /// Gates the BOOST half only (D11, DESIGN.md §5.4); dimming never needs it. nil = the class default
    /// (D8: built-in XDR and Apple XDR on; other HDR and OLED externals off until the user moves into the boost half).
    public var boostEnabled: Bool?
    /// The slider position (default Bright room).
    public var level: LevelPosition
    /// Safe or Peak.
    public var capMode: CapMode
    /// Table, overlay or automatic.
    public var mechanism: MechanismPreference
    /// Advanced override of the trigger ladder; nil = automatic.
    public var triggerOverride: TriggerStrategy?
    /// The transfer domain is derived from this record (§5.2); there is no separate domain setting.
    public var calibration: CalibrationRecord?
    /// The OLED override.
    public var oled: OLEDOverride
    /// The OLED burn-in notice was acknowledged.
    public var oledNoticeAcknowledged: Bool
    /// Last name seen, so a disconnected display can be listed and forgotten.
    public var lastKnownName: String?
    /// Preferences with every default of §3.8.
    public init(boostEnabled: Bool? = nil, level: LevelPosition = LevelPreset.brightRoom.position,
                capMode: CapMode = .safe, mechanism: MechanismPreference = .automatic,
                triggerOverride: TriggerStrategy? = nil, calibration: CalibrationRecord? = nil,
                oled: OLEDOverride = .automatic, oledNoticeAcknowledged: Bool = false, lastKnownName: String? = nil) {
        self.boostEnabled = boostEnabled; self.level = level; self.capMode = capMode; self.mechanism = mechanism
        self.triggerOverride = triggerOverride; self.calibration = calibration
        self.oled = oled; self.oledNoticeAcknowledged = oledNoticeAcknowledged; self.lastKnownName = lastKnownName
    }
}
