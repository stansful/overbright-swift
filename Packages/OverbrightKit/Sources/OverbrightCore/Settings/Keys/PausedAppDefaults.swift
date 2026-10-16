// OverbrightCore/Settings/Keys/PausedAppDefaults.swift — the suggested per-app pause list. ARCHITECTURE.md §3.8, §6.5, D10.

/// Default per-app pause list (ARCHITECTURE.md §6.5). Bundle IDs only; the UI shows Finder's names.
public nonisolated enum PausedAppDefaults {
    /// QuickTime Player, TV, Photos, IINA, Infuse, VLC, Final Cut Pro, DaVinci Resolve ×3, Plex ×2.
    public static let rules: [PausedAppRule] = [
        PausedAppRule(bundleID: "com.apple.QuickTimePlayerX", mode: .whilePlaying),
        PausedAppRule(bundleID: "com.apple.TV", mode: .whilePlaying),
        PausedAppRule(bundleID: "com.apple.Photos", mode: .whileFrontmost),
        PausedAppRule(bundleID: "com.colliderli.iina", mode: .whilePlaying),
        PausedAppRule(bundleID: "com.firecore.infuse", mode: .whilePlaying),
        PausedAppRule(bundleID: "org.videolan.vlc", mode: .whilePlaying),
        PausedAppRule(bundleID: "com.apple.FinalCut", mode: .whileFrontmost),
        PausedAppRule(bundleID: "com.blackmagic-design.DaVinciResolve", mode: .whileFrontmost),
        PausedAppRule(bundleID: "com.blackmagic-design.DaVinciResolveLite", mode: .whileFrontmost),
        PausedAppRule(bundleID: "com.blackmagic-design.DaVinciResolveAppStore", mode: .whileFrontmost),
        PausedAppRule(bundleID: "tv.plex.desktop", mode: .whilePlaying),
        PausedAppRule(bundleID: "tv.plex.htpc", mode: .whilePlaying),
    ]
}
