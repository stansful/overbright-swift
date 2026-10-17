// OverbrightPanelUI/Card/DisplayCardModel+Services.swift — a card model read from the services hub: the facts from the
// display directory, the preferences and the level from the settings store, the pause and banner from the engine.
// The card view, the panel's keyboard order and the status menu all build their models here. A panel pass reads the
// settings and the engine's pause and banner once for all its cards (`Inputs`), not once per card and per read.
import OverbrightCore

extension DisplayCardModel {
    /// What every card of one pass reads besides its own status: the settings and the engine's pause and banner, read
    /// once (observed when read inside a view or an `observe` closure).
    public struct Inputs {
        /// Every display's stored preferences.
        var perDisplay: [DisplayKey: DisplayPreferences]
        /// "Same level on all displays".
        var linkLevels: Bool
        /// The level of every display while levels are linked.
        var linkedLevel: LevelPosition
        /// "Add extra brightness only near full brightness".
        var taper: Bool
        /// The light of "Dimmed".
        var lastDimLight: Double
        /// A pause the user set is active.
        var isPaused: Bool
        /// The banner the panel shows.
        var banner: Banner?

        /// The inputs now, read from `services` with the engine's `status`.
        public init(services: OverbrightServices, status: BoostStatus) {
            let settings = services.settings
            perDisplay = settings[DisplaySettings.perDisplay]
            linkLevels = settings[DisplaySettings.linkLevels]
            linkedLevel = settings[DisplaySettings.linkedLevel]
            taper = settings[DisplaySettings.boostOnlyNearFullBrightness]
            lastDimLight = settings[DisplaySettings.lastDimLight]
            isPaused = status.pausedUntil != nil
            banner = status.banner
        }
    }

    /// The card model of `status` with everything else read from `services` (observed when read inside a view or an
    /// `observe` closure).
    public init(status: DisplayStatus, isMasterOn: Bool, services: OverbrightServices) {
        self.init(status: status, isMasterOn: isMasterOn, services: services,
                  inputs: Inputs(services: services, status: services.boost.status))
    }

    /// The card model of `status` over `inputs` read once for the pass; the facts come from `services`' directory.
    public init(status: DisplayStatus, isMasterOn: Bool, services: OverbrightServices, inputs: Inputs) {
        self.init(status: status, isMasterOn: isMasterOn, isPaused: inputs.isPaused, banner: inputs.banner,
                  facts: services.displays.facts(for: status.key),
                  preferences: inputs.perDisplay[status.key] ?? DisplayPreferences(), linkLevels: inputs.linkLevels,
                  linkedLevel: inputs.linkedLevel, taper: inputs.taper, lastDimLight: inputs.lastDimLight)
    }
}
