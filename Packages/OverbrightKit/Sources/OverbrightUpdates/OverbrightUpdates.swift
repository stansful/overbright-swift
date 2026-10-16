// OverbrightUpdates — module overview. ARCHITECTURE.md §2.1 rule 7 (the only module with networking APIs), §3.6
// (`UpdateChecking`), §8.2, D2; DESIGN.md §7.3, §7.9. Ported from Cranny's UpdateChecker (the owner's MIT code) by WP0b.
//
//   UpdateChecker.swift      the `UpdateChecking` and `ServiceLifecycle`: one GET against GitHub Releases, daily (one
//                            sleep to the next due time, no polling) while `UpdateSettings.automatic` is on, and on
//                            demand. Never downloads or installs anything; shows "Update Available" through `state`.
//   GitHub/                  the pure side: the repository setting (`OverbrightGitHubRepository` in Info.plist; empty =
//                            no check and no network at all), the request (ETag, no cookies, no identifiers), the
//                            release decoding, the version comparison and the localized failures.
//   Transport/               the single network call behind a protocol (tests answer with fixtures), an ephemeral
//                            `URLSession` created on the first request.
