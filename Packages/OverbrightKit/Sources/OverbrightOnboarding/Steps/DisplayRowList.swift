// OverbrightOnboarding/Steps/DisplayRowList.swift — step 2's rows (DESIGN.md §8): every row at once while they fit the
// page (the owner's two displays, and three, in English and in a 40 % longer translation, WelcomeStepFitTests); with
// more displays than fit, the rows scroll, and the scrolling is visible without touching it: the bottom edge fades
// into the window background (the next row reads as cut off there), there is room under the last row to scroll it
// clear of the fade, and the scroll bar flashes when the list appears (macOS 15 and later; overlay scroll bars stay
// hidden otherwise). The rows cross-fade when the displays change (`contentSwap`).
import OverbrightCore
import OverbrightDesign
import SwiftUI

/// Step 2's display rows.
struct DisplayRowList: View {
    let rows: [WelcomeDisplayRow]
    /// "Use extra brightness".
    let switchTitle: String
    let actions: WelcomeDisplayActions

    @Environment(\.overbright) private var theme

    var body: some View {
        ViewThatFits(in: .vertical) {
            stack
            ScrollView {
                stack.padding(.bottom, StepMetrics.scrollFade)
            }
            .scrollIndicators(.visible)
            .modifier(FlashesScrollIndicators())
            .overlay(alignment: .bottom) { fade }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    /// The rows, one under the other.
    private var stack: some View {
        VStack(spacing: Space.s) {
            ForEach(rows) { row in
                DisplayRowView(row: row, switchTitle: switchTitle, actions: actions)
                    .transition(.opacity)
            }
        }
        .animation(theme.animation(.contentSwap), value: rows)
    }

    /// The bottom edge of a scrolling list: the rows fade into the window background.
    private var fade: some View {
        let background = theme.color(.panelBackground)
        return LinearGradient(colors: [background.opacity(0), background], startPoint: .top, endPoint: .bottom)
            .frame(height: StepMetrics.scrollFade)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

/// Flashes the scroll bar once when the list appears (macOS 15 and later).
private struct FlashesScrollIndicators: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 15, *) {
            content.scrollIndicatorsFlash(onAppear: true)
        } else {
            content
        }
    }
}

#Preview("Display rows · five displays") {
    let services = WelcomePreview.services(.russianNames, adding: DisplayFixture.studioDisplayXDR.displays
                                           + DisplayFixture.proDisplayXDR.displays
                                           + DisplayFixture.sidecar.displays.filter { !$0.facts.isBuiltIn })
    DisplayRowList(rows: WelcomeDisplayRow.rows(in: services), switchTitle: "Use extra brightness",
                   actions: WelcomeDisplayActions(services: services, choices: WelcomeChoices()))
        .padding(.horizontal, WelcomeMetrics.inset)
        .frame(width: WelcomeMetrics.window.width, height: WelcomeMetrics.stageHeight)
        .overbrightThemeRoot()
}
