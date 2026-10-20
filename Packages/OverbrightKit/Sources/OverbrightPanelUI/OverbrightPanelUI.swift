// OverbrightPanelUI — the panel's content, its display cards, the Fill Light card and the local Help.
// ARCHITECTURE.md §2.1 (L2), §10.12; DESIGN.md §5, §12.6.
//
//   Panel/       `PanelView` (header, Fill Light card, banner, calibration tip, the cards, the footer's guard chips),
//                what it lists (`PanelContent`), its keyboard map and focus, its commands, its fixed sizes and its words
//   Card/        one display's card: `DisplayCardModel` (derived without a view from the services hub), its chip and
//                actions, its quick-level menu (SwiftUI and AppKit, shared with the status menu), the value text
//   FillLight/   the compact Fill Light card and its sliders
//   Help/        the answers of the Help window and its view
//   QA/          named engine statuses and gallery states for snapshots and `--qa-state`
//
// Layer 2: imports OverbrightCore, OverbrightPolicy, OverbrightDesign and Apple frameworks only (§2.1). The window that
// hosts the panel is AppShell's; Onboarding reuses the display card.
