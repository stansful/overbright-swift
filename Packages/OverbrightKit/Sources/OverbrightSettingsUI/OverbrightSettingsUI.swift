// OverbrightSettingsUI — module overview. ARCHITECTURE.md §2.1 (L2: Core, Policy and Design), §7.6, §10.2, §10.13, D15;
// DESIGN.md §7. Ported from Cranny's CrannySettingsUI (the owner's MIT code); the plug-in pane registry became a fixed
// list of seven panes.
//
//   Root/        WP0b: the window content (`SettingsRootView`, a `NavigationSplitView` with a searchable sidebar), the
//                state the window controller keeps (`SettingsSession`), the pane list and the seam every pane
//                implements (`SettingsPaneView`).
//   Search/      WP0b: the search index (pane names, row labels, keywords; case-, diacritic- and width-insensitive word
//                prefixes), deep links "pane#row" with the 1-s accent wash, the known pane keywords.
//   Components/  WP0b: the row kinds and conventions (changed dot and Reset to Default from Design), the pane footer
//                (Reset ‹Pane›…), Reset All with Undo, the shortcut recorder, the Updates section and the About content.
//   Panes/       WP11: every pane of DESIGN.md §7 (seeded empty by WP0b; About is composed of WP0b's About content).
//   Calibration/, SelfTest/  WP11.
