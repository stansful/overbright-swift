// OverbrightSettingsUI/Components/ShortcutRecording.swift — at most one shortcut recorder listens at a time (DESIGN.md
// §7.6). Each recorder installs its own key monitor, so two listening at once would race for the next key press;
// starting one stops the one before. Ported from Cranny's ShortcutRecorder.swift (the owner's MIT code).
import Foundation

/// The recorder that is listening, if any.
final class ShortcutRecording {
    /// The app's one coordinator.
    static let shared = ShortcutRecording()
    private var active: (id: UUID, stop: @MainActor () -> Void)?

    /// The listening recorder's id.
    var activeID: UUID? { active?.id }

    /// `id` starts listening; another listening recorder is stopped first.
    func begin(_ id: UUID, stop: @escaping @MainActor () -> Void) {
        if let previous = active, previous.id != id {
            active = nil
            previous.stop()
        }
        active = (id, stop)
    }

    /// `id` stopped listening (a no-op if another recorder took over).
    func end(_ id: UUID) {
        if active?.id == id { active = nil }
    }
}
