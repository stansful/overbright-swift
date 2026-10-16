// OverbrightPolicy/Domain/TransferDomainResolver.swift — the transfer domain actually used. ARCHITECTURE.md §3.10, §5.2.
// Real body since WP0a.
import Foundation
import OverbrightCore

/// The domain actually used (§5.2): `.linear` only from a confirmed, still-valid record; else `.encoded`.
public nonisolated enum TransferDomainResolver {
    /// `.linear` only when `record` says linear for this mechanism, on this OS build, at a potential within ±5 %.
    public static func effectiveDomain(_ record: CalibrationRecord?, mechanism: Mechanism, machine: MachineIdentity,
                                       potential: Double?) -> TransferDomain {
        guard let r = record, r.outcome == .linear, r.mechanism == mechanism, r.osBuild == machine.osBuild,
              let p = potential, abs(p - r.potentialAtTest) <= 0.05 * r.potentialAtTest else { return .encoded }
        return .linear
    }
}
