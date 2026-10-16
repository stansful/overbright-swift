// OverbrightUpdatesTests/UpdateCheckerTests.swift — the GitHub Releases update check (ARCHITECTURE.md §3.6, D2) against
// fixtures: no network. Ported from Cranny's UpdateCheckerTests (the owner's MIT code) with Core's `UpdateSettings`
// (automatic checks are OFF by default in Overbright) and `UpdateState` payloads. The fixtures follow the REST API's
// "release" object (only a few of its fields are read; the rest must be ignored).
import Foundation
import OverbrightCore
import OverbrightTestSupport
import Testing
@testable import OverbrightUpdates

// MARK: - Fixtures

private let latestFixture = Data("""
{
  "url": "https://api.github.com/repos/octo/overbright/releases/101",
  "html_url": "https://github.com/octo/overbright/releases/tag/v0.2.0",
  "id": 101,
  "tag_name": "v0.2.0",
  "target_commitish": "main",
  "name": "Overbright 0.2.0",
  "draft": false,
  "prerelease": false,
  "created_at": "2026-10-01T10:00:00Z",
  "published_at": "2026-10-01T10:05:00Z",
  "author": { "login": "octo", "id": 1 },
  "assets": [ { "name": "Overbright-0.2.0.zip", "size": 4200000,
                "browser_download_url": "https://github.com/octo/overbright/releases/download/v0.2.0/Overbright-0.2.0.zip" } ],
  "body": "## What's new\\n- Calmer ramps"
}
""".utf8)

private let listFixture = Data("""
[
  { "tag_name": "v0.4.0", "html_url": "https://github.com/octo/overbright/releases/tag/untagged-1", "draft": true, "prerelease": false },
  { "tag_name": "nightly", "html_url": "https://github.com/octo/overbright/releases/tag/nightly", "draft": false, "prerelease": true },
  { "tag_name": "v0.3.0-beta.1", "html_url": "https://github.com/octo/overbright/releases/tag/v0.3.0-beta.1", "draft": false, "prerelease": true,
    "assets": [], "body": null },
  { "tag_name": "v0.2.0", "html_url": "https://github.com/octo/overbright/releases/tag/v0.2.0", "draft": false, "prerelease": false },
  { "tag_name": "v0.1.0", "html_url": "https://github.com/octo/overbright/releases/tag/v0.1.0", "draft": false, "prerelease": false }
]
""".utf8)

private let repository = "octo/overbright"
/// The checker's clock in these tests: "up to date" carries it.
private let checkedAt = Date(timeIntervalSinceReferenceDate: 800_000_000)

/// Answers requests from a queue and records them.
private actor FakeUpdateTransport: UpdateTransport {
    enum Answer { case ok(Data, etag: String?), status(Int), failure(URLError.Code) }
    private var answers: [Answer]
    private(set) var requests: [URLRequest] = []

    init(_ answers: [Answer]) { self.answers = answers }

    func fetch(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        requests.append(request)
        guard !answers.isEmpty, let url = request.url else { throw URLError(.cannotConnectToHost) }
        switch answers.removeFirst() {
        case .ok(let data, let etag):
            let headers = etag.map { ["ETag": $0] } ?? [:]
            return (data, HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: headers)
                          ?? HTTPURLResponse())
        case .status(let code):
            return (Data(), HTTPURLResponse(url: url, statusCode: code, httpVersion: "HTTP/1.1", headerFields: [:])
                            ?? HTTPURLResponse())
        case .failure(let code):
            throw URLError(code)
        }
    }
}

/// Holds every request until `open()`, so two checks can overlap.
private actor GatedUpdateTransport: UpdateTransport {
    private let answer: Data
    private var isOpen = false
    private(set) var requests: [URLRequest] = []

    init(answer: Data) { self.answer = answer }

    func open() { isOpen = true }

    func fetch(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        requests.append(request)
        while !isOpen { try await Task.sleep(for: .milliseconds(5)) }
        guard let url = request.url,
              let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: [:])
        else { throw URLError(.badURL) }
        return (answer, response)
    }
}

/// A sleep the test ends by hand: records every wait; `release()` ends the waits so far. A cancelled wait throws, as
/// `Task.sleep` does.
@MainActor private final class ManualSleeper {
    private(set) var waits: [TimeInterval] = []
    private var released = 0

    func sleep(_ wait: TimeInterval) async throws {
        waits.append(wait)
        let index = waits.count
        while released < index { try await Task.sleep(for: .milliseconds(5)) }
    }

    func release() { released = waits.count }
}

/// `eventually` for conditions that await an actor.
@MainActor private func eventuallyAsync(_ condition: @MainActor () async -> Bool) async -> Bool {
    for _ in 0..<3000 {
        if await condition() { return true }
        try? await Task.sleep(for: .milliseconds(10))
    }
    return await condition()
}

@MainActor private func makeChecker(_ transport: any UpdateTransport, repository: String? = repository,
                                    version: String = "0.1.0",
                                    settings: SettingsStore = SettingsStore(defaults: InMemoryDefaults()),
                                    sleep: @escaping @MainActor (TimeInterval) async throws -> Void = { _ in
                                        throw CancellationError()
                                    }) -> UpdateChecker {
    UpdateChecker(settings: settings, configuration: UpdateConfiguration(repository: repository, currentVersion: version),
                  paths: .temporary(), transport: transport, now: { checkedAt }, sleep: sleep)
}

private func page(_ tag: String) throws -> URL {
    try #require(URL(string: "https://github.com/octo/overbright/releases/tag/\(tag)"))
}

private func available(_ tag: String) throws -> UpdateState {
    .available(version: String(tag.dropFirst()), url: try page(tag))
}

// MARK: - Configuration and request

@MainActor @Suite struct UpdateRequestTests {
    @Test func repositorySlugsAreValidated() {
        #expect(UpdateConfiguration.validRepository("octo/overbright") == "octo/overbright")
        #expect(UpdateConfiguration.validRepository("  octo/overbright.app \n") == "octo/overbright.app")
        for bad in ["", "octo", "octo/", "/overbright", "a/b/c", "../etc", "octo/..", "oc to/overbright",
                    "octo/overbright?x=1", "octo/overbright#x"] {
            #expect(UpdateConfiguration.validRepository(bad) == nil, "\(bad)")
        }
        #expect(UpdateConfiguration(repository: "", currentVersion: "0.1.0").repository == nil)   // empty key: off
        // About's link comes from the same validated slug: none for a bad or empty key.
        #expect(UpdateConfiguration(repository: " octo/overbright ", currentVersion: "0.1.0").repositoryURL
                == URL(string: "https://github.com/octo/overbright"))
        #expect(UpdateConfiguration(repository: "octo/overbright?x=1", currentVersion: "0.1.0").repositoryURL == nil)
        #expect(UpdateConfiguration(repository: nil, currentVersion: "0.1.0").repositoryURL == nil)
        #expect(UpdateConfiguration.repositoryInfoKey == "OverbrightGitHubRepository")
    }

    /// D2: the shipped Info.plist key is empty, so a build makes no request at all.
    @Test func theAppBundleOfTheTestsHasNoRepository() {
        #expect(UpdateConfiguration.main().repository == nil)
    }

    @Test func endpointsAndRequestCarryNoIdentifiers() throws {
        let latest = try #require(ReleaseEndpoint.latest.url(repository: repository))
        #expect(latest.absoluteString == "https://api.github.com/repos/octo/overbright/releases/latest")
        let list = try #require(ReleaseEndpoint(includesPrereleases: true).url(repository: repository))
        #expect(list.absoluteString == "https://api.github.com/repos/octo/overbright/releases?per_page=20")
        #expect(ReleaseEndpoint.list.url(repository: repository, perPage: 1)?.absoluteString
                == "https://api.github.com/repos/octo/overbright/releases?per_page=1")

        let request = UpdateRequest.make(url: latest, etag: "W/\"abc\"")
        #expect(request.httpMethod == "GET" && !request.httpShouldHandleCookies)
        #expect(request.cachePolicy == .reloadIgnoringLocalCacheData)
        #expect(request.value(forHTTPHeaderField: "If-None-Match") == "W/\"abc\"")
        #expect(request.value(forHTTPHeaderField: "Accept") == "application/vnd.github+json")
        #expect(request.value(forHTTPHeaderField: "User-Agent") == "Overbright")
        // Pinned, so CFNetwork does not send the user's preferred language instead (it would: "ru" on the owner's Mac).
        #expect(request.value(forHTTPHeaderField: "Accept-Language") == "en")
        #expect(request.allHTTPHeaderFields?.keys.sorted()
                == ["Accept", "Accept-Language", "If-None-Match", "User-Agent", "X-GitHub-Api-Version"])
        #expect(UpdateRequest.make(url: latest, etag: nil).value(forHTTPHeaderField: "If-None-Match") == nil)
    }

    @Test func httpStatusesMapToFailures() {
        #expect(UpdateFailure.http(403) == .rateLimited && UpdateFailure.http(429) == .rateLimited)
        #expect(UpdateFailure.http(404) == .repositoryNotFound)
        #expect(UpdateFailure.http(502) == .server(502))
        #expect(UpdateFailure.repositoryNotFound.message != UpdateFailure.server(404).message)
        #expect(UpdateFailure.server(502).message.contains("502"))
    }
}

// MARK: - Decoding and comparison

@MainActor @Suite struct UpdateEvaluationTests {
    @Test func releasesDecodeFromGitHubJSON() throws {
        let latest = try ReleaseEndpoint.latest.decode(latestFixture)
        #expect(latest == [GitHubRelease(tagName: "v0.2.0", htmlURL: try page("v0.2.0"))])
        let list = try ReleaseEndpoint.list.decode(listFixture)
        #expect(list.count == 5 && list[0].isDraft && list[2].isPrerelease)
        #expect(throws: DecodingError.self) { try ReleaseEndpoint.latest.decode(Data("{\"message\":\"Not Found\"}".utf8)) }
    }

    @Test func theNewestEligibleReleaseIsCompared() throws {
        let list = try ReleaseEndpoint.list.decode(listFixture)
        func evaluate(_ current: String, prereleases: Bool) -> UpdateState {
            UpdateEvaluator.evaluate(list, currentVersion: current, includesPrereleases: prereleases,
                                     repository: repository, checkedAt: checkedAt)
        }
        #expect(evaluate("0.1.0", prereleases: false) == (try available("v0.2.0")))
        #expect(evaluate("0.1.0", prereleases: true) == (try available("v0.3.0-beta.1")))
        #expect(evaluate("0.2.0", prereleases: false) == .upToDate(checkedAt: checkedAt))   // the draft 0.4.0 never counts
        #expect(evaluate("0.3.0", prereleases: true) == .upToDate(checkedAt: checkedAt))
        #expect(evaluate("0.2.0-beta.2", prereleases: false) == (try available("v0.2.0")))
        #expect(evaluate("0.10.0", prereleases: true) == .upToDate(checkedAt: checkedAt))   // numeric, not lexical
        #expect(UpdateEvaluator.evaluate([], currentVersion: "0.1.0", includesPrereleases: false, repository: repository,
                                         checkedAt: checkedAt) == .upToDate(checkedAt: checkedAt))
        #expect(evaluate("dev", prereleases: false) == .failed(message: UpdateFailure.badVersion.message))
    }

    @Test func onlyGitHubReleasePagesAreOpened() throws {
        let evil = GitHubRelease(tagName: "v9.0.0", htmlURL: URL(string: "https://evil.example/download"))
        #expect(UpdateEvaluator.releasePage(evil, repository: repository) == (try page("v9.0.0")))
        let plain = GitHubRelease(tagName: "v9.0.0", htmlURL: URL(string: "http://github.com/octo/overbright/releases/tag/v9.0.0"))
        #expect(UpdateEvaluator.releasePage(plain, repository: repository)?.scheme == "https")
        let missing = GitHubRelease(tagName: "v9.0.0", htmlURL: nil)
        #expect(UpdateEvaluator.releasePage(missing, repository: repository) == (try page("v9.0.0")))
    }

    @Test func automaticChecksAreDailyWithoutPolling() {
        let now = checkedAt
        #expect(UpdateChecker.delayUntilNextCheck(lastCheck: nil, now: now) == UpdateChecker.launchDelay)
        #expect(UpdateChecker.delayUntilNextCheck(lastCheck: now.addingTimeInterval(-3 * 86_400), now: now)
                == UpdateChecker.launchDelay)
        #expect(UpdateChecker.delayUntilNextCheck(lastCheck: now.addingTimeInterval(-3600), now: now) == 86_400 - 3600)
        #expect(UpdateChecker.delayUntilNextCheck(lastCheck: now.addingTimeInterval(3600), now: now)
                == UpdateChecker.interval)                                                 // clock moved back
    }

    @Test func aPrereleaseSwitchKeepsWhatIsStillTrue() throws {
        let stable = try available("v0.2.0")
        let beta = try available("v0.3.0-beta.1")
        let upToDate = UpdateState.upToDate(checkedAt: checkedAt)
        func after(_ state: UpdateState, includesPrereleases: Bool) -> UpdateState {
            UpdateChecker.state(state, afterPrereleasesChangedTo: includesPrereleases)
        }
        #expect(after(stable, includesPrereleases: true) == stable && after(stable, includesPrereleases: false) == stable)
        #expect(after(beta, includesPrereleases: false) == .idle)                        // pre-releases off: it no longer counts
        #expect(after(upToDate, includesPrereleases: false) == upToDate)                  // still true on the stable channel
        #expect(after(upToDate, includesPrereleases: true) == .idle)                      // a newer pre-release may exist
        #expect(after(.failed(message: "x"), includesPrereleases: true) == .idle)
        #expect(after(.checking, includesPrereleases: false) == .checking && after(.idle, includesPrereleases: true) == .idle)
    }
}

// MARK: - The checker

@MainActor @Suite struct UpdateCheckerTests {
    @Test func theSecondCheckRevalidatesWithTheETag() async throws {
        let transport = FakeUpdateTransport([.ok(latestFixture, etag: "W/\"abc\""), .status(304)])
        let settings = SettingsStore(defaults: InMemoryDefaults())
        let checker = makeChecker(transport, settings: settings)
        #expect(checker.isConfigured && checker.state == .idle)
        let first = await checker.check()
        #expect(first == (try available("v0.2.0")) && checker.state == first)
        #expect(settings[UpdateSettings.lastCheck] == checkedAt)
        let second = await checker.check()                                                // 304 → the cached answer
        #expect(second == first)
        let requests = await transport.requests
        #expect(requests.count == 2)
        #expect(requests[0].value(forHTTPHeaderField: "If-None-Match") == nil)
        #expect(requests[1].value(forHTTPHeaderField: "If-None-Match") == "W/\"abc\"")
    }

    @Test func switchingToPrereleasesAsksTheListWithoutTheOldETag() async throws {
        let transport = FakeUpdateTransport([.ok(latestFixture, etag: "W/\"latest\""), .ok(listFixture, etag: "W/\"list\"")])
        let settings = SettingsStore(defaults: InMemoryDefaults())
        let checker = makeChecker(transport, settings: settings)
        await checker.check()
        settings[UpdateSettings.prereleases] = true
        let result = await checker.check()
        #expect(result == (try available("v0.3.0-beta.1")))
        let requests = await transport.requests
        #expect(requests[1].url?.absoluteString.hasSuffix("/releases?per_page=20") == true)
        #expect(requests[1].value(forHTTPHeaderField: "If-None-Match") == nil)
    }

    @Test func failuresAreReportedOnlyWhenTheUserAsked() async throws {
        let transport = FakeUpdateTransport([.ok(latestFixture, etag: nil), .failure(.notConnectedToInternet),
                                             .failure(.notConnectedToInternet), .status(403), .status(502),
                                             .ok(Data("<html>".utf8), etag: nil)])
        let checker = makeChecker(transport)
        let available = await checker.check(userInitiated: false)
        #expect(await checker.check(userInitiated: false) == available)                   // offline in the background: keep it
        #expect(await checker.check(userInitiated: true) == .failed(message: UpdateFailure.offline.message))
        #expect(await checker.check() == .failed(message: UpdateFailure.rateLimited.message))
        #expect(await checker.check() == .failed(message: UpdateFailure.server(502).message))
        #expect(await checker.check() == .failed(message: UpdateFailure.unreadable.message))
    }

    @Test func anAnswerThatCannotBeUsedFailsOnlyWhenTheUserAsked() async throws {
        let transport = FakeUpdateTransport([.ok(latestFixture, etag: nil), .ok(latestFixture, etag: nil)])
        let settings = SettingsStore(defaults: InMemoryDefaults())
        let checker = makeChecker(transport, version: "dev", settings: settings)         // the running version is not semver
        #expect(await checker.check(userInitiated: false) == .idle)                     // automatic: nothing changes
        #expect(settings[UpdateSettings.lastCheck] != nil)                               // GitHub answered: next check in a day
        #expect(await checker.check() == .failed(message: UpdateFailure.badVersion.message))
    }

    @Test func notFoundTellsANewRepositoryFromAWrongOne() async throws {
        // `/latest` is 404 without a stable release: one release of the list proves the repository exists.
        let fresh = FakeUpdateTransport([.status(404), .ok(Data("[]".utf8), etag: nil)])
        #expect(await makeChecker(fresh).check() == .upToDate(checkedAt: checkedAt))
        let requests = await fresh.requests
        #expect(requests.count == 2 && requests[1].url?.absoluteString.hasSuffix("/releases?per_page=1") == true)
        #expect(requests[1].value(forHTTPHeaderField: "If-None-Match") == nil)
        // Both 404: GitHub does not know the repository (a wrong key is never "up to date").
        let wrong = FakeUpdateTransport([.status(404), .status(404)])
        #expect(await makeChecker(wrong).check() == .failed(message: UpdateFailure.repositoryNotFound.message))
        // The second request answers like the first would: rate limited, or offline.
        let limited = FakeUpdateTransport([.status(404), .status(429)])
        #expect(await makeChecker(limited).check() == .failed(message: UpdateFailure.rateLimited.message))
        let offline = FakeUpdateTransport([.status(404), .failure(.timedOut)])
        #expect(await makeChecker(offline).check() == .failed(message: UpdateFailure.offline.message))
        // The list answers `[]` for an existing repository, so its 404 needs no second request.
        let settings = SettingsStore(defaults: InMemoryDefaults())
        settings[UpdateSettings.prereleases] = true
        let list = FakeUpdateTransport([.status(404)])
        #expect(await makeChecker(list, settings: settings).check()
                == .failed(message: UpdateFailure.repositoryNotFound.message))
        #expect(await list.requests.count == 1)
    }

    @Test func checksAtTheSameTimeShareOneRequest() async throws {
        let transport = GatedUpdateTransport(answer: latestFixture)
        let checker = makeChecker(transport)
        let first = Task { await checker.check() }
        #expect(await eventuallyAsync { await transport.requests.count == 1 })
        let second = Task { await checker.check(userInitiated: false) }
        try await Task.sleep(for: .milliseconds(50))                                     // the second check waits as well
        await transport.open()
        let expected = try available("v0.2.0")
        let (one, two) = (await first.value, await second.value)
        #expect(one == expected && two == expected)
        #expect(await transport.requests.count == 1)
    }

    /// D2: without a repository nothing is requested, scheduled or read, whatever the settings say.
    @Test func withoutARepositoryNothingIsRequested() async throws {
        let transport = FakeUpdateTransport([.ok(latestFixture, etag: nil)])
        var slept = false
        let settings = SettingsStore(defaults: InMemoryDefaults())
        settings[UpdateSettings.automatic] = true
        let checker = makeChecker(transport, repository: nil, settings: settings, sleep: { _ in slept = true })
        #expect(!checker.isConfigured)
        await checker.start()
        checker.checkNow()
        #expect(await checker.check() == .failed(message: UpdateFailure.notConfigured.message))
        #expect(await transport.requests.isEmpty && !slept)
        await checker.stop()
    }

    // MARK: The schedule

    /// Automatic checks are off by default (DESIGN.md §7.3): starting schedules nothing until they are turned on.
    @Test func automaticChecksAreOffByDefault() async throws {
        let sleeper = ManualSleeper()
        let transport = FakeUpdateTransport([.ok(latestFixture, etag: nil)])
        let checker = makeChecker(transport, sleep: { try await sleeper.sleep($0) })
        await checker.start()
        defer { checker.stopNow() }
        try await Task.sleep(for: .milliseconds(100))
        let requests = await transport.requests
        #expect(sleeper.waits.isEmpty && requests.isEmpty)
    }

    @Test func theDailyCheckRunsAfterOneSleepAndFollowsTheSetting() async throws {
        let sleeper = ManualSleeper()
        let transport = FakeUpdateTransport([.ok(latestFixture, etag: nil)])
        let settings = SettingsStore(defaults: InMemoryDefaults())
        settings[UpdateSettings.automatic] = true
        let checker = makeChecker(transport, settings: settings, sleep: { try await sleeper.sleep($0) })
        await checker.start()
        defer { checker.stopNow() }
        #expect(await eventually { sleeper.waits == [UpdateChecker.launchDelay] })       // never checked: a minute after launch

        settings[UpdateSettings.automatic] = false                                        // turned off before the sleep ends
        try await Task.sleep(for: .milliseconds(100))
        sleeper.release()
        try await Task.sleep(for: .milliseconds(100))
        #expect(await transport.requests.isEmpty && sleeper.waits.count == 1)

        settings[UpdateSettings.automatic] = true                                         // on again: a new schedule
        #expect(await eventually { sleeper.waits.count == 2 })
        #expect(sleeper.waits.last == UpdateChecker.launchDelay)
        sleeper.release()
        let expected = try available("v0.2.0")
        #expect(await eventually { checker.state == expected })
        #expect(await eventually { sleeper.waits.count == 3 })
        #expect(sleeper.waits.last == UpdateChecker.interval)                             // then a day later, one sleep
        #expect(await transport.requests.count == 1)
    }

    @Test func aFailedAutomaticCheckRetriesInAnHour() async throws {
        let sleeper = ManualSleeper()
        let transport = FakeUpdateTransport([.failure(.notConnectedToInternet)])
        let settings = SettingsStore(defaults: InMemoryDefaults())
        settings[UpdateSettings.automatic] = true
        let checker = makeChecker(transport, settings: settings, sleep: { try await sleeper.sleep($0) })
        await checker.start()
        defer { checker.stopNow() }
        #expect(await eventually { sleeper.waits == [UpdateChecker.launchDelay] })
        sleeper.release()
        #expect(await eventually { sleeper.waits.count == 2 })
        #expect(sleeper.waits.last == UpdateChecker.retryDelay)
        #expect(await transport.requests.count == 1 && checker.state == .idle)          // nobody asked: no failure shown
    }

    @Test func turningPrereleasesOnAsksTheListTwoSecondsLater() async throws {
        let sleeper = ManualSleeper()
        let transport = FakeUpdateTransport([.ok(listFixture, etag: nil)])
        let settings = SettingsStore(defaults: InMemoryDefaults())
        settings[UpdateSettings.automatic] = true
        settings[UpdateSettings.lastCheck] = checkedAt                                    // checked just now: next one in a day
        let checker = makeChecker(transport, settings: settings, sleep: { try await sleeper.sleep($0) })
        await checker.start()
        defer { checker.stopNow() }
        #expect(await eventually { sleeper.waits.count == 1 })
        #expect(sleeper.waits.first == UpdateChecker.interval)

        settings[UpdateSettings.prereleases] = true
        #expect(await eventually { sleeper.waits.count == 2 })
        #expect(sleeper.waits.last == 2)
        sleeper.release()
        let beta = try available("v0.3.0-beta.1")
        #expect(await eventually { checker.state == beta })
        let requests = await transport.requests
        #expect(requests.count == 1 && requests.first?.url?.absoluteString.hasSuffix("/releases?per_page=20") == true)
    }

    @Test func withAutomaticChecksOffThePrereleaseSwitchAsksNothing() async throws {
        let sleeper = ManualSleeper()
        let transport = FakeUpdateTransport([.ok(latestFixture, etag: nil), .ok(listFixture, etag: nil)])
        let settings = SettingsStore(defaults: InMemoryDefaults())
        let checker = makeChecker(transport, settings: settings, sleep: { try await sleeper.sleep($0) })
        await checker.start()
        defer { checker.stopNow() }
        let stable = await checker.check()                                                // checked by hand: 0.2.0
        settings[UpdateSettings.prereleases] = true
        try await Task.sleep(for: .milliseconds(100))
        #expect(checker.state == stable)                                                  // still an update on either channel

        let beta = await checker.check()                                                  // by hand again: the list
        #expect(beta == (try available("v0.3.0-beta.1")))
        settings[UpdateSettings.prereleases] = false
        #expect(await eventually { checker.state == .idle })                             // the pre-release no longer counts
        #expect(await transport.requests.count == 2 && sleeper.waits.isEmpty)            // and nothing was asked by itself
    }
}
