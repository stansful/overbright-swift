// OverbrightBoostTests/Ladder/LadderTests.swift — the trigger ladder and its cache (ARCHITECTURE.md §4.7): the automatic
// order (Metal keep-alive first, no tagged layer; D4 as built), OLED black only, the cache key, the cached-rung-only
// backoff, the two-arm replacement rule with the wake/unlock quarantine, the lowest ready headroom, the override (the
// only way to the tagged layer), and the cache file.
import Foundation
import OverbrightCore
import OverbrightPolicy
import OverbrightTestSupport
import Testing
@testable import OverbrightBoost

@MainActor @Suite struct LadderTests {
    private let all = Set(TriggerStrategy.allCases)
    private let builtIn = DisplayFixture.builtinXDRLidOpen.displays[0].facts
    private let oled = DisplayFixture.mpg322uxHDROn.displays[0].facts
    private let display = DisplayFixture.Keys.builtIn

    private func numbers(_ rungs: [LadderRung]) -> [Int] { rungs.map(\.number) }

    /// The automatic ladder starts at the Metal keep-alive and leaves the tagged layer out on every macOS (D4 as
    /// built: the owner's built-in XDR turned white when a table was scaled behind it).
    @Test func automaticOrderStartsAtTheKeepAliveOnEveryOS() {
        for os in [14, 15, 26, 27] {
            let rungs = LadderPlanner.rungs(for: builtIn, isOLED: false, os: os, cache: nil, override: nil, backoff: false,
                                            available: all)
            #expect(numbers(rungs) == [5, 4, 3, 6, 7], "macOS \(os)")
        }
        #expect(LadderPlanner.automaticOrder == [5, 4, 3, 6, 7])
        let tahoe = LadderPlanner.automatic
        #expect(tahoe.map(\.strategy) == [.metalKeepAlive, .metalOneShot, .metalOneShot, .hlgStill, .hlgStill])
        #expect(tahoe.map(\.pixel) == [.bright, .bright, .black, .black, .bright])
        #expect(!tahoe.contains { $0.strategy == .taggedLayer })
        #expect(LadderPlanner.table.map(\.number) == [1, 2, 3, 4, 5, 6, 7])   // every rung keeps its cache number
    }

    @Test func oledUsesBlackRungsOnly() {
        let rungs = LadderPlanner.rungs(for: oled, isOLED: true, os: 27, cache: nil, override: nil, backoff: false,
                                        available: all)
        #expect(numbers(rungs) == [3, 6])
        #expect(rungs.allSatisfy { $0.pixel == .black })
    }

    @Test func unavailableStrategiesAreSkipped() {
        let rungs = LadderPlanner.rungs(for: builtIn, isOLED: false, os: 27, cache: nil, override: nil, backoff: false,
                                        available: [.metalOneShot, .hlgStill])
        #expect(numbers(rungs) == [4, 3, 6, 7])
    }

    @Test func cachedRungStartsTheArmAndBackoffRetriesOnlyIt() {
        let rungs = LadderPlanner.rungs(for: builtIn, isOLED: false, os: 27, cache: 4, override: nil, backoff: false,
                                        available: all)
        #expect(numbers(rungs) == [4, 3, 6, 7])
        let backoff = LadderPlanner.rungs(for: builtIn, isOLED: false, os: 27, cache: 4, override: nil, backoff: true,
                                          available: all)
        #expect(numbers(backoff) == [4])
        let uncached = LadderPlanner.rungs(for: builtIn, isOLED: false, os: 27, cache: nil, override: nil, backoff: true,
                                           available: all)
        #expect(numbers(uncached) == [5])
    }

    /// A tagged-layer rung cached before it left the automatic ladder (same macOS build) is not resumed: the arm
    /// starts at the top, and a backoff retries the top rung.
    @Test func aCachedTaggedRungStartsAtTheTop() {
        for cache in [1, 2] {
            let rungs = LadderPlanner.rungs(for: builtIn, isOLED: false, os: 27, cache: cache, override: nil,
                                            backoff: false, available: all)
            #expect(numbers(rungs) == [5, 4, 3, 6, 7])
            let backoff = LadderPlanner.rungs(for: builtIn, isOLED: false, os: 27, cache: cache, override: nil,
                                              backoff: true, available: all)
            #expect(numbers(backoff) == [5])
        }
    }

    @Test func overridePinsTheStrategy() {
        let rungs = LadderPlanner.rungs(for: oled, isOLED: true, os: 27, cache: 1, override: .metalKeepAlive,
                                        backoff: false, available: all)
        #expect(numbers(rungs) == [5])
        let pinned = LadderPlanner.rungs(for: builtIn, isOLED: false, os: 27, cache: nil, override: .metalOneShot,
                                         backoff: false, available: all)
        #expect(numbers(pinned) == [3, 4])
    }

    /// The tagged layer is reachable only through Advanced ▸ Trigger method, and only where it runs (macOS 26+);
    /// elsewhere the override falls back to the automatic ladder.
    @Test func taggedLayerOnlyThroughTheOverride() {
        let tagged = LadderPlanner.rungs(for: builtIn, isOLED: false, os: 27, cache: nil, override: .taggedLayer,
                                         backoff: false, available: all)
        #expect(numbers(tagged) == [1, 2])
        let backoff = LadderPlanner.rungs(for: builtIn, isOLED: false, os: 27, cache: 2, override: .taggedLayer,
                                          backoff: true, available: all)
        #expect(numbers(backoff) == [1])
        let oledTagged = LadderPlanner.rungs(for: oled, isOLED: true, os: 27, cache: nil, override: .taggedLayer,
                                             backoff: false, available: all)
        #expect(numbers(oledTagged) == [1, 2])                                 // a pinned strategy runs all its rungs
        let sequoia = LadderPlanner.rungs(for: builtIn, isOLED: false, os: 15, cache: nil, override: .taggedLayer,
                                          backoff: false, available: all)
        #expect(numbers(sequoia) == [5, 4, 3, 6, 7])
        let unavailable = LadderPlanner.rungs(for: builtIn, isOLED: false, os: 27, cache: nil, override: .taggedLayer,
                                              backoff: false, available: all.subtracting([.taggedLayer]))
        #expect(numbers(unavailable) == [5, 4, 3, 6, 7])
    }

    @Test func requestsPlaceAndBlend() {
        let table = LadderPlanner.table
        let builtInBright = LadderPlanner.request(for: table[1], facts: builtIn, potential: 16)
        #expect(builtInBright.placement == .topRightCorner && builtInBright.blend == .normal)
        #expect(builtInBright.headroomTag == 16)                             // policy A: tagged at the potential
        let externalBright = LadderPlanner.request(for: table[3], facts: oled, potential: 4.6549)
        #expect(externalBright.blend == .softLight)
        let externalBlack = LadderPlanner.request(for: table[2], facts: oled, potential: 4.6549)
        #expect(externalBlack.blend == .normal)
        #expect(LadderPlanner.request(for: table[0], facts: builtIn, potential: 0.5).headroomTag == 1)
    }

    // MARK: Cache

    @Test func cacheKeyIsDisplayAndBuild() {
        let cache = StrategyCache()
        cache.recordWin(rung: 3, for: display, osBuild: "26A434")
        #expect(cache.record(for: display, osBuild: "26A434")?.rung == 3)
        #expect(cache.record(for: display, osBuild: "26B100") == nil)        // a new build learns again
        #expect(StrategyCache.key(display, osBuild: "26A434") == "\(display.rawValue)|26A434")
    }

    /// "Heavier" is later in the automatic order (5, 4, 3, 6, 7): rung 3 replaces rung 5 after two failed arms.
    @Test func heavierRungReplacesOnlyAfterTwoFailedArms() {
        let cache = StrategyCache()
        cache.recordWin(rung: 5, for: display, osBuild: "b")
        cache.recordFailure(rung: 5, for: display, osBuild: "b", quarantined: false)
        cache.recordWin(rung: 3, for: display, osBuild: "b")
        #expect(cache.record(for: display, osBuild: "b")?.rung == 5)         // one failed arm: kept
        cache.recordFailure(rung: 5, for: display, osBuild: "b", quarantined: false)
        cache.recordWin(rung: 3, for: display, osBuild: "b")
        #expect(cache.record(for: display, osBuild: "b")?.rung == 3)         // the second: replaced
        #expect(cache.record(for: display, osBuild: "b")?.failures == 0)
        cache.recordFailure(rung: 3, for: display, osBuild: "b", quarantined: false)
        cache.recordFailure(rung: 3, for: display, osBuild: "b", quarantined: false)
        cache.recordWin(rung: 4, for: display, osBuild: "b")                 // earlier in the order: never
        #expect(cache.record(for: display, osBuild: "b")?.rung == 3)
    }

    /// A tagged rung cached before it left the automatic ladder never fails again, so the next win replaces it; a
    /// tagged win under Advanced ▸ Trigger method never replaces an automatic rung.
    @Test func taggedRungsGiveWayToTheAutomaticLadder() {
        let cache = StrategyCache()
        cache.recordWin(rung: 1, for: display, osBuild: "b")
        cache.recordWin(rung: 5, for: display, osBuild: "b")
        #expect(cache.record(for: display, osBuild: "b")?.rung == 5)
        cache.recordFailure(rung: 5, for: display, osBuild: "b", quarantined: false)
        cache.recordFailure(rung: 5, for: display, osBuild: "b", quarantined: false)
        cache.recordWin(rung: 2, for: display, osBuild: "b")
        #expect(cache.record(for: display, osBuild: "b")?.rung == 5)
    }

    @Test func quarantinedFailuresDoNotCount() {
        let cache = StrategyCache()
        cache.recordWin(rung: 5, for: display, osBuild: "b")
        cache.recordFailure(rung: 5, for: display, osBuild: "b", quarantined: true)
        cache.recordFailure(rung: 5, for: display, osBuild: "b", quarantined: true)
        cache.recordWin(rung: 4, for: display, osBuild: "b")
        #expect(cache.record(for: display, osBuild: "b")?.rung == 5)
        cache.recordFailure(rung: 4, for: display, osBuild: "b", quarantined: false)   // not the cached rung
        #expect(cache.record(for: display, osBuild: "b")?.failures == 0)
    }

    @Test func winningAgainClearsFailures() {
        let cache = StrategyCache()
        cache.recordWin(rung: 2, for: display, osBuild: "b")
        cache.recordFailure(rung: 2, for: display, osBuild: "b", quarantined: false)
        cache.recordWin(rung: 2, for: display, osBuild: "b")
        #expect(cache.record(for: display, osBuild: "b")?.failures == 0)
    }

    @Test func lowestReadyHeadroomIsKept() {
        let cache = StrategyCache()
        cache.learnReadyHeadroom(5.33, for: display, osBuild: "b")
        cache.learnReadyHeadroom(2.667, for: display, osBuild: "b")
        cache.learnReadyHeadroom(3.2, for: display, osBuild: "b")
        cache.learnReadyHeadroom(0.9, for: display, osBuild: "b")               // not a grant
        #expect(cache.record(for: display, osBuild: "b")?.lowestReadyHeadroom == 2.667)
        cache.forget()
        #expect(cache.records.isEmpty)
    }

    @Test func cacheFileRoundTrips() async throws {
        let url = FileManager.default.temporaryDirectory
            .appending(path: "overbright-ladder-\(UUID().uuidString)/strategy-cache.json")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let file = JSONDocumentFile<[String: StrategyRecord]>(url: url)
        let cache = StrategyCache()
        await cache.attach(file: file, osBuild: "b")
        cache.recordWin(rung: 3, for: display, osBuild: "b")
        cache.learnReadyHeadroom(2.6, for: display, osBuild: "b")
        let saved = await eventually { (try? file.load()).map { if case .loaded(let v) = $0 { v.count == 1 } else { false } } ?? false }
        #expect(saved)
        let reopened = StrategyCache()
        await reopened.attach(file: JSONDocumentFile(url: url), osBuild: "b")
        #expect(reopened.record(for: display, osBuild: "b") == StrategyRecord(rung: 3, failures: 0, lowestReadyHeadroom: 2.6))
    }

    /// Only the running build's records are read, so records of earlier macOS builds are dropped when the file is
    /// attached and the pruned map is written back once (C-BOOST-15: the file no longer grows with every update).
    @Test func attachingDropsRecordsOfOtherBuilds() async throws {
        let url = FileManager.default.temporaryDirectory
            .appending(path: "overbright-ladder-\(UUID().uuidString)/strategy-cache.json")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let other = DisplayKey(rawValue: "0B21E7F1-0000-4000-8000-0000000000AA")
        let stored = [StrategyCache.key(display, osBuild: "25A1"): StrategyRecord(rung: 2),
                      StrategyCache.key(other, osBuild: "25A1"): StrategyRecord(rung: 4),
                      StrategyCache.key(display, osBuild: "26B2"): StrategyRecord(rung: 1, lowestReadyHeadroom: 2.5)]
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(stored).write(to: url)
        let file = JSONDocumentFile<[String: StrategyRecord]>(url: url)
        let cache = StrategyCache()
        await cache.attach(file: file, osBuild: "26B2")
        let current = StrategyCache.key(display, osBuild: "26B2")
        #expect(cache.records == [current: StrategyRecord(rung: 1, lowestReadyHeadroom: 2.5)])
        let pruned = await eventually {
            (try? file.load()).map { if case .loaded(let v) = $0 { v.count == 1 } else { false } } ?? false
        }
        #expect(pruned)
        #expect(StrategyCache.osBuild(ofKey: current) == "26B2")
    }

    /// The highest grant seen is kept, and small rises (read-back noise) are not stored (DESIGN.md §12.1; C-BOOST-25).
    @Test func highestGrantedHeadroomIsKept() {
        let cache = StrategyCache()
        cache.learnGrantedHeadroom(2.4, for: display, osBuild: "b")
        cache.learnGrantedHeadroom(2.667, for: display, osBuild: "b")
        cache.learnGrantedHeadroom(1.6, for: display, osBuild: "b")
        cache.learnGrantedHeadroom(2.672, for: display, osBuild: "b")               // below the resolution
        cache.learnGrantedHeadroom(0.9, for: display, osBuild: "b")                 // not a grant
        #expect(cache.record(for: display, osBuild: "b")?.highestGrantedHeadroom == 2.667)
    }

    // MARK: In the engine

    /// The second arm starts at the cached rung; a pre-held arm never writes the cache.
    @Test func engineStartsAtTheCachedRung() async throws {
        let h = EngineHarness()
        h.scripted.update(DisplayFixture.Keys.builtIn) { $0.respondingStrategies = [.metalOneShot] }
        await h.start()
        #expect(await h.boost())
        // The keep-alive (rung 5) gets no headroom, the bright one-shot (rung 4) does.
        #expect(h.engine.strategyCache.record(for: display, osBuild: h.fixture.machine.osBuild)?.rung == 4)
        h.engine.setOn(false, source: .panel)
        await h.advance(.seconds(1))
        let made = h.triggers.made.count
        #expect(await h.boost())
        #expect(h.triggers.made.dropFirst(made).map(\.request.strategy) == [.metalOneShot])
    }
}
