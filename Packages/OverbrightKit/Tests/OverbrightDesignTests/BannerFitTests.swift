// OverbrightDesignTests/BannerFitTests.swift — the panel's banner shows its whole sentence (DESIGN.md §2.2: layouts grow
// in height instead of truncating meaning; §5.8, §5.13, §16). For every banner, in every language Overbright ships, with
// a short, a very long and a right-to-left app name, the banner is at least as tall as its sentence laid out in full in
// the banner's text column of the panel's 304-pt card column: nothing is cut after a few lines, and no sentence takes
// more than six lines. Only a long app name is middle-truncated, to `BannerModel.nameWidth`, with the full sentence
// kept for the help tag and VoiceOver. Measured with the banner itself in an NSHostingView without a window; nothing is
// ordered in.
import AppKit
import OverbrightCore
import SwiftUI
import Testing
@testable import OverbrightDesign

@MainActor @Suite struct BannerFitTests {
    /// The panel's card column, where the banner sits: 320 pt less 8 pt on each side (the card's inner width plus its
    /// 12-pt padding on each side).
    static let width = StatusChip.maximumWidth + 2 * Space.l
    nonisolated static let display = DisplayKey(rawValue: "A")
    /// A short name, one longer than a banner line, and a right-to-left (Hebrew) one longer than `nameWidth`.
    nonisolated static let appNames = [
        "Booster",
        "Extended Professional Video Player Studio Edition for Color Grading and Live Monitoring",
        "מאיר המסכים המקצועי של האולפן להקלטה ולעריכת וידאו",
    ]

    /// Every banner, naming `app` where a banner names one.
    nonisolated static func banners(naming app: String) -> [Banner] {
        let booster = ConflictingApp(entryID: "s1", severity: .booster, bundleID: nil, processID: 1, displayName: app)
        let colorApp = ConflictingApp(entryID: "s2", severity: .gammaWriter, bundleID: nil, processID: 2, displayName: app)
        return [.userPaused(until: Date(timeIntervalSince1970: 1_792_160_400)), .conflict(booster), .conflict(colorApp),
                .foreignTableAtLaunch, .flickerStop(display: display), .unattributedDrift(display: display),
                .attributedDrift(colorApp, display: display), .focusOff, .thermalCritical, .lowPowerMode,
                .battery(percent: 12, threshold: 20), .onBattery,
                .outsideSchedule(ScheduleWindow(startMinute: 8 * 60, endMinute: 20 * 60))]
    }

    /// Which banner `banner` is: an exhaustive switch, so a new case does not compile until it is measured here.
    nonisolated static func kind(_ banner: Banner) -> String {
        switch banner {
        case .userPaused: "user pause"
        case let .conflict(app): app.severity == .booster ? "booster" : "color app"
        case .foreignTableAtLaunch: "foreign table"
        case .flickerStop: "flicker stop"
        case .unattributedDrift: "unattributed drift"
        case .attributedDrift: "attributed drift"
        case .focusOff: "Focus"
        case .thermalCritical: "heat"
        case .lowPowerMode: "Low Power Mode"
        case .battery: "battery"
        case .onBattery: "on battery"
        case .outsideSchedule: "schedule"
        }
    }

    /// The height `view` takes in `width`.
    private func height(_ view: some View, width: CGFloat) -> CGFloat {
        NSHostingView(rootView: view.frame(width: width).fixedSize(horizontal: false, vertical: true)
            .overbrightThemeRoot()).fittingSize.height
    }

    /// The width of `symbol` as the banner draws it.
    private func glyphWidth(_ symbol: OverbrightSymbol) -> CGFloat {
        NSHostingView(rootView: Image(symbol: symbol).font(.system(size: GlyphSize.banner)).fixedSize()).fittingSize.width
    }

    @Test func everyBannerIsMeasured() {
        #expect(Set(Self.banners(naming: "App").map(Self.kind)).count == 13)
        #expect(CopyLanguage.available.count == 35)
    }

    /// A long translation grows the banner, within reason: with the long app name, at most this many lines, so the
    /// card list below keeps its room (a longer sentence is reworded first, DESIGN.md §16).
    static let maximumLines: CGFloat = 6

    /// Without buttons the banner is its padding around the glyph and the sentence, so its height must cover the
    /// sentence's full height in the text column (the column is the card column less the padding, the glyph and the
    /// gap). A line limit fails this for any sentence longer than the limit.
    @Test(arguments: CopyLanguage.available)
    func everyBannerShowsItsWholeSentence(_ code: String) throws {
        let language = try #require(CopyLanguage.named(code))
        let line = height(Text(verbatim: "A").font(OverbrightFont.banner.font), width: Self.width)
        var failures: [String] = []
        for name in Self.appNames {
            for banner in Self.banners(naming: name) {
                let model = BannerModel.make(banner, displayNames: [Self.display: "Studio Display"], in: language)
                let column = Self.width - 2 * Space.l - glyphWidth(model.symbol) - Space.m
                let sentence = height(Text(verbatim: model.sentence).font(OverbrightFont.banner.font), width: column)
                let drawn = height(PausedBanner(model, primary: nil), width: Self.width)
                if drawn + 0.5 < sentence + 2 * Space.l {
                    failures.append("\(Self.kind(banner)) «\(model.sentence)»: \(drawn) pt for \(sentence) pt of text")
                }
                if sentence > Self.maximumLines * line + 0.5 {
                    failures.append("\(Self.kind(banner)) «\(model.sentence)»: \(sentence / line) lines")
                }
            }
        }
        #expect(failures.isEmpty, "\(code): banners that cut their sentence: \(failures)")
    }

    /// A long app name, left to right or right to left, is middle-truncated to `nameWidth` in the shown sentence and
    /// kept whole in the help tag and VoiceOver; a short one is shown as it is.
    @Test(arguments: CopyLanguage.available)
    func aLongAppNameIsMiddleTruncated(_ code: String) throws {
        let language = try #require(CopyLanguage.named(code))
        for name in Self.appNames {
            let fits = OverbrightFont.banner.width(of: name) <= BannerModel.nameWidth
            for banner in Self.banners(naming: name) {
                let model = BannerModel.make(banner, displayNames: [Self.display: "Studio Display"], in: language)
                switch banner {
                case .conflict, .attributedDrift:
                    #expect(model.accessibilityLabel.contains(name.overbrightIsolated), "\(code) \(Self.kind(banner))")
                    #expect(model.sentence.contains(name.overbrightIsolated) == fits, "\(code) \(Self.kind(banner))")
                    #expect((model.sentence == model.accessibilityLabel) == fits, "\(code) \(Self.kind(banner))")
                default:
                    #expect(model.sentence == model.accessibilityLabel, "\(code) \(Self.kind(banner)) names no app")
                }
            }
        }
    }
}
