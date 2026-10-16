// OverbrightAppShell — the composition root, the status item and every window. ARCHITECTURE.md §2.1, §7.4, §7.6, §10.0.
// Placeholder written by WP0a so that every target of Package.swift exists from the start (§2.1 rule 4);
// its owner (WP0a) replaces it.
import OverbrightCore
import OverbrightPolicy
import OverbrightDesign

/// Names the module until its work package lands; the placeholder test checks that it links.
public enum OverbrightAppShellModule {
    /// The target name.
    public static let name = "OverbrightAppShell"
}
