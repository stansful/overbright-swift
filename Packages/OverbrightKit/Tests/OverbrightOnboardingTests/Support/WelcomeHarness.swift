// OverbrightOnboardingTests/Support/WelcomeHarness.swift — Welcome sessions over the Core fakes for the WP12 suites
// (ARCHITECTURE.md §9.1): a preview hub whose engine status carries classified verdicts (`WelcomePreview`), the
// recording app control and engine, a shortcut center that renders key caps in a named keyboard layout (read-only:
// no input source is selected), and the English source strings whatever language the test process runs in.
import AppKit
import Foundation
import Observation
import OverbrightCore
import OverbrightDesign
import SwiftUI
import Testing
@testable import OverbrightOnboarding

/// A class of this test bundle: a bundle without translations, so `String(localized:bundle:)` gives the English keys.
final class WelcomeEnglishMarker {}

/// The bundle that yields English source strings.
let englishBundle = Bundle(for: WelcomeEnglishMarker.self)

/// One Welcome session and the fakes behind it.
@MainActor struct WelcomeHarness {
    let session: WelcomeSession
    let services: OverbrightServices
    let app: PreviewAppControl
    let boost: PreviewBoostControl
    let outcomes: Outcomes

    /// The outcomes `onFinish` reported.
    @MainActor final class Outcomes { var values: [WelcomeOutcome] = [] }

    /// A session at `step` over `fixture` (classified verdicts), recording its outcome.
    init(_ fixture: DisplayFixture = .builtinXDRLidOpen, step: WelcomeStep = .hello, updatesConfigured: Bool = false,
         records: Bool = true, configure: (OverbrightServices) -> Void = { _ in }) throws {
        let services = WelcomePreview.services(fixture, updatesConfigured: updatesConfigured)
        let app = PreviewAppControl()
        services.app = app
        configure(services)
        let outcomes = Outcomes()
        self.services = services
        self.app = app
        self.boost = try #require(services.boost as? PreviewBoostControl)
        self.outcomes = outcomes
        session = WelcomeSession(services: services, initialStep: step, recordsOutcome: records) {
            outcomes.values.append($0)
        }
    }

    /// The step 2 rows now, with the session's pending choices, in English.
    var rows: [WelcomeDisplayRow] {
        WelcomeDisplayRow.rows(in: services, choices: session.choices, language: .english())
    }

    /// Step 2's actions over this session's choices; `confirmOLED` answers the OLED notice.
    func actions(confirmOLED: @escaping @MainActor (String) -> Bool = { _ in true },
                 openURL: @escaping @MainActor (URL) -> Void = { _ in }) -> WelcomeDisplayActions {
        WelcomeDisplayActions(services: services, choices: session.choices, confirmOLED: confirmOLED, openURL: openURL)
    }

    /// The row of `key`.
    func row(_ key: DisplayKey) throws -> WelcomeDisplayRow { try #require(rows.first { $0.key == key }) }
}

/// A `ShortcutCenter` with the catalog defaults that renders key caps through one keyboard layout, as the real center
/// does with the current one (`KeyCombo.keyCaps(in:)`, the code of `HotKeyCenter.displayString`).
@MainActor @Observable final class LayoutShortcutCenter: ShortcutCenter {
    /// The layout the caps are drawn in.
    let layout: KeyCombo.KeyboardLayout?
    private var bindings: [ShortcutID: KeyCombo?]

    /// The catalog defaults in `layout`.
    init(layout: KeyCombo.KeyboardLayout?) {
        self.layout = layout
        bindings = Dictionary(uniqueKeysWithValues: ShortcutCatalog.all.map { ($0.id, $0.defaultCombo) })
    }

    /// An installed macOS layout by its short name ("German"), read-only; the test fails when macOS has none by that
    /// name (no fallback to the current layout).
    static func named(_ name: String) throws -> LayoutShortcutCenter {
        let identifier = "com.apple.keylayout.\(name)"
        let layout = try #require(KeyCombo.KeyboardLayout.named(identifier), "macOS ships the \(name) layout")
        #expect(layout.identifier == identifier)
        return LayoutShortcutCenter(layout: layout)
    }

    func state(_ id: ShortcutID) -> ShortcutState {
        guard let binding = bindings[id], let combo = binding else { return .off }
        return .registered(combo)
    }

    @discardableResult func set(_ id: ShortcutID, _ combo: KeyCombo?) -> ShortcutState {
        bindings[id] = .some(combo)
        return state(id)
    }

    func setRecording(_ recording: Bool) {}

    func displayString(_ id: ShortcutID) -> String? {
        guard case .registered(let combo) = state(id) else { return nil }
        return combo.keyCaps(in: layout)
    }
}

/// A preview hub over `fixture` whose shortcut center renders in `center`'s layout.
@MainActor func servicesWithShortcuts(_ center: any ShortcutCenter,
                                      fixture: DisplayFixture = .builtinXDRLidOpen) -> OverbrightServices {
    let base = WelcomePreview.services(fixture)
    let services = OverbrightServices(settings: base.settings, paths: base.paths, machine: base.machine, time: base.time,
                                      journal: base.journal, announcer: base.announcer,
                                      ownEDRSurfaces: base.ownEDRSurfaces, displays: base.displays,
                                      signals: base.signals, boost: base.boost, fillLight: base.fillLight,
                                      shortcuts: center, updates: base.updates)
    services.app = PreviewAppControl()
    return services
}

/// A display directory that is not the Core fake (what the real app wires): the card treats its ports as real.
@MainActor @Observable final class StaticDirectory: DisplayDirectory {
    var displays: [DisplayFacts] = []
    var generation = 0
    func facts(for key: DisplayKey) -> DisplayFacts? { displays.first { $0.ref.key == key } }
}

/// A preview hub over `base`'s fakes whose display directory is not the Core fake, listing `base`'s displays.
@MainActor func servicesWithRealDirectory(_ base: OverbrightServices = WelcomePreview.services()) -> OverbrightServices {
    let directory = StaticDirectory()
    directory.displays = base.displays.displays
    let services = OverbrightServices(settings: base.settings, paths: base.paths, machine: base.machine, time: base.time,
                                      journal: base.journal, announcer: base.announcer,
                                      ownEDRSurfaces: base.ownEDRSurfaces, displays: directory,
                                      signals: base.signals, boost: base.boost, fillLight: base.fillLight,
                                      shortcuts: base.shortcuts, updates: base.updates)
    services.app = PreviewAppControl()
    return services
}

/// A small box a sendable closure can read while the test changes it (the OLED notice's answer).
@MainActor final class Answer {
    var value: Bool
    init(_ value: Bool) { self.value = value }
}

/// Every `NSScrollView` under `view` (SwiftUI's `ScrollView` is one).
@MainActor func scrollViews(in view: NSView) -> [NSScrollView] {
    let own = (view as? NSScrollView).map { [$0] } ?? []
    return own + view.subviews.flatMap { scrollViews(in: $0) }
}

extension FitMeasure {
    /// The height `view` takes at `width` (its ideal height there: what a layout of that width draws).
    static func height(_ view: some View, width: CGFloat) -> CGFloat {
        let host = NSHostingView(rootView: view.frame(width: width, alignment: .topLeading)
            .fixedSize(horizontal: false, vertical: true))
        host.frame = CGRect(x: 0, y: 0, width: width, height: 1000)
        host.layoutSubtreeIfNeeded()
        return host.fittingSize.height
    }
}
