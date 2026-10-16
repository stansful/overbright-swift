// OverbrightFillLight — the edge light around one display for video calls. ARCHITECTURE.md §10.9, §7.6, D12;
// DESIGN.md §7.7, §11.
//
//   FillLightController     implements `FillLightControl` and `ServiceLifecycle`: settings → style, the camera rule,
//                           the chosen display, `OwnEDRSurfaces` registration, announcements and the journal
//   FillLightRule           the camera rule (on when a camera starts, off when it stops, manual Off wins until the
//                           camera stops; Signals debounces the signal 1 s on / 3 s off, §7.1) as a pure state machine
//   ColorTemperature        warmth → kelvin (6 500–3 000 K) → black-body colour in linear sRGB (pure)
//   FrameGeometry           the lit frame: outer edge = the display below the menu bar, inner edge a rounded rectangle
//   FillLightStyle          what a surface shows: width, colour, value (≤ 2× white with EDR) and the headroom request
//   FillLightSurface(s)     the seam between the controller and the window; tests use fakes that never order a window in
//   SystemFillLightSurfaces the real frame windows (§7.6 recipe): tagged CALayer colour on macOS 26+, a clear-only
//                           CAMetalLayer on 14–25, an SDR colour otherwise (and as the `--qa-simulate` stand-in)
//
// Layer 1: imports OverbrightCore, OverbrightPolicy and Apple frameworks only (§2.1). EDR layer properties are
// allowed in this module (§2.1 rule 6); EDR colours start from `CGColor` (§4.7).
