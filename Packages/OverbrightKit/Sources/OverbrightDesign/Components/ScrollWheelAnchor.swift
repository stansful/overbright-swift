// OverbrightDesign/Components/ScrollWheelAnchor.swift — where a control sits in its window, for `ScrollWheelSteps`.
// DESIGN.md §5.5, §15. SwiftUI gives a view neither its NSWindow nor its frame in window coordinates; a plain NSView
// behind the control has both. The slider places it only while the pointer is over it (an off-screen ImageRenderer
// draws a placeholder for platform views, and nothing listens otherwise). It never takes a click or an accessibility
// focus.
import AppKit
import SwiftUI

/// A transparent, click-through view behind a control that keeps `steps` attached to the control's window and frame.
struct ScrollWheelAnchor: NSViewRepresentable {
    /// The scroll listener of the control.
    let steps: ScrollWheelSteps

    func makeNSView(context: Context) -> AnchorView {
        let view = AnchorView()
        view.steps = steps
        return view
    }

    func updateNSView(_ view: AnchorView, context: Context) {
        guard view.steps !== steps else { return }
        view.steps = steps
        if view.window != nil { steps.attach(view) }
    }

    static func dismantleNSView(_ view: AnchorView, coordinator: ()) {
        if view.steps?.anchor === view { view.steps?.attach(nil) }
        view.steps = nil
    }

    /// The anchor: no drawing, no hits, no accessibility element.
    final class AnchorView: NSView {
        /// The listener this view anchors.
        weak var steps: ScrollWheelSteps?

        override func hitTest(_ point: NSPoint) -> NSView? { nil }

        override func isAccessibilityElement() -> Bool { false }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard let steps else { return }
            if window != nil {
                steps.attach(self)
            } else if steps.anchor === self || steps.anchor == nil {
                steps.attach(nil)
            }
        }
    }
}
