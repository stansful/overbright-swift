// OverbrightDesign — the design system: tokens, theme, components and the copy of Core and Policy enums.
// ARCHITECTURE.md §2.1 rule 5, §8.8, §10.11; DESIGN.md §2, §3, §5, §12, §13, App. A.
//
//   Tokens/      colours (`OverbrightColor`, `BoostColor`, `SemanticColor`, `SRGBA` for the contrast audit),
//                `OverbrightFont`, `Space`, `Radius`, `StrokeWidth`, `HitTarget`, `OverbrightMotion`, `OverbrightSymbol`,
//                `SurfaceMaterial` (glass with the 14/15 fallback and Reduce Transparency)
//   Theme/       `OverbrightTheme` and `.overbrightThemeRoot(_:)`, the right-to-left rules, `HapticFeedback`
//   Components/  `BoostSlider` (+ `BoostSliderModel`, its rules), `StatusChip`, `GuardChip`, `PausedBanner`,
//                `ReadoutText`, `EDRPreviewSurface`, `StepWedgeView`, `KeyCap`
//   Styles/      `ChipButtonStyle`, `IconButtonStyle`, `OverbrightLinkButtonStyle`, `.overbrightFocusRing`
//   Settings/    `SettingRowConventions`, `SettingsStore.binding(_:)`
//   Copy/        the only producers of engine-state copy: `ChipModel`, `VerdictText`, `BannerModel`, `ValueText`,
//                `HUDText`, `SafeLimitText`, the names of Core enums, `FixAction`, announcements and confirmations,
//                all in `CopyLanguage` (the app's language, or one localization for tests and fit checks)
//
// Rules (DESIGN.md §2.0): no module outside Design writes a literal colour, font size, spacing, radius or animation;
// views read `@Environment(\.overbright)`; every surface applies `.overbrightThemeRoot(_:)` once; components take
// already-localized strings and names inside sentences are bidi-isolated (`String.overbrightIsolated`).

/// Names the module (diagnostics, tests).
public enum OverbrightDesignModule {
    /// The target name.
    public static let name = "OverbrightDesign"
}
