// OverbrightDisplays/Directory/OnlineScreens.swift — what a screen-parameters pass reads first: the online display IDs
// and each one's own NSScreen facts. ARCHITECTURE.md §7.1, §10.4 (as built: energy D1). `CoreGraphicsDisplayReader`
// fills it on the main actor without any per-display CoreGraphics query; `DisplayDirectoryModel` compares its IDs with
// the last full pass to decide whether that pass's CoreGraphics facts still hold. Tests build it directly.
import CoreGraphics

/// The online displays' IDs and NSScreen facts.
nonisolated struct OnlineScreens: Hashable, Sendable {
    /// `CGGetOnlineDisplayList`, in CoreGraphics order.
    var ids: [CGDirectDisplayID]
    /// The NSScreen facts by display ID (a hardware-mirror member and a display in transition have none).
    var screens: [CGDirectDisplayID: RawDisplay.Screen]
}
