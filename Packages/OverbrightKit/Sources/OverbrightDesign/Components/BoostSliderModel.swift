// OverbrightDesign/Components/BoostSliderModel.swift — the rules of the level slider, apart from drawing.
// DESIGN.md §5.5, §13.2; ARCHITECTURE.md §5.3. Geometry (fractions of the track from its leading edge), the shown
// ticks, the allowed-now marker, snapping with its haptics, keyboard and scroll steps in stops, named stops for ⌥-arrows
// and VoiceOver, and the halves that are disabled. Pure, so every rule is tested without a window.
import OverbrightCore
import OverbrightPolicy

/// The level slider's behaviour for one display.
public nonisolated struct BoostSliderModel: Hashable, Sendable {
    /// A key that moves the thumb.
    public enum Key: Hashable, Sendable {
        /// ← (→ right to left): 1/12 stop toward the dim end.
        case stepTowardDim
        /// → (← right to left): 1/12 stop toward the boost end.
        case stepTowardBoost
        /// ⌥← (⌥→ right to left): the previous named stop.
        case previousStop
        /// ⌥→: the next named stop.
        case nextStop
        /// Home: Standard.
        case home
        /// End: Max.
        case end
    }

    /// The gain at the top of the boost half (`GainCeiling.sliderTop`).
    public var top: Double
    /// The gain macOS allows now (the marker), nil without a reading.
    public var allowedNow: Double?
    /// The presets shown on this display.
    public var presets: [LevelPreset]
    /// The dim half works.
    public var dimEnabled: Bool
    /// How the boost half draws and behaves.
    public var boostHalf: BoostHalfState

    /// Snapping reaches this far from the detent or a shown tick (in level units; ±3 %).
    public static let snapDistance = 0.03
    /// A drag slower than this (level units per second, ≈ 150 pt/s on the 240-pt track) settles into a tick.
    public static let slowDragSpeed = 1.25
    /// Named stops on the dim half, as light relative to Standard (50 %, 25 %, 10 %, 5 %, 2 %).
    public static let dimStopLights = [0.5, 0.25, 0.10, 0.05, 0.02]
    /// The boost half needs a top of at least ×1.05 (DESIGN.md §5.5 "Disabled boost half").
    public static let minimumTop = 1.05
    /// Max below this adds "small gain on this display" to the value tag.
    public static let smallGainTop = 1.3

    /// The model of one slider.
    public init(top: Double, allowedNow: Double?, presets: [LevelPreset], dimEnabled: Bool, boostHalf: BoostHalfState) {
        self.top = top; self.allowedNow = allowedNow; self.presets = presets; self.dimEnabled = dimEnabled
        self.boostHalf = boostHalf
    }

    // MARK: Halves

    /// The thumb may move into the boost half (it may also when the half is off for the display: that turns it on).
    public var boostEnabled: Bool {
        if case .unavailable = boostHalf { return false }
        return top >= Self.minimumTop
    }

    /// The boost half draws hatched as a whole (turned off for the display, or unavailable).
    public var boostHalfHatched: Bool {
        switch boostHalf {
        case .switchedOff, .unavailable: true
        case .active, .inactive: !boostEnabled
        }
    }

    /// The span the thumb may take.
    public var range: ClosedRange<Double> { (dimEnabled ? -1 : 0)...(boostEnabled ? 1 : 0) }

    /// `level` kept inside `range`.
    public func clamped(_ level: LevelPosition) -> LevelPosition {
        LevelPosition(min(max(level.value, range.lowerBound), range.upperBound))
    }

    /// The fill right of the detent is the warm colour (extra light is on screen); otherwise it is hatched.
    public var boostFillIsWarm: Bool { boostHalf == .active && boostEnabled }

    /// Max is below ×1.3: the value tag adds "small gain on this display".
    public var isSmallGain: Bool { boostEnabled && top < Self.smallGainTop }

    // MARK: Geometry

    /// The fraction of the track (0 at the leading, dim end; 1 at the boost end) of `level`.
    public static func fraction(of level: LevelPosition) -> Double { (level.value + 1) / 2 }

    /// The level at `fraction` of the track.
    public static func level(atFraction fraction: Double) -> LevelPosition { LevelPosition(fraction * 2 - 1) }

    /// The levels of the preset ticks (the shown presets on the boost half; none on the dim half).
    public var tickLevels: [LevelPosition] {
        guard boostEnabled else { return [] }
        return presets.filter { $0 != .standard }.map(\.position).sorted()
    }

    /// Where the allowed-now marker sits: while extra light is on screen with a reading that stops the thumb short of
    /// the top; nil otherwise (off, paused, no reading, nothing limited).
    public var markerLevel: LevelPosition? {
        guard boostFillIsWarm, let allowed = allowedNow, allowed < top - 0.005 else { return nil }
        return LevelMapping.position(forGain: allowed, top: top)
    }

    // MARK: Named stops

    /// Standard, the shown presets and the dim stops, in order from the dim end.
    public var namedStops: [LevelPosition] {
        var stops: [LevelPosition] = [.standard]
        if dimEnabled { stops += Self.dimStopLights.map { LevelMapping.position(forDimLight: $0) } }
        stops += tickLevels
        return stops.sorted()
    }

    /// The next named stop above `level` (nil at the last one).
    public func nextStop(after level: LevelPosition) -> LevelPosition? {
        namedStops.first { $0.value > level.value + 0.001 }
    }

    /// The named stop below `level` (nil at the first one).
    public func previousStop(before level: LevelPosition) -> LevelPosition? {
        namedStops.last { $0.value < level.value - 0.001 }
    }

    // MARK: Keys, scroll, VoiceOver

    /// The level after `key` from `level`. Arrow steps are 1/12 stop of light and never cross Standard in one press.
    public func level(after key: Key, from level: LevelPosition) -> LevelPosition {
        switch key {
        case .stepTowardDim: step(from: level, by: -1)
        case .stepTowardBoost: step(from: level, by: 1)
        case .previousStop: previousStop(before: level) ?? level
        case .nextStop: nextStop(after: level) ?? level
        case .home: .standard
        case .end: clamped(LevelPreset.max.position)
        }
    }

    /// `notches` arrow steps (scroll wheel notches; negative toward the dim end).
    public func step(from level: LevelPosition, by notches: Int) -> LevelPosition {
        guard notches != 0 else { return level }
        let next = StepMath.step(from: level, by: Double(notches) * StepMath.arrowKeyStops, top: top)
        return clamped(next)
    }

    /// VoiceOver's increment and decrement: the next or previous named stop.
    public func adjusted(_ level: LevelPosition, increment: Bool) -> LevelPosition {
        clamped((increment ? nextStop(after: level) : previousStop(before: level)) ?? level)
    }

    // MARK: Dragging

    /// The level for a drag at `fraction` of the track moving at `speed` (level units per second): a slow drag within
    /// ±3 % of the detent or a shown tick settles there; a fast one passes through.
    public func dragged(toFraction fraction: Double, speed: Double) -> LevelPosition {
        let raw = clamped(Self.level(atFraction: min(max(fraction, 0), 1)))
        guard speed < Self.slowDragSpeed else { return raw }
        let targets = [LevelPosition.standard] + tickLevels
        if let target = targets.min(by: { abs($0.value - raw.value) < abs($1.value - raw.value) }),
           abs(target.value - raw.value) <= Self.snapDistance {
            return clamped(target)
        }
        return raw
    }

    /// The haptic of a move from `old` to `new`: `.alignment` when the thumb settles into Standard, `.levelChange` when
    /// it crosses or settles on a shown preset; nil otherwise (DESIGN.md §13.2).
    public func haptic(from old: LevelPosition, to new: LevelPosition) -> HapticPattern? {
        guard old != new else { return nil }
        if new == .standard { return .alignment }
        let low = min(old.value, new.value), high = max(old.value, new.value)
        let touched = tickLevels.contains { tick in
            tick.value == new.value || (tick.value > low && tick.value < high) || (tick.value == high && high == new.value)
        }
        return touched ? .levelChange : nil
    }
}
