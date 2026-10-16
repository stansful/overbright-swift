// OverbrightIntents/Router/StateReport.swift — the answer of Get Overbright State. DESIGN.md §12.8 ("Get State
// dialog"), §1 principle 4 (one value text everywhere); ARCHITECTURE.md §7.7.

/// What Get Overbright State returns: the on/off value and the dialog, already localized ("Overbright is on.
/// Built-in Display: Bright room · ×1.29." / "Overbright is off.").
public nonisolated struct StateReport: Hashable, Sendable {
    /// The master switch (the intent's result value).
    public var isOn: Bool
    /// The spoken and shown sentence.
    public var dialog: String

    /// A report.
    public init(isOn: Bool, dialog: String) { self.isOn = isOn; self.dialog = dialog }
}
