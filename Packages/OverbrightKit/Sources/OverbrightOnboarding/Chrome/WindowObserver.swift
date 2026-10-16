// OverbrightOnboarding/Chrome/WindowObserver.swift — what the Welcome content needs to know about its window: whether it
// is actually visible (not occluded, not minimised), so the before/after card pauses its EDR content when nobody can see
// it (DESIGN.md §8: "The card pauses while the window is hidden"; D22). Event-driven: window notifications, no polling.
// Ported from Cranny's WindowVisibility (the owner's MIT code).
import AppKit
import SwiftUI

/// Reports its window's visibility.
struct WindowObserver: NSViewRepresentable {
    @Binding var isVisible: Bool

    func makeNSView(context: Context) -> ObserverView {
        let view = ObserverView()
        update(view)
        return view
    }

    func updateNSView(_ view: ObserverView, context: Context) { update(view) }

    private func update(_ view: ObserverView) {
        let binding = $isVisible
        view.onVisibility = { visible in if binding.wrappedValue != visible { binding.wrappedValue = visible } }
    }

    /// The observing view: invisible and click-through.
    final class ObserverView: NSView {
        var onVisibility: @MainActor (Bool) -> Void = { _ in }
        private var observer: (any NSObjectProtocol)?

        /// Also called with `window == nil` when the view leaves its window: the observer goes with it.
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let observer { NotificationCenter.default.removeObserver(observer) }
            observer = nil
            guard let window else { return }
            observer = NotificationCenter.default.addObserver(forName: NSWindow.didChangeOcclusionStateNotification,
                                                              object: window, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.reportVisibility() }                 // queue: .main
            }
            Task { [weak self] in self?.reportVisibility() }                        // not during SwiftUI's update
        }

        override func hitTest(_ point: NSPoint) -> NSView? { nil }

        private func reportVisibility() {
            onVisibility(window?.occlusionState.contains(.visible) ?? false)
        }
    }
}
