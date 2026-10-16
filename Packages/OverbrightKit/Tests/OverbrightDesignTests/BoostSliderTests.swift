// OverbrightDesignTests/BoostSliderTests.swift — the level slider (DESIGN.md §5.5, §13.2; ARCHITECTURE.md §5.3): the
// detent, the shown ticks, the allowed-now marker, keyboard steps in stops that never cross Standard, ⌥ and VoiceOver
// named stops in canonical units, snapping and its haptics, disabled halves, and the drawing (warm only while extra
// light is on screen). ARCHITECTURE.md §10.11 Acceptance.
import OverbrightCore
import OverbrightPolicy
import SwiftUI
import Testing
@testable import OverbrightDesign

@Suite struct BoostSliderTests {
    /// M4 Max built-in: Safe top ×1.667, Peak ×2.587 (ARCHITECTURE.md §5.3).
    nonisolated static let safeTop = 1.667, peakTop = 2.587
    nonisolated static let allPresets: [LevelPreset] = [.indoor, .brightRoom, .sunlight, .max]

    private func model(top: Double = safeTop, allowed: Double? = nil, presets: [LevelPreset] = allPresets,
                       dim: Bool = true, half: BoostHalfState = .active) -> BoostSliderModel {
        BoostSliderModel(top: top, allowedNow: allowed, presets: presets, dimEnabled: dim, boostHalf: half)
    }

    // MARK: Geometry

    @Test func theDetentIsTheCentreOfTheTrack() {
        #expect(BoostSliderModel.fraction(of: .standard) == 0.5)
        #expect(BoostSliderModel.fraction(of: LevelPosition(-1)) == 0)
        #expect(BoostSliderModel.fraction(of: LevelPosition(1)) == 1)
        #expect(BoostSliderModel.level(atFraction: 0.75) == LevelPosition(0.5))
        #expect(BoostSliderTrack.width == 240)
    }

    @Test func ticksSitAtTheShownPresetsOnTheBoostHalfOnly() {
        #expect(model().tickLevels.map(\.value) == [0.25, 0.5, 0.75, 1])
        // MSI OLED in Safe shows Bright room and Max only (§5.3).
        let oled = PresetVisibility.visiblePresets(top: 1.3)
        #expect(model(top: 1.3, presets: oled).tickLevels.map(\.value) == [0.5, 1])
        #expect(model(half: .unavailable(reason: "HDR is off")).tickLevels.isEmpty)
        #expect(model(presets: [.standard, .max]).tickLevels.map(\.value) == [1])
    }

    // MARK: The allowed-now marker

    @Test func theMarkerSitsWhereTheThumbStopsNow() throws {
        let marker = try #require(model(top: Self.peakTop, allowed: 1.55).markerLevel)
        #expect(abs(marker.value - log(1.55) / log(Self.peakTop)) < 1e-9)
        #expect(abs(LevelMapping.requestedGain(for: marker, top: Self.peakTop) - 1.55) < 1e-9)
    }

    @Test func theMarkerHidesWithoutAReadingOrALimit() {
        #expect(model(allowed: nil).markerLevel == nil, "no reading")
        #expect(model(allowed: 2.0).markerLevel == nil, "macOS allows more than the top")
        #expect(model(allowed: 1.4, half: .inactive).markerLevel == nil, "off or paused")
        #expect(model(allowed: 1.4, half: .switchedOff).markerLevel == nil, "extra brightness off")
        #expect(model(allowed: 1.4).markerLevel != nil)
    }

    // MARK: Halves

    @Test func anUnavailableBoostHalfStopsTheThumbAtTheDetent() {
        let blocked = model(half: .unavailable(reason: "HDR is off"))
        #expect(!blocked.boostEnabled)
        #expect(blocked.boostHalfHatched)
        #expect(blocked.range == -1...0)
        #expect(blocked.clamped(LevelPosition(0.6)) == .standard)
        #expect(blocked.level(after: .stepTowardBoost, from: .standard) == .standard)
        #expect(blocked.level(after: .end, from: .standard) == .standard)
        // A Safe top below ×1.05 disables the half too.
        #expect(!model(top: 1.04).boostEnabled)
    }

    @Test func aDisabledDimHalfStopsTheThumbAtTheDetent() {
        let noDim = model(dim: false)
        #expect(noDim.range == 0...1)
        #expect(noDim.level(after: .stepTowardDim, from: .standard) == .standard)
        #expect(!noDim.namedStops.contains { $0.isDim })
    }

    @Test func aSwitchedOffHalfIsHatchedButMovable() {
        let off = model(half: .switchedOff)
        #expect(off.boostEnabled, "moving past the detent turns extra brightness on")
        #expect(off.boostHalfHatched)
        #expect(!off.boostFillIsWarm)
    }

    @Test func onlyExtraLightOnScreenIsWarm() {
        #expect(model(half: .active).boostFillIsWarm)
        #expect(!model(half: .inactive).boostFillIsWarm)
        #expect(!model(half: .switchedOff).boostFillIsWarm)
        #expect(!model(half: .unavailable(reason: "x")).boostFillIsWarm)
    }

    // MARK: Keyboard steps

    /// ← / → move by 1/12 stop of light.
    @Test func arrowStepsAreATwelfthOfAStop() {
        let m = model()
        let up = m.level(after: .stepTowardBoost, from: LevelPosition(0.3))
        let delta = StepMath.stops(at: up, top: Self.safeTop) - StepMath.stops(at: LevelPosition(0.3), top: Self.safeTop)
        #expect(abs(delta - 1.0 / 12) < 1e-9)
        let down = m.level(after: .stepTowardDim, from: LevelPosition(-0.6))
        let dimDelta = StepMath.stops(at: down, top: Self.safeTop) - StepMath.stops(at: LevelPosition(-0.6), top: Self.safeTop)
        #expect(abs(dimDelta + 1.0 / 12) < 1e-9)
    }

    /// A key step never crosses Standard: it stops there, and the next press continues past it.
    @Test func aStepNeverCrossesStandard() {
        let m = model()
        let nearDetent = LevelPosition(-0.05)
        let first = m.level(after: .stepTowardBoost, from: nearDetent)
        #expect(first == .standard)
        #expect(m.level(after: .stepTowardBoost, from: first).isBoost)
        #expect(m.level(after: .stepTowardDim, from: LevelPosition(0.05)) == .standard)
    }

    /// ARCHITECTURE.md §5.3 "Steps per class": arrow presses from Standard to the top.
    @Test(arguments: [(safeTop, 9), (peakTop, 17), (1.3, 5), (1.704, 10), (2.0, 12)])
    func arrowPressesToTheTop(top: Double, presses: Int) {
        let m = model(top: top)
        var level = LevelPosition.standard, count = 0
        while level.value < 1, count < 100 { level = m.level(after: .stepTowardBoost, from: level); count += 1 }
        #expect(count == presses, "top ×\(top)")
    }

    @Test func sixtyEightPressesDimToTheFloor() {
        let m = model()
        var level = LevelPosition.standard, count = 0
        while level.value > -1, count < 200 { level = m.level(after: .stepTowardDim, from: level); count += 1 }
        #expect(count == 68)
        #expect(abs(LevelMapping.dimLight(for: level) - 0.02) < 1e-9)
    }

    @Test func homeIsStandardAndEndIsMax() {
        #expect(model().level(after: .home, from: LevelPosition(0.7)) == .standard)
        #expect(model().level(after: .end, from: LevelPosition(-0.7)) == LevelPosition(1))
    }

    @Test func scrollNotchesStepLikeArrows() {
        let m = model()
        #expect(m.step(from: LevelPosition(0.3), by: 1) == m.level(after: .stepTowardBoost, from: LevelPosition(0.3)))
        #expect(m.step(from: LevelPosition(0.3), by: 0) == LevelPosition(0.3))
        // Three notches from just below Standard stop at Standard (never crossing in one move).
        #expect(m.step(from: LevelPosition(-0.1), by: 3) == .standard)
    }

    // MARK: Named stops (⌥-arrows, VoiceOver)

    /// Standard, the shown presets and 50 %, 25 %, 10 %, 5 %, 2 % of Standard light (§5.3 positions).
    @Test func namedStopsAreTheDetentThePresetsAndTheDimStops() {
        let stops = model().namedStops.map(\.value)
        let expected = [-1, -0.899, -0.809, -0.660, -0.500, 0, 0.25, 0.5, 0.75, 1]
        #expect(stops.count == expected.count)
        for (stop, value) in zip(stops, expected) { #expect(abs(stop - value) < 0.0015, "\(stop) vs \(value)") }
    }

    @Test func optionArrowsJumpBetweenNamedStops() {
        let m = model()
        #expect(m.level(after: .nextStop, from: .standard) == LevelPreset.indoor.position)
        #expect(m.level(after: .nextStop, from: LevelPosition(0.3)) == LevelPreset.brightRoom.position)
        #expect(abs(m.level(after: .previousStop, from: .standard).value + 0.5) < 0.001)
        #expect(m.level(after: .nextStop, from: LevelPosition(1)) == LevelPosition(1), "Max is the last stop")
    }

    /// VoiceOver's increment and decrement move between named stops; the value is the canonical text.
    @Test func voiceOverAdjustsBetweenNamedStopsInCanonicalUnits() {
        let m = model()
        var level = LevelPosition.standard
        level = m.adjusted(level, increment: true)
        #expect(level == LevelPreset.indoor.position)
        level = m.adjusted(level, increment: true)
        #expect(level == LevelPreset.brightRoom.position)
        let value = ValueText.forLevel(level, top: Self.safeTop, presets: Self.allPresets, isEstimate: false, in: english)
        #expect(value.text == "Bright room · ×1.29")
        #expect(value.accessibilityText == "Bright room, 1.29 times")
        let estimate = ValueText.forLevel(level, top: Self.safeTop, presets: Self.allPresets, isEstimate: true, in: english)
        #expect(estimate.accessibilityText == "Bright room, about 1.29 times, not calibrated")
        level = m.adjusted(.standard, increment: false)
        #expect(ValueText.forLevel(level, top: Self.safeTop, presets: Self.allPresets, isEstimate: false, in: english).text
                == "Dimmed · 50%")
        level = m.adjusted(level, increment: false)
        #expect(ValueText.forLevel(level, top: Self.safeTop, presets: Self.allPresets, isEstimate: false, in: english)
                .accessibilityText == "Dimmed, 25%")
        #expect(ValueText.forLevel(.standard, top: Self.safeTop, presets: Self.allPresets, isEstimate: true, in: english).text
                == "Standard")
    }

    @Test func theAccessibilityLabelNamesTheDisplay() {
        #expect(BoostSlider.label("Built-in Display", in: english) == "Level, \u{2068}Built-in Display\u{2069}")
        #expect(BoostSlider.extraRangeLabel(in: english) == "Extra range")
        let range = ValueText.extraRange(allowed: 1.55, peak: 2.6, in: english)
        #expect(range.text == "macOS allows ×1.55 now. This display can reach ×2.6 at most.")
        #expect(range.accessibilityText == "macOS allows 1.55 times now. This display can reach 2.6 times at most.")
    }

    // MARK: Snapping and haptics

    @Test func aSlowDragSettlesIntoTheDetentOrATick() {
        let m = model()
        #expect(m.dragged(toFraction: BoostSliderModel.fraction(of: LevelPosition(0.52)), speed: 0.2) == LevelPosition(0.5))
        #expect(m.dragged(toFraction: BoostSliderModel.fraction(of: LevelPosition(-0.02)), speed: 0.2) == .standard)
        #expect(abs(m.dragged(toFraction: BoostSliderModel.fraction(of: LevelPosition(0.6)), speed: 0.2).value - 0.6) < 1e-9)
    }

    @Test func aFastDragPassesThrough() {
        let m = model()
        let fraction = BoostSliderModel.fraction(of: LevelPosition(0.52))
        #expect(abs(m.dragged(toFraction: fraction, speed: 5).value - 0.52) < 1e-9)
    }

    @Test func aDragStopsAtADisabledHalf() {
        #expect(model(half: .unavailable(reason: "x")).dragged(toFraction: 1, speed: 0) == .standard)
    }

    /// `.alignment` when the thumb settles into Standard, `.levelChange` when it crosses or settles on a preset.
    @Test func hapticsMarkTheDetentAndThePresets() {
        let m = model()
        #expect(m.haptic(from: LevelPosition(0.02), to: .standard) == .alignment)
        #expect(m.haptic(from: LevelPosition(0.2), to: LevelPosition(0.3)) == .levelChange, "crosses Indoor")
        #expect(m.haptic(from: LevelPosition(0.45), to: LevelPosition(0.5)) == .levelChange, "settles on Bright room")
        #expect(m.haptic(from: LevelPosition(0.5), to: LevelPosition(0.55)) == nil, "leaving a tick")
        #expect(m.haptic(from: LevelPosition(0.6), to: LevelPosition(0.7)) == nil)
        #expect(m.haptic(from: LevelPosition(-0.3), to: LevelPosition(-0.4)) == nil, "no ticks on the dim half")
        #expect(m.haptic(from: .standard, to: .standard) == nil)
    }

    @Test func smallGainIsFlaggedBelowTimesOnePointThree() {
        #expect(model(top: 1.2, presets: [.max]).isSmallGain)
        #expect(!model(top: 1.3).isSmallGain)
        #expect(ValueText.smallGain(in: english) == "small gain on this display")
    }

    // MARK: Value tag and VoiceOver defaults

    /// The tag sits over the thumb but never past an end of the 240-pt track: at Max and at the dim floor it shifts
    /// inward, so the panel cannot clip it (a ~95-pt "Max · ≈ ×2.59" used to end 26 pt past the slider).
    @Test func theValueTagStaysInsideTheTrack() {
        let track = BoostSliderTrack.width
        #expect(BoostSliderValueTag.center(thumbX: 120, tagWidth: 95, trackWidth: track) == 120, "centred mid-track")
        #expect(BoostSliderValueTag.center(thumbX: track, tagWidth: 95, trackWidth: track) == track - 47.5, "at Max")
        #expect(BoostSliderValueTag.center(thumbX: 0, tagWidth: 95, trackWidth: track) == 47.5, "at the dim floor")
        #expect(BoostSliderValueTag.center(thumbX: 230, tagWidth: 40, trackWidth: track) == 220)
        #expect(BoostSliderValueTag.center(thumbX: 200, tagWidth: track, trackWidth: track) == track / 2, "a full-width tag")
        for x in stride(from: 0.0, through: track, by: 10) {
            for width in [30.0, 95, 180, 240] {
                let center = BoostSliderValueTag.center(thumbX: x, tagWidth: width, trackWidth: track)
                #expect(center - width / 2 >= 0 && center + width / 2 <= track, "x \(x), width \(width)")
            }
        }
    }

    /// Without `.spokenValue`, VoiceOver still hears canonical units when the host shows the canonical text, and the
    /// host's own words (a guard) otherwise (DESIGN.md §5.5, §12.7).
    @Test func voiceOverHearsTheSpokenFormByDefault() {
        let level = LevelPreset.brightRoom.position
        func spoken(_ shown: String, at level: LevelPosition = LevelPreset.brightRoom.position) -> String {
            BoostSlider.spoken(shown, at: level, top: Self.safeTop, presets: Self.allPresets, in: english)
        }
        let estimate = ValueText.forLevel(level, top: Self.safeTop, presets: Self.allPresets, isEstimate: true, in: english)
        #expect(spoken(estimate.text) == "Bright room, about 1.29 times, not calibrated")
        let calibrated = ValueText.forLevel(level, top: Self.safeTop, presets: Self.allPresets, isEstimate: false,
                                            in: english)
        #expect(spoken(calibrated.text) == "Bright room, 1.29 times")
        let dimmed = LevelMapping.position(forDimLight: 0.25)
        let dimText = ValueText.forLevel(dimmed, top: Self.safeTop, presets: Self.allPresets, isEstimate: false, in: english)
        #expect(spoken(dimText.text, at: dimmed) == dimText.accessibilityText)
        #expect(spoken("Standard", at: .standard) == "Standard")
        #expect(spoken("Paused: Low Power Mode") == "Paused: Low Power Mode", "a guard is read as shown")
    }

    /// Each half's help tag is its own: an unavailable boost half says why over the boost half only, a disabled dim
    /// half says why over the dim half only, and VoiceOver hears both reasons as the hint (DESIGN.md §5.5).
    @Test func eachHalfHasItsOwnHelpTag() {
        let noDim = "macOS doesn’t let apps adjust this display."
        let blocked = model(half: .unavailable(reason: "HDR is off"))
        #expect(BoostSlider.helpTags(blocked, dimReason: noDim, extraRange: nil) == (nil, "HDR is off"), "dim half works")
        let both = model(dim: false, half: .unavailable(reason: "HDR is off"))
        #expect(BoostSlider.helpTags(both, dimReason: noDim, extraRange: nil) == (noDim, "HDR is off"))
        #expect(BoostSlider.disabledHint(both, dimReason: noDim, in: english) == "HDR is off \(noDim)")
        #expect(BoostSlider.disabledHint(model(dim: false), dimReason: noDim, in: english) == noDim)
        #expect(BoostSlider.disabledHint(model(), dimReason: noDim, in: english).isEmpty, "both halves work")
        // While the marker shows, the boost half's tag says what macOS allows now; nothing without a marker.
        let limited = model(top: Self.peakTop, allowed: 1.55)
        let range = BoostSlider.extraRange(limited, given: nil)
        #expect(range?.text == ValueText.extraRange(allowed: 1.55, peak: nil).text)
        #expect(BoostSlider.helpTags(limited, dimReason: nil, extraRange: range) == (nil, range?.text))
        #expect(BoostSlider.helpTags(model(), dimReason: nil, extraRange: range) == (nil, nil), "no marker")
    }

    /// Without `.extraRange`, VoiceOver's "Extra range" still says what macOS allows while extra light is on screen
    /// with a reading; the host's text (with the Peak sentence) wins.
    @Test func extraRangeHasADefault() {
        #expect(BoostSlider.extraRange(model(allowed: 1.4), given: nil)?.accessibilityText
                == ValueText.extraRange(allowed: 1.4, peak: nil).accessibilityText)
        #expect(BoostSlider.extraRange(model(allowed: nil), given: nil) == nil, "no reading")
        #expect(BoostSlider.extraRange(model(allowed: 1.4, half: .inactive), given: nil) == nil, "off or paused")
        let host = ValueText.extraRange(allowed: 1.4, peak: 2.6, in: english)
        #expect(BoostSlider.extraRange(model(allowed: 1.4), given: host) == host)
    }

    /// While a guard pauses the display the tag names it; a user pause, a cap and per-display reasons do not
    /// (DESIGN.md §5.5 "Paused").
    @Test func theValueTagNamesTheGuard() {
        #expect(ValueText.guarded(by: .lowPowerMode, in: english)?.text == "Paused: Low Power Mode")
        #expect(ValueText.guarded(by: .battery(percent: 12, threshold: 20), in: english)?.text
                == "Paused: battery below 20%")
        #expect(ValueText.guarded(by: .onBattery, in: english)?.text == "Paused: on battery")
        #expect(ValueText.guarded(by: .thermalCritical, in: english)?.text == "Paused: Mac is hot")
        #expect(ValueText.guarded(by: .outsideSchedule, in: english)?.text == "Paused: outside set hours")
        #expect(ValueText.guarded(by: .focusOff, in: english)?.accessibilityText == "Off for this Focus")
        for reason in [LimitReason.userPaused(until: Date(timeIntervalSince1970: 0)), .thermalSerious, .fullScreenVideo,
                       .masterOff, .headroom, .boostNotEnabled] {
            #expect(ValueText.guarded(by: reason, in: english) == nil, "\(reason)")
        }
    }
}

/// The slider drawn: warm only while extra light is on screen, the marker, the hatch.
@MainActor @Suite struct BoostSliderRenderTests {
    private static let size = CGSize(width: 300, height: 40)

    private func slider(_ level: Double, allowed: Double? = nil, half: BoostHalfState) -> BoostSlider {
        BoostSlider(level: .constant(LevelPosition(level)), top: 2.587, allowedNow: allowed,
                    presets: [.indoor, .brightRoom, .sunlight, .max], dimEnabled: true, boostHalf: half,
                    accessibilityName: "Built-in Display", valueText: { _ in "" }, onCommit: { _ in })
    }

    @Test(arguments: [ColorScheme.light, .dark])
    func extraLightOnScreenIsWarm(scheme: ColorScheme) throws {
        let warm = OverbrightColor.boostWarm(dark: scheme == .dark, highContrast: false)
        let background: Color = scheme == .dark ? Color(white: 0.12) : .white
        let on = try render(slider(0.8, half: .active), size: Self.size, scheme: scheme, background: background)
        #expect(on.count { $0.isClose(to: warm) } > 100)
        let off = try render(slider(0.8, half: .inactive), size: Self.size, scheme: scheme, background: background)
        #expect(off.count { $0.isClose(to: warm) } == 0, "off or paused draws the hatch, never warm")
    }

    @Test func increaseContrastUsesTheStrongerWarm() throws {
        let theme = OverbrightTheme(increaseContrast: true)
        let pixels = try render(slider(0.8, half: .active), size: Self.size, theme: theme)
        let strong = OverbrightColor.boostWarm(dark: false, highContrast: true)
        #expect(pixels.count { $0.isClose(to: strong, tolerance: 0.04) } > 100)
    }

    /// The value tag drawn over a track 30 pt in from each side of a 300-pt canvas: at either end, in either direction
    /// and with the longest English text, its ink stays over the track (DESIGN.md §5.5; ARCHITECTURE.md §8.8 valueTag).
    @Test(arguments: [(0.0, LayoutDirection.leftToRight), (240, .leftToRight), (0, .rightToLeft), (240, .rightToLeft)])
    func theValueTagIsDrawnOverTheTrack(thumbX: Double, direction: LayoutDirection) throws {
        let track = Color.clear
            .frame(width: BoostSliderTrack.width, height: HitTarget.sliderThumb)
            .overlay(alignment: .topLeading) {
                BoostSliderValueTag(text: "Max · ≈ ×1.20 · small gain on this display", thumbX: thumbX)
            }
            .padding(.top, 50)
        let pixels = try render(track, size: CGSize(width: 300, height: 120), direction: direction)
        let ink = try #require(pixels.xRange { $0.r < 0.6 && $0.g < 0.6 && $0.b < 0.6 })
        #expect(ink.lowerBound >= 30 && ink.upperBound <= 270, "x \(thumbX) \(direction): ink at \(ink)")
        let short = try render(Color.clear.frame(width: BoostSliderTrack.width, height: HitTarget.sliderThumb)
            .overlay(alignment: .topLeading) { BoostSliderValueTag(text: "Max · ≈ ×2.59", thumbX: thumbX) }
            .padding(.top, 50), size: CGSize(width: 300, height: 120), direction: direction)
        let shortInk = try #require(short.xRange { $0.r < 0.6 && $0.g < 0.6 && $0.b < 0.6 })
        #expect(shortInk.lowerBound >= 30 && shortInk.upperBound <= 270, "x \(thumbX) \(direction): ink at \(shortInk)")
    }

    /// The marker stands where `allowedNow` puts the thumb's stop: ×1.55 of a ×2.587 top is 46 % of the boost half.
    @Test func theMarkerIsDrawnAtTheAllowedLevel() throws {
        let pixels = try render(slider(0.9, allowed: 1.55, half: .active), size: Self.size)
        let warm = OverbrightColor.boostWarm(dark: false, highContrast: false)
        let warmRange = try #require(pixels.xRange { $0.isClose(to: warm) })
        // The track starts 30 pt in (10 pt margin + 14-pt glyph + 6-pt gap); the detent is at 150.
        let markerX = 30 + 240 * (1 + log(1.55) / log(2.587)) / 2
        #expect(abs(warmRange.lowerBound - 150) < 2, "warm from the detent: \(warmRange)")
        // Beyond the marker the hatch replaces the warm fill, so the warm run ends at the marker.
        #expect(abs(warmRange.upperBound - markerX) < 3, "warm until the marker at \(markerX): \(warmRange)")
    }
}
