// OverbrightPanelUI/Panel/MenuAnchor.swift — pops an AppKit menu up at a SwiftUI view, so the keyboard reaches what a
// right-click shows: ⌃↩ opens the focused card's context menu (DESIGN.md §5.4, §5.12; nothing depends on
// right-click, §1 principle 8).
import AppKit
import SwiftUI

/// A reference to the AppKit view behind a SwiftUI view, for popping up menus there.
@MainActor final class MenuAnchorReference {
    /// The anchor view, once SwiftUI has made it.
    weak var view: NSView?

    /// Pops `items` up under the anchor's top-leading corner; nothing when the anchor is not in a window.
    func popUp(_ items: [NSMenuItem]) {
        guard let view, view.window != nil, !items.isEmpty else { return }
        let menu = NSMenu()
        menu.autoenablesItems = false
        for item in items { menu.addItem(item) }
        menu.popUp(positioning: nil, at: CGPoint(x: 0, y: view.bounds.height), in: view)
    }
}

/// An invisible view that hands its `NSView` to a `MenuAnchorReference`.
struct MenuAnchor: NSViewRepresentable {
    let reference: MenuAnchorReference

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        reference.view = view
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) { reference.view = nsView }
}
