// OverbrightDesign/Theme/HapticFeedback.swift — how components reach the trackpad. DESIGN.md §13.2, §5.5 ("Snapping").
// A component never plays a haptic itself: it asks the environment's performer, which the surface root sets from
// `Haptics` (General ▸ Haptic feedback). Without one (previews, tests, Welcome) nothing is played.
import OverbrightCore
import SwiftUI

/// Plays a haptic pattern (felt only while a finger is on a Force Touch trackpad; every haptic has a visual
/// counterpart).
public nonisolated struct HapticFeedback: Sendable {
    private let perform: @MainActor @Sendable (HapticPattern) -> Void

    /// A performer that calls `perform` (tests record the patterns).
    public init(_ perform: @escaping @MainActor @Sendable (HapticPattern) -> Void) { self.perform = perform }

    /// Plays nothing.
    public static let none = HapticFeedback { _ in }

    /// Plays through `haptics`, which honours General ▸ Haptic feedback.
    @MainActor public static func playing(_ haptics: Haptics) -> HapticFeedback {
        HapticFeedback { pattern in haptics.play(pattern) }
    }

    /// Plays `pattern` now.
    @MainActor public func play(_ pattern: HapticPattern) { perform(pattern) }
}

public extension EnvironmentValues {
    /// The haptic performer of the surface (`.none` unless the root sets one).
    @Entry var overbrightHaptics: HapticFeedback = .none
}
