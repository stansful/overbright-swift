// OverbrightCore/Platform/MachineIdentity.swift — the Mac model and OS build, read once per launch.
// ARCHITECTURE.md §3.2, §5.2, §7.5.
import Foundation

/// The Mac and OS build, for the compatibility-model list, the strategy cache key and calibration validity (§7.5).
public nonisolated struct MachineIdentity: Hashable, Codable, Sendable {
    /// `hw.model`, e.g. "Mac16,5".
    public var model: String
    /// `kern.osversion`, e.g. "26A123" (the build).
    public var osBuild: String
    /// The macOS major version (27 for macOS 27.0.1).
    public var osMajor: Int
    /// The macOS minor version.
    public var osMinor: Int
    /// The macOS patch version.
    public var osPatch: Int
    /// An identity (fakes and tests construct values directly).
    public init(model: String, osBuild: String, osMajor: Int, osMinor: Int, osPatch: Int) {
        self.model = model; self.osBuild = osBuild; self.osMajor = osMajor; self.osMinor = osMinor; self.osPatch = osPatch
    }
    /// Reads sysctl and `ProcessInfo` (read-only). Fakes and tests construct values directly.
    public static func current() -> MachineIdentity {
        let v = ProcessInfo.processInfo.operatingSystemVersion
        return MachineIdentity(model: sysctlString("hw.model") ?? "unknown", osBuild: sysctlString("kern.osversion") ?? "unknown",
                               osMajor: v.majorVersion, osMinor: v.minorVersion, osPatch: v.patchVersion)
    }
    private static func sysctlString(_ name: String) -> String? {
        var size = 0
        guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 0 else { return nil }
        var bytes = [UInt8](repeating: 0, count: size)
        guard sysctlbyname(name, &bytes, &size, nil, 0) == 0 else { return nil }
        return String(decoding: bytes.prefix { $0 != 0 }, as: UTF8.self)
    }
}
