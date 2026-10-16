// OverbrightOnboarding/Chrome/WelcomeView.swift — the Welcome window's content (DESIGN.md §8): the step (its stage on
// top, its copy and controls below) and the footer. ↩ continues, ⌘[ goes back, Esc asks "Skip setup?" ([Skip]
// [Continue Setup] [Quit Overbright]). Hosted by the shell's `WelcomeWindowController`, which keeps the
// `WelcomeSession`. Ported from Cranny's WelcomeView (the owner's MIT code) without the notch stage.
import Foundation
import OverbrightCore
import OverbrightDesign
import SwiftUI

/// The Welcome window's content.
public struct WelcomeView: View {
    /// 640 × 480 (DESIGN.md §8); the window is not resizable.
    public static let windowSize = WelcomeMetrics.window

    /// The window's title (hidden in the title bar; read by VoiceOver and Mission Control).
    public static var windowTitle: String { OnboardingCopy.windowTitle }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var session: WelcomeSession
    @State private var isVisible = true

    /// Shows `session`, which the window controller keeps.
    public init(session: WelcomeSession) {
        _session = State(initialValue: session)
    }

    public var body: some View {
        VStack(spacing: 0) {
            StepPage(session: session, isWindowVisible: isVisible)
                .id(session.step)
                .transition(reduceMotion ? .opacity
                            : .asymmetric(insertion: .move(edge: session.movedForward ? .trailing : .leading),
                                          removal: .move(edge: session.movedForward ? .leading : .trailing))
                                .combined(with: .opacity))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
            WelcomeFooter(session: session)
                .padding(.horizontal, WelcomeMetrics.inset)
                .padding(.vertical, Space.xl)
        }
        .animation(OverbrightTheme(reduceMotion: reduceMotion).animation(.contentSwap), value: session.step)
        .frame(width: WelcomeMetrics.window.width, height: WelcomeMetrics.window.height)
        .background(.background)
        .background(WindowObserver(isVisible: $isVisible))
        .background { EscapeKey(session: session) }
        .ignoresSafeArea()
        .modifier(SkipConfirmation(session: session))
        .overbrightThemeRoot()
    }
}

/// Esc anywhere in the window asks first (DESIGN.md §8).
private struct EscapeKey: View {
    let session: WelcomeSession

    var body: some View {
        Button { session.requestSkip() } label: { EmptyView() }
            .keyboardShortcut(.cancelAction)
            .opacity(0)
            .accessibilityHidden(true)
    }
}

/// "Skip setup?" (DESIGN.md §12.4): [Skip] [Continue Setup] [Quit Overbright].
private struct SkipConfirmation: ViewModifier {
    @Bindable var session: WelcomeSession

    func body(content: Content) -> some View {
        content.alert(Text(verbatim: OnboardingCopy.skipTitle), isPresented: $session.isConfirmingSkip) {
            Button { session.skip() } label: { Text(verbatim: OnboardingCopy.skip) }
            Button(role: .cancel) {} label: { Text(verbatim: OnboardingCopy.continueSetup) }
            Button { session.quit() } label: { Text(verbatim: OnboardingCopy.quit) }
        } message: {
            Text(verbatim: OnboardingCopy.skipMessage)
        }
    }
}

/// The step on screen.
private struct StepPage: View {
    let session: WelcomeSession
    let isWindowVisible: Bool

    var body: some View {
        switch session.step {
        case .hello: HelloStep(session: session, isWindowVisible: isWindowVisible)
        case .displays: DisplaysStep(session: session)
        case .defaults: DefaultsStep(session: session)
        case .findIt: FindItStep(session: session)
        case .done: DoneStep(session: session)
        }
    }
}

#Preview("Welcome · step 1") {
    WelcomeView(session: WelcomeSession(services: .preview()) { _ in })
}

#Preview("Welcome · last step") {
    WelcomeView(session: WelcomeSession(services: .preview(), initialStep: .done) { _ in })
}
