// OverbrightDesign/Components/BoostSlider+Accessibility.swift — the words VoiceOver and the help tags give from the
// level slider. DESIGN.md §5.5 (VoiceOver, disabled halves), §12.7. One adjustable element: label "Level, ‹display
// name›", the value in canonical units with "times" and "percent" spelled out, the custom content "Extra range", and a
// hint that says why a half is disabled; each half's help tag covers that half only.
import Foundation
import OverbrightCore
import OverbrightPolicy
import SwiftUI

extension BoostSlider {
    /// "Level, ‹display name›".
    nonisolated static func label(_ name: String, in language: CopyLanguage = .app) -> String {
        let name = name.overbrightIsolated
        return String(localized: "Level, \(name)", bundle: language.bundle, locale: language.locale,
                      comment: "VoiceOver: label of a display’s level slider; the argument is the display’s name")
    }

    /// "Extra range": the label of the slider's VoiceOver custom content.
    nonisolated static func extraRangeLabel(in language: CopyLanguage = .app) -> String {
        String(localized: "Extra range", bundle: language.bundle, locale: language.locale,
               comment: "VoiceOver: label of the slider’s custom content that says how much extra range macOS allows")
    }

    /// The VoiceOver value when the host gives no spoken form: the spoken form of `shown` when it is the canonical
    /// text of `level` ("Bright room · ≈ ×1.29" → "Bright room, about 1.29 times, not calibrated"), else `shown`
    /// itself (a guard's reason, or the host's own words).
    nonisolated static func spoken(_ shown: String, at level: LevelPosition, top: Double, presets: [LevelPreset],
                                   in language: CopyLanguage = .app) -> String {
        for isEstimate in [false, true] {
            let canonical = ValueText.forLevel(level, top: top, presets: presets, isEstimate: isEstimate, in: language)
            if canonical.text == shown { return canonical.accessibilityText }
        }
        return shown
    }

    /// The "Extra range" content: the host's (`given`), or what macOS allows now while extra light is on screen with
    /// a reading ("macOS allows ×1.55 now.", without the Peak sentence the host can add); nil otherwise.
    nonisolated static func extraRange(_ model: BoostSliderModel, given: ValueText?) -> ValueText? {
        if let given { return given }
        guard model.boostFillIsWarm, let allowed = model.allowedNow else { return nil }
        return ValueText.extraRange(allowed: allowed, peak: nil)
    }

    /// The help tags of the two halves, each shown over its own half only (DESIGN.md §5.5): a disabled dim half says
    /// why (`dimReason`); the boost half says why it is unavailable, or what macOS allows now while the allowed-now
    /// marker shows. Nil where a half has nothing to say.
    nonisolated static func helpTags(_ model: BoostSliderModel, dimReason: String?,
                                     extraRange: ValueText?) -> (dim: String?, boost: String?) {
        let dim = model.dimEnabled ? nil : dimReason
        if case let .unavailable(reason) = model.boostHalf { return (dim, reason) }
        return (dim, model.markerLevel != nil ? extraRange?.text : nil)
    }

    /// VoiceOver's hint: why a half is disabled. The help tags sit inside the one accessibility element, so VoiceOver
    /// hears the reasons here; empty when both halves work.
    nonisolated static func disabledHint(_ model: BoostSliderModel, dimReason: String?,
                                         in language: CopyLanguage = .app) -> String {
        var boost = ""
        if case let .unavailable(reason) = model.boostHalf { boost = reason }
        let dim = model.dimEnabled ? "" : dimReason ?? ""
        return CopyFormat.sentences(boost, dim, in: language)
    }
}

/// VoiceOver's "Extra range" content of the slider, when there is a reading.
struct BoostSliderExtraRange: ViewModifier {
    /// The content; nil adds none.
    let text: ValueText?

    func body(content: Content) -> some View {
        if let text {
            content.accessibilityCustomContent(Text(verbatim: BoostSlider.extraRangeLabel()),
                                               Text(verbatim: text.accessibilityText))
        } else {
            content
        }
    }
}
