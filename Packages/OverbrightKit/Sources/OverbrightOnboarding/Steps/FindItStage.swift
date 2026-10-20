// OverbrightOnboarding/Steps/FindItStage.swift — step 4's stage (DESIGN.md §8): a strip of menu bar with Overbright's
// symbol at its trailing end (the menu bar extras' side; it follows the layout direction), the caption "Click for the
// panel, right-click for the menu", and one row per registered shortcut: its live key caps (Design's `KeyCap`, text
// from `ShortcutCenter.displayString`) and what it does; VoiceOver reads what it does as the label and the key caps as
// the value. While Back to Standard has no shortcut (a first run: none ships bound, D17), a link under them reads "You
// can set keyboard shortcuts in Settings ▸ Shortcuts." and opens Settings ▸ Shortcuts there. The sun is `sun.max`, the
// status symbol's own fallback (§4.1): the code-drawn symbol belongs to the shell.
import OverbrightCore
import OverbrightDesign
import SwiftUI

/// Step 4's stage.
struct FindItStage: View {
    /// The registered shortcuts, in order.
    let shortcuts: [FindItShortcut]
    let copy: FindItStep.Copy
    /// Opens Settings ▸ Shortcuts (the link shown while Back to Standard has no shortcut).
    var openShortcutSettings: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: Space.l) {
            VStack(alignment: .trailing, spacing: Space.s) {
                MenuBarStrip()
                Text(verbatim: copy.menuBar)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.trailing)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !shortcuts.isEmpty {
                Grid(alignment: .leading, horizontalSpacing: Space.m, verticalSpacing: Space.s) {
                    ForEach(shortcuts) { shortcut in
                        GridRow {
                            KeyCap(shortcut.keys)
                                .frame(minWidth: StepMetrics.keyCapColumn, alignment: .trailing)
                                .accessibilityHidden(true)
                            Text(verbatim: copy.title(of: shortcut.id))
                                .font(.callout)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(Text(verbatim: copy.title(of: shortcut.id)))
                        .accessibilityValue(Text(verbatim: shortcut.keys))
                    }
                }
            }
            if FindItShortcut.offersShortcutSettings(shortcuts) {
                Button(action: openShortcutSettings) {
                    Text(verbatim: copy.setShortcuts)
                        .font(.callout)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .buttonStyle(OverbrightLinkButtonStyle())
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

/// A strip of menu bar with Overbright's symbol highlighted, as when its panel is open.
private struct MenuBarStrip: View {
    var body: some View {
        HStack(spacing: Space.l) {
            Spacer(minLength: 0)
            Image(symbol: .sunMax)
                .font(.body.weight(.medium))
                .frame(width: StepMetrics.menuBarHighlight.width, height: StepMetrics.menuBarHighlight.height)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
        }
        .padding(.horizontal, Space.s)
        .frame(height: StepMetrics.menuBarHeight)
        .stepCard(cornerRadius: Radius.control)
        .accessibilityHidden(true)
    }
}

#Preview("Find it stage") {
    let services = WelcomePreview.services()
    FindItStage(shortcuts: FindItShortcut.rows(services.shortcuts), copy: FindItStep.Copy.localized)
        .padding(WelcomeMetrics.inset)
        .frame(width: WelcomeMetrics.window.width, height: WelcomeMetrics.stageHeight)
        .overbrightThemeRoot()
}
