// OverbrightAppShellTests/LoginItemControllerTests.swift — opening at login (ARCHITECTURE.md §3.6, D15; DESIGN.md §7.3,
// §8) against a fake `SMAppService`: the real login items are never touched. Ported from Cranny's
// LoginItemControllerTests (the owner's MIT code); the launch behaviour picks register or unregister, and nothing opens
// System Settings on its own.
import AppKit
import Foundation
import OverbrightCore
import ServiceManagement
import Testing
@testable import OverbrightAppShell

/// Records every call; `register()` moves to `statusAfterRegister` or throws. `statusReads` counts the reads of
/// `status` (each one is an XPC round trip with the real `SMAppService`).
final class FakeLoginItem: LoginItemService {
    var status: SMAppService.Status {
        get { statusReads += 1; return storedStatus }
        set { storedStatus = newValue }
    }
    private var storedStatus: SMAppService.Status = .notRegistered
    private(set) var statusReads = 0
    var statusAfterRegister: SMAppService.Status = .enabled
    var registerFails = false
    private(set) var calls: [String] = []

    struct Refused: Error {}

    func register() throws {
        calls.append("register")
        if registerFails { throw Refused() }
        status = statusAfterRegister
    }
    func unregister() throws {
        calls.append("unregister")
        status = .notRegistered
    }
    func openSystemSettingsLoginItems() { calls.append("openSettings") }
}

private let applications = URL(filePath: "/Applications/Overbright.app")
private let translocated = URL(filePath: "/private/var/folders/xy/T/AppTranslocation/1234-ABCD/d/Overbright.app")

/// Counts deliveries of one test's own posts (other tests post `didBecomeActive` too).
@MainActor private final class Deliveries {
    var count = 0
}

@MainActor @Suite struct LoginItemControllerTests {
    @Test func statusesMapToStates() {
        #expect(LoginItemController.state(for: .enabled) == .enabled)
        #expect(LoginItemController.state(for: .requiresApproval) == .requiresApproval)
        #expect(LoginItemController.state(for: .notRegistered) == .disabled)
        #expect(LoginItemController.state(for: .notFound) == .disabled)     // an ad-hoc app never registered
    }

    @Test func translocatedCopiesAreDetected() {
        #expect(LoginItemController.isTranslocated(translocated))
        #expect(!LoginItemController.isTranslocated(applications))
        #expect(!LoginItemController.isTranslocated(URL(filePath: "/Users/me/Downloads/Overbright.app")))
    }

    /// D15: both "Open Overbright" choices register; "Don't open Overbright" unregisters; repeats do nothing.
    @Test func launchBehaviorRegistersOrUnregisters() {
        let fake = FakeLoginItem()
        let controller = LoginItemController(service: fake, bundleURL: applications)
        controller.refresh()
        #expect(controller.state == .disabled)
        controller.apply(.launchOnly)
        #expect(controller.state == .enabled && fake.calls == ["register"])
        controller.apply(.launchAndEnable)                                       // already registered
        #expect(fake.calls == ["register"])
        controller.apply(.dontLaunch)
        #expect(controller.state == .disabled && fake.calls == ["register", "unregister"])
        controller.apply(.dontLaunch)
        #expect(fake.calls == ["register", "unregister"])
    }

    /// Approval is finished in Login Items: the state says so, and only the Open System Settings button goes there.
    @Test func approvalIsReportedAndNeverOpensSystemSettingsByItself() {
        let fake = FakeLoginItem()
        fake.statusAfterRegister = .requiresApproval
        let controller = LoginItemController(service: fake, bundleURL: applications)
        controller.apply(.launchOnly)
        #expect(controller.state == .requiresApproval && fake.calls == ["register"])
        controller.apply(.launchOnly)                                            // pending: nothing new
        #expect(fake.calls == ["register"])
        controller.openSystemSettings()
        #expect(fake.calls == ["register", "openSettings"])
        fake.status = .enabled                                                   // approved; Overbright active again
        controller.refresh()
        #expect(controller.state == .enabled && controller.unavailable == nil)
    }

    @Test func aRefusedRegistrationIsUnavailableUntilItWorks() {
        let fake = FakeLoginItem()
        fake.registerFails = true
        let controller = LoginItemController(service: fake, bundleURL: applications)
        controller.apply(.launchOnly)
        #expect(controller.state == .unavailable && controller.unavailable == .refused)
        controller.refresh()                                                     // still not registered: keep explaining
        #expect(controller.state == .unavailable && controller.unavailable == .refused)
        fake.registerFails = false
        controller.apply(.launchOnly)                                            // tried again
        #expect(controller.state == .enabled && controller.unavailable == nil)
        #expect(fake.calls == ["register", "register"])
    }

    @Test func aTranslocatedCopyNeverRegisters() {
        let fake = FakeLoginItem()
        let controller = LoginItemController(service: fake, bundleURL: translocated)
        #expect(controller.state == .unavailable && controller.unavailable == .translocated)
        controller.apply(.launchAndEnable)
        #expect(fake.calls.isEmpty && controller.state == .unavailable)
    }

    @Test func theStatusIsReadAgainWhenOverbrightBecomesActive() async throws {
        let fake = FakeLoginItem()
        let controller = LoginItemController(service: fake, bundleURL: applications)
        controller.start()
        defer { controller.stop() }
        #expect(controller.state == .disabled)
        fake.status = .enabled                                                   // changed in System Settings meanwhile
        NotificationCenter.default.post(name: NSApplication.didBecomeActiveNotification, object: nil)
        for _ in 0..<400 where controller.state != .enabled { try await Task.sleep(for: .milliseconds(25)) }
        #expect(controller.state == .enabled)
    }

    /// The status is an XPC round trip, and only Settings and Welcome show it: neither the launch (`start()`) nor an
    /// activation before anything showed it reads it.
    @Test func theStatusIsReadOnFirstUseNotAtLaunch() async throws {
        let fake = FakeLoginItem()
        fake.status = .enabled
        let controller = LoginItemController(service: fake, bundleURL: applications)
        controller.start()
        defer { controller.stop() }
        #expect(fake.statusReads == 0)

        // Main-queue observers of one post run in the order they were added: once the probe ran, the controller's
        // observer (added first, for every sender) has run too.
        let sender = NSObject(), deliveries = Deliveries()
        let probe = NotificationCenter.default.addObserver(forName: NSApplication.didBecomeActiveNotification,
                                                           object: sender, queue: .main) { _ in
            MainActor.assumeIsolated { deliveries.count += 1 }
        }
        defer { NotificationCenter.default.removeObserver(probe) }
        NotificationCenter.default.post(name: NSApplication.didBecomeActiveNotification, object: sender)
        for _ in 0..<400 where deliveries.count < 1 { try await Task.sleep(for: .milliseconds(25)) }
        #expect(deliveries.count == 1 && fake.statusReads == 0)                  // nothing showed it yet

        #expect(controller.state == .enabled && fake.statusReads == 1)           // the first reader asks
        #expect(controller.state == .enabled && fake.statusReads == 1)           // later reads do not

        fake.status = .notRegistered                                             // changed in System Settings
        NotificationCenter.default.post(name: NSApplication.didBecomeActiveNotification, object: sender)
        for _ in 0..<400 where controller.state != .disabled { try await Task.sleep(for: .milliseconds(25)) }
        #expect(controller.state == .disabled && fake.statusReads >= 2)
    }
}
