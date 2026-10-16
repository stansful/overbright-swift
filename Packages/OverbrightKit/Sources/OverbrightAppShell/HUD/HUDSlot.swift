// OverbrightAppShell/HUD/HUDSlot.swift — the one place at the bottom of a display that the HUD and the Keep-this-level
// prompt share: never two at once (DESIGN.md §6, D19). The prompt takes the HUD's place and wins over it; the HUD
// does not show while the prompt does.
import Foundation

/// The occupant of the HUD's place.
final class HUDSlot {
    /// Who may hold the place.
    enum Occupant: Equatable { case hud, prompt }

    /// The app's one slot.
    static let shared = HUDSlot()

    /// Who holds the place now.
    private(set) var occupant: Occupant?
    private var release: [Occupant: () -> Void] = [:]

    /// A slot (tests make their own).
    init() {}

    /// Takes the place for `occupant`; `onEvicted` closes it when the prompt takes the place from the HUD. Returns false
    /// when the HUD asks while the prompt holds it.
    @discardableResult
    func claim(_ occupant: Occupant, onEvicted: @escaping () -> Void) -> Bool {
        if occupant == .hud, self.occupant == .prompt { return false }
        if let current = self.occupant, current != occupant {
            release.removeValue(forKey: current)?()
        }
        self.occupant = occupant
        release[occupant] = onEvicted
        return true
    }

    /// Gives the place up.
    func leave(_ occupant: Occupant) {
        guard self.occupant == occupant else { return }
        self.occupant = nil
        release[occupant] = nil
    }
}
