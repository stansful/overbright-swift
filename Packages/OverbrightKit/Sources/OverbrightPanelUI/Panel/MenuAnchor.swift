// OverbrightPanelUI/Panel/MenuAnchor.swift — pops an AppKit menu up at a SwiftUI view, so the keyboard reaches what a
// right-click or a SwiftUI menu shows: ⌃↩ opens the focused card's context menu, Space and Return open a focused footer
// chip's menu, the "⋯" menu and the Fill Light card's display pop-up (DESIGN.md §5.4, §5.12; nothing depends on
// right-click or the pointer, §1 principle 8).
import AppKit
import SwiftUI

/// A reference to the AppKit view behind a SwiftUI view, for popping up menus there. Layouts that measure several
/// alternatives (`ViewThatFits`) may make one view per alternative: the menu opens at the one that is in a window.
@MainActor final class MenuAnchorReference {
    private let views = NSHashTable<NSView>.weakObjects()

    /// The anchor view on screen, once SwiftUI has made it.
    var view: NSView? { views.allObjects.first { $0.window != nil && !$0.isHiddenOrHasHiddenAncestor } }

    /// Remembers `view` as one of the anchor's views.
    func attach(_ view: NSView) { views.add(view) }

    /// Pops `items` up under the anchor's top-leading corner; nothing when the anchor is not in a window.
    func popUp(_ items: [NSMenuItem]) {
        guard let view, !items.isEmpty else { return }
        let menu = NSMenu()
        menu.autoenablesItems = false
        for item in items { menu.addItem(item) }
        menu.popUp(positioning: nil, at: CGPoint(x: 0, y: view.isFlipped ? 0 : view.bounds.height), in: view)
    }
}

/// How the panel opens a menu from the keyboard: AppKit's menu at the anchor (tests record the rows instead of
/// tracking a menu, which would wait for a click).
struct PanelMenuPresenter: Sendable {
    /// Opens `items` at `anchor`.
    let present: @MainActor (MenuAnchorReference, [NSMenuItem]) -> Void

    /// The menu at the anchor.
    static let appKit = PanelMenuPresenter { anchor, items in anchor.popUp(items) }
}

extension EnvironmentValues {
    /// How the panel's views open their keyboard menus.
    @Entry var panelMenuPresenter: PanelMenuPresenter = .appKit
}

/// An invisible view that hands its `NSView` to a `MenuAnchorReference`.
struct MenuAnchor: NSViewRepresentable {
    let reference: MenuAnchorReference

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        reference.attach(view)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) { reference.attach(nsView) }
}
