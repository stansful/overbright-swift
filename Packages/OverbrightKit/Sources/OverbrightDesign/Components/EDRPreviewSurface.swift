// OverbrightDesign/Components/EDRPreviewSurface.swift — the Welcome before/after card. DESIGN.md §8, App. A; D16.
// Seam written by WP0a (ARCHITECTURE.md §10.0): the initializer is fixed. This is the one Design file allowed to use
// EDR layer properties (ARCHITECTURE.md §2.1 rule 6); WP9 builds the EDR content (registered with `OwnEDRSurfaces` by
// its host) and the draggable divider. The WP0a body is the SDR stand-in only: no EDR request, no window.
import SwiftUI

/// A card whose right part shows `gain` × white as EDR content in our own view (no table write), with a divider the
/// user drags; `simulated` draws an SDR stand-in (`--qa-simulate`, previews, snapshots).
public struct EDRPreviewSurface: View {
    private let gain: Double
    @Binding private var divider: Double
    private let simulated: Bool

    /// - Parameters:
    ///   - gain: the light gain of the "after" part.
    ///   - divider: the divider position, 0 … 1 of the width.
    ///   - simulated: draw the SDR stand-in instead of EDR content.
    public init(gain: Double, divider: Binding<Double>, simulated: Bool) {
        self.gain = gain; _divider = divider; self.simulated = simulated
    }

    /// WP0a placeholder: the SDR stand-in (grey before, white after).
    public var body: some View {
        GeometryReader { proxy in
            HStack(spacing: 0) {
                Rectangle().fill(Color(white: 0.8))
                    .frame(width: proxy.size.width * min(max(divider, 0), 1))
                Rectangle().fill(Color.white)
            }
        }
        .accessibilityHidden(true)
    }
}
