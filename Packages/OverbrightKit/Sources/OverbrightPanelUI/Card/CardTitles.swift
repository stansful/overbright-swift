// OverbrightPanelUI/Card/CardTitles.swift — the titles of the display cards and menu rows. DESIGN.md §5.4: two
// displays with the same name get " (1)", " (2)" in UUID order, as macOS does. Presentation only: no logic decides
// anything by a name (D8, ARCHITECTURE.md §4.5 invariant 10); names are only grouped to number the duplicates.
import Foundation
import OverbrightCore

/// Display titles for the panel and the menus.
public enum CardTitles {
    /// The title of every display in `displays`: its name, or its name with " (n)" when another display has the same
    /// name (numbered in display-key order).
    public static func titles(for displays: [(key: DisplayKey, name: String)]) -> [DisplayKey: String] {
        var titles: [DisplayKey: String] = [:]
        let groups = Dictionary(grouping: displays, by: \.name)
        for (_, group) in groups {
            guard group.count > 1 else {
                if let only = group.first { titles[only.key] = only.name }
                continue
            }
            for (index, display) in group.sorted(by: { $0.key < $1.key }).enumerated() {
                titles[display.key] = numbered(display.name, index + 1)
            }
        }
        return titles
    }

    /// The titles of the statuses' displays.
    public static func titles(for statuses: [DisplayStatus]) -> [DisplayKey: String] {
        titles(for: statuses.map { (key: $0.key, name: $0.name) })
    }

    /// "MPG322UX (2)".
    static func numbered(_ name: String, _ number: Int) -> String {
        String(localized: "\(Bidi.isolated(name)) (\(number))", bundle: .module,
               comment: "Panel: the name of one of several displays with the same name; the number tells them apart")
    }
}
