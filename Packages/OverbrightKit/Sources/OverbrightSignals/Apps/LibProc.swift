// OverbrightSignals/Apps/LibProc.swift — the two libproc reads Signals makes: every PID, and one PID's executable path.
// ARCHITECTURE.md §7.2 (drift attribution), §7.3 (the WindowServer by its executable, never by a name), §8.1 rule 3.
// No permission is needed, and `proc_pidpath` reads other users' processes too: the WindowServer runs as
// `_windowserver` [VERIFIED 2026-10-16, macOS 27.0.1: 922 of 923 PIDs readable, ≈ 5 ms for all of them].
// Thread: any (synchronous system calls); every caller runs them off the main actor.
import Darwin

/// Process listing through libproc.
nonisolated enum LibProc {
    /// Every PID now (empty when libproc refuses).
    static func allProcessIDs() -> [Int32] {
        let estimate = proc_listallpids(nil, 0)
        guard estimate > 0 else { return [] }
        var pids = [pid_t](repeating: 0, count: Int(estimate) + 64)
        let count = pids.withUnsafeMutableBytes { buffer in
            proc_listallpids(buffer.baseAddress, Int32(buffer.count))
        }
        guard count > 0 else { return [] }
        return pids.prefix(Int(count)).filter { $0 > 0 }
    }

    /// `proc_pidpath` of `pid`, nil when it cannot be read.
    static func executablePath(of pid: Int32) -> String? {
        var buffer = [CChar](repeating: 0, count: 4 * Int(MAXPATHLEN))
        let length = proc_pidpath(pid, &buffer, UInt32(buffer.count))
        guard length > 0 else { return nil }
        return String(decoding: buffer.prefix(Int(length)).map { UInt8(bitPattern: $0) }, as: UTF8.self)
    }
}
