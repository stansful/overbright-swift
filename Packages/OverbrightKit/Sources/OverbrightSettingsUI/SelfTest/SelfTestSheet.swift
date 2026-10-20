// OverbrightSettingsUI/SelfTest/SelfTestSheet.swift — the self-test sheet (DESIGN.md §10), from Settings ▸ Advanced ▸
// Run Self-Test… (and the panel's "⋯" menu, which opens Settings there): the consent and options, the progress per
// display with Stop, and the results table with Save Log…, Copy and Done. The state is a `SelfTestModel`; closing the
// sheet stops a run.
import Foundation
import OverbrightCore
import OverbrightDesign
import SwiftUI

/// The self-test sheet.
public struct SelfTestSheet: View {
    @State private var model: SelfTestModel
    private let onDone: @MainActor () -> Void

    /// The size of the sheet.
    static let size = CGSize(width: 580, height: 480)

    /// A sheet over `services`; `onDone` closes it (Cancel before a run, Done after it).
    public init(services: OverbrightServices, onDone: @escaping @MainActor () -> Void) {
        self.init(model: SelfTestModel(services: services), onDone: onDone)
    }

    /// A sheet showing `model` (tests and snapshots).
    init(model: SelfTestModel, onDone: @escaping @MainActor () -> Void) {
        _model = State(initialValue: model)
        self.onDone = onDone
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Space.l) {
            Text(verbatim: SelfTestText.title)
                .font(.title2.weight(.semibold))
                .accessibilityAddTraits(.isHeader)
            switch model.phase {
            case .before: SelfTestOptionsView(model: model)
            case .running: SelfTestRunningView(model: model)
            case .results(let report): SelfTestResultsView(model: model, report: report)
            }
            Spacer(minLength: 0)
            buttons
        }
        .padding(Space.xxl)
        .frame(width: Self.size.width, height: Self.size.height, alignment: .topLeading)
        .onDisappear { model.close() }
        .overbrightThemeRoot()
    }

    @ViewBuilder private var buttons: some View {
        HStack(spacing: Space.m) {
            switch model.phase {
            case .before:
                Spacer()
                Button(role: .cancel) { onDone() } label: { Text(verbatim: PaneWords.cancel) }
                    .keyboardShortcut(.cancelAction)
                Button { model.start() } label: { Text(verbatim: SelfTestText.run) }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!model.canRun)
            case .running:
                Spacer()
                Button { model.stop() } label: { Text(verbatim: SelfTestText.stop) }
                    .keyboardShortcut(.cancelAction)
            case .results:
                Button { model.save() } label: { Text(verbatim: SelfTestText.saveLog) }
                Button { model.copy() } label: { Text(verbatim: SelfTestText.copy) }
                Spacer()
                Button { onDone() } label: { Text(verbatim: SelfTestText.done) }
                    .keyboardShortcut(.defaultAction)
            }
        }
    }
}

/// Before the run: what the test does, a checkbox per display, Test every method.
private struct SelfTestOptionsView: View {
    @Bindable var model: SelfTestModel

    var body: some View {
        VStack(alignment: .leading, spacing: Space.l) {
            Text(verbatim: SelfTestText.intro)
                .fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: Space.s) {
                ForEach(model.displays) { display in
                    Toggle(isOn: Binding(get: { model.chosen.contains(display.key) }, set: { on in
                        if on { model.chosen.insert(display.key) } else { model.chosen.remove(display.key) }
                    })) {
                        Text(verbatim: display.name)
                    }
                    .toggleStyle(.checkbox)
                }
            }
            HStack(spacing: Space.m) {
                Toggle(isOn: $model.everyMethod) { Text(verbatim: SelfTestText.everyMethod) }
                    .toggleStyle(.checkbox)
                Text(verbatim: SelfTestText.everyMethodNote)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

/// While it runs: one progress line and bar per chosen display.
private struct SelfTestRunningView: View {
    let model: SelfTestModel

    var body: some View {
        VStack(alignment: .leading, spacing: Space.l) {
            ForEach(model.progress, id: \.display) { progress in
                let name = model.name(of: progress.display.rawValue)
                VStack(alignment: .leading, spacing: Space.xs) {
                    Text(verbatim: progress.rung.map { SelfTestText.progress(display: name, rung: $0, seconds: progress.secondsInRung) }
                         ?? name)
                        .monospacedDigit()
                        .lineLimit(1)
                        .truncationMode(.middle)
                    ProgressView(value: progress.fraction)
                        .progressViewStyle(.linear)
                        .accessibilityLabel(Text(verbatim: name))
                }
            }
        }
    }
}

/// After the run: a table per display, its summary, and the privacy note.
private struct SelfTestResultsView: View {
    let model: SelfTestModel
    let report: SelfTestReport

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.xl) {
                ForEach(model.orderedResults(report), id: \.key) { display in
                    let name = model.name(of: display.key)
                    VStack(alignment: .leading, spacing: Space.s) {
                        Text(verbatim: name).font(.headline).accessibilityAddTraits(.isHeader)
                        SelfTestResultsTable(results: display.results)
                        Text(verbatim: SelfTestText.summary(display: name, results: display.results))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Text(verbatim: SelfTestText.privacy)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

#Preview("Self-test · before") {
    SelfTestSheet(services: .preview(fixture: .russianNames)) {}
}

#Preview("Self-test · results") {
    let services = OverbrightServices.preview()
    let held = SelfTestStrategyResult(strategy: .taggedLayer, pixel: .black, verdict: .held, baselineHeadroom: 1.2,
                                      secondsToFirstMovement: 0.4, secondsToStable: 1.6, heldFraction: 1, samples: [])
    (services.boost as? PreviewBoostControl)?.selfTestReport = SelfTestReport(
        startedAt: Date(timeIntervalSinceReferenceDate: 800_000_000), machine: DisplayFixture.ownerMachine,
        appVersion: "0.1.0", displays: [DisplayFixture.Keys.builtIn.rawValue: [held]], journal: [])
    let model = SelfTestModel(services: services, archiveFolder: .some(nil))
    model.start()
    return SelfTestSheet(model: model) {}
}
