// OverbrightDisplaysTests/DisplayMonitorTests.swift — `--monitor` is read-only and prints what HARDWARE-TEST reads
// (ARCHITECTURE.md §8.5, §10.4 acceptance "--monitor never writes (a fake-port test and a lint test)", D20, D26): one
// JSON line per display per interval with the table class against the profile base, its ratio, the table maximum and
// middle entry and the three headroom values; fake ports record no write and no restore; the Monitor sources contain
// no write, restore or display-configuration call.
import CoreGraphics
import Foundation
import OverbrightCore
import OverbrightPolicy
import OverbrightTestSupport
import Testing
@testable import OverbrightDisplays

/// Lines the monitor printed.
private final class Lines {
    var all: [String] = []
    var objects: [[String: Any]] {
        all.compactMap { try? JSONSerialization.jsonObject(with: Data($0.utf8)) as? [String: Any] }
    }
}

/// A port whose table cannot be read; records any write or restore attempt.
private nonisolated final class UnreadablePort: GammaPort {
    let attempts = LockedValue(0)
    func capacity(of display: CGDirectDisplayID) -> Int { 1024 }
    func read(_ display: CGDirectDisplayID) throws -> GammaTable { throw GammaError.coreGraphics(code: 1001) }
    func profileBase(of display: CGDirectDisplayID, count: Int) -> GammaTable { .identity(count: count) }
    func write(_ table: GammaTable, to display: CGDirectDisplayID) throws { attempts.value += 1 }
    func restoreSystemColorSettings() { attempts.value += 1 }
    var writeCount: Int { 0 }
}

@Suite struct DisplayMonitorTests {
    private func refs(_ fixture: DisplayFixture) -> [DisplayRef] { fixture.displays.map(\.facts.ref) }

    /// Runs the monitor over `gamma` and `fixture`'s scripted headroom for `duration` (manual time).
    private func monitor(_ gamma: any GammaPort, _ fixture: DisplayFixture, duration: Duration) async -> Lines {
        let time = ManualTimeSource()
        let headroom = ScriptedHeadroom(fixture: fixture, time: time)
        let lines = Lines()
        let displays = refs(fixture)
        let task = Task {
            await DisplayMonitor.run(gamma: gamma, headroom: headroom, time: time, interval: .milliseconds(250),
                                     duration: duration, displays: { displays }, output: { lines.all.append($0) })
        }
        _ = await eventually { time.sleeperCount > 0 }                // the loop printed at 0 s and sleeps
        await time.advance(by: duration)
        await task.value
        return lines
    }

    @Test func theMonitorNeverWrites() async throws {
        let gamma = FakeGammaPort(fixture: .hardwareMirror)
        let foreign = GammaTable(red: GammaTable.identity(count: 1024).red.map { $0 * 1.2 },
                                 green: GammaTable.identity(count: 1024).green.map { $0 * 1.2 },
                                 blue: GammaTable.identity(count: 1024).blue.map { $0 * 1.2 })
        gamma.foreignWrite(foreign, to: 1)                                // another app scaled the built-in
        let lines = await monitor(gamma, .hardwareMirror, duration: .seconds(1))
        #expect(lines.all.count == 4 * 2)                                 // 0, 0.25, 0.5, 0.75 s × two displays
        #expect(gamma.writeCount == 0)
        #expect(gamma.writes.allSatisfy { $0.isForeign })
        #expect(gamma.restoreCount == 0)
        #expect(gamma.table(of: 1) == foreign)                            // left exactly as it was
        #expect(gamma.table(of: 6) == .identity(count: 256))
    }

    @Test func linesCarryTheClassAgainstTheProfileBaseAndTheHeadroom() async throws {
        let gamma = FakeGammaPort(fixture: .hardwareMirror)
        let identity = GammaTable.identity(count: 1024)
        let foreign = GammaTable(red: identity.red.map { $0 * 1.2 }, green: identity.green.map { $0 * 1.2 },
                                 blue: identity.blue.map { $0 * 1.2 })
        gamma.foreignWrite(foreign, to: 1)
        let objects = await monitor(gamma, .hardwareMirror, duration: .milliseconds(250)).objects
        #expect(objects.count == 2)
        let builtIn = try #require(objects.first { $0["id"] as? Int == 1 })
        #expect(builtIn["key"] as? String == DisplayFixture.Keys.builtIn.rawValue)
        let expectedClass = TableClassifier.classify(foreign, expectedBase: identity)
        #expect(builtIn["class"] as? String == MonitorLine.code(expectedClass))
        #expect(abs((builtIn["max"] as? Double ?? 0) - 1.2) < 1e-6)
        #expect(abs((builtIn["mid"] as? Double ?? 0) - Double(foreign.green[512])) < 1e-6)
        #expect(builtIn["entries"] as? Int == 1024)
        #expect(builtIn["potential"] as? Double == 16)
        #expect(builtIn["current"] as? Double == 1)                      // idle: nothing requests EDR
        #expect(builtIn["reference"] as? Double == 0)
        #expect(builtIn["t"] as? Double == 0)
        // The projector mirrors the built-in: a table of its own, no headroom of its own.
        let projector = try #require(objects.first { $0["id"] as? Int == 6 })
        #expect(projector["entries"] as? Int == 256)
        #expect(projector["current"] is NSNull && projector["potential"] is NSNull)
    }

    @Test func aDisplayWithoutTableOrWithAnUnreadableOneSaysSo() async throws {
        let sidecar = await monitor(FakeGammaPort(fixture: .sidecar), .sidecar, duration: .milliseconds(250)).objects
        let line = try #require(sidecar.first { $0["id"] as? Int == 5 })
        #expect(line["class"] as? String == "noTable")
        #expect(line["max"] == nil)

        let port = UnreadablePort()
        let unreadable = await monitor(port, .builtinXDRLidOpen, duration: .milliseconds(250)).objects
        #expect(unreadable.first?["class"] as? String == "unreadable")
        #expect((unreadable.first?["error"] as? String)?.contains("1001") == true)
        #expect(port.attempts.value == 0)
    }

    @Test func withoutADurationItRunsUntilCancelled() async {
        let time = ManualTimeSource()
        let gamma = FakeGammaPort(fixture: .builtinXDRLidOpen)
        let headroom = ScriptedHeadroom(fixture: .builtinXDRLidOpen, time: time)
        let lines = Lines()
        let displays = refs(.builtinXDRLidOpen)
        let task = Task {
            await DisplayMonitor.run(gamma: gamma, headroom: headroom, time: time, interval: .milliseconds(250),
                                     duration: nil, displays: { displays }, output: { lines.all.append($0) })
        }
        _ = await eventually { time.sleeperCount > 0 }
        await time.advance(by: .seconds(10))
        #expect(lines.all.count == 41)                                    // 0 … 10 s inclusive
        task.cancel()
        await task.value
        #expect(time.sleeperCount == 0)
        #expect(gamma.writeCount == 0)
    }

    @Test func scaledLinesCarryTheirRatio() throws {
        let ref = DisplayRef(key: DisplayFixture.Keys.builtIn, id: 1)
        func object(_ tableClass: TableClass) throws -> [String: Any] {
            let line = MonitorLine(seconds: 0.25, display: ref,
                                   table: .read(tableClass: tableClass, maximum: 1, middle: 0.6, entries: 1024),
                                   reading: nil)
            return try #require(try JSONSerialization.jsonObject(with: Data(line.json.utf8)) as? [String: Any])
        }
        #expect(try object(.scaled(ratio: 1.2371234567))["ratio"] as? Double == 1.237123)
        #expect(try object(.scaled(ratio: 1.2))["class"] as? String == "scaled")
        #expect(try object(.scaled(ratio: nil))["ratio"] is NSNull)       // a clamped plateau hides the ratio
        #expect(try object(.matchesBase)["ratio"] == nil)
        for (tableClass, code) in [(TableClass.foreign, "foreign"), (.invalid, "invalid"), (.matchesBase, "matchesBase")] {
            #expect(try object(tableClass)["class"] as? String == code)
        }
    }

    /// The lint half: nothing in `Sources/OverbrightDisplays/Monitor/` writes a table, restores, captures or
    /// reconfigures a display (comments excluded).
    @Test func monitorSourcesContainNoWrite() throws {
        let folder = URL(filePath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().appending(path: "Sources/OverbrightDisplays/Monitor", directoryHint: .isDirectory)
        let files = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "swift" }
        #expect(files.count >= 2)
        let forbidden = try NSRegularExpression(pattern: [
            "\\bwrite\\s*\\(", "\\.write\\b", "restoreSystem" + "ColorSettings", "CGSet" + "Display",
            "CGDisplay" + "Restore", "CGDisplay" + "Capture", "CGCapture" + "AllDisplays", "CGConfigure" + "Display",
            "CGBegin" + "DisplayConfiguration", "CGDisplay" + "Release",
        ].joined(separator: "|"))
        for file in files {
            let code = try String(contentsOf: file, encoding: .utf8).split(separator: "\n", omittingEmptySubsequences: false)
                .map { line in line.range(of: "//").map { String(line[..<$0.lowerBound]) } ?? String(line) }
            for (index, line) in code.enumerated() {
                let range = NSRange(line.startIndex..., in: line)
                #expect(forbidden.firstMatch(in: line, range: range) == nil, "\(file.lastPathComponent):\(index + 1): \(line)")
            }
        }
    }
}
