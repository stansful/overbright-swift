// OverbrightDesignTests/ChipModelTests.swift — DESIGN.md §12.2 and ARCHITECTURE.md §6.2: every `LimitReason` maps to
// its chip (copy, colour, symbol, actions) or to none; chips are per-display only (a reason the banner says never
// repeats as a chip); the engine phase wins while preparing or failed. English whatever the system language.
import Foundation
import OverbrightCore
import Testing
@testable import OverbrightDesign

@Suite struct ChipModelTests {
    nonisolated static let booster = ConflictingApp(entryID: "s1", severity: .booster, bundleID: "com.example.booster", processID: 1,
                                        displayName: "Booster")
    nonisolated static let colorApp = ConflictingApp(entryID: "s2", severity: .gammaWriter, bundleID: "com.example.warm", processID: 2,
                                         displayName: "Warmth")
    nonisolated static let mayInterfere = ConflictingApp(entryID: "s3", severity: .conditional, bundleID: "com.example.tool",
                                             processID: 3, displayName: "Tool")
    nonisolated static let display = DisplayKey(rawValue: "A")
    nonisolated static let context = ChipContext(allowedGain: 1.55, appName: "Player", language: english)

    /// Every case of `LimitReason` (one value each; `notSupported` and `tripped` per cause below).
    nonisolated static let everyReason: [LimitReason] = [
        .masterOff, .notSupported(.turnOnHDR), .shielded, .conflict(booster), .conflict(colorApp), .conflict(mayInterfere),
        .tripped(.oscillation), .tripped(.repairBudgetExceeded), .tripped(.attributedDrift(colorApp)),
        .tripped(.headroomNeverArrived), .tripped(.foreignTableAtLaunch), .userPaused(until: .distantFuture), .focusOff,
        .boostNotEnabled, .thermalCritical, .lowPowerMode, .battery(percent: 12, threshold: 20), .onBattery,
        .outsideSchedule, .fullScreenVideo, .fullScreenApp, .pausedApp(bundleID: "com.example.player"), .game, .oledIdle,
        .hdrSuppressedByMacOS, .thermalSerious, .safeLimit, .oledLimit, .nearFullBrightnessOnly, .headroom,
        .waitingForHeadroom,
    ]

    private func chip(_ reason: LimitReason, phase: EnginePhase = .boosted, tries: Int = 0) -> ChipModel? {
        ChipModel.make(reason: reason, phase: phase, failedTries: tries, context: Self.context)
    }

    /// Reasons that apply to every display are the banner's: never a chip (DESIGN.md §5.7, §6.2).
    @Test(arguments: everyReason) func globalReasonsAreNeverChips(reason: LimitReason) {
        guard reason.isGlobal || reason == .masterOff || reason == .shielded else { return }
        #expect(chip(reason) == nil, "\(reason)")
        #expect(ChipModel.chipReason(in: [reason], display: Self.display, banner: nil) == nil)
    }

    /// Every per-display reason has a chip with words, and its glyph is on the symbol list.
    @Test(arguments: everyReason) func perDisplayReasonsHaveAChip(reason: LimitReason) throws {
        guard !reason.isGlobal, reason != .masterOff, reason != .shielded else { return }
        let model = try #require(chip(reason), "\(reason)")
        #expect(!model.text.isEmpty && !model.explanation.isEmpty && !model.accessibilityLabel.isEmpty)
        #expect(OverbrightSymbol.allCases.contains(model.symbol))
    }

    /// The table of DESIGN.md §12.2: text, glyph, colour, sentence and actions.
    @Test func theChipTable() throws {
        typealias Row = (LimitReason, String, OverbrightSymbol, SemanticColor, String, [FixAction])
        let rows: [Row] = [
            (.boostNotEnabled, "Extra brightness off", .sunMax, .neutral,
             "Extra brightness is off for this display. Dimming still works.", [.turnOn]),
            (.headroom, "Limited by macOS", .sunMin, .info,
             "macOS allows ×1.55 right now. It lowers the extra range when the surroundings are bright, the display is warm or the battery is low.", []),
            (.hdrSuppressedByMacOS, "Limited by macOS", .sunMin, .info, "macOS is limiting HDR right now.", []),
            (.nearFullBrightnessOnly, "Below full brightness", .sunMin, .info,
             "Extra brightness fades out as you lower the display brightness. Turn the brightness up for more.", [.changeSetting]),
            (.oledLimit, "OLED limit", .lockFill, .info,
             "Extra brightness stays at 1.3 times on OLED displays to protect the panel. Choose Peak for more.", [.choosePeak]),
            (.thermalSerious, "Limited by heat", .thermometerMedium, .warning,
             "Your Mac is warm, so extra brightness stays at 1.2 times until it cools down.", []),
            (.fullScreenVideo, "Paused: video", .playRectangleFill, .neutral,
             "Extra brightness pauses while an app plays video full screen on this display.", [.changeRules]),
            (.fullScreenApp, "Paused: full screen", .playRectangleFill, .neutral,
             "Extra brightness pauses while an app is full screen on this display.", [.changeRules]),
            (.pausedApp(bundleID: "com.example.player"), "Paused: \u{2068}Player\u{2069}", .pauseFill, .neutral,
             "Extra brightness pauses while \u{2068}Player\u{2069} is in front on this display.", [.editApps]),
            (.game, "Paused: game", .gameControllerFill, .neutral,
             "Extra brightness pauses while a game is in front on this display.", [.changeRules]),
            (.oledIdle, "Paused: idle", .zzz, .neutral,
             "Extra brightness pauses after 5 minutes without input on OLED displays. Move the pointer or press a key to continue.", []),
            (.conflict(Self.mayInterfere), "\u{2068}Tool\u{2069} may interfere", .exclamationMarkCircleFill, .info,
             "\u{2068}Tool\u{2069} can change display colors in some modes. If it does, Overbright stops on this display.", []),
            (.tripped(.oscillation), "Stopped", .exclamationMarkTriangleFill, .danger,
             "Overbright stopped on this display to prevent flicker.", [.tryAgain]),
            (.tripped(.repairBudgetExceeded), "Stopped", .exclamationMarkTriangleFill, .danger,
             "Overbright stopped on this display to prevent flicker.", [.tryAgain]),
            (.tripped(.attributedDrift(Self.colorApp)), "Stopped: \u{2068}Warmth\u{2069}", .exclamationMarkTriangleFill, .danger,
             "\u{2068}Warmth\u{2069} changed the colors of this display.", [.continueAnyway]),
            (.tripped(.foreignTableAtLaunch), "Colors changed", .exclamationMarkTriangleFill, .danger,
             "Another app changed this display’s colors in a way Overbright can’t reset.", [.openSystemSettings]),
        ]
        for (reason, text, symbol, color, sentence, actions) in rows {
            let model = try #require(chip(reason), "\(reason)")
            #expect(model.text == text, "\(reason)")
            #expect(model.symbol == symbol, "\(reason)")
            #expect(model.color == color, "\(reason)")
            #expect(model.explanation == sentence, "\(reason)")
            #expect(model.actions == actions, "\(reason)")
        }
    }

    @Test func safeLimitQuotesTheDisplaysClass() throws {
        let xdr = SafeLimitText(panelClass: .builtInXDR, isOLED: false, safeTop: 1.667)
        let model = try #require(ChipModel.make(reason: .safeLimit, phase: .boosted, failedTries: 0,
                                                context: ChipContext(safeLimit: xdr, language: english)))
        #expect(model.text == "Safe limit")
        #expect(model.symbol == .lockFill && model.color == .info && model.actions == [.choosePeak])
        #expect(model.explanation
                == "Safe stays at the level this display can hold across the whole screen, ×1.67 here. Choose Peak for more.")
        let unknown = try #require(chip(.safeLimit))
        #expect(unknown.explanation.hasSuffix("Choose Peak for more."))
    }

    /// "Preparing…" and "No extra range" come from the engine phase and win while they apply.
    @Test func thePhaseWinsWhilePreparingOrFailed() throws {
        let arming = try #require(chip(.safeLimit, phase: .arming(rung: 0)))
        #expect(arming.text == "Preparing…" && arming.showsProgress && arming.color == .info)
        #expect(arming.explanation == "Overbright is unlocking extra range on this display. The first time takes a few seconds.")
        #expect(try #require(chip(.headroom, phase: .gating(rung: 1))).text == "Preparing…")
        #expect(ChipModel.make(reason: nil, phase: .gating(rung: 2), failedTries: 0) != nil)
        let failed = try #require(chip(.boostNotEnabled, phase: .failed(.headroomNeverArrived)))
        #expect(failed.text == "No extra range" && failed.color == .danger && failed.symbol == .exclamationMarkTriangleFill)
        #expect(ChipModel.make(reason: nil, phase: .boosted, failedTries: 0) == nil, "a working display shows no chip")
        #expect(chip(.waitingForHeadroom)?.text == "Preparing…")
    }

    /// After two failed tries the popover changes and offers the self-test (and Compatibility mode where advised).
    @Test func noExtraRangeChangesAfterTwoTries() {
        let first = ChipModel.noExtraRange(failedTries: 1, context: ChipContext(language: english))
        #expect(first.explanation == "macOS didn’t make extra range available. This can happen right after waking up, or when HDR is off.")
        #expect(first.actions == [.tryAgain, .learnMore])
        #expect(first.helpAnchor == "no-extra-range")
        let again = ChipModel.noExtraRange(failedTries: 2, context: ChipContext(language: english))
        #expect(again.explanation == "macOS still didn’t make extra range available.")
        #expect(again.actions == [.tryAgain, .runSelfTest, .learnMore])
        let advised = ChipModel.noExtraRange(failedTries: 2, context: ChipContext(compatibilityAdvised: true, language: english))
        #expect(advised.actions == [.tryAgain, .runSelfTest, .useCompatibilityMode, .learnMore])
    }

    /// A dim-only display shows its verdict badge as a neutral chip with the verdict's sentence and fix.
    @Test func aDimOnlyVerdictIsANeutralChip() throws {
        let model = try #require(chip(.notSupported(.turnOnHDR)))
        #expect(model.text == "HDR is off" && model.color == .neutral && model.symbol == .display)
        #expect(model.actions == [.openSystemSettings])
        #expect(model.explanation.hasPrefix("Turn on High Dynamic Range for this display in Displays settings"))
    }

    /// The chip skips global reasons and the trip the banner already names for this display.
    @Test func theChipIsTheFirstPerDisplayReasonTheBannerDoesNotSay() {
        let reasons: [LimitReason] = [.lowPowerMode, .tripped(.oscillation), .headroom]
        #expect(ChipModel.chipReason(in: reasons, display: Self.display, banner: nil) == .tripped(.oscillation))
        #expect(ChipModel.chipReason(in: reasons, display: Self.display, banner: .flickerStop(display: Self.display))
                == .headroom)
        let other = DisplayKey(rawValue: "B")
        #expect(ChipModel.chipReason(in: reasons, display: Self.display, banner: .flickerStop(display: other))
                == .tripped(.oscillation), "a stop on another display keeps this card's chip")
        #expect(ChipModel.chipReason(in: [.tripped(.foreignTableAtLaunch)], display: Self.display,
                                     banner: .foreignTableAtLaunch) == nil)
        #expect(ChipModel.chipReason(in: [.masterOff, .shielded], display: Self.display, banner: nil) == nil)
    }

    /// The chip of a display's status: decision, phase, failed tries.
    @Test func theChipOfAStatus() throws {
        let decision = DisplayDecision(key: Self.display, target: .boost(gain: 1.4), reasons: [.focusOff, .headroom],
                                       eligibility: EligibilityResult(verdict: .supported(safeGain: 1.667, peakGain: 2.587),
                                                                      advisories: [], defaultBoostEnabled: true,
                                                                      defaultMechanism: .table),
                                       mechanism: .table, domain: .encoded, requestedGain: 1.6)
        let status = DisplayStatus(key: Self.display, name: "Built-in Display", phase: .boosted, decision: decision,
                                   appliedGain: 1.4, appliedFactor: 1.15, mechanism: .table, strategy: nil, lastReading: nil,
                                   sdrWhite: nil)
        let context = ChipContext.of(status, facts: nil, language: english)
        let model = try #require(ChipModel.make(for: status, banner: .focusOff, context: context))
        #expect(model.text == "Limited by macOS")
        #expect(model.explanation.hasPrefix("macOS allows ×1.40 right now."))
    }

    /// Every English chip fits its line: 280 pt (DESIGN.md §5.7, §16).
    @Test(arguments: everyReason) func everyChipFitsTheCard(reason: LimitReason) {
        guard let model = chip(reason) else { return }
        let width = OverbrightFont.chip.width(of: model.text) + 12 + Space.xs + 2 * Space.m
        #expect(width <= StatusChip.maximumWidth, "\(model.text): \(width) pt")
    }
}
