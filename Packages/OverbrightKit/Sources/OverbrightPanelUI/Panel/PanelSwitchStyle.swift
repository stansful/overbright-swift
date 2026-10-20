// OverbrightPanelUI/Panel/PanelSwitchStyle.swift — the master switch as menu-bar panels draw theirs: the user's accent
// colour while on, the track colour while off, whether or not the panel is the key window. DESIGN.md §5.1 (the panel is
// non-activating and not key when clicked open, so a system switch would always draw its inactive grey and only the
// knob would tell on from off), §5.3 (`Toggle`, small, VoiceOver "Overbright, on"). The drawing is Design's
// `AccentSwitch` (Settings and Welcome use it too); the header shows its own title, so the switch shows no label. It
// stays a `Toggle`, so VoiceOver and the keyboard treat it as a switch.
import OverbrightDesign
import SwiftUI

/// A small switch whose "on" track is the accent colour in any window state, without its label on screen.
struct PanelSwitchStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        AccentSwitch(configuration: configuration)
    }
}
