// OverbrightFillLight/Window/SystemFillLightSurfaces.swift — the real frame windows. ARCHITECTURE.md §7.6, §8.5
// (`--qa-simulate`: SDR stand-ins for every EDR surface), §10.9, D24 (developing never changes display state).
// Thread: main.
import AppKit
import CoreGraphics
import OverbrightCore

/// Makes `FillLightWindow`s: tagged `CALayer` colour on macOS 26+, a clear-only `CAMetalLayer` on 14–25, SDR when the
/// display has no Metal device. Constructing it does nothing; a window appears only when the controller applies a
/// style to a surface it made.
public final class SystemFillLightSurfaces: FillLightSurfaceFactory {
    /// Real EDR windows, or SDR stand-ins.
    public nonisolated enum Mode: Hashable, Sendable {
        /// The app: EDR where the display has extra range.
        case live
        /// `--qa-simulate`: never EDR, and a simulated display without a real screen uses the main screen (and
        /// counts it as its own, so moving between real screens never removes it).
        case sdrStandIn
    }

    /// The mode this factory makes windows in.
    public let mode: Mode
    /// Frame windows ordered in now.
    public private(set) var openWindowCount = 0
    private let time: any TimeSource

    /// A factory; `time` paces the Metal path's first-present retry.
    public init(mode: Mode = .live, time: any TimeSource = SystemTimeSource()) {
        self.mode = mode
        self.time = time
    }

    /// The colour path this macOS offers: tagged layers on 26+, the Metal clear on 14–25.
    public static var preferredRendering: FillLightRendering {
        if #available(macOS 26.0, *) { .taggedLayer } else { .metalClear }
    }

    /// A window for `display`, not ordered in yet.
    public func makeSurface(on display: DisplayRef) throws -> any FillLightSurface {
        let standIn = mode == .sdrStandIn
        let id = display.id
        let screenNow: @MainActor () -> NSScreen? = { ScreenLookup.screen(for: id) ?? (standIn ? NSScreen.main : nil) }
        // A simulated display without a real screen shows on the main screen, whose ID is not its own: the stand-in
        // reports its own display for any screen then, so a screen change never removes it as "left its display".
        let displayIDOf: @MainActor (NSScreen?) -> CGDirectDisplayID? = { screen in
            if standIn, ScreenLookup.screen(for: id) == nil { return id }
            return screen.flatMap(ScreenLookup.displayID(of:))
        }
        guard let screen = screenNow() else { throw FillLightError.noScreen(id) }
        let rendering: FillLightRendering = standIn ? .sdr : Self.preferredRendering
        return FillLightWindow(display: display, screen: screen, screenNow: screenNow, displayIDOf: displayIDOf,
                               rendering: rendering, time: time) { [weak self] orderedIn in
            self?.openWindowCount += orderedIn ? 1 : -1
        }
    }
}
