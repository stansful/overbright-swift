// OverbrightPanelUI/Card/DisplayCardModel+Services.swift — a card model read from the services hub: the facts from the
// display directory, the preferences and the level from the settings store, the pause and banner from the engine.
// The card view, the panel's keyboard order and the status menu all build their models here.
import OverbrightCore

extension DisplayCardModel {
    /// The card model of `status` with everything else read from `services` (observed when read inside a view or an
    /// `observe` closure).
    public init(status: DisplayStatus, isMasterOn: Bool, services: OverbrightServices) {
        let settings = services.settings
        let boost = services.boost.status
        self.init(status: status, isMasterOn: isMasterOn, isPaused: boost.pausedUntil != nil, banner: boost.banner,
                  facts: services.displays.facts(for: status.key),
                  preferences: settings[DisplaySettings.perDisplay][status.key] ?? DisplayPreferences(),
                  linkLevels: settings[DisplaySettings.linkLevels], linkedLevel: settings[DisplaySettings.linkedLevel],
                  taper: settings[DisplaySettings.boostOnlyNearFullBrightness])
    }
}
