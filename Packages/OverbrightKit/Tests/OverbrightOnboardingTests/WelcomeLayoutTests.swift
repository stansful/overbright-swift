// OverbrightOnboardingTests/WelcomeLayoutTests.swift — the Welcome window keeps one layout from step to step (DESIGN.md
// §8; WP14 C-ONBOARD-1), measured on rendered pixels and laid-out heights: the progress dots show on every step, the
// last one with Turn On Overbright included, in the centre of the window whatever the widths of the button groups (in
// the row while the buttons leave the centre free, else on their own line just above it, the footer's only change of
// height); every step has the same split, the stage on top and the headline right under its divider (the full stage
// on steps 1, 4 and 5, the compact one on steps 2 and 3, whose controls come after the headline); step 5 sums up the
// defaults it applies; and a display row puts its switch on its own line rather than wrapping the name beside it.
// Rendered in-process in windows that are never ordered in.
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

    /// Every kind of footer: each step, and the last one with Turn On Overbright, whose three buttons are the widest.
    static func footerSessions() -> [(String, WelcomeSession)] {
        WelcomeStep.allCases.map { ("\($0)", WelcomeChromeSnapshotTests.session($0)) }
            + [("done, Turn On", WelcomeChromeSnapshotTests.session(.done, turnOn: true))]
    }

    /// The size of the progress dots (the same on every step: one capsule and four dots).
    static var dotsSize: CGSize {
        let dots = ProgressDots(current: 1, count: WelcomeStep.allCases.count)
        return CGSize(width: FitMeasure.idealWidth(dots),
                      height: FitMeasure.height(dots, width: WelcomeMetrics.window.width))
    }

    /// The height of the footer's button row (as high on every step).
    static var buttonRowHeight: CGFloat {
        let footer = WelcomeFooter(session: WelcomeChromeSnapshotTests.session(.hello),
                                   labels: WelcomeFooterFitTests.english)
        return FitMeasure.height(footer.row(dots: .inRow), width: WelcomeFooterFitTests.budget)
    }

    /// The progress dots as the footer of `session` with `labels` draws them (as the window places it, in Light): where
    /// they are, read from the footer's height (a line higher when they sit above the row), and the horizontal extent
    /// of what is drawn on their middle line, in points from the window's leading edge, nil when nothing is. Above the
    /// row the whole width of the line is read; in the row, the centre the `CentredRow` keeps clear of the buttons.
    static func drawnDots(_ session: WelcomeSession, labels: WelcomeFooter.Labels) throws
        -> (placement: WelcomeFooter.DotsPlacement, extent: ClosedRange<CGFloat>?) {
        let rep = try ChromeSnapshot.render(WelcomeChromeSnapshotTests.footer(session, labels: labels), .light)
        let row = buttonRowHeight, dots = dotsSize
        let aboveRow = rep.size.height > 2 * WelcomeMetrics.footerPadding + row + 0.5
        let y = WelcomeMetrics.footerPadding + (aboveRow ? dots.height : row) / 2
        let centre = WelcomeMetrics.window.width / 2, reach = dots.width / 2 + Space.m
        let range = aboveRow ? 0...(rep.size.width - 0.5) : (centre - reach)...(centre + reach)
        let placement: WelcomeFooter.DotsPlacement = aboveRow ? .aboveRow : .inRow
        guard let background = color(rep, x: 1, y: y) else { return (placement, nil) }
        let inked = stride(from: range.lowerBound, through: range.upperBound, by: 0.5).filter { x in
            distance(color(rep, x: x, y: y), background) > 0.02
        }
        guard let first = inked.first, let last = inked.last else { return (placement, nil) }
        return (placement, first...last)
    }

    /// Whether `extent` is the dots alone, centred in the window: its middle at the window's centre and its width the
    /// dots'.
    static func isCentredDots(_ extent: ClosedRange<CGFloat>) -> Bool {
        abs((extent.lowerBound + extent.upperBound) / 2 - WelcomeMetrics.window.width / 2) <= 1
            && abs(extent.upperBound - extent.lowerBound - dotsSize.width) <= 2
    }

    /// On every step, the last one with Turn On Overbright included, the dots are drawn centred in the window, in
    /// English and in Russian: they never drift with the width of the buttons, and never hide. In English they sit in
    /// the row on every step but the last one with Turn On Overbright, whose three buttons reach the centre: there
    /// they sit just above the row.
    @Test(arguments: ["en", "ru"])
    func theDotsStayInTheCentreOfTheWindow(_ code: String) throws {
        let labels = WelcomeFooter.Labels.localized(in: code == "en" ? englishBundle : onboardingBundle(code))
        var placements: [WelcomeFooter.DotsPlacement] = []
        for (name, session) in Self.footerSessions() {
            let drawn = try Self.drawnDots(session, labels: labels)
            let extent = try #require(drawn.extent, "\(code) \(name): no dots")
            #expect(Self.isCentredDots(extent),
                    "\(code) \(name): \(extent), the dots are \(Self.dotsSize.width) pt wide")
            placements.append(drawn.placement)
        }
        #expect(placements.dropLast().allSatisfy { $0 == .inRow }, "\(code): \(placements)")
        if code == "en" { #expect(placements.last == .aboveRow) }
    }

    /// Only the dots' own line changes the footer's height: with the dots in the row the footer is the button row
    /// between its paddings, and above the row a line higher (the dots and the space under them). The page above it
    /// is that much shorter there, on the last step with Turn On Overbright (`WelcomeStepFitTests` measures step 5
    /// under that footer).
    @Test func onlyTheDotsLineChangesTheFooterHeight() {
        let width = WelcomeMetrics.window.width, row = Self.buttonRowHeight
        let inRow = 2 * WelcomeMetrics.footerPadding + row
        let aboveRow = inRow + Self.dotsSize.height + WelcomeMetrics.dotsSpacing
        for (name, session) in Self.footerSessions() {
            let footer = WelcomeFooter(session: session, labels: WelcomeFooterFitTests.english)
            #expect(abs(FitMeasure.height(footer.row(dots: .inRow).padding(.vertical, WelcomeMetrics.footerPadding),
                                          width: width) - inRow) < 0.5, "\(name)")
            #expect(abs(FitMeasure.height(footer.row(dots: .aboveRow).padding(.vertical, WelcomeMetrics.footerPadding),
                                          width: width) - aboveRow) < 0.5, "\(name)")
        }
        #expect(abs(WelcomeMetrics.window.height - inRow - WelcomeStepFitTests.pageHeight) < 0.5)
        #expect(abs(WelcomeMetrics.window.height - aboveRow - WelcomeStepFitTests.lastPageHeight) < 0.5)
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
            let language = try code == "en" ? CopyLanguage.english()
                : #require(CopyLanguage.named(code), "\(code): no Design table")
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
