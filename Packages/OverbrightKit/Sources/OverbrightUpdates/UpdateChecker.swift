// OverbrightUpdates/UpdateChecker.swift — the GitHub Releases update check. ARCHITECTURE.md §2.1 rule 7, §3.6
// (`UpdateChecking`), §7.4 (lifecycle order), §8.2, D2; DESIGN.md §7.3, §7.9. Ported from Cranny's UpdateChecker
// (the owner's MIT code): Core's `UpdateSettings` keys and `UpdateState`, the `ServiceLifecycle` start and stop.
//
// Daily (one sleep to the next due time, no polling) while General ▸ Check for updates automatically is on, and on
// demand. One GET with the stored ETag, an ephemeral session, no cookies and no identifiers; never downloads or installs
// anything. No repository configured (`OverbrightGitHubRepository` empty, the default) = no check and no network at
// all. The request, decoding and comparison live in GitHub/.
import Foundation
import Observation
import OverbrightCore
import os

private let log = Log.logger(.updates)

/// Checks GitHub Releases for a newer Overbright (`services.updates`).
@MainActor @Observable public final class UpdateChecker: UpdateChecking, ServiceLifecycle {
    /// What Settings ▸ General, About and the menu show.
    public private(set) var state: UpdateState = .idle
    /// False when this build has no repository: no request is ever made.
    public var isConfigured: Bool { configuration.repository != nil }

    @ObservationIgnored let configuration: UpdateConfiguration
    @ObservationIgnored private let settings: SettingsStore
    @ObservationIgnored private let transport: any UpdateTransport
    @ObservationIgnored private let cache: JSONFileStore<ReleaseCache?>
    @ObservationIgnored private let now: @MainActor () -> Date
    @ObservationIgnored private let sleep: @MainActor (TimeInterval) async throws -> Void
    @ObservationIgnored private var schedule: Task<Void, Never>?
    @ObservationIgnored private var inFlight: Task<Result<[GitHubRelease], UpdateFailure>, Never>?
    @ObservationIgnored private var tokens: [ObservationToken] = []

    /// A day between automatic checks; the first one waits a minute after launch, a failed one retries in an hour.
    nonisolated static let interval: TimeInterval = 86_400
    /// The wait before the first automatic check of a launch.
    nonisolated static let launchDelay: TimeInterval = 60
    /// The wait before an automatic check that failed is tried again.
    nonisolated static let retryDelay: TimeInterval = 3600

    /// The app's checker: the repository from Info.plist, the update cache under `paths.caches`. Construction makes
    /// no request and reads no file (`constructingServicesTouchesNoHardware`); `start()` schedules the first check.
    public convenience init(settings: SettingsStore, paths: AppPaths) {
        self.init(settings: settings, configuration: .main(), paths: paths, transport: URLSessionUpdateTransport())
    }

    /// Tests inject the configuration, the transport, the clock and the sleep.
    init(settings: SettingsStore, configuration: UpdateConfiguration, paths: AppPaths, transport: any UpdateTransport,
         now: @escaping @MainActor () -> Date = { Date() },
         sleep: @escaping @MainActor (TimeInterval) async throws -> Void = { try await Task.sleep(for: .seconds($0)) }) {
        self.settings = settings; self.configuration = configuration; self.transport = transport
        self.now = now; self.sleep = sleep
        // Written off the main actor by the store's actor; the directory is created on the first save.
        let folder = paths.caches.appending(path: AppPaths.updatesFolder, directoryHint: .isDirectory)
        cache = JSONFileStore(url: folder.appending(path: "releases.json"), defaultValue: nil)
    }

    // MARK: ServiceLifecycle

    /// "Updates".
    public var serviceName: String { "Updates" }

    /// Schedules the daily check and follows General ▸ Updates (automatic, pre-releases). Nothing without a repository.
    public func start() async {
        guard isConfigured else { log.info("update check off: no repository in this build"); return }
        guard tokens.isEmpty else { return }
        tokens = [
            observe({ [settings] in settings[UpdateSettings.automatic] }) { [weak self] _ in self?.scheduleAutomatic() },
            observe({ [settings] in settings[UpdateSettings.prereleases] }) { [weak self] includes in
                self?.prereleasesChanged(to: includes)
            },
        ]
        scheduleAutomatic()
    }

    /// Cancels the schedule (a check in flight finishes, unobserved).
    public func stop() async { stopNow() }

    /// Cancels the schedule at once.
    public func stopNow() {
        tokens.removeAll()
        schedule?.cancel()
        schedule = nil
    }

    // MARK: Checking

    /// Fire-and-forget form for buttons (Check Now, Check for Updates).
    public func checkNow() { Task { await check(userInitiated: true) } }

    /// Checks now. A user-initiated check shows `.checking` and reports failures; an automatic one keeps the last state
    /// on failure (an "Update available" never disappears because the network was down).
    @discardableResult func check(userInitiated: Bool = true) async -> UpdateState {
        guard let repository = configuration.repository else {
            if userInitiated { state = .failed(message: UpdateFailure.notConfigured.message) }
            return state
        }
        let includesPrereleases = settings[UpdateSettings.prereleases]
        if userInitiated { state = .checking }
        let task = inFlight ?? Task { await self.fetchReleases(repository: repository, includesPrereleases: includesPrereleases) }
        inFlight = task
        let result = await task.value
        if inFlight == task { inFlight = nil }

        let outcome: UpdateState
        switch result {
        case .success(let releases):
            let checkedAt = now()
            outcome = UpdateEvaluator.evaluate(releases, currentVersion: configuration.currentVersion,
                                               includesPrereleases: includesPrereleases, repository: repository,
                                               checkedAt: checkedAt)
            // GitHub answered: the next automatic check is a day away even if the answer can't be used.
            settings[UpdateSettings.lastCheck] = checkedAt
        case .failure(let failure):
            log.error("update check failed: \(String(describing: failure), privacy: .public)")
            outcome = .failed(message: failure.message)
        }
        if case .failed(let reason) = outcome, !userInitiated, state != .checking {
            // Nobody asked: keep what the user sees (an "Update available" survives a bad network or a bad answer).
            log.error("automatic update check failed, keeping the last state: \(reason, privacy: .public)")
        } else {
            state = outcome
            log.info("update check: \(String(describing: outcome), privacy: .public)")
        }
        if case .success = result { scheduleAutomatic() }
        return state
    }

    /// What survives a change of the pre-release setting:
    /// - an available stable release is still newer than the running version on either channel;
    /// - an available pre-release no longer counts once pre-releases are off;
    /// - "up to date" stays true when pre-releases are turned off (the newest stable release is never newer than the
    ///   newest release), but a newer pre-release may exist once they are on;
    /// - a failure belonged to the other request. A running check finishes and reports as usual.
    nonisolated static func state(_ state: UpdateState, afterPrereleasesChangedTo includesPrereleases: Bool) -> UpdateState {
        switch state {
        case .idle, .checking:
            state
        case .available(let version, _):
            !includesPrereleases && SemanticVersion(version)?.prerelease != nil ? .idle : state
        case .upToDate:
            includesPrereleases ? .idle : state
        case .failed:
            .idle
        }
    }

    /// Seconds until the next automatic check: a minute after launch when the last check is a day old (or never
    /// happened), else the rest of the day. A last check "in the future" (clock changed) waits one interval.
    nonisolated static func delayUntilNextCheck(lastCheck: Date?, now: Date) -> TimeInterval {
        guard let lastCheck else { return launchDelay }
        let due = lastCheck.addingTimeInterval(interval).timeIntervalSince(now)
        return min(max(launchDelay, due), interval)
    }

    // MARK: Private

    /// The last answer came from the other endpoint: keep what is still true without asking GitHub, and ask again
    /// shortly when checks are automatic (with automatic checks off, nothing is requested until the user checks).
    private func prereleasesChanged(to includesPrereleases: Bool) {
        state = Self.state(state, afterPrereleasesChangedTo: includesPrereleases)
        scheduleAutomatic(after: 2)
    }

    private func scheduleAutomatic(after delay: TimeInterval? = nil) {
        schedule?.cancel()
        schedule = nil
        guard isConfigured, settings[UpdateSettings.automatic] else { return }
        let wait = delay ?? Self.delayUntilNextCheck(lastCheck: settings[UpdateSettings.lastCheck], now: now())
        schedule = Task { [weak self, sleep] in
            do { try await sleep(wait) } catch { return }
            guard !Task.isCancelled, let self else { return }
            let before = self.settings[UpdateSettings.lastCheck]
            await self.check(userInitiated: false)
            // Success reschedules from the new `lastCheck`; a failure retries in an hour.
            if self.settings[UpdateSettings.lastCheck] == before, !Task.isCancelled {
                self.scheduleAutomatic(after: Self.retryDelay)
            }
        }
    }

    private func fetchReleases(repository: String,
                               includesPrereleases: Bool) async -> Result<[GitHubRelease], UpdateFailure> {
        let endpoint = ReleaseEndpoint(includesPrereleases: includesPrereleases)
        guard let url = endpoint.url(repository: repository) else { return .failure(.notConfigured) }
        let cached = await cache.load()
        let request = UpdateRequest.make(url: url, etag: cached?.etag(repository: repository, endpoint: endpoint))
        do {
            let (data, response) = try await transport.fetch(request)
            switch response.statusCode {
            case 200:
                let releases = try await Self.decode(data, endpoint: endpoint)
                if let etag = response.value(forHTTPHeaderField: "ETag") {
                    let entry = ReleaseCache(repository: repository, endpoint: endpoint, etag: etag, releases: releases)
                    do { try await cache.save(entry) } catch {
                        log.error("release cache not saved: \(error.localizedDescription, privacy: .public)")
                    }
                }
                return .success(releases)
            case 304:
                guard let cached, cached.etag(repository: repository, endpoint: endpoint) != nil else {
                    return .failure(.unreadable)
                }
                return .success(cached.releases)
            case 404 where endpoint == .latest:
                return try await latestNotFound(repository: repository)
            case let status:
                // On the list a 404 can only mean an unknown repository: an existing one answers `[]`.
                if status == 404 { Self.logNotFound(repository) }
                return .failure(.http(status))
            }
        } catch let failure as UpdateFailure {
            return .failure(failure)
        } catch is DecodingError {
            return .failure(.unreadable)
        } catch {
            return .failure(.offline)
        }
    }

    /// `/releases/latest` answers 404 both for a repository without a published stable release (only drafts or
    /// pre-releases, or nothing yet) and for one GitHub does not know. One request for a single release of the list
    /// tells them apart, so a wrong `OverbrightGitHubRepository` never passes for "up to date".
    private func latestNotFound(repository: String) async throws -> Result<[GitHubRelease], UpdateFailure> {
        guard let url = ReleaseEndpoint.list.url(repository: repository, perPage: 1) else {
            return .failure(.notConfigured)
        }
        let (_, response) = try await transport.fetch(UpdateRequest.make(url: url, etag: nil))
        switch response.statusCode {
        case 200:
            log.info("update check: \(repository, privacy: .public) has no stable release yet")
            return .success([])
        case let status:
            if status == 404 { Self.logNotFound(repository) }
            return .failure(.http(status))
        }
    }

    /// The repository is build configuration, not user data: logged in the clear so the cause is obvious.
    private static func logNotFound(_ repository: String) {
        log.error("update check: GitHub has no repository \(repository, privacy: .public) (HTTP 404); check \(UpdateConfiguration.repositoryInfoKey, privacy: .public) in Info.plist")
    }

    /// Release lists carry notes and assets: decode them off the main actor.
    @concurrent private nonisolated static func decode(_ data: Data, endpoint: ReleaseEndpoint) async throws -> [GitHubRelease] {
        try endpoint.decode(data)
    }
}
