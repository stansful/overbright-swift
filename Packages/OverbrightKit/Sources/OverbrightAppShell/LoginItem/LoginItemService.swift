// OverbrightAppShell/LoginItem/LoginItemService.swift — the slice of `SMAppService` the login item controller uses,
// so tests inject a fake and never touch the real login items. Ported from Cranny's LoginItemController.swift (the
// owner's MIT code). ARCHITECTURE.md §3.6 (`LoginItemState`), D15.
import ServiceManagement

/// The app as a login item.
protocol LoginItemService: AnyObject {
    /// The registration status (an XPC round trip with the real service).
    var status: SMAppService.Status { get }
    /// Registers the app to open at login.
    func register() throws
    /// Removes the app from the login items.
    func unregister() throws
    /// Opens Login Items in System Settings.
    func openSystemSettingsLoginItems()
}

/// `SMAppService.mainApp`: the app itself as a login item, no helper.
final class MainAppLoginItem: LoginItemService {
    var status: SMAppService.Status { SMAppService.mainApp.status }
    func register() throws { try SMAppService.mainApp.register() }
    func unregister() throws { try SMAppService.mainApp.unregister() }
    func openSystemSettingsLoginItems() { SMAppService.openSystemSettingsLoginItems() }
}
