// OverbrightFillLightTests/Fakes/FakeFillLightSurfaces.swift — a surface factory that records and never orders a window
// in (ARCHITECTURE.md §10.9 "never ordered in during tests", §3.9 package-local fakes).
import CoreGraphics
import OverbrightCore
@testable import OverbrightFillLight

/// One recorded frame: every style it was given, refreshes, removal. No window, no layer.
@MainActor final class FakeFillLightSurface: FillLightSurface {
    let display: DisplayRef
    let rendering: FillLightRendering
    var onScreenChange: (@MainActor (CGDirectDisplayID?) -> Void)?
    private(set) var styles: [FillLightStyle] = []
    private(set) var refreshCount = 0
    private(set) var isRemoved = false

    init(display: DisplayRef, rendering: FillLightRendering) {
        self.display = display
        self.rendering = rendering
    }

    /// Shown: given a style and not removed (what "ordered in" would be for the real window).
    var isShown: Bool { !styles.isEmpty && !isRemoved }
    /// The style shown last.
    var style: FillLightStyle? { styles.last }

    func apply(_ style: FillLightStyle) { styles.append(style) }
    func refresh() { refreshCount += 1 }
    func remove() { isRemoved = true }

    /// AppKit moved the window to the screen of `id`.
    func moveToScreen(_ id: CGDirectDisplayID?) { onScreenChange?(id) }
}

/// Makes `FakeFillLightSurface`s; can refuse displays.
@MainActor final class FakeFillLightSurfaces: FillLightSurfaceFactory {
    /// The rendering of every surface it makes.
    var rendering: FillLightRendering = .taggedLayer
    /// Displays it refuses (no screen).
    var refused: Set<CGDirectDisplayID> = []
    /// Every surface made, in order.
    private(set) var made: [FakeFillLightSurface] = []

    /// Surfaces made and not removed.
    var live: [FakeFillLightSurface] { made.filter { !$0.isRemoved } }
    /// The one live surface, if exactly one.
    var current: FakeFillLightSurface? { live.count == 1 ? live[0] : nil }
    var openWindowCount: Int { live.filter(\.isShown).count }

    func makeSurface(on display: DisplayRef) throws -> any FillLightSurface {
        guard !refused.contains(display.id) else { throw FillLightError.unavailable(display.id) }
        let surface = FakeFillLightSurface(display: display, rendering: rendering)
        made.append(surface)
        return surface
    }
}
