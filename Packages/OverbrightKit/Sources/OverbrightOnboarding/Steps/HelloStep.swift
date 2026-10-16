// OverbrightOnboarding/Steps/HelloStep.swift — Welcome step 1 Hello (DESIGN.md §8, §0 #12; D16): the before/after card
// on the stage (a sample page at Standard on the left and at Bright room on the right of a draggable divider, our own
// EDR content in this window only, Design's `EDRPreviewSurface`), or a static illustration when no display can show
// extra brightness. Nothing outside the card changes: no table is written, nothing turns on. The card registers with
// `OwnEDRSurfaces` on the window's display while it shows EDR content (`EDRCardHold`), and pauses while the window is
// hidden (it draws its SDR stand-in then, so it holds no extra range nobody sees). Seeded by WP0b with its headline;
// built by WP12 (ARCHITECTURE.md §10.14).
import Foundation
import OverbrightCore
import OverbrightDesign
import SwiftUI

/// Welcome step 1 Hello.
struct HelloStep: View {
    let session: WelcomeSession
    /// Whether the window can be seen (the card pauses while it cannot).
    let isWindowVisible: Bool
    /// The step's words (tests pass longer ones).
    var copy = Copy.localized

    @State private var divider = 0.5
    @State private var windowDisplay: DisplayKey?
    @State private var hold: EDRCardHold?

    /// The step's words.
    struct Copy {
        /// "Use your display’s extra range".
        var title: String
        /// The paragraph under the headline.
        var message: String
        /// The caption under the card.
        var caption: String
        /// The sentence when no display has extra range.
        var noneCapable: String

        /// The words in the current language.
        static var localized: Copy { localized(in: .module) }

        /// The words from `bundle` (tests pick a language; a bundle without translations gives the English keys).
        static func localized(in bundle: Bundle) -> Copy {
            Copy(title: String(localized: "Use your display’s extra range", bundle: bundle,
                               comment: "Welcome ▸ Hello: headline"),
                 message: String(localized: "Your display can show light brighter than ordinary white. Overbright lets everyday content use that range, so the screen stays readable in a bright room or in sunlight. For the most light, turn your display brightness all the way up first; Overbright adds to it. Drag the divider to compare.",
                                 bundle: bundle, comment: "Welcome ▸ Hello: body under the headline"),
                 caption: String(localized: "Only this card is brighter. It’s a preview: the real result depends on your display.",
                                 bundle: bundle,
                                 comment: "Welcome ▸ Hello: caption under the before/after card (only the card is brighter)"),
                 noneCapable: String(localized: "None of your displays has extra range right now. The next step shows why.",
                                     bundle: bundle,
                                     comment: "Welcome ▸ Hello: shown instead of the card when no display can show extra brightness"))
        }

        /// Every string passed through `transform` (the fit tests' pseudo-long locale).
        func map(_ transform: (String) -> String) -> Copy {
            Copy(title: transform(title), message: transform(message), caption: transform(caption),
                 noneCapable: transform(noneCapable))
        }
    }

    var body: some View {
        let services = session.services
        let rows = WelcomeDisplayRow.rows(in: services)
        let card = WelcomeCard.make(rows: rows, windowDisplay: windowDisplay)
        let simulated = WelcomeCard.simulates(services)
        let held = card.heldDisplay(windowDisplay: windowDisplay, isWindowVisible: isWindowVisible, simulated: simulated)
        StepLayout {
            StepStage {
                HelloStage(card: card, divider: $divider, simulated: simulated || !isWindowVisible,
                           illustration: rows.first?.isBuiltIn == true ? .laptopComputer : .display)
            }
            .background { if !simulated { WindowScreenReader { windowDisplay = $0 } } }
        } content: {
            HelloLower(copy: copy, card: card)
        }
        .welcomeStepRoot()
        .onAppear {
            let hold = hold ?? EDRCardHold(surfaces: services.ownEDRSurfaces)
            self.hold = hold
            hold.hold(held)
        }
        .onChange(of: held) { _, display in hold?.hold(display) }
        .onDisappear { hold?.release() }
    }
}

/// Step 1's stage: the card, or the illustration.
struct HelloStage: View {
    let card: WelcomeCard
    @Binding var divider: Double
    /// Draw the card's SDR stand-in (simulated run, or the window is hidden).
    let simulated: Bool
    /// The glyph shown instead of the card: the laptop when the first display is built in.
    var illustration = OverbrightSymbol.display

    var body: some View {
        switch card {
        case .preview(_, let gain):
            EDRPreviewSurface(gain: gain, divider: $divider, simulated: simulated)
                .frame(maxWidth: StepMetrics.cardWidth, maxHeight: StepMetrics.stageContentHeight)
        case .checking, .noneCapable:
            Image(symbol: illustration)
                .font(.system(size: StepMetrics.illustration, weight: .thin))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
    }
}

/// Step 1's copy under the stage.
struct HelloLower: View {
    let copy: HelloStep.Copy
    let card: WelcomeCard

    var body: some View {
        StepHeader(title: copy.title, message: copy.message)
            .welcomeStepHeader()
        if let caption {
            Text(verbatim: caption)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// The caption under the card, the sentence that explains a missing card, or nothing while displays are read.
    var caption: String? {
        switch card {
        case .preview: copy.caption
        case .noneCapable: copy.noneCapable
        case .checking: nil
        }
    }
}

#Preview("1 Hello") {
    HelloStep(session: WelcomeSession(services: WelcomePreview.services(), initialStep: .hello) { _ in },
              isWindowVisible: true)
        .frame(width: WelcomeMetrics.window.width, height: 400)
}

#Preview("1 Hello · no extra range") {
    HelloStep(session: WelcomeSession(services: WelcomePreview.services(.lcdOnly), initialStep: .hello) { _ in },
              isWindowVisible: true)
        .frame(width: WelcomeMetrics.window.width, height: 400)
}
