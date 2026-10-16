// OverbrightDesign/Components/StepWedgeView.swift — the calibration squares. DESIGN.md §9, App. A.
// Seam written by WP0a (ARCHITECTURE.md §10.0): the initializer is fixed; WP9 draws the patches in the screen's colour
// space on the black surround.
import SwiftUI

/// Patches of the given code values on a surround (calibration: 0.95 next to white on black).
public struct StepWedgeView: View {
    private let patches: [Double]
    private let surround: Double

    /// - Parameters:
    ///   - patches: code values of the squares, 0 … 1.
    ///   - surround: the code value around them (0 = black).
    public init(patches: [Double], surround: Double) {
        self.patches = patches; self.surround = surround
    }

    /// WP0a placeholder: grey squares on the surround.
    public var body: some View {
        HStack(spacing: Space.xl) {
            ForEach(Array(patches.enumerated()), id: \.offset) { _, value in
                Rectangle().fill(Color(white: value)).aspectRatio(1, contentMode: .fit)
            }
        }
        .padding(Space.huge)
        .background(Color(white: surround))
        .accessibilityHidden(true)
    }
}
