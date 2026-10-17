// OverbrightSignals/FullScreen/FullScreenTracker.swift — runs the full-screen check and publishes its outcome.
// ARCHITECTURE.md §6.5, §7.1 ("Full screen", "Playing video"), §7.3, §10.8.
// A check is requested by events (Space change, app activation, a regular app's termination, screen parameters, wake)
// and, while boosted, by the 2 s re-check; requests are debounced 0.6 s (Space animations produce transient window
// lists). One check reads the window list off the main actor, then on the main actor the screens (and whether they have
// separate Spaces), which of the windows' owners are regular apps (`SignalsPlatform.regularProcessIDs(among:)`: a few
// lookups instead of mapping every running app, whose dynamic properties AppKit re-fetches from LaunchServices once the
// list changed: ≈ 7.5 → 0.6 ms of CPU per check), the frontmost app (the only app mapped in full, for the games
// category, read once per bundle) and the display-sleep assertions, applies the sticky menu-bar
// absence and `FullScreenDetector.evaluate`, and publishes full-screen displays, full-screen-video displays and the
// frontmost app (its displays, `isPlaying`, `isGame`) in ONE outcome, so the snapshot never shows a half-updated front.
// When a sticky absence masks a present menu bar, one more check runs as the mask expires. Nothing is pending while no
// request is. The WindowServer's PID, once a snapshot found it, is kept for the session and handed to every later read
// (`WindowListSnapshot`: no lookup per check).
// Thread: main.
import Foundation
import OverbrightCore

/// The debounced full-screen and frontmost-app check.
final class FullScreenTracker {
    /// Debounce of every request (Space animations settle first).
    static let debounce: Duration = .milliseconds(600)

    /// One published outcome.
    struct Outcome: Hashable, Sendable {
        /// `SystemSnapshot.fullScreenDisplays`.
        var fullScreenDisplays: Set<DisplayKey>
        /// `SystemSnapshot.fullScreenVideoDisplays`.
        var fullScreenVideoDisplays: Set<DisplayKey>
        /// `SystemSnapshot.frontmost`.
        var frontmost: FrontmostApp?
    }

    /// Receives every completed check (set by the owner once it exists).
    var onOutcome: (@MainActor (Outcome) -> Void)?
    private let platform: any SignalsPlatform
    private let time: any TimeSource
    private let deadline: DeadlineTimer
    private var menuBar = MenuBarPresence()
    private var games: [URL: Bool] = [:]
    /// The WindowServer's PID, fixed for the login session (kept across stop and start).
    private(set) var windowServerPID: Int32?
    private var isChecking = false
    private var needsAnotherCheck = false

    /// A tracker over `platform`.
    init(platform: any SignalsPlatform, time: any TimeSource) {
        self.platform = platform; self.time = time
        deadline = DeadlineTimer(time: time)
    }

    /// Requests are honoured.
    private(set) var isEnabled = false
    /// A debounced check is waiting.
    var isPending: Bool { deadline.isPending }

    /// Starts honouring requests.
    func start() { isEnabled = true }

    /// Drops any pending check and the menu-bar history.
    func stop() {
        isEnabled = false
        deadline.cancel()
        menuBar = MenuBarPresence()
        games = [:]
    }

    /// Requests a check 0.6 s from now (a later request moves it).
    func request() {
        guard isEnabled else { return }
        deadline.schedule(after: Self.debounce) { [weak self] in
            Task { await self?.check() }
        }
    }

    /// Runs one check now (a check already in flight runs another one after it).
    func check() async {
        guard isEnabled else { return }
        if isChecking { needsAnotherCheck = true; return }
        isChecking = true
        let list = await platform.windowList(windowServerPID: windowServerPID)
        isChecking = false
        if let pid = list.windowServerPID { windowServerPID = pid }
        guard isEnabled else { return }
        let outcome = evaluate(list)
        onOutcome?(outcome.outcome)
        if needsAnotherCheck {
            needsAnotherCheck = false
            request()
        } else if let resolvesAt = outcome.resolvesAt {
            deadline.schedule(at: resolvesAt) { [weak self] in Task { await self?.check() } }
        }
    }

    // MARK: Private

    private func evaluate(_ list: WindowListSnapshot) -> (outcome: Outcome, resolvesAt: MonotonicInstant?) {
        let screens = platform.screens()
        let front = platform.frontmostApplication()
        let holders = platform.displaySleepHolders()
        let ignored = Set([platform.ownProcessID] + [platform.dockProcessID()].compactMap { $0 })
        // The detector asks whether an owner is regular only for this list's layer-0 windows that are not ignored
        // (`FullScreenDetector.counts`), so the answer for these owners alone decides exactly what the whole set did.
        let owners = Set(list.windows.lazy.filter { $0.layer == 0 }.map(\.ownerPID)).subtracting(ignored)
        let context = FullScreenDetector.Context(frontmostPID: front?.processID, ignoredPIDs: ignored,
                                                 regularPIDs: platform.regularProcessIDs(among: owners),
                                                 displaySleepHolders: holders ?? [])
        let separateSpaces = platform.screensHaveSeparateSpaces()
        let observed = FullScreenDetector.observedMenuBar(windows: list.windows, displays: screens,
                                                          windowServerPID: list.windowServerPID,
                                                          separateSpaces: separateSpaces)
        let effective = menuBar.update(observed: observed, at: time.now)
        let result = FullScreenDetector.evaluate(windows: list.windows, displays: screens, context: context,
                                                 menuBarPresent: effective.present, separateSpaces: separateSpaces)
        let frontmost = front.map { app in
            FrontmostApp(bundleID: app.bundleID, processID: app.processID, displays: result.frontmostDisplays,
                         isPlaying: holders.map { $0.contains(app.processID) }, isGame: isGame(app))
        }
        let outcome = Outcome(fullScreenDisplays: result.fullScreenDisplays,
                              fullScreenVideoDisplays: result.fullScreenVideoDisplays, frontmost: frontmost)
        return (outcome, effective.resolvesAt)
    }

    /// The games category of `app`'s bundle, read once per bundle.
    private func isGame(_ app: RunningAppInfo) -> Bool {
        guard let url = app.bundleURL else { return false }
        if let cached = games[url] { return cached }
        let game = GameCategory.isGame(category: platform.appCategory(bundleURL: url), bundleID: app.bundleID)
        games[url] = game
        return game
    }
}
