// OverbrightAppShell/Launch/LaunchGate.swift — pairs the launch work (launch check, services' start) with the quit
// work (services' stop). The stop must never run when the start did not: `--diagnostics` quits without starting
// anything, and a quit that arrives while the launch work is still running waits for it (up to `quitWait`) before
// the services stop. Ported verbatim from Cranny's LaunchGate.swift (the owner's MIT code). ARCHITECTURE.md §7.4.
// Seeded by WP0a; WP0b owns `Launch/`.
import Foundation

/// The launch work and the quit work, in order.
final class LaunchGate {
    /// Where the launch is.
    enum Phase: Equatable { case notLaunched, launching, launched }

    /// The longest a quit waits for the launch work (a hung one must not block quitting).
    static let quitWait: Duration = .seconds(3)

    private(set) var phase = Phase.notLaunched
    private var pendingQuit: (() -> Void)?
    private var quitTimeout: Task<Void, Never>?

    /// Runs `work` (the launch check and the services' start) once.
    func launch(_ work: @escaping @MainActor () async -> Void) {
        guard phase == .notLaunched else { return }
        phase = .launching
        Task {
            await work()
            self.phase = .launched
            self.releaseQuit()
        }
    }

    /// Whether the quit work may run: only after a launch (never in `--diagnostics`).
    var runsTerminateHooks: Bool { phase != .notLaunched }

    /// `applicationShouldTerminate`: true when the quit must wait; `reply` is then called once, when the launch work
    /// finished or `limit` passed, whichever comes first. A second request while one waits shares its reply.
    func defersQuit(atMost limit: Duration = LaunchGate.quitWait, reply: @escaping () -> Void) -> Bool {
        guard phase == .launching else { return false }
        guard pendingQuit == nil else { return true }
        pendingQuit = reply
        quitTimeout = Task { [weak self] in
            try? await Task.sleep(for: limit)
            guard !Task.isCancelled else { return }
            self?.releaseQuit()
        }
        return true
    }

    private func releaseQuit() {
        quitTimeout?.cancel()
        quitTimeout = nil
        let reply = pendingQuit
        pendingQuit = nil
        reply?()
    }
}
