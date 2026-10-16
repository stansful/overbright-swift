// OverbrightAppShell/Services/QuietControlOutlet.swift — the control outlet of a launch that must not publish.
// ARCHITECTURE.md §7.7, §8.5 (`--qa-simulate` never writes the real channel), D25.
import OverbrightChannel
import OverbrightIntents

/// An outlet that has no control: `ControlStatePublisher` then publishes nothing (`--qa-simulate`, tests).
final class QuietControlOutlet: ControlStateOutlet {
    var isControlInstalled: Bool { false }
    func ensureToken() {}
    func post(_ word: UInt64) {}
    func writeSnapshot(_ state: BoostChannel.State) {}
    func reloadControl() {}
    func reloadAllControls() {}
}
