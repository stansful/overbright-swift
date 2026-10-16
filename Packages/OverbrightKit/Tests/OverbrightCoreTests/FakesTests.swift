// OverbrightCoreTests/FakesTests.swift — the fakes behave as ARCHITECTURE.md §3.9 promises, so WP4–WP8 can trust them.
import CoreGraphics
import Foundation
import Testing
@testable import OverbrightCore

// MARK: - ManualTimeSource

/// Wake-ups seen by sleeping tasks (main actor).
@MainActor private final class WakeLog { var entries: [String] = [] }

@MainActor @Suite struct ManualTimeSourceTests {
    @Test func sleepersWakeInDeadlineOrderOnlyWhenTimeMovesPastThem() async {
        let time = ManualTimeSource()
        let log = WakeLog()
        let start = time.wallClock
        for (name, ms) in [("late", 300), ("early", 100), ("tie-a", 200), ("tie-b", 200)] {
            Task { try? await time.sleep(for: .milliseconds(ms)); log.entries.append(name) }
        }
        for _ in 0..<50 where time.sleeperCount < 4 { await Task.yield() }
        #expect(time.sleeperCount == 4 && time.nextDeadline == MonotonicInstant(sinceOrigin: .milliseconds(100)))
        await time.advance(by: .milliseconds(99))
        #expect(log.entries.isEmpty)
        await time.advance(by: .milliseconds(150))
        #expect(log.entries == ["early", "tie-a", "tie-b"])
        await time.advance(by: .seconds(1))
        #expect(log.entries == ["early", "tie-a", "tie-b", "late"] && time.sleeperCount == 0)
        #expect(time.now == MonotonicInstant(sinceOrigin: .milliseconds(1249)))
        #expect(time.wallClock == start.addingTimeInterval(1.249))
    }

    /// A ramp of 18 steps sleeping 1/60 s each finishes within one 300 ms advance (woken tasks sleep again inside it).
    @Test func chainedSleepsRunWithinOneAdvance() async {
        let time = ManualTimeSource()
        let log = WakeLog()
        Task {
            for step in 1...18 {
                try? await time.sleep(for: .microseconds(16_667))
                log.entries.append("\(step)")
            }
        }
        for _ in 0..<50 where time.sleeperCount == 0 { await Task.yield() }
        await time.advance(by: .milliseconds(301))
        #expect(log.entries.count == 18)
    }

    @Test func cancellingASleeperThrowsAtOnce() async {
        let time = ManualTimeSource()
        let task = Task { try await time.sleep(for: .seconds(10)) }
        for _ in 0..<50 where time.sleeperCount == 0 { await Task.yield() }
        task.cancel()
        await #expect(throws: CancellationError.self) { try await task.value }
        #expect(time.sleeperCount == 0)
        let already = Task { try await time.sleep(for: .seconds(1)) }
        already.cancel()
        await #expect(throws: CancellationError.self) { try await already.value }
        try? await time.sleep(for: .zero)                                         // returns at once
    }

    @Test func theWallClockCanJumpAlone() {
        let time = ManualTimeSource(start: Date(timeIntervalSinceReferenceDate: 0))
        time.setWallClock(Date(timeIntervalSinceReferenceDate: 3600))
        #expect(time.wallClock == Date(timeIntervalSinceReferenceDate: 3600) && time.now.sinceOrigin == .zero)
    }
}

// MARK: - FakeGammaPort

@Suite struct FakeGammaPortTests {
    private let id: CGDirectDisplayID = 1
    private func scaled(_ table: GammaTable, by factor: Float) -> GammaTable {
        GammaTable(red: table.red.map { $0 * factor }, green: table.green.map { $0 * factor }, blue: table.blue.map { $0 * factor })
    }

    @Test func writesAreRecordedAndReadBackUnderEitherModel() throws {
        let time = ManualTimeSource()
        let port = FakeGammaPort(fixture: .builtinXDRLidOpen, time: time)
        let base = try #require(port.base(of: id))
        #expect(try port.capacity(of: id) == 1024 && port.writeCount == 0 && port.read(id) == base)
        let boosted = scaled(base, by: 1.237)
        try port.write(boosted, to: id)
        #expect(port.writeCount == 1 && port.writes.first?.table == boosted && port.writes.first?.isForeign == false)
        #expect(try port.read(id) == boosted && port.screenTable(of: id) == boosted)
        port.clampsReadBack = true                                                // D26: the other read-back model
        #expect(try port.read(id).maximum == 1 && port.table(of: id) == boosted)
        #expect(try port.read(id).red[100] == boosted.red[100])                  // sub-1 entries unchanged
    }

    @Test func deathRevertsEveryDisplayAndRestoreNeedsAPriorWrite() throws {
        let port = FakeGammaPort(fixture: .russianNames)
        let base1 = try #require(port.base(of: 1)), base2 = try #require(port.base(of: 2))
        port.restoreSystemColorSettings()                                         // no write yet: nothing happens
        #expect(port.restoreCount == 1)
        try port.write(scaled(base1, by: 1.2), to: 1)
        try port.write(scaled(base2, by: 0.5), to: 2)
        port.simulateProcessDeath()
        #expect(port.table(of: 1) == base1 && port.table(of: 2) == base2)
        try port.write(scaled(base1, by: 1.2), to: 1)
        port.simulateOtherWriterDeath()
        #expect(port.table(of: 1) == base1)
        try port.write(scaled(base1, by: 1.2), to: 1)
        port.restoreWritesZeros = true                                            // the failed global restore of D7
        port.restoreSystemColorSettings()
        #expect(port.table(of: 1)?.maximum == 0 && port.table(of: 2)?.maximum == 0)
        port.restoreWritesZeros = false
        port.restoreSystemColorSettings()
        #expect(port.table(of: 1) == base1)
    }

    @Test func ignoredWritesReadBackButNeverReachTheScreen() throws {
        let port = FakeGammaPort(fixture: .neoIgnoresWrites)
        #expect(port.ignoresWrites)
        let base = try #require(port.base(of: id))
        try port.write(scaled(base, by: 1.3), to: id)
        #expect(try port.read(id) == scaled(base, by: 1.3) && port.screenTable(of: id) == base && port.writeCount == 1)
    }

    @Test func foreignWritesBaseChangesAndFailures() throws {
        let port = FakeGammaPort(fixture: .calibratedProfile)
        let base = try #require(port.base(of: id))
        #expect(base != .identity(count: 1024))                                   // a calibrated, per-channel base
        #expect(port.profileBase(of: id, count: 256).count == 256)
        #expect(abs((port.profileBase(of: id, count: 256).blue.last.map(Double.init) ?? 0) - 0.96) < 0.001)
        #expect(port.profileBase(of: 99, count: 8) == .identity(count: 8))        // unknown: identity
        port.foreignWrite(scaled(base, by: 0.9), to: id)
        #expect(try port.writeCount == 0 && port.writes.last?.isForeign == true && port.read(id) == scaled(base, by: 0.9))
        let newBase = GammaTable.identity(count: 1024)
        port.changeBase(newBase, for: id, appliesNow: false)                      // the event comes first …
        #expect(try port.base(of: id) == newBase && port.read(id) == scaled(base, by: 0.9))
        port.resetToBase(id)                                                      // … WindowServer's table later
        #expect(try port.read(id) == newBase)
        port.failNextWrite(with: .coreGraphics(code: 1001))
        #expect(throws: GammaError.coreGraphics(code: 1001)) { try port.write(newBase, to: id) }
        #expect(port.writeCount == 0)
        port.removeDisplay(id)
        #expect(throws: GammaError.displayGone) { try port.read(id) }
        #expect(throws: GammaError.displayGone) { try port.write(newBase, to: id) }
    }

    @Test func displaysWithoutATableRefuseReadsAndWrites() {
        let port = FakeGammaPort(fixture: .sidecar)
        #expect(port.capacity(of: 5) == 0)
        #expect(throws: GammaError.noTable) { try port.read(5) }
        #expect(throws: GammaError.noTable) { try port.write(.identity(count: 4), to: 5) }
    }

    /// A write can block inside "WindowServer" (§4.6): reads go on meanwhile, and the write lands when released.
    @Test func aStalledWriteLandsWhenReleased() async throws {
        let port = FakeGammaPort(fixture: .builtinXDRLidOpen)
        let base = try #require(port.base(of: id))
        let release = DispatchSemaphore(value: 0)
        port.stallNextWrite(until: release)
        let writer = Task.detached { try port.write(.identity(count: 1024), to: 1) }
        var waited = 0
        while !port.isWriteStalled && waited < 3000 { try await Task.sleep(for: .milliseconds(10)); waited += 1 }
        #expect(try port.isWriteStalled && port.writeCount == 0 && port.read(id) == base)
        release.signal()
        try await writer.value
        #expect(!port.isWriteStalled && port.writeCount == 1)
        try port.write(base, to: id)                                              // only the next write stalled
        #expect(port.writeCount == 2)
    }
}

// MARK: - ScriptedHeadroom and FakeTriggerFactory

@MainActor @Suite struct ScriptedHeadroomTests {
    private let builtIn = DisplayFixture.Keys.builtIn
    private var ref: DisplayRef { DisplayRef(key: builtIn, id: 1) }
    private func request(_ strategy: TriggerStrategy) -> TriggerRequest {
        TriggerRequest(strategy: strategy, pixel: .black, placement: .topRightCorner, blend: .normal, headroomTag: 16)
    }

    @Test func aPresentedTriggerRampsHeadroomToTheGrant() async throws {
        let time = ManualTimeSource()
        let headroom = ScriptedHeadroom(fixture: .builtinXDRLidOpen, time: time)
        let factory = FakeTriggerFactory(headroom: headroom)
        #expect(headroom.reading(for: ref)?.current == 1 && headroom.reading(for: ref)?.potential == 16)
        let trigger = try factory.makeTrigger(request(.metalOneShot), on: ref)
        #expect(factory.openWindowCount == 1)
        #expect(await trigger.present(.black))
        await time.advance(by: .milliseconds(199))
        #expect(headroom.currentHeadroom(of: builtIn) == 1)                       // not before the response delay
        await time.advance(by: .milliseconds(501))
        let mid = try #require(headroom.currentHeadroom(of: builtIn))
        #expect(mid > 1.5 && mid < 2.6)                                           // ramping
        await time.advance(by: .seconds(1))
        #expect(abs((headroom.reading(for: ref)?.current ?? 0) - 1600.0 / 600) < 1e-9)
        #expect(headroom.reading(for: ref)?.time == time.now)
        trigger.remove()
        #expect(headroom.currentHeadroom(of: builtIn) == 1 && factory.openWindowCount == 0)
        #expect(factory.presents.count == 1 && factory.made.first?.display == ref)
    }

    @Test func strategiesThatMacOSIgnoresNeverMoveHeadroom() async throws {
        let time = ManualTimeSource()
        let headroom = ScriptedHeadroom(fixture: .builtinXDRLidOpen, time: time)
        headroom.update(builtIn) { $0.respondingStrategies = [.hlgStill] }
        let factory = FakeTriggerFactory(headroom: headroom)
        factory.failingPresents = [.metalKeepAlive]
        factory.makeErrors = [.hlgSampleBuffer: .assetUnavailable]
        let t2 = try factory.makeTrigger(request(.metalOneShot), on: ref)
        #expect(await t2.present(.bright))
        let t3 = try factory.makeTrigger(request(.metalKeepAlive), on: ref)
        #expect(await !t3.present(.bright))
        #expect(throws: TriggerError.assetUnavailable) { try factory.makeTrigger(request(.hlgSampleBuffer), on: ref) }
        await time.advance(by: .seconds(5))
        #expect(headroom.currentHeadroom(of: builtIn) == 1)
        let t4 = try factory.makeTrigger(request(.hlgStill), on: ref)
        #expect(await t4.present(.black))
        await time.advance(by: .seconds(2))
        #expect((headroom.currentHeadroom(of: builtIn) ?? 0) > 2.6)
        factory.availableStrategies = [.metalOneShot]
        #expect(!factory.isAvailable(.taggedLayer))
        #expect(throws: TriggerError.needsNewerMacOS(26)) { try factory.makeTrigger(request(.taggedLayer), on: ref) }
    }

    /// D6: another source holds EDR (H0 high), then leaves at a scripted time.
    @Test func preHeldHeadroomLeavesOnSchedule() async {
        let time = ManualTimeSource()
        var script = HeadroomScript(potential: 16, grant: 2.667)
        script.preHeld = 2.6
        script.preHeldLeavesAfter = .seconds(30)
        let headroom = ScriptedHeadroom(time: time, scripts: [builtIn: script])
        #expect(headroom.reading(for: ref)?.current == 2.6)
        await time.advance(by: .seconds(30))
        #expect(headroom.reading(for: ref)?.current == 1)
        #expect(headroom.readCount == 2)
    }

    @Test func overridesGrantChangesAndMirrors() async throws {
        let time = ManualTimeSource()
        let headroom = ScriptedHeadroom(fixture: .hardwareMirror, time: time)
        let factory = FakeTriggerFactory(headroom: headroom)
        #expect(headroom.reading(for: DisplayRef(key: DisplayFixture.Keys.projector, id: 6)) == nil)  // no own screen
        let overlay = try factory.makeOverlay(on: ref)
        try overlay.setFactor(1.2, headroomRequest: 1.3)                          // an overlay's EDR request
        await time.advance(by: .seconds(2))
        #expect(abs((headroom.currentHeadroom(of: builtIn) ?? 0) - 1600.0 / 600) < 1e-9)
        headroom.setOverride(1, for: nil)                                         // a lock shield
        #expect(headroom.currentHeadroom(of: builtIn) == 1)
        headroom.setOverride(nil)
        headroom.setGrant(5.33, for: builtIn, over: .seconds(2))                  // the brightness keys lower SDR white
        await time.advance(by: .seconds(1))
        let rising = try #require(headroom.currentHeadroom(of: builtIn))
        #expect(rising > 2.7 && rising < 5.3)
        await time.advance(by: .seconds(1))
        #expect(abs((headroom.currentHeadroom(of: builtIn) ?? 0) - 5.33) < 1e-9)
        try overlay.setFactor(0.5, headroomRequest: 1)                            // dimming: no EDR request
        #expect(headroom.requestCount(on: builtIn) == 0 && headroom.currentHeadroom(of: builtIn) == 1)
        headroom.update(builtIn) { $0.potential = 1 }                             // potential falls: H follows
        #expect(headroom.currentHeadroom(of: builtIn) == 1)
    }

    @Test func windowsMoveAndOcclude() async throws {
        let factory = FakeTriggerFactory()
        let trigger = try factory.makeTrigger(request(.taggedLayer), on: ref)
        var moved: [CGDirectDisplayID?] = []
        var occluded: [Bool] = []
        trigger.onScreenChange = { moved.append($0) }
        trigger.onOcclusionChange = { occluded.append($0) }
        factory.moveWindows(on: builtIn, toScreen: 2)
        factory.setOccluded(true, on: builtIn)
        factory.setOccluded(true, on: builtIn)                                    // no change: no callback
        #expect(moved == [2] && occluded == [true] && trigger.isOccluded)
        trigger.represent()
        trigger.requestHeadroom(3)
        trigger.remove()
        trigger.remove()
        #expect(factory.openWindowCount == 0 && factory.triggers.first?.representCount == 1)
        #expect(factory.triggers.first?.requestedHeadroom == [3] && factory.liveTriggers(on: builtIn).isEmpty)
        #expect(await !trigger.present(.black))                                  // removed: never presents again
    }
}

// MARK: - Directory, signals, probe, previews

@MainActor @Suite struct FakeServicesTests {
    @Test func theDirectoryListsBuiltInFirstAndCountsChanges() {
        let directory = FakeDisplayDirectory(fixture: .russianNames)
        #expect(directory.displays.map(\.ref.key) == [DisplayFixture.Keys.builtIn, DisplayFixture.Keys.mpg322ux])
        #expect(directory.facts(for: DisplayFixture.Keys.builtIn)?.name == "Встроенный дисплей Retina")
        #expect(directory.generation == 0)
        directory.remove(DisplayFixture.Keys.builtIn)                             // lid closed
        #expect(directory.displays.count == 1 && directory.generation == 1)
        directory.update(DisplayFixture.Keys.mpg322ux) { $0.ref.id = 7 }          // a new ID after reconfiguration
        #expect(directory.facts(for: DisplayFixture.Keys.mpg322ux)?.ref.id == 7 && directory.generation == 2)
        directory.add(DisplayFixture.builtinXDRLidOpen.displays[0].facts)
        #expect(directory.displays.first?.isBuiltIn == true && directory.generation == 3)
    }

    @Test func signalsDeliverEventsSynchronouslyAndRecordCalls() {
        let signals = FakeSystemSignals()
        let probe = FakeConflictProbe()
        var seen: [SystemEvent] = []
        let token = signals.addEventObserver { seen.append($0) }
        signals.emit(.locked)
        #expect(seen == [.locked])                                                // delivered before emit returns
        let app = ConflictingApp(entryID: "example", severity: .gammaWriter, bundleID: "com.example.tint", processID: 42,
                                 displayName: "Tint")
        signals.appLaunched(app, probe: probe)
        #expect(signals.snapshot.conflicts == [app] && probe.runningConflicts() == [app])
        signals.appTerminated(app, probe: probe)
        #expect(signals.snapshot.conflicts.isEmpty && probe.running.isEmpty)
        #expect(seen == [.locked, .appLaunched(bundleID: "com.example.tint"),
                         .appTerminated(bundleID: "com.example.tint", processID: 42)])
        token.cancel()
        signals.emit(.unlocked)
        #expect(seen.count == 3 && signals.observerCount == 0)

        signals.powerOnRefresh = PowerState(source: .battery, batteryPercent: 18, isLowPowerMode: false)
        signals.setBoostActive(true)                                              // reads power synchronously
        #expect(signals.boostActiveCalls == [true] && signals.refreshPowerNowCount == 1)
        #expect(signals.snapshot.power.batteryPercent == 18)
        signals.setFocusDirective(.off)
        #expect(signals.focusDirectives == [.off] && signals.snapshot.focus == .off)
    }

    @Test func theProbeNamesTheDriftAttribution() async {
        let app = ConflictingApp(entryID: "e", severity: .conditional, bundleID: nil, processID: 7, displayName: "E")
        let probe = FakeConflictProbe(driftAttribution: app)
        #expect(await probe.attributeDrift() == app && probe.attributionRequests == 1)
    }

    @Test func previewControlsRecordAndChangeState() async {
        let services = OverbrightServices.preview(fixture: .russianNames)
        let boost = services.boost as? PreviewBoostControl
        #expect(boost?.status.isReady == true && boost?.status.displays.count == 2 && boost?.status.isOn == false)
        services.boost.setOn(true, source: .panel)
        #expect(services.boost.status.isOn && services.boost.status.symbol == .on && services.boost.status.lastChange == nil)
        services.boost.step(.brighter, source: .shortcut)                          // the HUD's trigger
        #expect(services.boost.status.lastChange?.sequence == 1 && services.boost.status.lastChange?.source == .shortcut)
        services.boost.pause(until: Date(timeIntervalSinceReferenceDate: 1), source: .menu)
        #expect(services.boost.status.symbol == .paused)
        services.boost.returnToStandard(source: .shortcut)
        #expect(!services.boost.status.isOn && services.boost.status.lastChange?.sequence == 2)
        #expect(await services.boost.rescueDisplayColors() == .alreadyNeutral)
        #expect(await services.boost.runSelfTest(SelfTestOptions()).machine == DisplayFixture.ownerMachine)
        #expect(services.boost.beginCalibration(of: DisplayFixture.Keys.builtIn) == nil)
        #expect(boost?.calls.first == "setOn(true,panel)" && boost?.calls.count == 7)

        #expect(services.shortcuts.displayString(.toggle) == "⌃⌥⌘B")
        #expect(services.shortcuts.displayString(.brighter) == "⌃⌥⌘=" && services.shortcuts.displayString(.max) == nil)
        #expect(services.shortcuts.set(.max, KeyCombo(keyCode: 46, modifiers: [.control, .shift])) ==
                .registered(KeyCombo(keyCode: 46, modifiers: [.control, .shift])))
        #expect(services.shortcuts.displayString(.max) == "⌃⇧M")
        #expect(services.shortcuts.set(.toggle, nil) == .off)

        services.fillLight.setOn(true, source: .menu)
        #expect(services.fillLight.isOn && !services.fillLight.isAutomatic)
        #expect(!services.updates.isConfigured)
        services.updates.checkNow()
        #expect(services.updates.state == .idle)                                  // no repository: no check
        services.app?.setMenuBarIconVisible(false)
        #expect(services.app?.iconVisibility == .hiddenByUser)
        services.app?.setLaunchBehavior(.launchAndEnable)
        #expect(services.app?.loginItem == .enabled)
    }

    /// The hub is built from fakes with no I/O: no files, no defaults outside memory, no windows, no writes.
    @Test func previewServicesTouchNothing() {
        for fixture in DisplayFixture.allCases {
            let services = OverbrightServices.preview(fixture: fixture)
            #expect(!FileManager.default.fileExists(atPath: services.paths.root.path))
            #expect(services.machine == fixture.machine)
            #expect(services.displays.displays.count == fixture.displays.count)
            #expect(services.journal.snapshot().isEmpty && services.ownEDRSurfaces.displays.isEmpty)
            #expect(services.time.now == MonotonicInstant(sinceOrigin: .zero))
        }
    }
}

// MARK: - Fixtures

@Suite struct DisplayFixtureTests {
    @Test func everyFixtureIsConsistent() {
        for fixture in DisplayFixture.allCases {
            let displays = fixture.displays
            #expect(!displays.isEmpty, "\(fixture)")
            #expect(Set(displays.map(\.key)).count == displays.count, "\(fixture)")
            #expect(Set(displays.map(\.facts.ref.id)).count == displays.count, "\(fixture)")
            #expect(displays.first?.facts.isBuiltIn == displays.contains { $0.facts.isBuiltIn }, "\(fixture)")
            #expect(DisplayFixture(rawValue: fixture.rawValue) == fixture)
            for display in displays {
                #expect(display.facts.gammaCapacity == (display.profileBase?.count ?? 0), "\(fixture) \(display.key)")
                #expect(display.headroom.grant <= max(display.headroom.potential, 1), "\(fixture) \(display.key)")
                if let base = display.profileBase {
                    for channel in [base.red, base.green, base.blue] {
                        #expect(zip(channel, channel.dropFirst()).allSatisfy { $0 <= $1 }, "\(fixture) monotonic")
                        #expect((channel.first ?? 1) <= 0.1 && (channel.last ?? 0) >= 0.9, "\(fixture) plausible")
                    }
                }
            }
        }
        #expect(DisplayFixture(rawValue: "builtin-xdr-lid-open") == .builtinXDRLidOpen)          // make run's default
    }

    /// The owner's measured values (docs/research/display-facts.md).
    @Test func theOwnersDisplaysCarryTheirMeasuredValues() throws {
        let builtIn = try #require(DisplayFixture.builtinXDRLidOpen.displays.first)
        #expect(builtIn.facts.panelClass == .builtInXDR && builtIn.facts.hasNotch && builtIn.facts.sdrMaxNits == 600)
        #expect(builtIn.facts.panelPeakNits == 1600 && builtIn.headroom.potential == 16)
        #expect(abs(builtIn.headroom.grant - 2.667) < 0.001 && builtIn.profileBase == .identity(count: 1024))
        let msi = try #require(DisplayFixture.mpg322uxHDROn.displays.first)
        #expect(msi.facts.panelClass == .oledExternal && msi.facts.supportsPQ == true && !msi.facts.isBuiltIn)
        #expect(msi.headroom.potential == 4.6549 && msi.facts.panelFrameAverageNits == 265.05)
        #expect(msi.facts.panelMinNits == 0.0003 && msi.facts.panelPeakNits == 465.49)
        #expect(abs(msi.headroom.grant - 1.756) < 0.001)
        #expect(DisplayFixture.mpg322uxHDROff.displays.first?.headroom.potential == 1)
        #expect(DisplayFixture.ownerMachine.model == "Mac16,5" && DisplayFixture.ownerMachine.osMajor == 27)
        #expect(DisplayFixture.neoIgnoresWrites.machine.model == "Mac17,5" && DisplayFixture.neoIgnoresWrites.tableWritesIgnored)
        #expect(DisplayFixture.hardwareMirror.displays.last?.facts.isMirrored == true)
        #expect(DisplayFixture.sidecar.displays.last?.facts.panelClass == .virtualDisplay)
        // Same displays, other names: identical facts apart from the name (no logic may compare names, D8).
        var russian = try #require(DisplayFixture.russianNames.displays.first?.facts)
        russian.name = builtIn.facts.name
        #expect(russian == builtIn.facts)
    }
}
