// OverbrightSignals/Apps/AppEventFilter.swift — posts each app launch and termination once. ARCHITECTURE.md §7.1
// ("Active Space, app activation, launch, termination"), §7.2.
// A regular app is reported twice, by the workspace's did-launch and did-terminate notifications and by the running
// list's KVO, in either order; an agent or accessory app only by KVO (`RunningAppsObserver`). A launch is posted when
// the process was not known to run (the list at `SignalsMonitor.start()` seeds it); a termination unless the same
// process's termination was just posted, so an unknown process's termination is never swallowed (the engine's 50 ms
// drift check and the end of a continuation or attributed trip hang on it). The termination history is short: the
// two reports of one termination arrive within a few run-loop turns, and a duplicate that slips through costs one
// extra drift check.
// Thread: any (a value type; `SignalsMonitor` keeps it on the main actor).

/// Which launches and terminations were already posted.
nonisolated struct AppEventFilter: Hashable, Sendable {
    /// Recent terminations kept to recognise the second report of one.
    static let terminationHistory = 32

    /// Processes known to run.
    private(set) var running: Set<Int32>
    /// The latest posted terminations, oldest first.
    private(set) var ended: [Int32] = []

    /// A filter that knows `running` already runs (their launches are not posted).
    init(running: Set<Int32> = []) { self.running = running }

    /// Whether to post `processID`'s launch: true the first time it is reported running.
    mutating func shouldPostLaunch(_ processID: Int32) -> Bool {
        ended.removeAll { $0 == processID }                    // a reused process ID starts over
        return running.insert(processID).inserted
    }

    /// Whether to post `processID`'s termination: false only for the second report of one just posted.
    mutating func shouldPostTermination(_ processID: Int32) -> Bool {
        running.remove(processID)
        guard !ended.contains(processID) else { return false }
        ended.append(processID)
        if ended.count > Self.terminationHistory { ended.removeFirst(ended.count - Self.terminationHistory) }
        return true
    }
}
