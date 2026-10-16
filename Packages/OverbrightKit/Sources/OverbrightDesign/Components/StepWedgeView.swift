// OverbrightDesign/Components/StepWedgeView.swift — the calibration squares. DESIGN.md §9, App. A.
// Seam written by WP0a (ARCHITECTURE.md §10.0): the initializer is fixed. The patches are 100 × 100 pt squares of the
// given code values on the surround (black during calibration), filled in the colour space of the window that shows
// them: the calibration window takes the screen's colour space, so code values reach the framebuffer unchanged.
import AppKit
import SwiftUI

/// Patches of the given code values on a surround (calibration: 0.95 next to white on black).
public struct StepWedgeView: View {
    /// The edge of one patch.
    public static let patchSize: CGFloat = 100

    private let patches: [Double]
    private let surround: Double

    /// - Parameters:
    ///   - patches: code values of the squares, 0 … 1.
    ///   - surround: the code value around them (0 = black).
    public init(patches: [Double], surround: Double) {
        self.patches = patches; self.surround = surround
    }

    /// The patches, centred on the surround.
    public var body: some View {
        StepWedgeCanvas(patches: patches.map { min(max($0, 0), 1) }, surround: min(max(surround, 0), 1))
            .frame(minWidth: Self.minimumWidth(count: patches.count), minHeight: Self.patchSize + 2 * Space.huge)
            .accessibilityHidden(true)
    }

    /// The width the patches and their gaps take, plus the margins.
    public static func minimumWidth(count: Int) -> CGFloat {
        CGFloat(count) * patchSize + CGFloat(max(count - 1, 0)) * Space.xl + 2 * Space.huge
    }

    /// The frames of `count` patches centred in `bounds`, from the leading edge (left to right).
    public static func patchFrames(count: Int, in bounds: CGRect) -> [CGRect] {
        let total = CGFloat(count) * patchSize + CGFloat(max(count - 1, 0)) * Space.xl
        let x0 = bounds.midX - total / 2, y = bounds.midY - patchSize / 2
        return (0..<count).map { i in
            CGRect(x: x0 + CGFloat(i) * (patchSize + Space.xl), y: y, width: patchSize, height: patchSize)
        }
    }
}

/// Draws the wedge with AppKit, in the window's colour space (sRGB without a window).
private struct StepWedgeCanvas: NSViewRepresentable {
    let patches: [Double]
    let surround: Double

    func makeNSView(context: Context) -> CodeValueView { CodeValueView() }

    func updateNSView(_ view: CodeValueView, context: Context) {
        view.patches = patches
        view.surround = surround
    }
}

/// An NSView that fills code values in its window's colour space.
final class CodeValueView: NSView {
    var patches: [Double] = [] { didSet { needsDisplay = true } }
    var surround: Double = 0 { didSet { needsDisplay = true } }

    override var isFlipped: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        let space = window?.colorSpace?.cgColorSpace ?? CGColorSpace(name: CGColorSpace.sRGB)
        func fill(_ rect: CGRect, _ value: Double) {
            guard let space, let color = CGColor(colorSpace: space, components: Self.components(value, in: space)) else {
                return
            }
            context.setFillColor(color)
            context.fill(rect)
        }
        fill(bounds, surround)
        for (frame, value) in zip(StepWedgeView.patchFrames(count: patches.count, in: bounds), patches) {
            fill(frame, value)
        }
    }

    /// The same code value on every channel of `space`, then alpha 1.
    static func components(_ value: Double, in space: CGColorSpace) -> [CGFloat] {
        Array(repeating: CGFloat(value), count: space.numberOfComponents) + [1]
    }
}

#Preview("Step wedge") {
    StepWedgeView(patches: [0.85, 0.90, 0.95, 1], surround: 0)
        .frame(width: 560, height: 180)
}
