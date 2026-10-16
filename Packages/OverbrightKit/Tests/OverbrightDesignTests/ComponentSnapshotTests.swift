// OverbrightDesignTests/ComponentSnapshotTests.swift — opt-in gallery of every component in Light, Dark and Increase
// Contrast (ARCHITECTURE.md §9.1 "UI", §10.11 "component snapshots"). Writes PNGs for a human or a design QA script:
//
//   OVERBRIGHT_SNAPSHOT_DIR=/tmp/snapshots make test FILTER=ComponentSnapshotTests
//
// writes into /tmp/snapshots/Design. Never runs in CI (no directory set). Views are hosted in an off-screen window that
// is never ordered in (AppKit controls such as menus and progress indicators render only there), with the window's
// appearance set to Light or Dark; the welcome card is always the SDR stand-in.
import AppKit
import OverbrightCore
import OverbrightPolicy
import SwiftUI
import Testing
@testable import OverbrightDesign

nonisolated private let directory = SnapshotOutput.directory("Design")

@MainActor @Suite(.enabled(if: directory != nil, "set OVERBRIGHT_SNAPSHOT_DIR to write the gallery"))
struct ComponentSnapshotTests {
    private enum Variant: String, CaseIterable {
        case light, dark, contrastLight = "contrast-light", contrastDark = "contrast-dark"
        var dark: Bool { self == .dark || self == .contrastDark }
        var theme: OverbrightTheme { OverbrightTheme(increaseContrast: self == .contrastLight || self == .contrastDark) }
    }

    private static let top = 2.587
    private static let presets = PresetVisibility.visiblePresets(top: top)

    private func slider(_ level: Double, allowed: Double? = nil, half: BoostHalfState = .active, dim: Bool = true,
                        top: Double = top) -> some View {
        BoostSlider(level: .constant(LevelPosition(level)), top: top, allowedNow: allowed,
                    presets: PresetVisibility.visiblePresets(top: top), dimEnabled: dim, boostHalf: half,
                    accessibilityName: "Built-in Display",
                    valueText: { ValueText.forLevel($0, top: top, presets: Self.presets, isEstimate: true).text },
                    onCommit: { _ in })
    }

    private var scenes: [(String, CGSize, AnyView)] {
        let chips: [ChipModel] = [ChipModel.preparing(), ChipModel.noExtraRange(failedTries: 0, context: ChipContext())]
            + [LimitReason.headroom, .safeLimit, .oledLimit, .thermalSerious, .nearFullBrightnessOnly, .boostNotEnabled,
               .fullScreenVideo, .pausedApp(bundleID: "com.example.player"), .oledIdle, .tripped(.oscillation),
               .notSupported(.turnOnHDR)]
            .compactMap { ChipModel.make(reason: $0, phase: .boosted, failedTries: 0,
                                         context: ChipContext(allowedGain: 1.55, appName: "A Very Long Video Player Name")) }
        let banners: [Banner] = [.userPaused(until: Date(timeIntervalSince1970: 1_792_160_400)), .lowPowerMode,
                                 .battery(percent: 12, threshold: 20), .focusOff, .thermalCritical,
                                 .flickerStop(display: DisplayKey(rawValue: "A"))]
        return [
            ("slider-boosting", CGSize(width: 320, height: 60), AnyView(slider(0.5, allowed: 2.2))),
            ("slider-limited-by-macos", CGSize(width: 320, height: 60), AnyView(slider(0.75, allowed: 1.55))),
            ("slider-dimmed", CGSize(width: 320, height: 60), AnyView(slider(LevelMapping.position(forDimLight: 0.25).value))),
            ("slider-off", CGSize(width: 320, height: 60), AnyView(slider(0.5, half: .inactive))),
            ("slider-extra-brightness-off", CGSize(width: 320, height: 60), AnyView(slider(0, half: .switchedOff))),
            ("slider-unavailable", CGSize(width: 320, height: 60), AnyView(slider(0, half: .unavailable(reason: "HDR is off")))),
            ("slider-small-gain", CGSize(width: 320, height: 60), AnyView(slider(1, top: 1.2))),
            ("slider-no-dim", CGSize(width: 320, height: 60), AnyView(slider(0.3, dim: false))),
            ("slider-rtl", CGSize(width: 320, height: 60),
             AnyView(slider(0.5, allowed: 1.55).environment(\.layoutDirection, .rightToLeft))),
            ("chips", CGSize(width: 320, height: 520), AnyView(VStack(alignment: .leading, spacing: Space.s) {
                ForEach(Array(chips.enumerated()), id: \.offset) { _, chip in StatusChip(chip, actions: []) }
            })),
            ("banners", CGSize(width: 320, height: 520), AnyView(VStack(spacing: Space.m) {
                ForEach(Array(banners.enumerated()), id: \.offset) { _, banner in
                    PausedBanner(BannerModel.make(banner), primary: {}, secondary: nil)
                }
            })),
            ("footer-chips", CGSize(width: 320, height: 60), AnyView(HStack(spacing: Space.s) {
                GuardChip(.battery(.belowThreshold, threshold: 20), menu: [])
                GuardChip(.autoPause(anyRuleOn: true), menu: [])
                GuardChip(.timer(minutes: nil, remaining: nil), menu: [])
            })),
            ("readouts", CGSize(width: 320, height: 140), AnyView(VStack(alignment: .leading, spacing: Space.s) {
                ReadoutText(ReadoutValues(state: .off, appliedGain: 1, requestedGain: nil, nits: nil, preset: nil,
                                          isEstimate: true, dimPercent: nil))
                ReadoutText(ReadoutValues(state: .boost, appliedGain: 1.29, requestedGain: nil, nits: 775, preset: .brightRoom,
                                          isEstimate: false, dimPercent: nil))
                ReadoutText(ReadoutValues(state: .boost, appliedGain: 1.21, requestedGain: 1.47, nits: nil, preset: nil,
                                          isEstimate: true, dimPercent: nil))
                ReadoutText(ReadoutValues(state: .dim, appliedGain: 0.25, requestedGain: nil, nits: nil, preset: nil,
                                          isEstimate: false, dimPercent: 25))
            })),
            ("key-caps", CGSize(width: 200, height: 50), AnyView(HStack { KeyCap("⌃⌥⌘B"); KeyCap("⌃⌥⌘0") })),
            ("step-wedge", CGSize(width: 560, height: 180), AnyView(StepWedgeView(patches: [0.85, 0.9, 0.95, 1], surround: 0))),
            ("welcome-card", CGSize(width: 400, height: 220),
             AnyView(EDRPreviewSurface(gain: 1.29, divider: .constant(0.5), simulated: true))),
        ]
    }

    @Test func everyComponentInEveryVariant() throws {
        let dir = try #require(directory)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        for (name, size, view) in scenes {
            for variant in Variant.allCases {
                let image = try snapshot(view, size: size, variant: variant)
                try write(image, to: dir.appending(path: "\(name)-\(variant.rawValue).png"))
            }
        }
    }

    private func snapshot(_ view: AnyView, size: CGSize, variant: Variant) throws -> CGImage {
        let root = view
            .padding(Space.l)
            .frame(width: size.width, height: size.height)
            .background(Color(nsColor: .windowBackgroundColor))
            .overbrightThemeRoot(variant.theme)
        let host = NSHostingView(rootView: root)
        let window = NSWindow(contentRect: NSRect(origin: CGPoint(x: -30_000, y: -30_000), size: size),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.appearance = NSAppearance(named: variant.dark ? .darkAqua : .aqua)
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        host.layoutSubtreeIfNeeded()
        host.display()
        let rep = try #require(host.bitmapImageRepForCachingDisplay(in: host.bounds))
        host.cacheDisplay(in: host.bounds, to: rep)
        window.contentView = nil
        window.close()
        return try #require(rep.cgImage)
    }

    private func write(_ image: CGImage, to url: URL) throws {
        let data = try #require(NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]))
        try data.write(to: url)
    }
}
