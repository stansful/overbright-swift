// OverbrightPanelUI/Help/HelpView.swift — the local Help window's content. DESIGN.md §12.6, §2.0 rule 3 (the host
// applies `.overbrightThemeRoot` once), §15 (VoiceOver: each answer is a heading plus its text).
// Seam written by WP0a (ARCHITECTURE.md §10.0): `init(anchor:)` is fixed (the shell's Help window hosts it); WP10 adds
// `init(anchor:backToStandardKeys:)` (fixed key caps, for tests and previews) and `init(anchor:shortcuts:)`, which
// observes the shortcut center as Welcome step 4 does: answer 3 shows the live Back to Standard shortcut, follows a
// rebind or a clear while the window is open, and appears once the shortcuts register after the window opened.
import OverbrightCore
import OverbrightDesign
import SwiftUI

/// Every Help entry, scrolled to `anchor` ("no-extra-range", "control-center", …) when given.
public struct HelpView: View {
    private let anchor: String?
    private let fixedKeys: String?
    private let shortcuts: (any ShortcutCenter)?

    /// Help, optionally at `anchor` (answer 3 without a shortcut).
    public init(anchor: String?) { self.init(anchor: anchor, backToStandardKeys: nil) }

    /// Help at `anchor`; `backToStandardKeys` is the key caps of Back to Standard (`ShortcutCenter.displayString`),
    /// read once.
    public init(anchor: String?, backToStandardKeys: String?) {
        self.anchor = anchor
        fixedKeys = backToStandardKeys
        shortcuts = nil
    }

    /// Help at `anchor`, with answer 3 naming Back to Standard's live key caps from `shortcuts` (observed: a rebind,
    /// a clear or a late registration updates the open window).
    public init(anchor: String?, shortcuts: any ShortcutCenter) {
        self.anchor = anchor
        fixedKeys = nil
        self.shortcuts = shortcuts
    }

    /// The key caps answer 3 names now (nil: the variant without a shortcut).
    var backToStandardKeys: String? { shortcuts.map { $0.displayString(.standard) } ?? fixedKeys }

    /// The answers, in order.
    var entries: [HelpEntry] { HelpEntry.all(backToStandardKeys: backToStandardKeys) }

    /// The anchor the view scrolls to: a known one, else none (the top).
    var resolvedAnchor: String? { HelpView.resolve(anchor) }

    /// A known anchor, or nil for nil and unknown ones (the window then opens at the top).
    public static func resolve(_ anchor: String?) -> String? {
        guard let anchor, HelpEntry.Anchor.all.contains(anchor) else { return nil }
        return anchor
    }

    public var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: Space.xxl) {
                    ForEach(entries) { entry in
                        HelpEntryView(entry: entry, isHighlighted: entry.id == resolvedAnchor)
                            .id(entry.id)
                    }
                }
                .padding(Space.xxl)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .onAppear { scroll(proxy) }
            .onChange(of: anchor) { scroll(proxy) }
        }
        .frame(minWidth: 480, idealWidth: 520, minHeight: 360, idealHeight: 520)
    }

    private func scroll(_ proxy: ScrollViewProxy) {
        guard let target = resolvedAnchor else { return }
        proxy.scrollTo(target, anchor: .top)
    }
}

/// One answer: the question as a heading, then the answer.
private struct HelpEntryView: View {
    let entry: HelpEntry
    let isHighlighted: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            Text(verbatim: entry.question)
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            Text(verbatim: entry.answer)
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        }
        .padding(Space.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            if isHighlighted {
                RoundedRectangle(cornerRadius: Radius.card, style: .continuous).fill(.tint.opacity(0.08))
            }
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview("Help") {
    HelpView(anchor: nil, backToStandardKeys: "⌃⌥⌘0")
        .overbrightThemeRoot()
}

#Preview("Help · the live shortcut") {
    HelpView(anchor: HelpEntry.Anchor.backToStandard, shortcuts: PreviewShortcutCenter())
        .overbrightThemeRoot()
}

#Preview("Help · at an anchor, no shortcut") {
    HelpView(anchor: HelpEntry.Anchor.controlCenter)
        .overbrightThemeRoot()
}
