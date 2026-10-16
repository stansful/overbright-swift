// OverbrightSignalsTests/Fixtures/WindowFixtures.swift — window lists from the owner's Mac. ARCHITECTURE.md §7.3, §10.8
// (fixtures: layers 0/24/2001/2004, the 30-pt menu bar window, the notch band).
// Recorded read-only on macOS 27.0.1 (26A434), Mac16,5, without Screen Recording permission: the MSI MPG322UX at
// 2560 × 1440 pt, the WindowServer (PID 415) owning the 2560 × 30 menu-bar window at layer 24; while locked, loginwindow
// (PID 419) frontmost with a display-sized window at layer 2004 and a 30000 × 30000 one at layer 2001; ordinary
// layer-0 windows of other apps. The notched built-in (1728 × 1117 pt, 32-pt notch band) lies to the MSI's left.
import CoreGraphics
import OverbrightCore
@testable import OverbrightSignals

enum WindowFixtures {
    typealias Window = FullScreenDetector.Window

    static let windowServer: Int32 = 415
    static let loginWindow: Int32 = 419
    static let windowManager: Int32 = 659
    static let chrome: Int32 = 3603
    static let editor: Int32 = 41105
    static let player: Int32 = 5000
    static let notes: Int32 = 5001
    static let ourPID: Int32 = 100
    static let dock: Int32 = 50
    static let shade: Int32 = 6000

    /// The notched built-in (main display, at the origin).
    static let builtIn = FullScreenDetector.Display(key: DisplayFixture.Keys.builtIn,
                                                    bounds: CGRect(x: 0, y: 0, width: 1728, height: 1117), notchBand: 32)
    /// The MSI to the built-in's right, tops aligned.
    static let msi = FullScreenDetector.Display(key: DisplayFixture.Keys.mpg322ux,
                                                bounds: CGRect(x: 1728, y: 0, width: 2560, height: 1440), notchBand: 0)
    /// The MSI alone at the origin (the lid-closed recording).
    static let msiAlone = FullScreenDetector.Display(key: DisplayFixture.Keys.mpg322ux,
                                                     bounds: CGRect(x: 0, y: 0, width: 2560, height: 1440), notchBand: 0)

    static func window(_ pid: Int32, _ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat,
                       layer: Int = 0, alpha: Double = 1) -> Window {
        Window(layer: layer, bounds: CGRect(x: x, y: y, width: width, height: height), ownerPID: pid, alpha: alpha)
    }

    /// The WindowServer's menu bar on `display` (30 pt on the MSI, the notch band's height on the built-in).
    static func menuBar(on display: FullScreenDetector.Display) -> Window {
        window(windowServer, display.bounds.minX, display.bounds.minY, display.bounds.width,
               display.notchBand > 0 ? display.notchBand : 30, layer: FullScreenDetector.menuBarLayer)
    }

    /// The recording on the MSI, unlocked: menu bar, an editor window and Stage Manager's strips.
    static let msiDesktop: [Window] = [
        menuBar(on: msiAlone),
        window(editor, 446, 169, 1601, 1244),
        window(windowManager, -7, 759, 66, 82),
        window(windowManager, 15, 666, 112, 138),
        window(chrome, 15, 666, 112, 138),
    ]

    /// The recording while locked: loginwindow's shield windows above everything.
    static let msiLocked: [Window] = [
        window(loginWindow, 0, 0, 2560, 1440, layer: 2004),
        window(loginWindow, -15000, -15000, 30000, 30000, layer: 2001),
    ] + msiDesktop

    /// A context with nothing special: `frontmost` in front, our PID and the Dock ignored.
    static func context(frontmost: Int32?, nonRegular: Set<Int32> = [], holders: Set<Int32> = []) -> FullScreenDetector.Context {
        FullScreenDetector.Context(frontmostPID: frontmost, ignoredPIDs: [ourPID, dock], nonRegularPIDs: nonRegular,
                                   displaySleepHolders: holders)
    }
}
