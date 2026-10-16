// OverbrightDesign/Tokens/OverbrightSymbol.swift — the allow-list of SF Symbols. DESIGN.md §13.1.
// Seam written by WP0a (ARCHITECTURE.md §10.0); WP9 owns it and `SymbolTests` (every symbol exists on macOS 14,
// none restricted, the moon used only for Focus). Raw values are the system symbol names.
import SwiftUI

/// Every SF Symbol Overbright draws. Views use `Image(symbol:)`, never a symbol name string.
public nonisolated enum OverbrightSymbol: String, CaseIterable, Sendable {
    // Levels
    /// Boosting.
    case sunMax = "sun.max"
    /// Boosting (filled).
    case sunMaxFill = "sun.max.fill"
    /// Dimmed, and the dim end of the slider.
    case sunMin = "sun.min"
    /// Dimmed (filled).
    case sunMinFill = "sun.min.fill"
    // Focus only
    /// The Focus filter (never for dimming).
    case moonFill = "moon.fill"
    // Displays
    /// An external display.
    case display = "display"
    /// Several displays.
    case display2 = "display.2"
    /// The built-in display.
    case laptopComputer = "laptopcomputer"
    // Guards
    /// Battery below a level.
    case battery25Percent = "battery.25percent"
    /// Charging.
    case battery100PercentBolt = "battery.100percent.bolt"
    /// On the adapter.
    case powerPlugFill = "powerplug.fill"
    /// Low Power Mode.
    case boltFill = "bolt.fill"
    /// Warm.
    case thermometerMedium = "thermometer.medium"
    /// Hot.
    case thermometerHigh = "thermometer.high"
    /// The auto-off timer.
    case timer = "timer"
    /// The schedule.
    case clockFill = "clock.fill"
    /// Full-screen video and auto-pause.
    case playRectangleFill = "play.rectangle.fill"
    /// Games.
    case gameControllerFill = "gamecontroller.fill"
    /// OLED idle.
    case zzz = "zzz"
    /// Locked.
    case lockFill = "lock.fill"
    // States
    /// Paused.
    case pauseFill = "pause.fill"
    /// Paused (circled).
    case pauseCircleFill = "pause.circle.fill"
    /// A warning.
    case exclamationMarkTriangleFill = "exclamationmark.triangle.fill"
    /// Attention.
    case exclamationMarkCircleFill = "exclamationmark.circle.fill"
    /// A checkmark.
    case checkmark = "checkmark"
    /// Done.
    case checkmarkCircleFill = "checkmark.circle.fill"
    /// Close.
    case xmark = "xmark"
    /// Preparing.
    case hourglass = "hourglass"
    // Chrome
    /// The overflow menu.
    case ellipsis = "ellipsis"
    /// The overflow menu (circled).
    case ellipsisCircle = "ellipsis.circle"
    /// Disclosure.
    case chevronDown = "chevron.down"
    /// Disclosure.
    case chevronRight = "chevron.right"
    /// Settings.
    case gearshapeFill = "gearshape.fill"
    /// Information.
    case infoCircleFill = "info.circle.fill"
    /// Help.
    case questionMarkCircle = "questionmark.circle"
    /// Shortcuts.
    case keyboard = "keyboard"
    /// Advanced.
    case wrenchAndScrewdriverFill = "wrench.and.screwdriver.fill"
    /// Self-Test.
    case stethoscope = "stethoscope"
    /// Linked levels.
    case link = "link"
    /// Copy.
    case docOnDoc = "doc.on.doc"
    /// Save.
    case squareAndArrowDown = "square.and.arrow.down"
    /// Undo.
    case arrowCounterclockwise = "arrow.counterclockwise"
    /// Try again.
    case arrowClockwise = "arrow.clockwise"
    /// Quit.
    case power = "power"
    // Fill Light
    /// Fill Light.
    case personCropRectangle = "person.crop.rectangle"
    /// The camera rule.
    case cameraFill = "camera.fill"
}

public extension Image {
    /// The SF Symbol `symbol`.
    init(symbol: OverbrightSymbol) { self.init(systemName: symbol.rawValue) }
}
