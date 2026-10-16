// OverbrightFillLight/Surface/FillLightSurfaceFactory.swift — makes frame surfaces. ARCHITECTURE.md §7.6, §8.5
// (`--qa-simulate` swaps every EDR surface for an SDR stand-in), §10.9.
import OverbrightCore

/// Makes the Fill Light's surface for a display. The composition root passes `SystemFillLightSurfaces()` (or its SDR
/// stand-in under `--qa-simulate`); tests pass a fake. Making a surface shows nothing until `apply(_:)`.
@MainActor public protocol FillLightSurfaceFactory: AnyObject {
    /// A surface for `display`; throws `FillLightError` when it cannot host one (no screen, no colour path).
    func makeSurface(on display: DisplayRef) throws -> any FillLightSurface
    /// Frame windows ordered in now (diagnostics; 0 while the Fill Light is off).
    var openWindowCount: Int { get }
}
