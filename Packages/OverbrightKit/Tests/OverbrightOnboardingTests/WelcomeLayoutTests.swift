// OverbrightOnboardingTests/WelcomeLayoutTests.swift — the Welcome window keeps one layout from step to step (DESIGN.md
// §8; WP14 C-ONBOARD-1), measured on rendered pixels and laid-out heights: the progress dots sit in the centre of the
// window on every step whose buttons leave the centre free, whatever the widths of the button groups; every step has
// the same split, the stage on top and the headline right under its divider (the full stage on steps 1, 4 and 5, the
// compact one on steps 2 and 3, whose controls come after the headline); step 5 sums up the defaults it applies; and a
// display row puts its switch on its own line rather than wrapping the name beside it. Rendered in-process in windows
// that are never ordered in.
import AppKit
import OverbrightCore
import OverbrightDesign
import SwiftUI
import Testing
@testable import OverbrightOnboarding

@MainActor @Suite struct WelcomeLayoutTests {
    /// The largest difference of one RGB component between two colours.
    static func distance(_ a: NSColor?, _ b: NSColor?) -> CGFloat {
        guard let a = a?.usingColorSpace(.deviceRGB), let b = b?.usingColorSpace(.deviceRGB) else { return 1 }
        return max(abs(a.redComponent - b.redComponent), abs(a.greenComponent - b.greenComponent),
                   abs(a.blueComponent - b.blueComponent))
    }

    /// The colour of `rep` at a point in points.
    static func color(_ rep: NSBitmapImageRep, x: CGFloat, y: CGFloat) -> NSColor? {
        let scale = CGFloat(rep.pixelsWide) / rep.size.width
        return rep.colorAt(x: Int((x * scale).rounded(.down)), y: Int((y * scale).rounded(.down)))
    }

    // MARK: Progress dots

    /// The horizontal extent of what is drawn on the footer's middle line within `range` (points from the window's
    /// leading edge), nil when nothing is.
    static func inkExtent(_ rep: NSBitmapImageRep, in range: ClosedRange<CGFloat>) -> ClosedRange<CGFloat>? {
        let y = rep.size.height / 2
        guard let background = color(rep, x: 2, y: y) else { return nil }
        let inked = stride(from: range.lowerBound, through: range.upperBound, by: 0.5).filter { x in
            distance(color(rep, x: x, y: y), background) > 0.02
        }
        guard let first = inked.first, let last = inked.last else { return nil }
        return first...last
    }

    /// On every step whose button groups leave the centre free, the dots are centred in the window, in English and in
    /// Russian: they no longer drift with the width of the buttons. On the last step with Turn On Overbright the
    /// buttons reach the centre, and the dots step aside rather than move.
    @Test(arguments: ["en", "ru"])
    func theDotsStayInTheCentreOfTheWindow(_ code: String) throws {
        let labels = WelcomeFooter.Labels.localized(in: code == "en" ? englishBundle : onboardingBundle(code))
        let centre = WelcomeMetrics.window.width / 2
        let dots = FitMeasure.idealWidth(ProgressDots(current: 1, count: WelcomeStep.allCases.count))
        var centred: [WelcomeStep] = []
        for step in WelcomeStep.allCases {
            let session = WelcomeChromeSnapshotTests.session(step)
            let rep = try ChromeSnapshot.render(WelcomeChromeSnapshotTests.footer(session, labels: labels), .light)
            let free = FitMeasure.idealWidth(WelcomeFooter(session: session, labels: labels).row(showsDots: true))
                <= WelcomeFooterFitTests.budget
            guard free else { continue }
            let extent = try #require(Self.inkExtent(rep, in: (centre - dots)...(centre + dots)), "\(code) \(step)")
            #expect(abs((extent.lowerBound + extent.upperBound) / 2 - centre) <= 1, "\(code) \(step): \(extent)")
            #expect(abs(extent.upperBound - extent.lowerBound - dots) <= 2, "\(code) \(step): \(extent)")
            centred.append(step)
        }
        #expect(centred == WelcomeStep.allCases, "\(code): \(centred)")             // Done without Turn On included
        let turnOn = WelcomeChromeSnapshotTests.session(.done, turnOn: true)
        #expect(FitMeasure.idealWidth(WelcomeFooter(session: turnOn, labels: labels).row(showsDots: true))
                > WelcomeFooterFitTests.budget, "\(code): the last step's buttons reach the centre")
    }

    /// The centred row's arithmetic: twice the wider side, the middle and its spacing; the sides never matter alone.
    @Test func theCentredRowNeedsTwiceTheWiderSide() {
        #expect(CentredRow.idealWidth(leading: 90, middle: 68, trailing: 150, spacing: 12) == 392)
        #expect(CentredRow.idealWidth(leading: 150, middle: 68, trailing: 90, spacing: 12) == 392)
    }

    // MARK: One split on every step

    /// The page of `step` (no footer) in Light, at the page's own size.
    static func page(_ step: WelcomeStep) throws -> NSBitmapImageRep {
        let services = step == .displays ? WelcomePreview.services(.russianNames) : WelcomePreview.services()
        let session = WelcomeStepSnapshotTests.session(services, step)
        let view = WelcomeStepSnapshotTests.page(session).environment(\.isStaticSnapshot, true)
        return try ChromeSnapshot.render(view, .light,
                                         size: CGSize(width: WelcomeMetrics.window.width,
                                                      height: WelcomeStepFitTests.pageHeight))
    }

    /// The stage each step has: the full one where the stage carries the step (the card, the menu bar and key caps,
    /// the app icon), the compact one where the controls need the room.
    static let stages: [WelcomeStep: StageSize] = [
        .hello: .regular, .displays: .compact, .defaults: .compact, .findIt: .regular, .done: .regular,
    ]

    /// Every step: the stage band on top ends at its size (the divider, seen at the window's edge, clear of content),
    /// and the first thing drawn under it is the headline, at the copy's top padding: the headline sits at the stage
    /// boundary on every step, and step 3's switches come after it.
    @Test(arguments: WelcomeStep.allCases)
    func theHeadlineSitsUnderTheStage(_ step: WelcomeStep) throws {
        let size = try #require(Self.stages[step])
        let rep = try Self.page(step)
        let edge: CGFloat = Space.xs
        let stage = Self.color(rep, x: edge, y: Space.xs)
        let divider = try #require(stride(from: Space.xs, to: rep.size.height, by: 0.5).first { y in
            Self.distance(Self.color(rep, x: edge, y: y), stage) > 0.02
        })
        #expect(abs(divider - size.height) <= 1, "\(step): the stage ends at \(divider), not \(size.height)")

        let copy = Self.color(rep, x: edge, y: size.headlineTop)
        let columns = stride(from: WelcomeMetrics.inset, through: WelcomeMetrics.inset + 160, by: 1)
        let first = try #require(stride(from: size.height + 2, to: rep.size.height, by: 0.5).first { y in
            columns.contains { Self.distance(Self.color(rep, x: $0, y: y), copy) > 0.15 }
        })
        #expect(first >= size.headlineTop && first <= size.headlineTop + Space.m,
                "\(step): the first ink under the stage is at \(first), the headline at \(size.headlineTop)")
    }

    // MARK: Step 5

    /// Step 5 sums up what Done applies of step 3: the pause rules that are on, then what happens at login; a rule
    /// that is off is left out, and a choice made in step 3 shows at once.
    @Test func theDoneStepSumsUpTheDefaults() throws {
        let harness = try WelcomeHarness(step: .done)
        let choices = harness.session.choices, settings = harness.services.settings
        #expect(DoneSummary.lines(choices: choices, settings: settings)
                == [.battery(percent: 20), .lowPower, .fullScreenVideo, .login(.launchOnly)])
        choices.setBatteryThreshold(35, in: settings)
        choices.pauseInLowPowerMode = false
        choices.launchBehavior = .dontLaunch
        #expect(DoneSummary.lines(choices: choices, settings: settings)
                == [.battery(percent: 35), .fullScreenVideo, .login(.dontLaunch)])
        choices.setPausesOnBattery(false, in: settings)
        choices.pauseForFullScreenVideo = false
        #expect(DoneSummary.lines(choices: choices, settings: settings) == [.login(.dontLaunch)])
        #expect(DoneSummary.Line.login(.launchOnly).symbol == .power)
        #expect(DoneSummary.Line.battery(percent: 20).symbol == DefaultsStep.stageSymbols[0])
    }

    // MARK: Step 2 rows

    /// A display row's name line in every language Overbright ships, with the owner's three displays: the glyph,
    /// name, badge and switch on one line when they fit, else the switch on its own line under the name, never the
    /// name wrapped beside the switch (the Russian built-in display did). Measured: the line is exactly one of the
    /// two layouts' heights.
    @Test func theNameNeverWrapsBesideTheSwitch() throws {
        let services = WelcomePreview.threeDisplays
        let width = WelcomeStepFitTests.width - 2 * Space.m                     // the row's padding
        var stacked: Set<String> = []
        for code in ["en"] + CopyLanguage.available.filter({ $0 != "en" }) {
            let language = code == "en" ? CopyLanguage.english() : (CopyLanguage.named(code) ?? .english())
            let title = DisplaysStep.Copy.localized(in: code == "en" ? englishBundle : onboardingBundle(code))
                .useExtraBrightness
            for row in WelcomeDisplayRow.rows(in: services, language: language) where row.canBoost {
                let toggle = ExtraBrightnessSwitch(title: title, isOn: .constant(row.boostEnabled))
                let line = FitMeasure.height(DisplayNameLine(row: row) { toggle }, width: width)
                let identity = FitMeasure.height(DisplayNameLine(row: row) { EmptyView() }, width: 2 * width)
                let control = FitMeasure.height(toggle, width: width)
                let oneLine = max(identity, control), twoLines = identity + Space.xxs + control
                #expect(abs(line - oneLine) < 0.5 || abs(line - twoLines) < 0.5,
                        "\(code) \(row.name): \(line) pt, one line \(oneLine), two lines \(twoLines)")
                if abs(line - twoLines) < 0.5 { stacked.insert("\(code) \(row.name)") }
            }
        }
        #expect(stacked.contains("ru Встроенный дисплей Retina"), "\(stacked.sorted())")
        #expect(!stacked.contains { $0.hasPrefix("en ") }, "English keeps one line: \(stacked.sorted())")
    }
}
