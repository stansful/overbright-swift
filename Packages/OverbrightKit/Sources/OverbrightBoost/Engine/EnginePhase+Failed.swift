// OverbrightBoost/Engine/EnginePhase+Failed.swift — a convenience on Core's engine phase. ARCHITECTURE.md §4.2.
import OverbrightCore

extension EnginePhase {
    /// `failed(_)`, whatever the cause.
    var isFailed: Bool {
        if case .failed = self { return true }
        return false
    }
}
