// OverbrightAppShellTests/HUDSnapshotTests.swift — a snapshot of the HUD for every HUD state of DESIGN.md §5.13
// (`hud-boost` … `hud-automation-back`) and of the Keep-this-level prompt (`keep-level`), in Light, Dark and Increase
// Contrast (ARCHITECTURE.md §9.1: in-process `cacheDisplay` in a borderless window that is never ordered in). Design's
// `HUDText` gives the words once WP9's copy lands; until then DESIGN.md §12.9's English stands in. PNGs are written
// only with `OVERBRIGHT_SNAPSHOT_DIR=<dir>` (into `<dir>/AppShell/`).
import AppKit
import OverbrightCore
import OverbrightDesign
import OverbrightPanelUI
import SwiftUI
import Testing
@testable import OverbrightAppShell

@MainActor @Suite struct HUDSnapshotTests {
    enum Appearance: String, CaseIterable {
        case light, dark, increaseContrast

        var nsAppearance: NSAppearance? {
            switch self {
            case .light: NSAppearance(named: .aqua)
            case .dark: NSAppearance(named: .darkAqua)
            case .increaseContrast: NSAppearance(named: .accessibilityHighContrastAqua)
            }
        }
    }

    /// DESIGN.md §12.9's words for a change, standing in for Design's builder.
    static func standIn(_ change: LevelChange, _ status: BoostStatus) -> HUDText {
        let isDimmed = status.displays.contains { $0.phase == .dimmed }
        func reason(_ text: String, _ symbol: OverbrightSymbol) -> HUDText {
            HUDText(symbol: symbol, displayName: nil, value: nil, reason: text, announcement: text)
        }
        switch change.kind {
        case .level:
            let value = !status.isOn ? "Off" : isDimmed ? "Dimmed · 25 %"
                : (status.displays.first?.appliedGain ?? 1) > 1 ? "Bright room · ×1.29" : "Standard"
            return HUDText(symbol: isDimmed ? .sunMin : .sunMaxFill,
                           displayName: change.display == nil ? nil : status.displays.first?.name, value: value,
                           reason: nil, announcement: value)
        case .preparing: return reason("Preparing…", .hourglass)
        case .blocked: return reason("Paused: Low Power Mode", .pauseFill)
        case .automationStopped(.battery): return reason("Paused: battery below 20 %", .pauseFill)
        case .automationStopped(.thermalSerious): return reason("Limited: Mac is warm", .thermometerMedium)
        case .automationStopped(.outsideSchedule): return reason("Paused: outside set hours", .pauseFill)
        case .automationStopped: return reason("Paused: Low Power Mode", .pauseFill)
        case .automationResumed: return reason("Extra brightness is back", .sunMaxFill)
        case .timerEnded: return reason("Off: timer ended", .timer)
        }
    }

    private func render(_ view: some View, _ appearance: Appearance) throws -> NSBitmapImageRep {
        let host = NSHostingView(rootView: view.background(Color(nsColor: .windowBackgroundColor))
            .overbrightThemeRoot(OverbrightTheme(increaseContrast: appearance == .increaseContrast)))
        host.appearance = appearance.nsAppearance
        host.frame = CGRect(origin: .zero, size: host.fittingSize)
        let window = NSWindow(contentRect: host.frame, styleMask: [.borderless], backing: .buffered, defer: true)
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        let rep = try #require(host.bitmapImageRepForCachingDisplay(in: host.bounds))
        host.cacheDisplay(in: host.bounds, to: rep)
        window.contentView = nil
        return rep
    }

    private func hasInk(_ rep: NSBitmapImageRep) -> Bool {
        guard let background = rep.colorAt(x: 1, y: 1) else { return false }
        for x in stride(from: 0, to: rep.pixelsWide, by: 2) {
            for y in stride(from: 0, to: rep.pixelsHigh, by: 2) {
                if let color = rep.colorAt(x: x, y: y),
                   abs(color.brightnessComponent - background.brightnessComponent) > 0.3 { return true }
            }
        }
        return false
    }

    @Test(arguments: Appearance.allCases)
    func everyHUDStateRenders(_ appearance: Appearance) throws {
        let directory = SnapshotOutput.directory("AppShell")
        if let directory { try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true) }
        #expect(ScriptedStatuses.hudNames.count == 14)
        for name in ScriptedStatuses.hudNames {
            let services = try #require(ScriptedStatuses.services(named: name))
            let status = services.boost.status
            let rep: NSBitmapImageRep
            if let pending = status.pendingConfirmation {
                let model = LevelConfirmationPromptModel()
                model.secondsLeft = LevelConfirmationPromptController.seconds(until: pending.deadline,
                                                                      now: pending.deadline.addingTimeInterval(-10))
                rep = try render(LevelConfirmationPromptView(model: model, keep: {}, goBack: {}), appearance)
                #expect(rep.pixelsWide >= Int(HUDPlacement.promptSize.width), "\(name)")
            } else {
                let change = try #require(status.lastChange, "\(name)")
                let display = HUDContent.shownDisplay(for: change, underPointer: nil, status: status)
                let text = HUDContent.text(for: change, status: status, on: display, services: services)
                    ?? Self.standIn(change, status)
                let level = HUDContent.level(of: display, status: status, services: services)
                rep = try render(HUDView(text: text, level: level,
                                         isBoosting: HUDController.isBoosting(display, status: status)), appearance)
                #expect(rep.pixelsWide >= Int(HUDPlacement.size.width), "\(name)")
            }
            #expect(hasInk(rep), "\(name) \(appearance.rawValue): nothing drawn")
            if let directory, let data = rep.representation(using: .png, properties: [:]) {
                try data.write(to: directory.appending(path: "\(name)-\(appearance.rawValue).png"))
            }
        }
    }
}
