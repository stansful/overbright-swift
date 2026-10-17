// OverbrightAppShell/HUD/HUDPlacement.swift — where the HUD and the Keep-this-level prompt go: horizontally centred on
// the display whose level changed (the display under the pointer for "every display"), 64 pt above the bottom of its
// visible frame (above the Dock), clear of the system's brightness indicator and notification banners. DESIGN.md §6.
import AppKit
import OverbrightCore

/// The HUD's frame.
enum HUDPlacement {
    /// The HUD (DESIGN.md §6: 280 × 56 pt).
    static let size = CGSize(width: 280, height: 56)
    /// The Keep-this-level prompt, in the HUD's place (taller: two buttons).
    static let promptSize = CGSize(width: 280, height: 96)
    /// Distance from the bottom of the visible frame.
    static let bottomInset: CGFloat = 64

    /// The frame of a window of `size` on a screen whose visible frame is `visibleFrame`.
    static func frame(size: CGSize, visibleFrame: CGRect) -> CGRect {
        CGRect(x: (visibleFrame.midX - size.width / 2).rounded(), y: visibleFrame.minY + bottomInset,
               width: size.width, height: size.height)
    }

    /// The visible frame of the screen showing `display` (by its CoreGraphics ID), else the screen under `pointer`,
    /// else the main screen; nil without any screen.
    static func visibleFrame(for display: CGDirectDisplayID?, pointer: CGPoint,
                             screens: [(id: CGDirectDisplayID?, frame: CGRect, visibleFrame: CGRect)],
                             main: CGRect?) -> CGRect? {
        if let display, let screen = screens.first(where: { $0.id == display }) { return screen.visibleFrame }
        if let screen = screens.first(where: { $0.frame.contains(pointer) }) { return screen.visibleFrame }
        return main ?? screens.first?.visibleFrame
    }

    /// The frame for a window of `size` about `display` now (AppKit's screens and pointer); nil for "every display"
    /// places it on the screen under the pointer.
    @MainActor
    static func currentFrame(size: CGSize, display: DisplayKey?, services: OverbrightServices) -> CGRect? {
        let id = display.flatMap { services.displays.facts(for: $0)?.ref.id }
        guard let visible = visibleFrame(for: id, pointer: NSEvent.mouseLocation, screens: currentScreens,
                                         main: NSScreen.main?.visibleFrame) else { return nil }
        return frame(size: size, visibleFrame: visible)
    }

    /// The display under `pointer`: the facts whose CoreGraphics ID is the screen's that contains the pointer.
    static func display(at pointer: CGPoint, screens: [(id: CGDirectDisplayID?, frame: CGRect, visibleFrame: CGRect)],
                        displays: [DisplayFacts]) -> DisplayKey? {
        guard let id = screens.first(where: { $0.frame.contains(pointer) })?.id else { return nil }
        return displays.first { $0.ref.id == id }?.ref.key
    }

    /// The display under the pointer now (a change to every display is shown about it, DESIGN.md §6).
    @MainActor
    static func currentPointerDisplay(services: OverbrightServices) -> DisplayKey? {
        display(at: NSEvent.mouseLocation, screens: currentScreens, displays: services.displays.displays)
    }

    /// AppKit's screens with their CoreGraphics IDs.
    @MainActor
    private static var currentScreens: [(id: CGDirectDisplayID?, frame: CGRect, visibleFrame: CGRect)] {
        NSScreen.screens.map { screen in
            (id: (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)
                .map { CGDirectDisplayID($0.uint32Value) },
             frame: screen.frame, visibleFrame: screen.visibleFrame)
        }
    }
}
