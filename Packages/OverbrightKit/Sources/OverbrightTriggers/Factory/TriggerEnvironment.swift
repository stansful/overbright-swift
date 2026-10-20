// OverbrightTriggers/Factory/TriggerEnvironment.swift — everything a trigger needs from the outside, in one value:
// screens, the window presenter, the clear-frame surfaces, the time source, the HLG stills and the lab switches.
// ARCHITECTURE.md §3.6, §4.7, §8.1 rule 5, §9.1 ("No test ever orders a window in"). Thread: main.
//
// `SystemTriggerFactory`'s public initialiser builds the live environment; tests build one with a recording
// presenter, fixed screens and scripted surfaces, so they exercise the real handle code without putting a window,
// a Metal device or an EDR request on screen.
import CoreGraphics
import Foundation
import OverbrightCore

/// The dependencies of `SystemTriggerFactory` and its handles.
struct TriggerEnvironment {
    /// Screen lookups (`NSScreen` in the app).
    var screens: any TriggerScreens
    /// Orders windows in and out (`SystemWindowPresenter` in the app; never in tests).
    var presenter: any WindowPresenting
    /// A clear-frame surface on a display's GPU with a drawable of the given edge in pixels; nil without a Metal
    /// device.
    var makeClearSurface: (_ display: CGDirectDisplayID, _ drawablePixels: Int) -> (any ClearFrameSurface)?
    /// Sleeps of the present retries, the readiness polls and the T3 keep-alive.
    var time: any TimeSource
    /// The T4 stills.
    var stills: HLGStillCache
    /// Enables the macOS 14–25 T1 path (the deprecated `CALayer` EDR flag with an untagged colour). Off: untested on a
    /// real 14/15 Mac, so 14–25 start at T2 (D4).
    var allowsLegacyLayerPath = false
    /// Tags T2/T3's `CAMetalLayer` (`contentsHeadroom` + `.high`, macOS 26+). Off: tag policy A leaves the Metal
    /// strategies untagged (§4.7); the hardware session may turn it on (H-T2c).
    var tagsMetalLayers = false

    /// The app's environment: `NSScreen`, the real presenter and the display's own Metal device.
    static func live(time: any TimeSource, cacheDirectory: URL) -> TriggerEnvironment {
        TriggerEnvironment(
            screens: SystemTriggerScreens(),
            presenter: SystemWindowPresenter(),
            makeClearSurface: { display, pixels in
                MetalClearSurface(display: display, drawablePixels: pixels, wantsEDR: true)
            },
            time: time,
            stills: HLGStillCache(directory: cacheDirectory))
    }
}
