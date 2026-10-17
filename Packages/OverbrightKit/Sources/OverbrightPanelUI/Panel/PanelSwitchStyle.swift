// OverbrightPanelUI/Panel/PanelSwitchStyle.swift — the master switch as menu-bar panels draw theirs: the user's accent
// colour while on, the track colour while off, whether or not the panel is the key window. DESIGN.md §5.1 (the panel is
// non-activating and not key when clicked open, so a system switch would always draw its inactive grey and only the
// knob would tell on from off), §5.3 (`Toggle`, small, VoiceOver "Overbright, on"), §2.1 (system accent for system
// controls; Increase Contrast adds a full-strength edge), §3.1 (`press`), §2.3 (the hit area). It stays a `Toggle`, so
// VoiceOver and the keyboard treat it as a switch.
import OverbrightDesign
import SwiftUI

/// A small switch whose "on" track is the accent colour in any window state.
struct PanelSwitchStyle: ToggleStyle {
    /// The track (the size of a small system switch).
    static let trackSize = CGSize(width: 30, height: 17)
    /// The knob's inset inside the track.
    static let knobInset: CGFloat = 2

    func makeBody(configuration: Configuration) -> some View {
        PanelSwitch(configuration: configuration)
    }
}

private struct PanelSwitch: View {
    let configuration: ToggleStyleConfiguration
    @Environment(\.overbright) private var theme
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        let size = PanelSwitchStyle.trackSize
        let knob = size.height - 2 * PanelSwitchStyle.knobInset
        let isOn = configuration.isOn
        Button { configuration.isOn.toggle() } label: {
            ZStack(alignment: isOn ? .trailing : .leading) {
                Capsule(style: .continuous)
                    .fill(isOn ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(theme.color(.track)))
                Capsule(style: .continuous)
                    .strokeBorder(theme.color(.cardStroke), lineWidth: StrokeWidth.regular)
                    .opacity(theme.palette == .highContrast ? 1 : 0)
                Circle()
                    .fill(theme.color(.thumb))
                    .frame(width: knob, height: knob)
                    .overbrightShadow(.thumb)
                    .padding(PanelSwitchStyle.knobInset)
            }
            .frame(width: size.width, height: size.height)
            .frame(minWidth: HitTarget.minimum.width, minHeight: HitTarget.minimum.height)
            .contentShape(Rectangle())
            .animation(theme.animation(.press), value: isOn)
        }
        .buttonStyle(.plain)
        .opacity(isEnabled ? 1 : 0.5)
        .accessibilityRepresentation { Toggle(isOn: configuration.$isOn) { configuration.label } }
    }
}
