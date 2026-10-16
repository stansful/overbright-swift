// OverbrightAppShellTests/SingleInstanceTests.swift — one engine per user session (ARCHITECTURE.md §7.4, D27) over a
// scripted environment: no process is looked up, asked to reopen or waited for for real.
import Foundation
import OverbrightCore
import Testing
@testable import OverbrightAppShell

/// A scripted system: the running instances, the reopens asked for and the exits waited for.
@MainActor private final class FakeSystem {
    var running: [SingleInstance.Instance] = []
    var reopenSucceeds = true
    var exitsInTime = true
    private(set) var reopened: [pid_t] = []
    private(set) var waitedFor: [pid_t] = []

    func environment(bundleID: String? = "app.overbright.Overbright", pid: pid_t = 200) -> SingleInstance.Environment {
        SingleInstance.Environment(
            bundleIdentifier: bundleID, processIdentifier: pid,
            running: { _ in self.running },
            reopen: { instance in
                self.reopened.append(instance.processIdentifier)
                return self.reopenSucceeds
            },
            waitForExit: { pid, _ in
                self.waitedFor.append(pid)
                return self.exitsInTime
            })
    }
}

private let installed = SingleInstance.Instance(processIdentifier: 100,
                                                bundleURL: URL(filePath: "/Applications/Overbright.app"))
private let me = SingleInstance.Instance(processIdentifier: 200, bundleURL: URL(filePath: "/tmp/build/Overbright.app"))

@MainActor @Suite struct SingleInstanceTests {
    /// D27: another Overbright runs → it is asked to show itself and this launch exits.
    @Test func secondInstanceHandsOverAndExits() {
        let system = FakeSystem()
        system.running = [installed, me]
        let handedOver = SingleInstance.handOverIfRunning(arguments: LaunchArguments(["Overbright"]),
                                                          environment: system.environment())
        #expect(handedOver)
        #expect(system.reopened == [100])                                        // the other one, never itself
    }

    /// Alone (only this process runs), the launch carries on.
    @Test func aLoneInstanceCarriesOn() {
        let system = FakeSystem()
        system.running = [me]
        #expect(!SingleInstance.handOverIfRunning(arguments: LaunchArguments(["Overbright"]),
                                                  environment: system.environment()))
        #expect(system.reopened.isEmpty)
    }

    /// Even when the reopen is refused, two engines must not run: this launch still exits.
    @Test func aRefusedReopenStillExits() {
        let system = FakeSystem()
        system.running = [installed, me]
        system.reopenSucceeds = false
        #expect(SingleInstance.handOverIfRunning(arguments: LaunchArguments(["Overbright"]),
                                                 environment: system.environment()))
    }

    /// Command-line modes never hand over (the shell skips them too), and a process outside a bundle never does.
    @Test func commandLineModesAndBundlelessProcessesNeverHandOver() {
        let system = FakeSystem()
        system.running = [installed, me]
        for arguments in [["Overbright", "--diagnostics", "-"], ["Overbright", "--monitor"], ["Overbright", "--restore-gamma"]] {
            #expect(!SingleInstance.handOverIfRunning(arguments: LaunchArguments(arguments),
                                                      environment: system.environment()))
        }
        #expect(!SingleInstance.handOverIfRunning(arguments: LaunchArguments(["Overbright"]),
                                                  environment: system.environment(bundleID: nil)))
        #expect(system.reopened.isEmpty)
    }

    /// The relaunch after "Move to Applications" waits for the copy that moved (it is quitting) instead of handing
    /// over to it; a third, unrelated instance still wins.
    @Test func theRelaunchAfterAMoveWaitsForTheOldCopy() {
        let system = FakeSystem()
        system.running = [installed, me]
        let afterMove = LaunchArguments(["Overbright", SingleInstance.afterMoveArgument, "100"])
        #expect(!SingleInstance.handOverIfRunning(arguments: afterMove, environment: system.environment()))
        #expect(system.waitedFor == [100] && system.reopened.isEmpty)

        let other = SingleInstance.Instance(processIdentifier: 300, bundleURL: nil)
        system.running = [installed, me, other]
        #expect(SingleInstance.handOverIfRunning(arguments: afterMove, environment: system.environment()))
        #expect(system.reopened == [300])
    }

    /// An agent's QA run on the simulated ports writes no table: the owner's copy never hands over to it.
    @Test func aSimulatedInstanceIsNotAnEngine() {
        let system = FakeSystem()
        let qa = SingleInstance.Instance(processIdentifier: 300, bundleURL: nil, isSimulated: true)
        system.running = [qa, me]
        #expect(!SingleInstance.handOverIfRunning(arguments: LaunchArguments(["Overbright"]),
                                                  environment: system.environment()))
        system.running = [qa, installed, me]
        #expect(SingleInstance.handOverIfRunning(arguments: LaunchArguments(["Overbright"]),
                                                 environment: system.environment()))
        #expect(system.reopened == [installed.processIdentifier])               // the real one, never the QA run
    }

    /// `KERN_PROCARGS2`: argc, the executable path, padding, then the arguments (the environment after them).
    @Test func processArgumentsParse() throws {
        var bytes: [UInt8] = [3, 0, 0, 0]
        bytes += Array("/Applications/Overbright.app/Contents/MacOS/Overbright".utf8) + [0, 0, 0, 0]
        for argument in ["/Applications/Overbright.app/Contents/MacOS/Overbright", "--qa-simulate", "lcd-only"] {
            bytes += Array(argument.utf8) + [0]
        }
        bytes += Array("HOME=/Users/me".utf8) + [0]
        let arguments = try #require(ProcessArguments.parse(bytes))
        #expect(arguments.count == 3 && arguments[1] == "--qa-simulate")
        #expect(LaunchArguments(arguments).qaSimulates)
        #expect(ProcessArguments.parse([1, 0]) == nil)                          // too short
        #expect(ProcessArguments.parse([2, 0, 0, 0, 65, 0, 66, 0]) == nil)      // argc says 2, one argument
        // This test process can read its own arguments (the same user).
        let own = try #require(ProcessArguments.of(ProcessInfo.processInfo.processIdentifier))
        #expect(own == ProcessInfo.processInfo.arguments)
    }

    /// The copy that moved exits before it starts any service (`ApplicationsMover`): even when it is slow to go, this
    /// launch never hands over to it (that would leave nothing running) and carries on.
    @Test func aMovedCopyThatIsSlowToExitIsNeverHandedOverTo() {
        let system = FakeSystem()
        system.running = [installed, me]
        system.exitsInTime = false
        let afterMove = LaunchArguments(["Overbright", SingleInstance.afterMoveArgument, "100"])
        #expect(!SingleInstance.handOverIfRunning(arguments: afterMove, environment: system.environment()))
        #expect(system.waitedFor == [100] && system.reopened.isEmpty)
    }
}
