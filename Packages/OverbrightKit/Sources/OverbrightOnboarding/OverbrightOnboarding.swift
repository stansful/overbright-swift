// OverbrightOnboarding — module overview. ARCHITECTURE.md §2.1 (L2: Core, Policy, Design and PanelUI), §7.6, §10.2,
// §10.14, D16; DESIGN.md §8. Ported from Cranny's CrannyOnboarding (the owner's MIT code) without the notch stage and
// the tutorial.
//
//   Chrome/   WP0b: the window content (`WelcomeView`: the step above, the footer below), its state (`WelcomeSession`:
//             the step, ↩ / ⌘[ / Esc, Skip, Done, Quit Overbright, the close button counting as Skip), the step and
//             outcome vocabulary, and the shared pieces (progress dots, step header, layout, check badge, selectable
//             cards, window visibility).
//   Model/    WP12: the plan (`WelcomePlan`) and the choices Done and Skip apply (`WelcomeChoices`), seeded by WP0b.
//   Steps/    WP12: the five steps of DESIGN.md §8, seeded by WP0b with their headlines only.
