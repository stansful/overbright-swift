// OverbrightPolicy/Domain/IgnoredTableWriteModels.swift — Macs where table writes change nothing. ARCHITECTURE.md
// §3.10, §7.5, D4. Real body since WP0a (as `CompatibilityModels`; renamed when Compatibility mode was removed).
import OverbrightCore

/// Macs where table writes succeed, read back correctly and change nothing on screen (§7.5). Updatable list; only
/// diagnostics read it (`machine.tableWritesIgnored`), since no other mechanism remains to fall back to.
public nonisolated enum IgnoredTableWriteModels {
    /// `hw.model` values: the MacBook Neo (Mac17,5) and the M5 Pro/Max MacBook Pro (Mac17,6–17,9).
    public static let models: Set<String> = ["Mac17,5", "Mac17,6", "Mac17,7", "Mac17,8", "Mac17,9"]
    /// True on those models with macOS 26.3 or later.
    public static func tableWritesIgnored(_ machine: MachineIdentity) -> Bool {
        models.contains(machine.model) && (machine.osMajor, machine.osMinor) >= (26, 3)
    }
}
