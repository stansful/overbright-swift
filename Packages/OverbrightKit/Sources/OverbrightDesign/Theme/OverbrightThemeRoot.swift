// OverbrightDesign/Theme/OverbrightThemeRoot.swift — `@Environment(\.overbright)` and the root modifier every surface
// applies exactly once. DESIGN.md §2.0 rule 3, §2.5; ARCHITECTURE.md §10.0 (Design seam).
import SwiftUI

public extension EnvironmentValues {
    /// The surface's theme, set by `.overbrightThemeRoot(_:)`.
    @Entry var overbright: OverbrightTheme = OverbrightTheme()
}

/// Merges the live appearance and accessibility state into a base theme and publishes it as `\.overbright`. Apply
/// once at the root of every surface: panel, HUD, Keep-this-level prompt, Help, Settings, Welcome, calibration chrome,
/// self-test sheet.
public struct OverbrightThemeRoot: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.layoutDirection) private var layoutDirection

    /// Values a preview or a QA hook forces on top of the system state.
    public var base: OverbrightTheme

    /// A root over `base`.
    public init(_ base: OverbrightTheme) { self.base = base }

    /// Publishes the merged theme.
    public func body(content: Content) -> some View {
        var theme = base
        theme.reduceMotion = base.reduceMotion || reduceMotion
        theme.reduceTransparency = base.reduceTransparency || reduceTransparency
        theme.increaseContrast = base.increaseContrast || contrast == .increased
        theme.differentiateWithoutColor = base.differentiateWithoutColor || differentiateWithoutColor
        theme.voiceOverRunning = base.voiceOverRunning || voiceOver
        theme.colorScheme = colorScheme
        theme.layoutDirection = layoutDirection
        return content.environment(\.overbright, theme)
    }
}

public extension View {
    /// Applies the Overbright theme at the root of a surface (exactly once per surface).
    func overbrightThemeRoot(_ theme: OverbrightTheme = OverbrightTheme()) -> some View {
        modifier(OverbrightThemeRoot(theme))
    }
}
