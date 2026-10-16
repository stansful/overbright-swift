// Controls/ControlHandOff.swift — the extension's path of `BoostControlIntent` (macOS 26, when the system performs
// the control's intent in the extension). ARCHITECTURE.md §7.7; D25.
// Opens `overbright://control?set=on|off` (with the token the app keeps for `on`) without activating the app;
// LaunchServices delivers it to the running app or launches it, and the app still applies the policy. Then it waits up
// to 1 s for the published state, because the system reads the control's value when the intent returns. Darwin and
// distributed notifications cannot carry the request: they cannot launch the app, and a sandboxed sender cannot attach
// data.
import AppKit
import OverbrightChannel

/// Hands the toggle's new value to the app.
enum ControlHandOff {
    /// Asks the app to turn extra brightness on or off and waits briefly for its published state.
    static func request(on: Bool) async {
        let token = on ? BoostChannel.token(in: PreferencesChannelStore.app) : nil
        guard let url = URLRoute.control(on: on, token: token).url else { return }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false
        do {
            _ = try await NSWorkspace.shared.open(url, configuration: configuration)
        } catch {
            return
        }
        let word = NotifyStateWord()
        _ = await BoostChannel.waitForState(on: on, read: { BoostChannel.unpack(word.read()) },
                                            sleep: { try await Task.sleep(for: $0) })
    }
}
