// OverbrightBoost/Engine/FlickerGuard.swift — the rate limiter and the oscillation detector of WCAG 2.3.1 safety.
// ARCHITECTURE.md §4.5 invariant 8, §5.8; DESIGN.md §3.4. Pure (a value type; the controller passes instants and
// headroom readings in) and nonisolated.
import OverbrightCore

/// Per display: at least `minimumOpposingInterval` between opposing transitions (the rate limiter), and a trip after
/// `oscillationTripReversals` non-user direction reversals within `oscillationWindow` (the detector). User changes
/// never count; headroom-tracking clamps and raises do not count while the headroom readings since the last reversal
/// moved monotonically (following the brightness keys or ambient light is not flicker).
nonisolated struct FlickerGuard: Hashable, Sendable {
    /// The direction of a brightness transition.
    enum Direction: Hashable, Sendable { case up, down }

    /// Who caused a transition.
    enum Origin: Hashable, Sendable {
        /// A user's own change (slider, preset, step, intent, Focus): never counted.
        case user
        /// Policy, guards, repairs, base adoptions: counted.
        case automatic
        /// A safety drop or a recovery raise that follows headroom: counted unless the headroom moved monotonically.
        case headroomTracking
    }

    /// The last transition's direction.
    private(set) var lastDirection: Direction?
    /// When the last transition started.
    private(set) var lastTransition: MonotonicInstant?
    /// Counted reversals within the window.
    private(set) var reversals: [MonotonicInstant] = []
    /// Headroom readings since the last reversal (the monotonicity test).
    private var headroomSinceReversal: [Double] = []

    /// A guard with no history.
    init() {}

    /// How long a transition in `direction` must wait at `now` (zero when it may start; safety drops never ask).
    func delay(before direction: Direction, at now: MonotonicInstant) -> Duration {
        guard let lastDirection, let lastTransition, lastDirection != direction else { return .zero }
        let allowed = lastTransition + EngineTiming.minimumOpposingInterval
        return allowed > now ? allowed - now : .zero
    }

    /// Notes a headroom reading (for the monotonicity exemption).
    mutating func noteHeadroom(_ headroom: Double) {
        headroomSinceReversal.append(headroom)
        if headroomSinceReversal.count > 64 { headroomSinceReversal.removeFirst(headroomSinceReversal.count - 64) }
    }

    /// Whether the headroom readings since the last reversal moved in one direction only.
    var headroomMovedMonotonically: Bool {
        let h = headroomSinceReversal
        guard h.count > 1 else { return true }
        let pairs = zip(h, h.dropFirst())
        return pairs.allSatisfy { $1 >= $0 - 1e-6 } || pairs.allSatisfy { $1 <= $0 + 1e-6 }
    }

    /// Records a transition in `direction` at `now`. Returns true when the oscillation detector trips.
    mutating func record(_ direction: Direction, at now: MonotonicInstant, origin: Origin) -> Bool {
        if let lastDirection, lastDirection != direction {
            let counts: Bool = switch origin {
            case .user: false
            case .automatic: true
            case .headroomTracking: !headroomMovedMonotonically
            }
            if counts { reversals.append(now) }
            headroomSinceReversal = headroomSinceReversal.last.map { [$0] } ?? []
        }
        lastDirection = direction
        lastTransition = now
        return prune(now)
    }

    /// Counts one non-user reversal that is not a transition of ours (an unexplained base adoption, §4.8). Returns true
    /// when the detector trips.
    mutating func recordReversal(at now: MonotonicInstant) -> Bool {
        reversals.append(now)
        return prune(now)
    }

    /// Forgets everything (Try Again, a new arm after a trip).
    mutating func reset() { self = FlickerGuard() }

    private mutating func prune(_ now: MonotonicInstant) -> Bool {
        reversals.removeAll { now - $0 > EngineTiming.oscillationWindow }
        return reversals.count >= EngineTiming.oscillationTripReversals
    }
}
