// OverbrightOnboarding/Steps/WindowScreenReader.swift — which display the Welcome window is on, for step 1's card: the
// card shows Bright room of that display and registers its EDR content there (`OwnEDRSurfaces`, ARCHITECTURE.md D6).
// Event-driven (`NSWindow.didChangeScreenNotification`, no polling) and read-only: it reads the screen's display ID
// and its CoreGraphics UUID, nothing else.
import AppKit
import OverbrightCore
import OverbrightDesign
import SwiftUI

/// Reports the display its window is on (nil while it has no window or screen).
struct WindowScreenReader: NSViewRepresentable {
    /// Called with the window's display whenever it changes.
    let onChange: @MainActor (DisplayKey?) -> Void

    func makeNSView(context: Context) -> ReaderView {
        let view = ReaderView()
        view.onChange = onChange
        return view
    }

    func updateNSView(_ view: ReaderView, context: Context) { view.onChange = onChange }

    /// The observing view: invisible and click-through.
    final class ReaderView: NSView {
        var onChange: @MainActor (DisplayKey?) -> Void = { _ in }
        private var observer: (any NSObjectProtocol)?
        private var reported: DisplayKey??

        /// Also called with `window == nil` when the view leaves its window: the observer goes with it.
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let observer { NotificationCenter.default.removeObserver(observer) }
            observer = nil
            if let window {
                observer = NotificationCenter.default.addObserver(forName: NSWindow.didChangeScreenNotification,
                                                                  object: window, queue: .main) { [weak self] _ in
                    MainActor.assumeIsolated { self?.report() }                   // queue: .main
                }
            }
            Task { [weak self] in self?.report() }                             // not during SwiftUI's update
        }

        override func hitTest(_ point: NSPoint) -> NSView? { nil }

        private func report() {
            let key = window?.screen.flatMap(Self.displayKey(of:))
            guard reported != .some(key) else { return }
            reported = .some(key)
            onChange(key)
        }

        /// The CoreGraphics display of `screen`, as a `DisplayKey` (read-only).
        static func displayKey(of screen: NSScreen) -> DisplayKey? {
            guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
                return nil
            }
            return DisplayKey.of(number.uint32Value)
        }
    }
}

#Preview("Window screen reader") {
    @Previewable @State var display: DisplayKey?
    let services = WelcomePreview.services()
    // The preview hub's displays are fixtures, so a real screen shows its key rather than a fixture's name.
    Text(verbatim: display.map { services.displays.facts(for: $0)?.name ?? $0.rawValue } ?? "—")
        .font(.callout)
        .padding(Space.xl)
        .background { WindowScreenReader { display = $0 } }
        .overbrightThemeRoot()
}
