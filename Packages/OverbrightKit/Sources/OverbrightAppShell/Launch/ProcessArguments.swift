// OverbrightAppShell/Launch/ProcessArguments.swift — the launch arguments of another process of the same user, read with
// `sysctl(KERN_PROCARGS2)` (no permission; another user's process is not readable and reads as nil). ARCHITECTURE.md
// §7.4, D27: the single-instance check ignores an instance launched with `--qa-simulate`, which runs on the simulated
// ports and writes no table (a Release build refuses the switch, so such an instance is always a Debug QA run).
import Darwin
import Foundation

/// Reads another process's arguments.
enum ProcessArguments {
    /// The arguments `pid` was started with (argv, the executable path first), or nil when they cannot be read.
    static func of(_ pid: pid_t) -> [String]? {
        var mib: [Int32] = [CTL_KERN, KERN_PROCARGS2, pid]
        var size = 0
        guard sysctl(&mib, 3, nil, &size, nil, 0) == 0, size > 0 else { return nil }
        var buffer = [UInt8](repeating: 0, count: size)
        guard sysctl(&mib, 3, &buffer, &size, nil, 0) == 0 else { return nil }
        return parse(Array(buffer.prefix(size)))
    }

    /// `KERN_PROCARGS2`'s layout: a 32-bit argc, the executable path, NUL padding, then argc NUL-terminated
    /// arguments (the environment follows). Nil for a malformed buffer.
    static func parse(_ bytes: [UInt8]) -> [String]? {
        guard bytes.count > 4 else { return nil }
        let argc = Int(bytes[0]) | Int(bytes[1]) << 8 | Int(bytes[2]) << 16 | Int(bytes[3]) << 24
        guard argc > 0 else { return nil }
        var index = 4
        while index < bytes.count, bytes[index] != 0 { index += 1 }            // the executable path
        while index < bytes.count, bytes[index] == 0 { index += 1 }            // its padding
        var arguments: [String] = []
        while arguments.count < argc, index < bytes.count {
            let start = index
            while index < bytes.count, bytes[index] != 0 { index += 1 }
            arguments.append(String(decoding: bytes[start..<index], as: UTF8.self))
            index += 1
        }
        return arguments.count == argc ? arguments : nil
    }
}
