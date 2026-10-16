// OverbrightSignals/Camera/CameraTransport.swift — which cameras count for the Fill Light rule. ARCHITECTURE.md §3.8
// (`fillLight.cameraFilter`), §7.1 ("Camera in use": the transport type filters virtual cameras), §7.3.
// Virtual cameras and Continuity Camera also report "running somewhere". "Built-in and USB cameras only" keeps the
// devices whose `kCMIODevicePropertyTransportType` is IOAudioTypes.h's built-in ('bltn') or USB ('usb ') transport.
// Thread: any (pure).
import OverbrightCore

/// The transport-type filter of the camera rule.
nonisolated enum CameraTransport {
    /// `kIOAudioDeviceTransportTypeBuiltIn`.
    static let builtIn = fourCharacterCode("bltn")
    /// `kIOAudioDeviceTransportTypeUSB`.
    static let usb = fourCharacterCode("usb ")
    /// `kIOAudioDeviceTransportTypeVirtual` (OBS, Camo and similar).
    static let virtual = fourCharacterCode("virt")

    /// Whether a device with `transport` (nil: unknown) counts under `filter`.
    static func counts(transport: UInt32?, filter: CameraFilter) -> Bool {
        switch filter {
        case .anyCamera: true
        case .builtInAndUSB: transport == builtIn || transport == usb
        }
    }

    /// A four-character code as IOKit spells it ('bltn' → 0x626C746E).
    static func fourCharacterCode(_ code: String) -> UInt32 {
        code.utf8.prefix(4).reduce(0) { $0 << 8 | UInt32($1) }
    }
}
