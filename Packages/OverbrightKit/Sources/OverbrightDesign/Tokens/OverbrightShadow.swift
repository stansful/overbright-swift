// OverbrightDesign/Tokens/OverbrightShadow.swift — the few drop shadows Overbright draws itself. DESIGN.md §2.3
// (elevation: windows take the system's shadow, cards none), §2.4 ("Slider thumb: white with system shadow"), §5.5
// (thumb, value tag). Views write `.overbrightShadow(.thumb)`, never a literal shadow (ARCHITECTURE.md §9.2 rule 3).
import CoreGraphics
import SwiftUI

/// A drop shadow: colour, blur radius and downward offset.
public nonisolated enum OverbrightShadow: CaseIterable, Sendable {
    /// The slider thumb and the welcome card's divider handle: the system slider thumb's (black 30 %, blur 1, 0.5 pt
    /// down).
    case thumb
    /// The value tag's lift off the track (black 15 %, blur 2, 1 pt down).
    case valueTag

    /// The shadow's colour.
    public var color: SRGBA {
        switch self {
        case .thumb: SRGBA.black.opacity(0.3)
        case .valueTag: SRGBA.black.opacity(0.15)
        }
    }

    /// The blur radius in points.
    public var radius: CGFloat {
        switch self {
        case .thumb: 1
        case .valueTag: 2
        }
    }

    /// How far down the shadow falls, in points.
    public var offsetY: CGFloat {
        switch self {
        case .thumb: 0.5
        case .valueTag: 1
        }
    }
}

public extension View {
    /// Draws `shadow` under the view.
    func overbrightShadow(_ shadow: OverbrightShadow) -> some View {
        self.shadow(color: shadow.color.color, radius: shadow.radius, x: 0, y: shadow.offsetY)
    }
}
