// OverbrightDesign/Components/AccentSwitch.swift — Overbright's switch, drawn in shapes rather than by the system: the
// user's accent colour while on, the track colour while off, whether or not its window is key. DESIGN.md §5.1 (the
// panel is non-activating, so a system switch would always draw its inactive grey), §5.3 (`Toggle`, small, VoiceOver
// "Overbright, on"), §7.2, §2.1 (system accent; Increase Contrast adds a full-strength edge), §3.1 (`press`), §2.3 (the
// hit area), §17 (energy E3, 2026-10-21: the system `.switch`'s Liquid Glass knob renders with in-process Metal, whose
// state stays after the window closes and wakes the app every 3 s; Settings and Welcome use this one too). It stays a
// `Toggle`, so VoiceOver and the keyboard treat it as a switch: one element, Space toggles it.
import SwiftUI

/// A small switch with its label in front: in a grouped `Form` the label leads and the switch trails, as a system
/// switch's do; `.labelsHidden()` leaves the switch alone. One accessibility element, a switch named by the label.
public struct AccentSwitchStyle: ToggleStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        LabeledContent {
            AccentSwitch(configuration: configuration)
        } label: {
            configuration.label
        }
        .accessibilityRepresentation { Toggle(isOn: configuration.$isOn) { configuration.label } }
    }
}

extension ToggleStyle where Self == AccentSwitchStyle {
    /// Overbright's switch (`AccentSwitchStyle`), in place of the system `.switch`.
    public static var accentSwitch: AccentSwitchStyle { AccentSwitchStyle() }
}

/// The switch alone, without its label on screen (a host that shows its own, as the panel's header does); VoiceOver
/// reads it as a switch named by the label.
public struct AccentSwitch: View {
    /// The track (the size of a small system switch).
    public static let trackSize = CGSize(width: 30, height: 17)
    /// The knob's inset inside the track.
    static let knobInset: CGFloat = 2

    private let configuration: ToggleStyleConfiguration
    @Environment(\.overbright) private var theme
    @Environment(\.isEnabled) private var isEnabled

    /// The switch of a `ToggleStyle`'s `configuration`.
    public init(configuration: ToggleStyleConfiguration) {
        self.configuration = configuration
    }

    public var body: some View {
        let size = Self.trackSize
        let knob = size.height - 2 * Self.knobInset
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
                    .padding(Self.knobInset)
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
