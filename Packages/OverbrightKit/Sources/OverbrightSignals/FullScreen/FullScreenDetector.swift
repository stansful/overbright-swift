// OverbrightSignals/FullScreen/FullScreenDetector.swift — "does display X show a full-screen window, and whose?"
// ARCHITECTURE.md §6.5, §7.1, §7.3, §10.8.
//
// Ported from Cranny's CrannyAppShell/Overlay/FullScreenDetector.swift (the owner's MIT code, verified there with a real
// native full-screen transition on macOS 27). There is no public API, so: a layer-0 window of a regular app covers the
// display (±1 pt; on a notched built-in it may start below the notch band) AND (its owner is frontmost OR the menu-bar
// window is gone from that display). Window bounds, layers, alpha and owner PIDs need no Screen Recording permission.
// Extended for Overbright:
// - Split View: two or more full-height, non-overlapping layer-0 windows tile ≥ 98 % of the display, menu bar absent;
// - only regular apps count (an allowlist: the PIDs NSWorkspace lists with the `.regular` activation policy), plus the
//   frontmost app; accessory and agent apps (overlay shades, other apps' overlays) and window owners NSWorkspace does
//   not list at all never count unless frontmost; our own PID and the Dock never count (our Compatibility overlay,
//   Fill Light and calibration windows are full-screen windows of ours);
// - the menu-bar window is matched by the WindowServer's PID, never by its owner name (names are localized); with
//   "Displays have separate Spaces" off only the main display has one, so on the others only the frontmost app's
//   window counts, exact or (on a notched built-in that is not the main display) below the notch band, and no Split
//   View (C-SIGNALS-5);
// - full-screen video: the covering window's owner holds a display-sleep assertion (`PlaybackAssertions`);
// - the displays that show the frontmost app's topmost layer-0 window (per-app rules pause only those, §6.5).
// The locked screen's loginwindow windows sit at layers 2001/2004 and never count.
// Thread: any. `evaluate` is pure; the one window-server read is `WindowListSnapshot.read(windowServerPID:)` (@concurrent).
import CoreGraphics
import OverbrightCore

/// The pure full-screen heuristic over one window list.
nonisolated enum FullScreenDetector {
    /// One on-screen window as `CGWindowListCopyWindowInfo` reports it (CG global coordinates: top-left origin).
    struct Window: Hashable, Sendable {
        /// `kCGWindowLayer` (0 = normal windows, 24 = the menu bar on macOS 27).
        var layer: Int
        /// `kCGWindowBounds`.
        var bounds: CGRect
        /// `kCGWindowOwnerPID`.
        var ownerPID: Int32
        /// `kCGWindowAlpha` (a fully transparent window never counts).
        var alpha: Double
    }

    /// One display in CG global coordinates, with the notch band height (0 without a notch).
    struct Display: Hashable, Sendable {
        /// The display.
        var key: DisplayKey
        /// `CGDisplayBounds`.
        var bounds: CGRect
        /// `NSScreen.safeAreaInsets.top` (the camera housing band of a notched built-in).
        var notchBand: CGFloat
    }

    /// Who is who in one evaluation.
    struct Context: Hashable, Sendable {
        /// `NSWorkspace.frontmostApplication`'s PID.
        var frontmostPID: Int32?
        /// Never count: our own process and the Dock.
        var ignoredPIDs: Set<Int32>
        /// Regular apps (`NSRunningApplication.activationPolicy == .regular`): only their windows count, and the
        /// frontmost app's.
        var regularPIDs: Set<Int32>
        /// Processes holding a display-sleep assertion (playing video or presenting).
        var displaySleepHolders: Set<Int32>
    }

    /// What is in front of one display.
    struct Front: Hashable, Sendable {
        /// A full-screen window (or a Split View) covers the display.
        var isFullScreen = false
        /// The covering window's owner (Split View: the frontmost app's tile, else the topmost tile).
        var ownerPID: Int32?
        /// The owner holds a display-sleep assertion.
        var isVideo = false
    }

    /// The outcome for every display.
    struct Result: Hashable, Sendable {
        /// Per display (every display passed in has an entry).
        var fronts: [DisplayKey: Front]
        /// Displays that show the frontmost app's topmost layer-0 window (empty: menu bar only).
        var frontmostDisplays: Set<DisplayKey>
        /// `SystemSnapshot.fullScreenDisplays`.
        var fullScreenDisplays: Set<DisplayKey> { Set(fronts.filter(\.value.isFullScreen).keys) }
        /// `SystemSnapshot.fullScreenVideoDisplays` (a subset of `fullScreenDisplays`).
        var fullScreenVideoDisplays: Set<DisplayKey> { Set(fronts.filter(\.value.isVideo).keys) }
    }

    /// How a window covers a display.
    enum Coverage: Hashable, Sendable {
        /// Exactly the display's bounds.
        case exact
        /// Everything below the notch band: full-screen apps that stay out of the camera housing.
        case belowBand
    }

    /// The menu-bar window layer (`kCGMainMenuWindowLevelKey`, 24 on macOS 27).
    static let menuBarLayer = Int(CGWindowLevelForKey(.mainMenuWindow))
    /// Share of the display that Split View tiles must cover.
    static let splitViewCoverage = 0.98
    /// Two tiles may overlap by this share of the smaller one (the divider, rounding).
    static let tileOverlapTolerance = 0.02

    // MARK: Menu bar

    /// Whether the WindowServer's menu-bar window is on each display: a menu-bar-layer window owned by
    /// `windowServerPID` at the display's top-left corner with its width. Unknown PID (libproc could not tell, see
    /// `WindowListSnapshot`) → present everywhere (the conservative answer: only the exact-and-frontmost rule can then
    /// match). `separateSpaces` false ("Displays have separate Spaces" off): only the main display has a menu bar, so
    /// every other display counts as present for the same reason (its missing menu bar says nothing; `evaluate` then
    /// takes the frontmost app's window as the evidence, below a notch band as for an exact cover).
    static func observedMenuBar(windows: [Window], displays: [Display], windowServerPID: Int32?,
                                separateSpaces: Bool = true) -> [DisplayKey: Bool] {
        var result: [DisplayKey: Bool] = [:]
        for display in displays {
            guard let windowServerPID, separateSpaces || isMain(display) else { result[display.key] = true; continue }
            result[display.key] = windows.contains { isMenuBar($0, of: display.bounds, windowServerPID: windowServerPID) }
        }
        return result
    }

    /// The main display: the one at the origin of the global display space (`CGMainDisplayID`'s definition), which
    /// carries the only menu bar while Spaces span all displays.
    static func isMain(_ display: Display) -> Bool {
        abs(display.bounds.minX) < 1 && abs(display.bounds.minY) < 1
    }

    /// The WindowServer's menu-bar window of THIS display: same top-left corner and width (two displays side by side
    /// with aligned tops and equal widths differ only in x, so both coordinates are compared).
    static func isMenuBar(_ window: Window, of displayBounds: CGRect, windowServerPID: Int32) -> Bool {
        window.layer == menuBarLayer && window.ownerPID == windowServerPID
            && abs(window.bounds.minX - displayBounds.minX) < 1 && abs(window.bounds.minY - displayBounds.minY) < 1
            && abs(window.bounds.width - displayBounds.width) < 1
    }

    // MARK: Evaluation

    /// Evaluates every display with the observed menu bar (no sticky absence; `FullScreenTracker` passes the sticky
    /// presence through the other overload).
    static func evaluate(windows: [Window], displays: [Display], context: Context, windowServerPID: Int32?,
                         separateSpaces: Bool = true) -> Result {
        evaluate(windows: windows, displays: displays, context: context,
                 menuBarPresent: observedMenuBar(windows: windows, displays: displays, windowServerPID: windowServerPID,
                                                 separateSpaces: separateSpaces),
                 separateSpaces: separateSpaces)
    }

    /// Evaluates every display. `windows` is front to back (the window server's order); `menuBarPresent` is the
    /// effective presence per display (missing = present). `separateSpaces` false: a display other than the main one
    /// has no menu bar of its own, so its (always present) menu bar says nothing and the frontmost app's window is the
    /// only evidence, for an exact cover and, on a notched built-in, for one below the notch band alike (C-SIGNALS-5).
    static func evaluate(windows: [Window], displays: [Display], context: Context,
                         menuBarPresent: [DisplayKey: Bool], separateSpaces: Bool = true) -> Result {
        let candidates = windows.filter { counts($0, context) }
        var fronts: [DisplayKey: Front] = [:]
        for display in displays {
            let present = menuBarPresent[display.key] ?? true
            let hasOwnMenuBar = separateSpaces || isMain(display)
            var front = Front()
            for window in candidates {
                let frontmost = window.ownerPID == context.frontmostPID
                let covers: Bool
                switch coverage(window.bounds, display) {
                case .exact?: covers = frontmost || !present
                // A zoomed window on a notched display has the same frame: only a missing menu bar tells them apart.
                // A display without a menu bar of its own has none to miss: frontmost is the evidence, as for .exact.
                case .belowBand?: covers = !present || (!hasOwnMenuBar && frontmost)
                case nil: covers = false
                }
                if covers { front = Front(isFullScreen: true, ownerPID: window.ownerPID); break }
            }
            if !front.isFullScreen, !present,
               let owner = splitViewOwner(candidates, display: display, frontmostPID: context.frontmostPID) {
                front = Front(isFullScreen: true, ownerPID: owner)
            }
            front.isVideo = front.isFullScreen && front.ownerPID.map(context.displaySleepHolders.contains) == true
            fronts[display.key] = front
        }
        return Result(fronts: fronts, frontmostDisplays: frontmostDisplays(windows, displays: displays, context: context))
    }

    /// How `bounds` covers `display`, if it does.
    static func coverage(_ bounds: CGRect, _ display: Display) -> Coverage? {
        let d = display.bounds
        guard abs(bounds.minX - d.minX) < 1, abs(bounds.width - d.width) < 1, abs(bounds.maxY - d.maxY) < 1 else {
            return nil
        }
        if abs(bounds.minY - d.minY) < 1 { return .exact }
        if display.notchBand > 0, abs(bounds.minY - (d.minY + display.notchBand)) < 1 { return .belowBand }
        return nil
    }

    /// A window that may cover a display: layer 0, visible, larger than a point, not ours or the Dock's, and owned by
    /// a regular app or the frontmost one (an owner that is neither, listed or not, never counts).
    static func counts(_ window: Window, _ context: Context) -> Bool {
        window.layer == 0 && window.alpha > 0 && window.bounds.width > 1 && window.bounds.height > 1
            && !context.ignoredPIDs.contains(window.ownerPID)
            && (context.regularPIDs.contains(window.ownerPID) || window.ownerPID == context.frontmostPID)
    }

    /// Split View: walking front to back, full-height windows that do not overlap an earlier tile tile ≥ 98 % of the
    /// display (below the notch band on a notched built-in), with at least two tiles. The owner is the frontmost
    /// app's tile, else the topmost one. Windows that are not full height (palettes, sheets) are skipped, not tiles.
    static func splitViewOwner(_ candidates: [Window], display: Display, frontmostPID: Int32?) -> Int32? {
        let d = display.bounds
        let target = CGRect(x: d.minX, y: d.minY + display.notchBand, width: d.width, height: d.height - display.notchBand)
        let targetArea = area(target)
        guard targetArea > 0 else { return nil }
        var tiles: [(rect: CGRect, owner: Int32)] = []
        var covered = 0.0
        for window in candidates {
            let rect = window.bounds.intersection(target)
            guard !rect.isNull, area(rect) > 0,
                  rect.minY - target.minY < 1, target.maxY - rect.maxY < 1 else { continue }
            let overlapsTile = tiles.contains { tile in
                area(tile.rect.intersection(rect)) > tileOverlapTolerance * min(area(tile.rect), area(rect))
            }
            if overlapsTile { continue }
            tiles.append((rect, window.ownerPID))
            covered += area(rect)
            if tiles.count >= 2, covered >= splitViewCoverage * targetArea {
                return tiles.first { $0.owner == frontmostPID }?.owner ?? tiles[0].owner
            }
        }
        return nil
    }

    /// The displays the frontmost app's topmost layer-0 window intersects (empty when it shows only its menu bar, or
    /// when the frontmost process is ignored: our own panel never pauses anything).
    static func frontmostDisplays(_ windows: [Window], displays: [Display], context: Context) -> Set<DisplayKey> {
        guard let pid = context.frontmostPID, !context.ignoredPIDs.contains(pid) else { return [] }
        let top = windows.first { window in
            window.layer == 0 && window.ownerPID == pid && window.alpha > 0
                && window.bounds.width > 1 && window.bounds.height > 1
                && displays.contains { area($0.bounds.intersection(window.bounds)) > 0 }
        }
        guard let top else { return [] }
        return Set(displays.filter { area($0.bounds.intersection(top.bounds)) > 0 }.map(\.key))
    }

    /// The area of `rect` (0 for the null rectangle).
    static func area(_ rect: CGRect) -> Double {
        rect.isNull ? 0 : Double(rect.width) * Double(rect.height)
    }
}
