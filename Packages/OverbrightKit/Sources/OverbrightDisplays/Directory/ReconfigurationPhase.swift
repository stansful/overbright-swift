// OverbrightDisplays/Directory/ReconfigurationPhase.swift — what one display-reconfiguration callback means.
// ARCHITECTURE.md §4.3 (display removed; configuration began), §7.1, §10.4, D9. Pure.
import CoreGraphics

/// The meaning of one `CGDisplayReconfigurationCallBack` invocation.
nonisolated enum ReconfigurationPhase: Hashable, Sendable {
    /// `kCGDisplayBeginConfigurationFlag`: called once per online display before a change. No display queries here;
    /// overlays go to factor 1, nothing else.
    case began
    /// `kCGDisplayRemoveFlag` (or `kCGDisplayDisabledFlag`, the lid closing with an external display attached): the
    /// display is gone; handled at once, not debounced.
    case removed
    /// Any other after-phase flag (added, moved, mode, main, mirror, desktop shape): debounced.
    case changed

    /// The phase of `flags`.
    init(flags: CGDisplayChangeSummaryFlags) {
        if flags.contains(.beginConfigurationFlag) {
            self = .began
        } else if flags.contains(.removeFlag) || flags.contains(.disabledFlag) {
            self = .removed
        } else {
            self = .changed
        }
    }
}
