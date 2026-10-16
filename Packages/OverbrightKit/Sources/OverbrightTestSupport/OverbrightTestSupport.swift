// OverbrightTestSupport — test helpers for the test targets only (never linked into the app). ARCHITECTURE.md §9.1, §10.1.
// Placeholder written by WP0a so that every target of Package.swift exists from the start (§2.1 rule 4);
// its owner (WP0a) replaces it.
import OverbrightCore
import OverbrightPolicy

/// Names the module until its work package lands; the placeholder test checks that it links.
public enum OverbrightTestSupportModule {
    /// The target name.
    public static let name = "OverbrightTestSupport"
}
