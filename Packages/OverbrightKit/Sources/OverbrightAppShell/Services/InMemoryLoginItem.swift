// OverbrightAppShell/Services/InMemoryLoginItem.swift — the login item of a `--qa-simulate` launch. ARCHITECTURE.md
// §8.5 (a QA run changes nothing outside its own defaults suite), D24. A QA run is a Debug build in `build/`: registering
// it with `SMAppService` would put a development copy into the user's Login Items. This one keeps the status in memory,
// so Settings ▸ General and Welcome still show and change it.
import ServiceManagement

/// A login item whose status lives in memory.
final class InMemoryLoginItem: LoginItemService {
    /// The status `register()` and `unregister()` set (`.notRegistered` at first).
    private(set) var status: SMAppService.Status = .notRegistered
    /// Registers (in memory).
    func register() throws { status = .enabled }
    /// Unregisters (in memory).
    func unregister() throws { status = .notRegistered }
    /// Does nothing: a QA run never opens System Settings by itself.
    func openSystemSettingsLoginItems() {}
}
