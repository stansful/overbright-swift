// OverbrightDesign/Components/StatusChip.swift — a per-display limit or phase chip. DESIGN.md §5.7, §12.2, §12.7.
// Seam written by WP0a (ARCHITECTURE.md §10.0): the initializer is fixed. A capsule 20 pt high on its own line under
// the readout: glyph (12 pt, semantic colour) or a small progress indicator, and the text (`chip`, `labelColor`) on a
// 15 % tint, at most the card's inner width (280 pt) with app names middle-truncated. It is a button: click, Space or
// Return opens a popover with one sentence and its actions; Esc closes it and focus returns to the chip.
import OverbrightCore
import SwiftUI

/// A chip on its own line under a card's readout; a button that opens a popover with one sentence and its actions.
public struct StatusChip: View {
    /// The chip's height.
    public static let height: CGFloat = 20
    /// The widest a chip may be (the card's inner width).
    public static let maximumWidth: CGFloat = 280

    private let model: ChipModel
    private let actions: [ChipAction]
    @Environment(\.overbright) private var theme
    @State private var isShowingPopover = false

    /// A chip for `model` whose popover offers `actions`.
    public init(_ model: ChipModel, actions: [ChipAction]) {
        self.model = model; self.actions = actions
    }

    /// The chip.
    public var body: some View {
        Button { isShowingPopover.toggle() } label: { label }
            .buttonStyle(ChipButtonStyle())
            .help(model.accessibilityLabel == model.text ? "" : model.accessibilityLabel)
            .popover(isPresented: $isShowingPopover, arrowEdge: .bottom) {
                ChipPopover(explanation: model.explanation, actions: actions) { isShowingPopover = false }
                    .overbrightThemeRoot(theme)
            }
            .accessibilityLabel(Text(verbatim: model.accessibilityLabel))
            .accessibilityHint(Text(verbatim: Self.hint()))
            .overbrightFocusRing(cornerRadius: Self.height / 2)
    }

    private var label: some View {
        HStack(spacing: Space.xs) {
            if model.showsProgress {
                ProgressView().controlSize(.mini).frame(width: 12, height: 12)
            } else {
                Image(symbol: model.symbol)
                    .font(.system(size: 12))
                    .foregroundStyle(model.color.glyph(in: theme))
            }
            Text(verbatim: model.text)
                .font(OverbrightFont.chip.font)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.horizontal, Space.m)
        .frame(height: Self.height)
        .background(model.color.tint, in: Capsule(style: .continuous))
        .frame(maxWidth: Self.maximumWidth, alignment: .leading)
        .fixedSize(horizontal: true, vertical: false)
    }

    /// "Shows why": the chip's VoiceOver hint.
    static func hint(in language: CopyLanguage = .app) -> String {
        String(localized: "Shows why", bundle: language.bundle, locale: language.locale,
               comment: "VoiceOver: hint of a status chip, which opens a popover with the reason")
    }
}

/// The chip's popover: one sentence and its actions.
private struct ChipPopover: View {
    let explanation: String
    let actions: [ChipAction]
    let dismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            Text(verbatim: explanation)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
            if !actions.isEmpty {
                HStack(spacing: Space.m) {
                    ForEach(actions) { action in
                        Button { action.perform(); dismiss() } label: { Text(verbatim: action.title) }
                            .controlSize(.small)
                    }
                }
            }
        }
        .padding(Space.l)
        .frame(width: StatusChip.maximumWidth - Space.xl, alignment: .leading)
    }
}

#Preview("Status chips") {
    VStack(alignment: .leading, spacing: Space.m) {
        if let chip = ChipModel.make(reason: .headroom, phase: .boosted, failedTries: 0,
                                     context: ChipContext(allowedGain: 1.55)) {
            StatusChip(chip, actions: [])
        }
        StatusChip(ChipModel.preparing(), actions: [])
        StatusChip(ChipModel.noExtraRange(failedTries: 2, context: ChipContext()),
                   actions: [ChipAction(title: FixAction.tryAgain.title(), perform: {})])
        if let chip = ChipModel.make(reason: .pausedApp(bundleID: "com.example.player"), phase: .idle, failedTries: 0,
                                     context: ChipContext(appName: "A Very Long Video Player Name That Truncates")) {
            StatusChip(chip, actions: [])
        }
    }
    .padding()
    .frame(width: 304)
    .overbrightThemeRoot()
}
