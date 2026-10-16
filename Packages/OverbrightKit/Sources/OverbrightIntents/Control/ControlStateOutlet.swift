// OverbrightIntents/Control/ControlStateOutlet.swift — where the control's state goes. ARCHITECTURE.md §7.7; D25.
// The real outlet (`SystemControlOutlet`) posts notifyd, writes the app's preferences and reloads the control; tests
// record the calls instead, so no test touches the real notify name, preferences domain or Control Center.
import OverbrightChannel

/// The outputs of the control's one publish point, in the order `ControlStatePublisher` uses them: the notify word,
/// then the preferences snapshot, then a reload.
@MainActor public protocol ControlStateOutlet: AnyObject {
    /// Whether this build ships the control (`Contents/PlugIns/OverbrightControls.appex`, `CONTROLS=1`).
    var isControlInstalled: Bool { get }
    /// Makes the `set=on` token when there is none (never rotates an existing one).
    func ensureToken()
    /// Sets and posts the notifyd state word.
    func post(_ word: UInt64)
    /// Writes the preferences snapshot the extension falls back to.
    func writeSnapshot(_ state: BoostChannel.State)
    /// Asks Control Center to re-read the toggle (`reloadControls(ofKind:)`).
    func reloadControl()
    /// Asks Control Center to re-read every control of the app (`reloadAllControls()`, at launch and quit).
    func reloadAllControls()
}
