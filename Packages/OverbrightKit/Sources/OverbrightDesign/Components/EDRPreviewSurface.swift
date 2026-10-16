// OverbrightDesign/Components/EDRPreviewSurface.swift — the Welcome before/after card. DESIGN.md §8, App. A; D16.
// Seam written by WP0a (ARCHITECTURE.md §10.0): the initializer is fixed. This is the one Design file allowed to use EDR
// layer properties (ARCHITECTURE.md §2.1 rule 6). A sample page (text on white): Standard white on the leading side
// of a draggable divider, `gain` × white as EDR content of our own view on the other side. Nothing outside this view
// changes: no table write, no window of our own. macOS 26+: a headroom-tagged layer colour; 14–25: one clear-only Metal
// frame in extended linear sRGB (no shader, no library). The host registers the card with `OwnEDRSurfaces` while it
// shows it; the EDR layer hides itself whenever its window is not visible, so the card pauses while hidden.
// `simulated` (QA, previews, snapshots) draws an SDR stand-in: the Standard side at 1 / gain of the light.
// The divider moves by dragging, by VoiceOver's adjust actions and from the keyboard (DESIGN.md §15: every action has a
// key path): the card is one focusable element with the Overbright focus ring, and ← / → move the divider by 10 %
// toward the side they point at, mirrored right to left like the level slider's keys.
import AppKit
import Metal
import OverbrightPolicy
import QuartzCore
import SwiftUI

/// A card whose right part shows `gain` × white as EDR content in our own view (no table write), with a divider the
/// user drags; `simulated` draws an SDR stand-in (`--qa-simulate`, previews, snapshots).
public struct EDRPreviewSurface: View {
    private let gain: Double
    @Binding private var divider: Double
    private let simulated: Bool
    private var focusesOnAppear = false
    @Environment(\.layoutDirection) private var direction
    @Environment(\.overbright) private var theme
    @FocusState private var isFocused: Bool

    /// One arrow-key step of the divider: 10 % of the card's width.
    static let keyStep = 0.1

    /// - Parameters:
    ///   - gain: the light gain of the "after" part.
    ///   - divider: the divider position, 0 … 1 of the width.
    ///   - simulated: draw the SDR stand-in instead of EDR content.
    public init(gain: Double, divider: Binding<Double>, simulated: Bool) {
        self.gain = gain; _divider = divider; self.simulated = simulated
    }

    /// The Standard page's grey in the stand-in: the light of Standard relative to the brighter side, sRGB-encoded.
    public static func standInGrey(gain: Double) -> Double { FactorMath.encodeSRGB(1 / max(gain, 1)) }

    /// The divider after a press of `key` from `divider` in a `direction` layout: ← and → move it 10 % toward the side
    /// they point at (the divider is measured from the leading edge, so right to left → lowers it); nil for any other
    /// key.
    static func divider(after key: KeyEquivalent, from divider: Double, direction: LayoutDirection) -> Double? {
        guard let step = direction.step(for: key) else { return nil }
        return min(max(divider + Double(step) * keyStep, 0), 1)
    }

    /// The card with keyboard focus as soon as it appears (tests only: a window that is never ordered in gets no Tab).
    func focusedOnAppear() -> EDRPreviewSurface {
        var copy = self
        copy.focusesOnAppear = true
        return copy
    }

    /// The card.
    public var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let split = CGFloat(min(max(divider, 0), 1)) * width
            ZStack(alignment: .leading) {
                if simulated { Color.white } else { EDRWhiteLayer(gain: gain) }
                Color(white: simulated ? Self.standInGrey(gain: gain) : 1).frame(width: split)
                SamplePage().padding(Space.xl)
                Rectangle().fill(Color.black.opacity(0.35)).frame(width: StrokeWidth.regular).offset(x: split)
                Circle()
                    .fill(theme.color(.thumb))
                    .overbrightShadow(.thumb)
                    .frame(width: BoostSliderTrack.thumbSize, height: BoostSliderTrack.thumbSize)
                    .offset(x: split - BoostSliderTrack.thumbSize / 2)
                    .accessibilityHidden(true)
            }
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { value in
                divider = direction.fraction(atPhysicalX: value.location.x, width: width)
            })
        }
        .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        // Inside the focusable element, `\.isFocused` is the card's own focus (the ring shows after keyboard use).
        .overbrightFocusRing(cornerRadius: Radius.card)
        .focusable()
        .focusEffectDisabled()
        .focused($isFocused)
        .onKeyPress(keys: [.leftArrow, .rightArrow], phases: [.down, .repeat]) { press in
            guard let next = Self.divider(after: press.key, from: divider, direction: direction) else {
                return .ignored
            }
            divider = next
            return .handled
        }
        .onAppear { if focusesOnAppear { isFocused = true } }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: Self.dividerLabel()))
        .accessibilityValue(Text(verbatim: CopyFormat.percent(Int((min(max(divider, 0), 1) * 100).rounded()))))
        .accessibilityAdjustableAction { change in
            switch change {
            case .increment: divider = min(divider + Self.keyStep, 1)
            case .decrement: divider = max(divider - Self.keyStep, 0)
            @unknown default: break
            }
        }
    }

    /// "Before and after": the VoiceOver label of the divider.
    static func dividerLabel(in language: CopyLanguage = .app) -> String {
        String(localized: "Before and after", bundle: language.bundle, locale: language.locale,
               comment: "VoiceOver: label of the Welcome card’s divider between Standard and extra brightness")
    }
}

/// Lines of grey "text" on the page: the card shows what extra light does to an ordinary document.
private struct SamplePage: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            ForEach(0..<6, id: \.self) { line in
                Capsule().fill(Color.black.opacity(line == 0 ? 0.75 : 0.45))
                    .frame(height: line == 0 ? 10 : 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.trailing, CGFloat((line * 37) % 60))
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .accessibilityHidden(true)
    }
}

/// `gain` × white as EDR content of our own view.
private struct EDRWhiteLayer: NSViewRepresentable {
    let gain: Double

    func makeNSView(context: Context) -> EDRWhiteView { EDRWhiteView() }

    func updateNSView(_ view: EDRWhiteView, context: Context) { view.gain = gain }
}

/// A layer-backed view that shows white at `gain` × SDR white while its window is visible.
final class EDRWhiteView: NSView {
    var gain: Double = 1 { didSet { if gain != oldValue { refresh() } } }
    private var metalLayer: CAMetalLayer?
    private var queue: (any MTLCommandQueue)?
    private var occlusionObserver: (any NSObjectProtocol)?

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    override func makeBackingLayer() -> CALayer {
        if #available(macOS 26, *) { return CALayer() }
        let layer = CAMetalLayer()
        layer.pixelFormat = .rgba16Float
        layer.colorspace = CGColorSpace(name: CGColorSpace.extendedLinearSRGB)
        layer.wantsExtendedDynamicRangeContent = true
        layer.framebufferOnly = true
        layer.isOpaque = true
        layer.maximumDrawableCount = 2
        layer.allowsNextDrawableTimeout = true
        metalLayer = layer
        return layer
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if let occlusionObserver { NotificationCenter.default.removeObserver(occlusionObserver) }
        occlusionObserver = nil
        guard let window else { return }
        occlusionObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didChangeOcclusionStateNotification, object: window, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }                         // queue: .main
        }
        refresh()
    }

    override func layout() {
        super.layout()
        refresh()
    }

    /// Shows the EDR white while the window is visible; hides it (releasing the request) otherwise.
    private func refresh() {
        guard let layer else { return }
        let visible = window?.occlusionState.contains(.visible) == true
        if isHidden == visible { isHidden = !visible }
        guard visible else { return }
        let value = max(gain, 1)
        if #available(macOS 26, *) {
            guard let space = CGColorSpace(name: CGColorSpace.extendedLinearSRGB) else { return }
            let v = CGFloat(value)
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            layer.backgroundColor = CGColor(headroom: Float(value), colorSpace: space, red: v, green: v, blue: v, alpha: 1)
            layer.preferredDynamicRange = .high
            CATransaction.commit()
        } else {
            presentClear(value)
        }
    }

    /// One clear-only frame at `value` (macOS 14–25): a render pass with a clear load action and no draw call.
    private func presentClear(_ value: Double) {
        guard let metalLayer, let screen = window?.screen,
              let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else { return }
        // The device that drives this screen (never the system default, which could wake a discrete GPU).
        guard let device = CGDirectDisplayCopyCurrentMetalDevice(number.uint32Value) else { return }
        if metalLayer.device !== device || queue == nil {
            metalLayer.device = device
            queue = device.makeCommandQueue()
        }
        let scale = window?.backingScaleFactor ?? 2
        metalLayer.drawableSize = CGSize(width: max(bounds.width * scale, 1), height: max(bounds.height * scale, 1))
        guard let queue, let buffer = queue.makeCommandBuffer(), let drawable = metalLayer.nextDrawable() else { return }
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = drawable.texture
        pass.colorAttachments[0].loadAction = .clear
        pass.colorAttachments[0].storeAction = .store
        pass.colorAttachments[0].clearColor = MTLClearColor(red: value, green: value, blue: value, alpha: 1)
        guard let encoder = buffer.makeRenderCommandEncoder(descriptor: pass) else { return }
        encoder.endEncoding()
        buffer.present(drawable)
        buffer.commit()
    }
}

#Preview("Welcome card (stand-in)") {
    @Previewable @State var divider = 0.5
    EDRPreviewSurface(gain: 1.29, divider: $divider, simulated: true)
        .frame(width: 400, height: 200)
        .padding()
        .overbrightThemeRoot()
}
