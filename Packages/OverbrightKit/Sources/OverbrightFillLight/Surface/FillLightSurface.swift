// OverbrightFillLight/Surface/FillLightSurface.swift — one frame on one display, as the controller sees it.
// ARCHITECTURE.md §7.6, §7.1 (screen change → removed at once), §10.9 ("never ordered in during tests").
import CoreGraphics
import OverbrightCore

/// The Fill Light's frame on one display. The real one is a click-through, capture-excluded window
/// (`SystemFillLightSurfaces`); tests use fakes that record styles and never order a window in.
@MainActor public protocol FillLightSurface: AnyObject {
    /// The display it was made for.
    var display: DisplayRef { get }
    /// How it makes its colour (decides whether the controller asks for EDR headroom).
    var rendering: FillLightRendering { get }
    /// Called when AppKit moves the window to another screen (`NSWindow.didChangeScreenNotification`), with the new
    /// screen's display ID (nil: none). The controller removes the surface at once if it is not `display` (§7.1).
    var onScreenChange: (@MainActor (CGDirectDisplayID?) -> Void)? { get set }
    /// Shows `style`. The first call orders the window in; later calls change it in place.
    func apply(_ style: FillLightStyle)
    /// The display's frame or parameters changed, or the Mac woke: re-place the window and re-present the colour.
    func refresh()
    /// Orders the window out for good and releases everything it holds (window, layers, Metal device).
    func remove()
}
