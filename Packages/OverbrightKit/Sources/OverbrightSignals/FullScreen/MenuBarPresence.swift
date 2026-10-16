// OverbrightSignals/FullScreen/MenuBarPresence.swift — the menu bar's "absent" state, sticky for 3 s. ARCHITECTURE.md
// §7.3. In a full-screen Space the menu bar reappears while the pointer hovers at the top edge; without hysteresis the
// below-band and Split View rules would flip off for every hover. Once a display's menu bar is seen absent, a present
// reading within 3 s of the last absent one still counts as absent; `resolvesAt` says when a masked reading may count,
// so the tracker can re-check then instead of waiting for the next event.
// Thread: any (a value type, owned by the main-actor tracker).
import OverbrightCore

/// Sticky menu-bar absence per display.
nonisolated struct MenuBarPresence: Sendable {
    /// How long an absent menu bar stays absent after it was last seen absent.
    static let stickyAbsence: Duration = .seconds(3)

    /// The effective presence of one update.
    struct Effective: Hashable, Sendable {
        /// Per display: the menu bar counts as present.
        var present: [DisplayKey: Bool]
        /// The earliest instant at which a masked (present but sticky-absent) reading would count; nil when none is.
        var resolvesAt: MonotonicInstant?
    }

    private var lastSeenAbsent: [DisplayKey: MonotonicInstant] = [:]

    /// An empty history.
    init() {}

    /// Applies one observation (`observed`: the menu bar is on that display now) taken at `now`. Displays that are no
    /// longer observed are forgotten.
    mutating func update(observed: [DisplayKey: Bool], at now: MonotonicInstant) -> Effective {
        var present: [DisplayKey: Bool] = [:]
        var resolvesAt: MonotonicInstant?
        for (key, isPresent) in observed {
            if !isPresent {
                lastSeenAbsent[key] = now
                present[key] = false
            } else if let absent = lastSeenAbsent[key], now - absent < Self.stickyAbsence {
                present[key] = false
                let resolution = absent + Self.stickyAbsence
                resolvesAt = min(resolvesAt ?? resolution, resolution)
            } else {
                lastSeenAbsent[key] = nil
                present[key] = true
            }
        }
        lastSeenAbsent = lastSeenAbsent.filter { observed[$0.key] != nil }
        return Effective(present: present, resolvesAt: resolvesAt)
    }
}
