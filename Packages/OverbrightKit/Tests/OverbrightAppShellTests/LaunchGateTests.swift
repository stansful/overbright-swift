// OverbrightAppShellTests/LaunchGateTests.swift — the launch work and the quit work in order (ARCHITECTURE.md §7.4).
// Ported from Cranny's LifecycleTests (the owner's MIT code).
import Foundation
import OverbrightTestSupport
import Testing
@testable import OverbrightAppShell

/// Records what happens, in order, and holds the launch work until released.
private final class Journal {
    var entries: [String] = []
    var release: CheckedContinuation<Void, Never>?
    func waitForRelease() async { await withCheckedContinuation { release = $0 } }
}

@MainActor @Suite struct LaunchGateTests {
    /// `--diagnostics` (and `make smoke`) quits before anything started: no service may stop then.
    @Test func noQuitWorkWithoutALaunch() {
        let gate = LaunchGate()
        #expect(gate.phase == .notLaunched && !gate.runsTerminateHooks)
        #expect(!gate.defersQuit { Issue.record("nothing to wait for") })
    }

    /// A quit while the launch work runs waits for it, then the quit work may run.
    @Test func aQuitDuringTheLaunchWaitsForIt() async throws {
        let gate = LaunchGate()
        let journal = Journal()
        gate.launch {
            await journal.waitForRelease()
            journal.entries.append("launched")
        }
        #expect(gate.phase == .launching && gate.runsTerminateHooks)
        #expect(gate.defersQuit { journal.entries.append("quit") })
        #expect(gate.defersQuit { journal.entries.append("second quit") })        // shares the first reply
        #expect(await eventually { journal.release != nil })
        #expect(journal.entries.isEmpty)
        journal.release?.resume()
        #expect(await eventually { journal.entries.contains("quit") })
        #expect(journal.entries == ["launched", "quit"] && gate.phase == .launched)
        #expect(!gate.defersQuit { Issue.record("launched: quits at once") })
    }

    /// Launch work that never finishes cannot block quitting.
    @Test func aHungLaunchDelaysTheQuitOnlySoLong() async throws {
        let gate = LaunchGate()
        let journal = Journal()
        gate.launch { try? await Task.sleep(for: .seconds(60)) }
        #expect(gate.defersQuit(atMost: .milliseconds(50)) { journal.entries.append("quit") })
        #expect(await eventually { !journal.entries.isEmpty })
        #expect(journal.entries == ["quit"] && gate.phase == .launching)
    }
}
