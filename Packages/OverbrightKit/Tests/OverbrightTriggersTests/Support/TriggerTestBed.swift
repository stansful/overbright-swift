// OverbrightTriggersTests/Support/TriggerTestBed.swift — a `SystemTriggerFactory` over test doubles: two fixed screens
// (a notched built-in and an external to its right), a recording presenter, scripted surfaces, `ManualTimeSource`
// and a temporary cache folder. ARCHITECTURE.md §9.1, §10.5.
import CoreGraphics
import Foundation
import OverbrightCore
@testable import OverbrightTriggers

/// One factory under test and the doubles behind it.
final class TriggerTestBed {
    /// The built-in display (ID 1): 1512 × 982 pt at the origin, notch between x 662 and 850.
    static let builtIn = DisplayRef(key: DisplayKey(rawValue: "00000000-0000-0000-0000-0000000000B1"), id: 1)
    /// The external display (ID 2): 3840 × 2160 pt right of the built-in, no notch, scale 1.
    static let external = DisplayRef(key: DisplayKey(rawValue: "00000000-0000-0000-0000-0000000000E2"), id: 2)
    /// The built-in's geometry.
    static let builtInGeometry = ScreenGeometry(frame: CGRect(x: 0, y: 0, width: 1512, height: 982),
                                                auxiliaryTopLeftArea: CGRect(x: 0, y: 950, width: 662, height: 32),
                                                auxiliaryTopRightArea: CGRect(x: 850, y: 950, width: 662, height: 32),
                                                backingScaleFactor: 2)
    /// The external's geometry.
    static let externalGeometry = ScreenGeometry(frame: CGRect(x: 1512, y: 0, width: 3840, height: 2160),
                                                 backingScaleFactor: 1)

    let screens: FixedScreens
    let presenter = RecordingPresenter()
    let time = ManualTimeSource()
    let cacheDirectory: URL
    /// The T4 stills (in `cacheDirectory`).
    let stills: HLGStillCache
    /// Surfaces handed out, in order.
    private(set) var surfaces: [ScriptedClearSurface] = []
    /// Drawable edges asked for, in order.
    private(set) var surfaceRequests: [(display: CGDirectDisplayID, pixels: Int)] = []
    /// Presents the next surfaces fail first.
    var surfaceFailuresBeforeSuccess = 0
    /// No Metal device: `makeClearSurface` returns nil.
    var hasMetalDevice = true
    let factory: SystemTriggerFactory

    init(allowsLegacyLayerPath: Bool = false, tagsMetalLayers: Bool = false,
         codecs: [HLGStillAsset.Codec] = HLGStillAsset.Codec.allCases) {
        let screens = FixedScreens([Self.builtIn.id: Self.builtInGeometry, Self.external.id: Self.externalGeometry])
        let cacheDirectory = FileManager.default.temporaryDirectory
            .appending(path: "overbright-triggers-\(UUID().uuidString)", directoryHint: .isDirectory)
        let stills = HLGStillCache(directory: cacheDirectory, codecs: codecs)
        self.screens = screens
        self.cacheDirectory = cacheDirectory
        self.stills = stills
        var made: (CGDirectDisplayID, Int) -> (any ClearFrameSurface)? = { _, _ in nil }
        var environment = TriggerEnvironment(screens: screens, presenter: presenter,
                                             makeClearSurface: { made($0, $1) }, time: time, stills: stills)
        environment.allowsLegacyLayerPath = allowsLegacyLayerPath
        environment.tagsMetalLayers = tagsMetalLayers
        factory = SystemTriggerFactory(environment: environment)
        made = { [unowned self] display, pixels in self.makeSurface(display, pixels) }
    }

    deinit { try? FileManager.default.removeItem(at: cacheDirectory) }

    /// A rung request with sensible defaults.
    static func request(_ strategy: TriggerStrategy, pixel: TriggerPixel = .black,
                        placement: TriggerPlacement = .topRightCorner, blend: TriggerBlend = .normal,
                        edgePoints: Double = 1, tag: Double = 16) -> TriggerRequest {
        TriggerRequest(strategy: strategy, pixel: pixel, placement: placement, blend: blend, edgePoints: edgePoints,
                       headroomTag: tag)
    }

    private func makeSurface(_ display: CGDirectDisplayID, _ pixels: Int) -> (any ClearFrameSurface)? {
        surfaceRequests.append((display, pixels))
        guard hasMetalDevice else { return nil }
        let surface = ScriptedClearSurface(failuresBeforeSuccess: surfaceFailuresBeforeSuccess)
        surfaces.append(surface)
        return surface
    }
}
