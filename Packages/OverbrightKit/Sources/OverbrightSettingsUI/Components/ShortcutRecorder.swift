// OverbrightSettingsUI/Components/ShortcutRecorder.swift — the recorder control (DESIGN.md §7.6): the key caps of the
// binding (or "Record Shortcut"), recording state and a clear button. Click to record; Esc cancels; Delete clears; one
// recorder at a time (`ShortcutRecording`). Recording uses a local key monitor of this window only: no Accessibility
// permission. While it listens, every Overbright hot key pauses (`ShortcutCenter.setRecording`), so a combination that
// is already bound records instead of running. Ported from Cranny's ShortcutRecorder (the owner's MIT code).
import AppKit
import Foundation
import OverbrightCore
import OverbrightDesign
import SwiftUI

/// Records a key combination.
struct ShortcutRecorder: View {
    /// The shortcut's name (VoiceOver).
    let title: String
    /// The key caps to show (nil = no shortcut).
    let keys: String?
    /// Recording started (true) or ended (false), however it ended: keys, a click elsewhere, the window closing.
    var listening: (Bool) -> Void = { _ in }
    /// A recorded combination (nil = cleared).
    let record: (KeyCombo?) -> Void
    @State private var isRecording = false
    @State private var hint: String?
    @State private var monitor: (any NSObjectProtocol)?
    @State private var keyMonitor: Any?
    @State private var recordingID = UUID()

    var body: some View {
        HStack(spacing: Space.s) {
            Button {
                isRecording ? stop() : start()
            } label: {
                Text(verbatim: label)
                    .monospacedDigit()
                    .frame(minWidth: 96)
            }
            .buttonStyle(.bordered)
            .tint(isRecording ? .accentColor : nil)
            .help(Text(verbatim: hint ?? Self.tooltip))
            .accessibilityLabel(Text("Shortcut for \(title)", bundle: .module,
                                     comment: "VoiceOver: label of a shortcut recorder in Settings; the argument is the shortcut’s name"))
            .accessibilityValue(Text(verbatim: keys ?? Self.offTitle))
            .accessibilityHint(Text("Press to record new keys.", bundle: .module,
                                    comment: "VoiceOver: hint of a shortcut recorder in Settings"))
            Button {
                stop()
                record(nil)
            } label: {
                Image(symbol: .xmark)
            }
            .buttonStyle(.borderless)
            .opacity(keys == nil || isRecording ? 0 : 1)
            .disabled(keys == nil || isRecording)
            .accessibilityLabel(Text("Clear \(title)", bundle: .module,
                                     comment: "VoiceOver: the clear button of a shortcut recorder in Settings; the argument is the shortcut’s name"))
        }
        .onDisappear(perform: stop)
    }

    private var label: String {
        if isRecording {
            return hint ?? String(localized: "Type Shortcut", bundle: .module,
                                  comment: "Settings ▸ Shortcuts: the recorder button while it waits for keys (title case)")
        }
        return keys ?? String(localized: "Record Shortcut", bundle: .module,
                              comment: "Settings ▸ Shortcuts: the recorder button without a shortcut (title case)")
    }

    /// "Off": VoiceOver's value of a recorder without a shortcut.
    static var offTitle: String {
        String(localized: "Off", bundle: .module, comment: "VoiceOver: value of a shortcut recorder without a shortcut")
    }

    private static var tooltip: String {
        String(localized: "Click, then press the new keys. Esc cancels, Delete clears the shortcut.", bundle: .module,
               comment: "Settings ▸ Shortcuts: tooltip of a shortcut recorder")
    }

    private func start() {
        ShortcutRecording.shared.begin(recordingID) { stop() }
        hint = nil
        isRecording = true
        listening(true)
        // A local monitor sees key presses sent to this app's windows only (no Accessibility permission).
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            MainActor.assumeIsolated { handle(event) } ? nil : event                // local monitors run on main
        }
        // Clicking elsewhere or leaving the window ends recording.
        monitor = NotificationCenter.default.addObserver(forName: NSWindow.didResignKeyNotification, object: nil,
                                                         queue: .main) { _ in
            MainActor.assumeIsolated { stop() }                                     // queue: .main
        }
    }

    /// Returns true when the event was consumed.
    private func handle(_ event: NSEvent) -> Bool {
        guard isRecording else { return false }
        switch KeyComboFormatter.outcome(keyCode: event.keyCode,
                                         modifiers: KeyComboFormatter.modifiers(event.modifierFlags)) {
        case .cancel: stop()
        case .clear: stop(); record(nil)
        case .combo(let combo): stop(); record(combo)
        case .needsModifier:
            hint = String(localized: "Add Command, Control or Option", bundle: .module,
                          comment: "Settings ▸ Shortcuts: recorder hint after a key without modifiers (the key names as macOS writes them)")
            NSSound.beep()
        }
        return true
    }

    private func stop() {
        ShortcutRecording.shared.end(recordingID)
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        if let monitor { NotificationCenter.default.removeObserver(monitor) }
        keyMonitor = nil
        monitor = nil
        if isRecording { listening(false) }                                        // before `record` re-registers
        isRecording = false
        hint = nil
    }
}

#Preview("Recorder") {
    Form {
        LabeledContent {
            ShortcutRecorder(title: "Brighter", keys: nil) { _ in }
        } label: {
            Text(verbatim: "Brighter")
        }
    }
    .formStyle(.grouped)
    .frame(width: 520, height: 120)
}
