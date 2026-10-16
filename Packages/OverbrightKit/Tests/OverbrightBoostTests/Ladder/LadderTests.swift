// OverbrightBoostTests/Ladder/LadderTests.swift — the trigger ladder and its cache (ARCHITECTURE.md §4.7): order by OS
// and class, OLED black only, the cache key, the cached-rung-only backoff, the two-arm replacement rule with the
// wake/unlock quarantine, the lowest ready headroom, the override, and the cache file.
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

    @Test func orderByOS() {
        let sequoia = LadderPlanner.rungs(for: builtIn, isOLED: false, os: 15, cache: nil, override: nil, backoff: false,
                                          available: all)
        #expect(numbers(sequoia) == [3, 4, 5, 6, 7])                        // 14–25 start at T2
        let tahoe = LadderPlanner.rungs(for: builtIn, isOLED: false, os: 27, cache: nil, override: nil, backoff: false,
                                        available: all)
        #expect(numbers(tahoe) == [1, 2, 3, 4, 5, 6, 7])
        #expect(tahoe.map(\.strategy) == [.taggedLayer, .taggedLayer, .metalOneShot, .metalOneShot, .metalKeepAlive,
                                          .hlgStill, .hlgStill])
        #expect(tahoe.map(\.pixel) == [.black, .bright, .black, .bright, .bright, .black, .bright])
    }

    @Test func oledUsesBlackRungsOnly() {
        let rungs = LadderPlanner.rungs(for: oled, isOLED: true, os: 27, cache: nil, override: nil, backoff: false,
                                        available: all)
        #expect(numbers(rungs) == [1, 3, 6])
        #expect(rungs.allSatisfy { $0.pixel == .black })
    }

    @Test func unavailableStrategiesAreSkipped() {
        let rungs = LadderPlanner.rungs(for: builtIn, isOLED: false, os: 27, cache: nil, override: nil, backoff: false,
                                        available: [.metalOneShot, .hlgStill])
        #expect(numbers(rungs) == [3, 4, 6, 7])
    }

    @Test func cachedRungStartsTheArmAndBackoffRetriesOnlyIt() {
        let rungs = LadderPlanner.rungs(for: builtIn, isOLED: false, os: 27, cache: 4, override: nil, backoff: false,
                                        available: all)
        #expect(numbers(rungs) == [4, 5, 6, 7])
        let backoff = LadderPlanner.rungs(for: builtIn, isOLED: false, os: 27, cache: 4, override: nil, backoff: true,
                                          available: all)
        #expect(numbers(backoff) == [4])
        let uncached = LadderPlanner.rungs(for: builtIn, isOLED: false, os: 27, cache: nil, override: nil, backoff: true,
                                           available: all)
        #expect(numbers(uncached) == [1])
    }

    @Test func overridePinsTheStrategy() {
        let rungs = LadderPlanner.rungs(for: oled, isOLED: true, os: 27, cache: 1, override: .metalKeepAlive,
                                        backoff: false, available: all)
        #expect(numbers(rungs) == [5])
        let pinned = LadderPlanner.rungs(for: builtIn, isOLED: false, os: 27, cache: nil, override: .metalOneShot,
                                         backoff: false, available: all)
        #expect(numbers(pinned) == [3, 4])
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

    @Test func heavierRungReplacesOnlyAfterTwoFailedArms() {
        let cache = StrategyCache()
        cache.recordWin(rung: 1, for: display, osBuild: "b")
        cache.recordFailure(rung: 1, for: display, osBuild: "b", quarantined: false)
        cache.recordWin(rung: 3, for: display, osBuild: "b")
        #expect(cache.record(for: display, osBuild: "b")?.rung == 1)         // one failed arm: kept
        cache.recordFailure(rung: 1, for: display, osBuild: "b", quarantined: false)
        cache.recordWin(rung: 3, for: display, osBuild: "b")
        #expect(cache.record(for: display, osBuild: "b")?.rung == 3)         // the second: replaced
        #expect(cache.record(for: display, osBuild: "b")?.failures == 0)
    }

    @Test func quarantinedFailuresDoNotCount() {
        let cache = StrategyCache()
        cache.recordWin(rung: 1, for: display, osBuild: "b")
        cache.recordFailure(rung: 1, for: display, osBuild: "b", quarantined: true)
        cache.recordFailure(rung: 1, for: display, osBuild: "b", quarantined: true)
        cache.recordWin(rung: 4, for: display, osBuild: "b")
        #expect(cache.record(for: display, osBuild: "b")?.rung == 1)
        cache.recordFailure(rung: 2, for: display, osBuild: "b", quarantined: false)   // not the cached rung
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
        await cache.attach(file: file)
        cache.recordWin(rung: 3, for: display, osBuild: "b")
        cache.learnReadyHeadroom(2.6, for: display, osBuild: "b")
        let saved = await eventually { (try? file.load()).map { if case .loaded(let v) = $0 { v.count == 1 } else { false } } ?? false }
        #expect(saved)
        let reopened = StrategyCache()
        await reopened.attach(file: JSONDocumentFile(url: url))
        #expect(reopened.record(for: display, osBuild: "b") == StrategyRecord(rung: 3, failures: 0, lowestReadyHeadroom: 2.6))
    }

    // MARK: In the engine

    /// The second arm starts at the cached rung; a pre-held arm never writes the cache.
    @Test func engineStartsAtTheCachedRung() async throws {
        let h = EngineHarness()
        h.scripted.update(DisplayFixture.Keys.builtIn) { $0.respondingStrategies = [.metalOneShot] }
        await h.start()
        #expect(await h.boost())
        #expect(h.engine.strategyCache.record(for: display, osBuild: h.fixture.machine.osBuild)?.rung == 3)
        h.engine.setOn(false, source: .panel)
        await h.advance(.seconds(1))
        let made = h.triggers.made.count
        #expect(await h.boost())
        #expect(h.triggers.made.dropFirst(made).map(\.request.strategy) == [.metalOneShot])
    }
}
