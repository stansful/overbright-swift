// OverbrightDesign/Copy/GuardChipMenuItem.swift — the rows of a footer chip's menu. DESIGN.md §5.9.
// Seam written by WP0a (ARCHITECTURE.md §10.0); WP9 owns it.

/// One row of a footer chip's menu (title case, AppKit chrome).
public indirect enum GuardChipMenuItem {
    /// A choice; `isChecked` draws the checkmark.
    case item(title: String, isChecked: Bool, perform: @MainActor () -> Void)
    /// A submenu ("Battery Level ▸").
    case submenu(title: String, items: [GuardChipMenuItem])
    /// A separator.
    case separator
}
