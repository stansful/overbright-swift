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
                capMode: CapMode = .safe, triggerOverride: TriggerStrategy? = nil,
                calibration: CalibrationRecord? = nil, oled: OLEDOverride = .automatic,
                oledNoticeAcknowledged: Bool = false, lastKnownName: String? = nil) {
        self.boostEnabled = boostEnabled; self.level = level; self.capMode = capMode
        self.triggerOverride = triggerOverride; self.calibration = calibration
        self.oled = oled; self.oledNoticeAcknowledged = oledNoticeAcknowledged; self.lastKnownName = lastKnownName
    }

    /// Decodes what the synthesized decoder would, and drops a calibration record that measured Compatibility mode's
    /// overlay (removed 2026-10-21, ARCHITECTURE.md §7.5): its `mechanism` was `"overlay"`, and read as a table record
    /// it would confirm a domain the table never showed. The legacy `mechanism` keys (the preference here, the
    /// record's) are otherwise ignored: every display uses the color table. Reading them never throws, because
    /// `SettingsStore` falls back to no preferences at all on a decode error, and one display's old record must not
    /// reset every display.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        boostEnabled = try container.decodeIfPresent(Bool.self, forKey: .boostEnabled)
        level = try container.decode(LevelPosition.self, forKey: .level)
        capMode = try container.decode(CapMode.self, forKey: .capMode)
        triggerOverride = try container.decodeIfPresent(TriggerStrategy.self, forKey: .triggerOverride)
        calibration = try container.decodeIfPresent(CalibrationRecord.self, forKey: .calibration)
        oled = try container.decode(OLEDOverride.self, forKey: .oled)
        oledNoticeAcknowledged = try container.decode(Bool.self, forKey: .oledNoticeAcknowledged)
        lastKnownName = try container.decodeIfPresent(String.self, forKey: .lastKnownName)
        let record = try? container.nestedContainer(keyedBy: LegacyCalibrationKeys.self, forKey: .calibration)
        if (try? record?.decodeIfPresent(String.self, forKey: .mechanism)) == "overlay" { calibration = nil }
    }

    /// The key a calibration record stored before 2026-10-21.
    private enum LegacyCalibrationKeys: String, CodingKey {
        case mechanism
    }
}
