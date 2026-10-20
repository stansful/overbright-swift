// OverbrightSettingsUI/Calibration/CalibrationView.swift — the content of the calibration window (DESIGN.md §9): a
// black surround filling the display under test, the four 100 × 100 pt squares (85, 90, 95 and 100 % gray, Design's
// `StepWedgeView`, drawn in the window's colour space) while a step needs them, and the instructions in a dark card at
// the top, so an over-bright moment lights only small areas. Esc (Cancel) always ends the session at once; Space marks
// the merge during the sweep. The shell's `CalibrationWindowController` hosts it full screen on that display.
import OverbrightCore
import OverbrightDesign
import SwiftUI

/// The calibration window's content.
public struct CalibrationView: View {
    let model: CalibrationModel

    /// The squares' code values (DESIGN.md §9).
    static let patches: [Double] = [0.85, 0.90, 0.95, 1.00]
    /// The card's width.
    static let cardWidth: CGFloat = 560

    /// The content for `model`.
    public init(model: CalibrationModel) { self.model = model }

    public var body: some View {
        ZStack(alignment: .top) {
            Color.black.ignoresSafeArea()
            if model.showsPatches {
                StepWedgeView(patches: Self.patches, surround: 0)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            CalibrationCard(model: model)
                .frame(width: Self.cardWidth)
                .padding(.top, Space.huge)
        }
        .onExitCommand { model.cancel() }                               // Esc, wherever the focus is
        .environment(\.colorScheme, .dark)
        .overbrightThemeRoot()
    }
}

/// The dark card with the step's heading, text and buttons.
private struct CalibrationCard: View {
    let model: CalibrationModel

    var body: some View {
        VStack(alignment: .leading, spacing: Space.l) {
            Text(verbatim: heading)
                .font(.title2.weight(.semibold))
                .accessibilityAddTraits(.isHeader)
            content
            HStack(spacing: Space.m) { buttons }
        }
        .padding(Space.xxl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .windowBackgroundColor), in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .accessibilityElement(children: .contain)
    }

    private var heading: String {
        switch model.step {
        case .unavailable, .checklist: CalibrationCopy.title(display: model.displayName)
        case .comparison: CalibrationCopy.comparisonHeading
        case .sweepIntro, .sweep: CalibrationCopy.sweepHeading
        case .confirmation: CalibrationCopy.confirmationHeading
        case .results: CalibrationCopy.resultsHeading
        }
    }

    @ViewBuilder private var content: some View {
        switch model.step {
        case .unavailable:
            paragraph(CalibrationCopy.unavailable)
        case .checklist:
            CalibrationChecklistView(model: model)
        case .comparison:
            if model.isPreparing {
                preparing
            } else {
                Text(verbatim: model.showsBrighter ? CalibrationCopy.brighter : CalibrationCopy.standard)
                    .font(.largeTitle.weight(.semibold))
                    .accessibilityAddTraits(.updatesFrequently)
            }
            paragraph(CalibrationCopy.brighterQuestion)
        case .sweepIntro:
            paragraph(CalibrationCopy.sweepInstructions())
        case .sweep:
            if model.isPreparing { preparing }
            paragraph(model.isSweepPaused ? CalibrationCopy.pauseQuestion : CalibrationCopy.sweepInstructions())
        case .confirmation:
            paragraph(CalibrationCopy.confirmationQuestion)
        case .results:
            if let reason = model.stopReason, let line = CalibrationCopy.stopped(reason) { paragraph(line) }
            if let ending = model.ending { paragraph(CalibrationCopy.result(ending)) }
            paragraph(CalibrationCopy.turnBackOn).foregroundStyle(.secondary)
        }
    }

    @ViewBuilder private var buttons: some View {
        switch model.step {
        case .unavailable:
            Spacer()
            button(CalibrationCopy.tryAgain) { model.tryAgain() }
            button(CalibrationCopy.done) { model.done() }.keyboardShortcut(.defaultAction)
        case .checklist:
            Spacer()
            cancelButton
            button(CalibrationCopy.start) { model.start() }
                .keyboardShortcut(.defaultAction)
                .disabled(!model.canStart)
        case .comparison:
            cancelButton
            Spacer()
            button(CalibrationCopy.showAgain) { model.showAgain() }.disabled(model.isFlipping)
            button(CalibrationCopy.no) { model.answerBrighter(false) }.disabled(model.flips == 0)
            button(CalibrationCopy.yes) { model.answerBrighter(true) }.disabled(model.flips == 0)
        case .sweepIntro:
            cancelButton
            Spacer()
            button(CalibrationCopy.start) { model.startSweep() }.keyboardShortcut(.defaultAction)
        case .sweep:
            cancelButton
            Spacer()
            if model.isSweepPaused {
                button(CalibrationCopy.stop) { model.stopSweep() }
                button(CalibrationCopy.keepGoing) { model.keepGoing() }.keyboardShortcut(.defaultAction)
            } else {
                button(CalibrationCopy.merged) { model.markMerged() }
                    .keyboardShortcut(.space, modifiers: [])
                    .disabled(model.isPreparing)
            }
        case .confirmation:
            cancelButton
            Spacer()
            button(model.confirmationShown ? CalibrationCopy.showAgain : CalibrationCopy.show) { model.showConfirmation() }
                .disabled(model.isConfirming)
            button(CalibrationCopy.lookTheSame) { model.answerConfirmation(different: false) }
                .disabled(!model.confirmationShown || model.isConfirming)
            button(CalibrationCopy.lookDifferent) { model.answerConfirmation(different: true) }
                .disabled(!model.confirmationShown || model.isConfirming)
        case .results:
            Spacer()
            if model.ending == .inconclusive { button(CalibrationCopy.tryAgain) { model.tryAgain() } }
            button(CalibrationCopy.done) { model.done() }
                .keyboardShortcut(.defaultAction)
        }
    }

    private var cancelButton: some View {
        button(CalibrationCopy.cancel) { model.cancel() }.keyboardShortcut(.cancelAction)
    }

    private var preparing: some View {
        HStack(spacing: Space.m) {
            ProgressView().controlSize(.small)
            Text(verbatim: CalibrationCopy.preparing)
        }
    }

    private func paragraph(_ text: String) -> some View {
        Text(verbatim: text).fixedSize(horizontal: false, vertical: true)
    }

    private func button(_ title: String, action: @escaping @MainActor () -> Void) -> some View {
        Button(action: action) { Text(verbatim: title) }
    }
}

/// The checklist: live items with their state, asked items, and the colorimeter disclosure.
private struct CalibrationChecklistView: View {
    @Bindable var model: CalibrationModel
    @Environment(\.overbright) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            ForEach(CalibrationChecklist.Item.allCases, id: \.self) { item in
                row(item)
            }
            DisclosureGroup(isExpanded: $model.showsColorimeter) {
                VStack(alignment: .leading, spacing: Space.xs) {
                    HStack(spacing: Space.m) {
                        Text(verbatim: CalibrationCopy.sdrWhite)
                        TextField(value: $model.colorimeterNits, format: .number) { Text(verbatim: CalibrationCopy.sdrWhite) }
                            .labelsHidden()
                            .frame(width: SettingsMetrics.recorderMinWidth)
                            .multilineTextAlignment(.trailing)
                        Text(verbatim: CalibrationCopy.nitsUnit).foregroundStyle(.secondary)
                    }
                    if model.colorimeterValueIsImplausible {                   // the engine would ignore it; Start waits
                        Label {
                            Text(verbatim: CalibrationCopy.sdrWhiteRange())
                        } icon: {
                            Image(symbol: .exclamationMarkTriangleFill)
                                .foregroundStyle(SemanticColor.warning.glyph(in: theme))
                        }
                        .font(.callout)
                    }
                }
                .padding(.top, Space.xs)
            } label: {
                Text(verbatim: CalibrationCopy.colorimeter)
            }
        }
    }

    private func row(_ item: CalibrationChecklist.Item) -> some View {
        let passes = CalibrationChecklist.passes(item, model.systemSnapshot)
        return HStack(alignment: .firstTextBaseline, spacing: Space.m) {
            Group {
                switch passes {
                case true?: Image(symbol: .checkmarkCircleFill).foregroundStyle(SemanticColor.success.glyph(in: theme))
                case false?: Image(symbol: .exclamationMarkTriangleFill).foregroundStyle(SemanticColor.warning.glyph(in: theme))
                case nil: Image(symbol: .infoCircleFill).foregroundStyle(.secondary)
                }
            }
            .accessibilityHidden(true)
            Text(verbatim: CalibrationCopy.item(item))
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityValue(Text(verbatim: passes == false ? CalibrationCopy.notYet : ""))
    }
}

#Preview("Calibration · checklist") {
    let services = OverbrightServices.preview()
    CalibrationView(model: CalibrationModel(display: DisplayFixture.Keys.builtIn, name: "Built-in Display",
                                            services: services) { PreviewCalibrationSession() })
        .frame(width: 900, height: 600)
}

#Preview("Calibration · sweep") {
    let services = OverbrightServices.preview()
    let model = CalibrationModel(display: DisplayFixture.Keys.builtIn, name: "Built-in Display",
                                 services: services) { PreviewCalibrationSession() }
    model.start()
    model.answerBrighter(true)
    model.startSweep()
    return CalibrationView(model: model)
        .frame(width: 900, height: 600)
}

#Preview("Calibration · colorimeter value out of range") {
    let model = CalibrationModel(display: DisplayFixture.Keys.builtIn, name: "Built-in Display",
                                 services: .preview()) { PreviewCalibrationSession() }
    model.showsColorimeter = true
    model.colorimeterNits = 9000
    return CalibrationView(model: model)
        .frame(width: 900, height: 600)
}

#Preview("Calibration · unavailable") {
    CalibrationView(model: CalibrationModel(display: DisplayFixture.Keys.builtIn, name: "Built-in Display",
                                            services: .preview()) { nil })
        .frame(width: 900, height: 600)
}
