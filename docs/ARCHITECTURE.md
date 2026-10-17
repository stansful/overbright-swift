# Overbright Architecture

> One thin Xcode app, one Swift package, seventeen modules that never import each other sideways. A per-display engine raises EDR headroom with the lightest trigger that works, scales the display's transfer table only as far as measured headroom allows, judges every table against the display's own profile, and always lands on a neutral screen.

| | |
|---|---|
| Status | **As built through WP15, with WP14's review fixes** (2026-10-17; every area's fixes are on `main` and recorded where they land; §10.16 lists what is handed on). Written as v0.2 before any code existed and revised after a design review of 86 findings (Appendix B maps each one to its fix); every package since has synced its sections with "As built" notes. It is the contract every package codes against. `docs/DESIGN.md` is the single source of truth for pixels, colours, motion and copy; this document owns code structure, contracts, behaviour of the engine, threading, build and the work plan. Once code exists, the repo wins where a listing here and a file differ, and the listing is corrected (Cranny's rule). |
| Toolchain | Xcode 27.1 (27A9275), Swift 6.4, MacOSX27.0 SDK, verified on macOS 27.0.1. **Minimum toolchain for the app: Xcode 27 / Swift 6.4**, because `AppIntent.allowedExecutionTargets` is declared `@available(anyAppleOS 27.0, *)` in the macOS 27 SDK and does not exist in Xcode 26's SDK; `#available` cannot hide a symbol the SDK lacks [VERIFIED in the SDK's AppIntents swiftinterface]. The package alone (`swift-tools-version: 6.2`, no intent declarations) still builds and tests with Xcode 26 / Swift 6.2, which CI's macos-26 job exercises. `scripts/lib.sh` sets `MIN_XCODE_MAJOR=27`. **No Metal Toolchain** (D22). |
| Platform | macOS 14.0 deployment target, universal (arm64 + x86_64). Newer APIs only behind `#available`. Not sandboxed, hardened runtime, agent app (`LSUIElement`), ad-hoc signed by default. |
| Licence | MIT, clean room (D3). No code, assets or UI text from the incumbent commercial app or from any GPL project; zero third-party dependencies (D2). |
| Evidence | Five research reports and four feasibility studies were written before this document. They contain reverse-engineering notes and stay outside the repo. Everything a contributor needs from them is restated here and in `docs/research/` as behaviour and public-API facts. Every Swift contract in §3 and §3.10 was **compiled** for this document, the settings store against the real ported file (Appendix A). |
| Sibling | Scaffold, conventions, tooling and many files come from Cranny (`/Users/stansful/projects/my/nook-preview/Cranny`, the same owner's MIT project). "Cranny" in this document always means that repo. |

Status tags: **[VERIFIED]** built or run on macOS 27.0.1 for this document or its studies · **[SDK]** checked in the SDK headers · **[HW]** needs the owner's hardware session (`docs/HARDWARE-TEST.md`) · **[U]** unverified; the owning work package must confirm it.

**Contents.** 0 Decisions · 1 Goals, non-goals, repository · 2 Package · 3 Core contracts · 4 The per-display engine · 5 Brightness math · 6 Policy reducer · 7 System integration, safety, compatibility mode, surfaces · 8 Concurrency, persistence, logging, diagnostics, build, localization · 9 Testing, engineering rules, definition of done · **10 Work packages** · 11 Failure modes, risks, open hardware questions · Appendix A Verification log · Appendix B Review findings · Changelog.

---

## 0. Decisions

D1–D22 are the binding decisions the project owner's orchestrator took from the research. Each row says whether this document keeps it (**binding**), refines details inside it (**refined**) or changes it because a feasibility study or the review found evidence against it (**changed**). D23–D27 are new; D28 was taken in the WP14 review; D29 and D30 in the energy pass (2026-10-17).

| # | Decision | Why / evidence | State |
|---|---|---|---|
| D1 | **Identity.** Name **Overbright**; bundle id `app.overbright.Overbright` (= log subsystem = Application Support and Caches folder name); MIT; macOS 14 minimum, features gated by availability (the tagged-`CALayer` trigger needs 26, Control Center controls need 26, `allowedExecutionTargets` needs 27 and therefore the Xcode 27 toolchain); universal binary; `LSUIElement` menu bar app; not sandboxed; hardened runtime; ad-hoc signing by default, optional Developer ID signing and notarization exactly as Cranny (`SIGN_IDENTITY`, `TEAM_ID`, `NOTARY_PROFILE`). Never change the bundle id after the first public release. One engine per user session (D27). | Cranny's scaffold, verified there. The non-sandboxed shape keeps every display API, IORegistry read and window recipe simple; nothing in the feature set needs a TCC permission (§7). | binding |
| D2 | **Zero third-party dependencies, no analytics or crash SDK, no account, no network** except Cranny's GitHub Releases update check, which is inert while the Info.plist key `OverbrightGitHubRepository` is empty and is offered as a toggle on the Welcome "Done" step. `THIRD_PARTY_NOTICES.md` has exactly these rows: **Cranny** (MIT, "Copyright (c) 2026 Cranny contributors", full MIT notice reproduced: "portions of the scaffold, build scripts, localization tooling, settings store, hot-key center and update checker are derived from Cranny"); **acknowledgements by idea, no code**: xdr-boost (multiply overlay), xdr-light (trigger + table, keep-alive), displaytint (process-death revert report), MonitorControl (screenshot behaviour), all MIT. Never listed: GPL projects, and projects without a stated licence (brightboi). Cranny's sentence "includes no third-party code" is not copied: Overbright includes Cranny-derived code. `LICENSE` names "Overbright contributors". | Privacy is a differentiator: reviewers report unexplained background traffic from the incumbent, and newer competitors advertise "no network" (`docs/research/ux-landscape.md`). The MIT notice of ported code must be retained. | refined |
| D3 | **Copy denylist**, checked by `scripts/lint-copy.py` and `scripts/l10n/validate.py` in keys, values **and translator comments** of every catalog (`Resources/*.xcstrings`, `App/*.xcstrings`) in every language: `v[iíì]v[iíì]d`, `lumen[\s-]*digital`, `bright[\s-]*intosh`, `better[\s-]*display` (case-insensitive) and `\bLunar\b`, `lunar\.app`, `fyi\.lunar` (case-sensitive, because "lunar" is an ordinary word in Romanian, Spanish, Catalan and Portuguese). "BetterDisplay" and "Lunar" come off `validate.py`'s keep-as-is list. Competitor names reach the UI only at runtime, through `NSRunningApplication.localizedName` in a `%@`. **Allowlist of the source scan** (`noDenylistedNamesOutsideAllowlist`, Core, and `lint-copy.py`, over every text file of the repository: what git tracks plus untracked files `.gitignore` does not exclude, so the root's README, notices and Makefile, `.github/workflows`, the Xcode project and `Package.swift` too; as built in WP14, which widened it from `Sources/`, `Tests/`, `App/`, `Controls/`, `Shared/`, `scripts/` and `docs/`): (1) `Sources/OverbrightPolicy/Conflicts/ConflictCatalog.swift`, bundle-ID-shaped literals and bundle-less executable names only; (2) the denylist definitions in `scripts/lint-copy.py` and `scripts/l10n/l10n.py`, only on lines carrying `denylist-ok` (comments there may not name products otherwise); (3) any Markdown line carrying `<!-- denylist-ok -->` (CONTRIBUTING's clean-room paragraph uses it); (4) `docs/research/` as a whole. Tests never contain real catalogue bundle IDs: matcher tests use synthetic IDs (`com.example.booster`) or reference entries by `ConflictCatalog` id. For the record, the incumbent is Vivid by Lumen Digital. <!-- denylist-ok --> | A clean-room project must not echo its competitor in any language. The regexes were tested in Python: an earlier `viv[iíì]d` missed Spanish "vívido". Without the explicit allowlist, WP0a's own lint scripts and WP1's matcher tests would fail the lint. | refined |
| D4 | **Mechanism: EDR trigger + transfer-table scaling** through public CoreGraphics (`CGGetDisplayTransferByTable` / `CGSetDisplayTransferByTable`), per display. The trigger is a **strategy ladder** with automatic escalation, cached per display UUID + macOS build (§4.7): **T1** tagged `CALayer` (`preferredDynamicRange = .high`, headroom-tagged `CGColor`, macOS 26+) black, then 1.6; **T2** `CAMetalLayer` (`rgba16Float`, extended linear sRGB) one clear-only frame, black, then 1.6, re-presented on events; **T3** T2 with a 5 s keep-alive; **T4-alt** one in-memory HLG frame in `AVSampleBufferDisplayLayer` if hardware test H-T4d passes, else **T4** our own runtime-generated HLG still in a paused `AVPlayerLayer`; then T4 at peak. Trigger windows: 1 pt, `.screenSaver` level, all Spaces + full-screen auxiliary + `.canJoinAllApplications`, click-through, `sharingType = .none`, placed in the top-right corner (hidden by the rounded corner on notched built-ins). **Compatibility mode** (technique C): a full-screen EDR overlay with multiply compositing per display, suggested automatically on the models of Policy's `CompatibilityModels` (Mac17,5 and Mac17,6–17,9 on macOS ≥ 26.3, read through Core's `MachineIdentity`), or when the user says the screen did not get brighter (§7.5). | **Changed in three details**, following the trigger study: (1) the "1.0" pixel rung is dropped from the default ladder: on masked placements every value is invisible and on unmasked ones every non-black value is visible, so it only adds a timeout; (2) T4-alt (no file, no codec) is added ahead of T4; (3) macOS 14–25 start at T2, because the deprecated `CALayer` EDR flag path is untested on a real 14/15 Mac. A 0.2 s cadence is a lab setting only: it keeps the GPU working set allocated forever. OLED externals use black pixels only by default. Every strategy compiles at the macOS 14 floor for both architectures with zero warnings, and none needs a `.metal` file [VERIFIED]. Which rung engages and holds is [HW]. | changed |
| D5 | **Factor model in light units.** The level maps to a light gain `G`; every cap is a cap on `G`; the table factor is `F = tableFactor(G, domain)`. The default domain **`.encoded`** uses the sRGB curve at and below white (dimming) and the conservative pure power `F = G^(1/2.4)` above it, so `F^k ≤ G` for every truth exponent `k ≤ 2.4`, the sRGB curve included: it never clips under any of those models and costs ≤ 4 % of light if the truth is the sRGB curve (§5.2). **`.linear`** is selected only by a calibration whose linear result was positively confirmed, and falls back to `.encoded` whenever the OS build, mechanism or potential differ from the record's. **Central interlock, in one function** (`GainCeiling.liveCap`, called only by Boost's `TableWriter`): taper (D11), live Safe bound, then `G ≤ 0.97 × H_live` from a reading of the same display at most 150 ms old. Lowering for safety is immediate once the applied gain exceeds `0.98 × H` (a 1 % dead band); a user raise applies at once when a fresh reading supports it; a raise driven by headroom recovery waits for 1.5 s of stable headroom and ≥ 5 %. User and policy transitions ramp over 300 ms (250–400), Reduce Motion shortens to 160 ms but never snaps; every reapply after a reset ramps too; a rate limiter and an oscillation detector keep the screen flicker-safe (WCAG 2.3.1). | Whether the table scales linear light or encoded values on Apple XDR is unmeasured (`docs/research/edr-mechanism.md` §4). The v0.1 default (`encodeSRGB`) was safe only for exponents up to ≈ 2.33 and clipped under a pure 2.4 power (at H 3.2, `1.636^2.4 = 3.26 > H`). One visual keypress could set an unsafe domain; now only a confirmation that is impossible under the encoded truth can. | refined |
| D6 | **Gating.** Measure idle headroom `H0` (the highest of three reads 100 ms apart) before arming. **Normal path:** escalate to the next rung when `H < H0 + 0.05` for 2.5 s after a rung's first successful present; ready when `H ≥ max(1.1, H0 + 0.1)` and stable within ±0.05 for 1.5 s; 12 s timeout from the first movement. **Pre-held path:** when something already holds EDR on the display (another app's HDR content, Overbright's own Fill Light, Welcome card or calibration window, `OwnEDRSurfaces`), i.e. `H0 ≥ max(1.3, G_static / 0.97)`, or `H0 ≥ 1.25` and stable, arm the cheapest rung (so the grant survives when the other source leaves), skip the movement test and use the absolute gate (`H ≥ 1.1`, stable 1.5 s); escalate only while `H` is below the needed headroom. Generation numbers drop stale async completions (§4.6). | macOS 27 often idles at H ≈ 1.2 without any request, so a fixed 1.05 gate passes early. WindowServer's own logs on the owner's Mac show up-ramps with a median of 1.14 s (max 4.75 s) and near-instant drops [VERIFIED, passive log read]. Without the pre-held path, an HDR video or our own Fill Light pins `H0` at the grant ceiling, no rung can show movement, and the display ends in "No extra range" while plenty is available. The gate is not the safety mechanism; the interlock (D5) is, so a gating error can only slow the ramp. | refined |
| D7 | **Safety and restore.** Stop = ramp down → write each display's captured baseline → remove the trigger, in that order. A quit from inside the app is cancelled once, awaits the ramped stop for at most 1 s, then terminates (AppKit's `.terminateLater` wait serves no main-actor work, §7.4); a quit Apple Event (a script, the Dock, Activity Monitor, log out, restart, shut down) terminates at once; `applicationWillTerminate` writes ledger baselines synchronously as a fallback. Never call the global `CGDisplayRestoreColorSyncSettings` in normal operation; it is called only by the launch rescue, `--restore-gamma` and Advanced ▸ Reset Display Colors, always as **dirty-then-restore** (write the read-back table unchanged, then restore, then verify every display: `matchesBase`, or monotonic, starting ≤ 0.1 and ending ≥ 0.9; otherwise write the profile base explicitly and journal it). The launch rescue runs when any online table classifies as `scaled` against its profile base (D26) and no catalogued table writer (S1–S3) runs; it is skipped while the session is not on the console (D27). WindowServer reverts a process's table writes when that process dies (quit, crash, SIGKILL, jetsam), so there is no guardian process; a hang watchdog on a background queue writes ledger baselines if the main thread stalls for 3 s while a display is scaled, and bumps a **hang epoch** that makes `TableWriter` refuse every scaled write stamped before it until the engine re-gates. SIGTERM/SIGINT/SIGHUP sources run on a dedicated queue: write ledger baselines, attempt the main-actor stop with a 1 s timeout, exit. Back to Standard always works. Release launch arguments `--off`, `--restore-gamma`, `--diagnostics`, plus the read-only `--monitor` (§8.5). | Static inspection of macOS 27.0.1's display server confirms the revert on process death and shows that `CGDisplayRestoreColorSyncSettings` from a process that wrote no table does nothing; hence dirty-then-restore [VERIFIED, static inspection of system frameworks; HW run pending]. A third-party FAQ reports the global restore sometimes writing all-zero tables; the plausibility check catches that. Three residual cases keep a scaled table: a hung but living process (the watchdog), death while a display is captured (rare; the launch rescue), and session-level writes by other tools through private API (rescue cannot clear these; the UI explains). | refined |
| D8 | **Eligibility**, locale-independent: names are never compared. Exclude virtual displays (Sidecar, AirPlay, placeholder vendor, no table); hardware-mirror members without their own `NSScreen` → `mirrored` (dim only); reference > 0 → reference preset, no boost; potential ≤ 1 → "turn on HDR" (external with PQ support) or "switch preset" (built-in or XDR panel); potential ≤ 2 → LCD class, no boost; potential × 100 < 0.9 × the IORegistry panel peak → "the preset limits HDR"; a boosting class whose panel peak or SDR maximum no source gives → `panelFactsUnknown` (dim only, no gain claimed; WP14, C-PLATFORM-3); Peak gain at full brightness < 1.1 → "little gain"; else supported. **Verdict sentences quote the default (Safe) ceiling and, once one exists, the grant macOS actually gave; the potential-derived figure appears only in Advanced and diagnostics.** Built-in XDR and Apple XDR externals have extra brightness on by default; other HDR externals and OLED externals are opt-in (OLED with a burn-in notice, a lower Safe cap and idle pause). Dimming needs no opt-in on any display with a table or the overlay. | `maximumPotential…` reads ≈ preset peak ÷ 100 nits (16 on the M4 Max built-in in the 1600-nit preset, 4.6549 on the MSI OLED with HDR on = EDID max 465.49 ÷ 100) [VERIFIED]. Exact-value whitelists and English display names fail on this very Mac: the system runs ru-RU and macOS localizes the built-in display's name. OLED is detected by IORegistry minimum luminance ≤ 0.005 nits (self-emissive), never by name; the user override reaches the classifier through `DisplayPreferences`. Quoting "up to ≈ 2.7×" from the potential overpromised by about 70 % against the grants logged on this Mac. | refined |
| D9 | **Events.** Reconfiguration callback (begin phase: overlays to factor 1 only; **remove flag: handled at once on main**, trigger and overlay ordered out first; after phase debounced 0.5 s and confirmed at 2 s), screen-parameters change, workspace sleep/wake and screens sleep/wake, session resign/become active, active Space, app activation/launch/termination, accessibility display options, distributed lock/unlock and screensaver start/stop, ColorSync profile change, trigger occlusion and screen change, thermal, Low Power, IOPS power source, macOS 26 HDR-suppression messages (logged, shown as a reason, never escalated against, never a stop). **Shield and safety events reach every controller synchronously** (neutral before the handler returns), then one coalesced re-reduction. **Zero work while off.** While scaled or dimmed: a 2 s drift check (§4.8: the highest index with `B × F ≤ 0.98`, classified by the nearest hypothesis with a separation of at least twice the tolerance), plus a check 50 ms after any app terminates (WindowServer resets every display when any table writer dies), plus a headroom check; drift → recompute the expected base, adopt only near a ColorSync, reconfiguration or accessibility event and after two identical reads, reapply with a ramp; 3 repairs in 6 s, more than 2 unexplained adoptions in 60 s, or a known conflicting app → suspend and name the cause. | Tables are reset by reconfiguration, sleep/wake, profile and preset changes and other apps. Read-back of entries above 1.0 is **reported** to clamp (one field report); HARDWARE-TEST §2.0 settles it, and no check depends on it (D26). The battery-percent source runs only while boosted on battery; the power state is also read synchronously whenever the boost turns on, so the reducer never sees an hours-old percentage. Conflicts have four severity classes (§7.2). | refined |
| D10 | **Policy is a pure, exhaustively tested reducer** in the nonisolated `OverbrightPolicy` target: settings + system snapshot + per-display facts + machine identity → per-display target and ordered reasons. Guards and defaults: battery (pause below 20 %, adjustable 5–95 % in steps of 5, or only on the adapter), Low Power Mode → off, thermal serious → cap ×1.2, critical → off, auto-off timer (off; 5, 10, 15, 20, 30, 45 min, 1, 1.5, 2 h), OLED idle pause (5 min) from system idle time, **pause for full-screen video** (on, beta: a full-screen window whose owner holds a display-sleep assertion), **pause for every full-screen app** (off), per-app pause list with suggested defaults (QuickTime Player, TV, Photos, IINA, Infuse, VLC, Final Cut Pro, DaVinci Resolve ×3, Plex ×2), optional games rule (off), schedule window (off), Focus filter, conflicts. | **Refined:** (1) power and heat guards and the per-display boost switch block the boost half only; dimming always works, since it saves power; (2) app rules pause only the display that shows the app's window; (3) players use "while playing" (a display-sleep power assertion) instead of "while in front", marked beta until [HW]; (4) browsers and game launchers are deliberately not on the list; full-screen video in a browser is covered by the full-screen video rule; (5) a rule that paused every full-screen window would silently remove the boost from people who read or write full screen outdoors, the core use case. | refined |
| D11 | **Dim below minimum** is the left half of the one per-display slider, with a detent at Standard. Left of the detent multiplies the table below 1 (no trigger, any display with a table or the overlay, HDR or not, no per-display switch); right of it boosts. The dim half is shaped in stops: the first half of its travel covers −1 stop, the rest reaches the floor at 2 % of the current SDR light (−5.6 stops). Steps are defined in stops, not travel (§5.3). Setting a level below 10 % of Standard light from any surface asks "Keep this level?" and reverts after 10 s without an answer. "Add extra brightness only near full brightness" (default on) tapers the boost towards ×1 as the user lowers system brightness, so the brightness keys keep their normal range. | The incumbent's dim mode is well liked; a unified control is the precedent of other tools. Equal travel was 7.6–15× more change on the dim side than on the boost side; a 2 % floor relative to an already low system brightness is effectively black. Our name is "Dim below minimum" (Settings) / "Dimmed" (readout). | refined |
| D12 | **Fill Light**: an optional edge glow around a chosen display (width, warmth, brightness), using EDR headroom when available, click-through, excluded from capture where macOS allows, optionally on while a camera is in use (CoreMediaIO "running somewhere", no permission). While it is on, the panel shows a compact Fill Light card with its sliders. | **Changed: renamed from "Ring Light".** That name is already used by other products in this category, so our copy would mirror theirs; "Fill Light" is the generic photography term for the same job. The module is `OverbrightFillLight`. | changed |
| D13 | **Menu bar:** AppKit `NSStatusItem` (not a `MenuBarExtra`-only app, which macOS terminates when the user removes the extra) with a code-drawn template symbol (off / on / preparing / dimming / paused / attention). Left-click opens the panel (a SwiftUI view in a non-activating `NSPanel`, 320 pt wide); right-click or ⌃-click opens an `NSMenu` whose first line states any attention or pause cause. "Clicking the icon turns Overbright on or off" swaps the left click to a toggle and puts "Show Panel" at the top of the menu. **Every launch that is not a login launch shows UI**: Welcome until it is finished, else the panel under the icon, or Settings ▸ General when the icon is hidden or not visible; a relaunch while running does the same. A visibility check (3 s after launch and on every screen change) detects an icon that macOS hides or that the notch covers and says so. Quit is in the panel, the menu, Settings ▸ General and Welcome. Launched from outside `/Applications`, Overbright offers to move itself. The icon can be hidden after an explanation. A Dock icon with a Dock menu is optional (off). | HIG: menu bar extras use a symbol, offer a plain menu, and never rely on the extra being visible. macOS 26's "Allow in the Menu Bar" can hide any extra; the incumbent's first FAQ entry and its icon-not-visible helper show how often that happens. A cold launch that showed nothing would leave a hidden-icon user with no visible way to quit. | refined |
| D14 | **Panel anatomy:** header (symbol, title, master switch, overflow "…" with Dim All Displays, Fill Light, Settings, Self-Test, Help, Quit); one card per display that can boost or dim (name, the unified slider with detent and preset ticks Indoor / Bright room / Sunlight / Max, readout "Bright room · ×1.29", "≈ ×1.29" while uncalibrated, nits only with a trusted SDR white and a valid calibration, a status chip on its own line only when something per-display limits it); **headroom: a marker on the slider track where the thumb will stop now, with the allowed and the potential multiplier in its help tag and VoiceOver value**; footer guard chips (Battery, Auto-pause, Timer); one banner for every reason that applies to all displays; non-capable displays collapsed into one row with "Why?". One warm accent only for the boost zone. Cranny's token rules. Liquid Glass on the panel container only, never on cards. | **Refined:** a separate bar under the boost half could not show potential (its scale ends at the slider top, so it was simply full in Safe); the marker shows where the thumb stops, and the help tag says how far the display could go. Tick labels are not drawn under the half-width boost zone (four labels cannot fit 120 pt in every language); presets too close to show distinctly are hidden (§5.3). | refined |
| D15 | **Settings window:** an AppKit `NSWindow` hosting a SwiftUI `NavigationSplitView` with a searchable sidebar (Cranny's architecture). Panes: General (with **Quit Overbright**), Displays, Automations, Shortcuts, Fill Light, Advanced (with **Undo Reset** until the window closes and ⌘Z), About, with every row in DESIGN.md §7. | **Changed in one label:** the cap mode is **Safe / Peak**, not Safe / Max, because "Max" is already the top preset; one word must not mean two things. Reset All lives in Advanced. | changed |
| D16 | **Welcome window** (Cranny style, 640 × 480), five steps: a before/after card where only the card is boosted (EDR content inside our own window, no table write) with a draggable divider; per-display verdicts with fixes that refresh when displays change; defaults (guards and launch behaviour on one step); where to find Overbright; Done with the update-check toggle. Skipping applies every default, including the login item. A bottom-leading **Quit Overbright** button on every step. The calibration check moved out of Welcome into a one-time tip after the first boost. Reachable from Settings ▸ About. | HIG onboarding: teach through interaction, keep it short and optional, never put licensing in it. Calibration asks the user to turn off auto-brightness, which is unsafe while boosted and pointless before the first boost. | refined |
| D17 | **Shortcuts:** our own Carbon `RegisterEventHotKey` center and recorder (ported from Cranny's `HotKeyCenter`, signature `'OVBR'`). Actions and defaults (US key caps; copy always shows the live binding in the current keyboard layout): Turn on or off **⌃⌥⌘B**, Brighter **⌃⌥⌘=**, Less Bright **⌃⌥⌘-**, Back to Standard **⌃⌥⌘0**, Dim Below Minimum On or Off **⌃⌥⌘9**, Max (none), Fill Light (none). | No permission needed. The defaults avoid ⌃⌥Space (input sources), ⌃⌥⌘8 and ⌃⌥⌘, / ⌃⌥⌘. (accessibility), and ⌃⌥⌘V / ⌃⌥⌘D (another booster's defaults). ⌃⌥⌘9 is not among the system's symbolic hot keys on macOS 27.0.1 [VERIFIED: the only ⌃⌥⌘ entries are 8, comma and period]. "Dimmer" and "Dim" were near-homonyms that many languages translate to one word. The recorder warns about enabled macOS shortcuts. | refined |
| D18 | **App Intents and Focus filter ship in v1**: Turn Overbright On or Off, Turn On, Turn Off, **Set Extra Brightness** (a preset or a multiplier, for a display or all), **Dim Displays** (a light percentage 2–99, display optional), Pause for a duration, Resume, Get State (on/off + the panel's value text), Back to Standard; a `SetFocusFilterIntent` with Leave alone / Off / On at a level. The intent **declarations live in the app target** (`App/Intents/`) as one-line adapters with `App/Localizable.xcstrings`; their logic lives in `OverbrightIntents`' `IntentRouter`, created in `OverbrightApp.init` with no arguments and connected later by the composition root (`connect(boost:displays:signals:)`). **The Control Center `ControlWidgetToggle` is deferred in the default ad-hoc build**: a dormant, compile-checked extension target ships only when `CONTROLS=1` (default 1 when `TEAM_ID` is set), and is promoted to ad-hoc builds only if hardware test H-CC-1 passes on macOS 26 and 27 including after an update. Until then, Help points to the system **Run Shortcut** control wrapping our Turn On or Off action. No App Group, ever. | **Changed** following the controls study: a sandboxed ad-hoc extension builds, signs and registers [VERIFIED], but whether Control Center loads and renders it is unverified and every third-party report points the wrong way (macOS 14+ ties a sandbox container to the signature, and every ad-hoc update is a new code identity); App Groups are impossible without a Team ID. App Intents compiled into a static package module are extracted [VERIFIED], but package-defined intents are reported to show raw localization keys, and an `AppShortcutsProvider` in a package is silently dropped [VERIFIED]; so the user-facing declarations sit in the app target (a deliberate exception to Cranny's "app target = @main only"). Intents use the canonical units of DESIGN.md §1 principle 4. | changed |
| D19 | **HUD:** a small non-activating, capture-excluded panel that shows the new level when it changes through a shortcut, an intent or a Focus filter, "Preparing…" when an icon, shortcut or intent turn-on is not ready within 0.5 s, and a short reason whenever an automation stops, caps or resumes the boost on a visible display (timer, battery, Low Power, heat, schedule). Never for panel or Settings changes, nor for full-screen, app or game pauses the user caused. On by default. | Feedback without opening the panel; an unexplained dim reads as "it broke", the top complaint class in this category. | refined |
| D20 | **Diagnostics:** Copy Diagnostics (clipboard, never uploaded); an in-app Self-Test that records headroom, strategy and events into a log the user can save and share; `docs/HARDWARE-TEST.md` for the owner's session. **Refined:** the read-only `--monitor` launch argument prints each display's table class against its profile base (D26), table maximum and headroom every 250 ms, which replaces the research probes for the `kill -9` test. | Field reports need numbers; nothing leaves the Mac unless the user sends it. | refined |
| D21 | **Testing:** Swift Testing only; the engine is built on ports (`GammaPort`, `HeadroomPort`, `DisplayDirectory`, `TriggerFactory`, `TimeSource`, `SystemSignals`, `ConflictProbe`) with fakes and an injectable reducer; deterministic state-machine tests with a manual time source; property tests for the math; Cranny-style snapshot and measured-width localization tests; zero warnings; `check-modules` per target. Real-port tests are read-only. | **Refined:** the time port is named `TimeSource` (fake `ManualTimeSource`), because `Clock` is a Swift standard library protocol and `Settings` a SwiftUI scene: a Core type with either name would be ambiguous in every file [VERIFIED by a name probe]. | refined |
| D22 | **Energy:** zero work while off; no render loop unless a strategy demands it (and then measured); no Metal shader files, so the Metal Toolchain is not a build requirement. | A clear-only Metal pass needs no pipeline and no library: on the M4 Max it cleared an `rgba16Float` texture to 1.6 with `makeDefaultLibrary()` returning nil in the same process [VERIFIED off screen]. A lint check and a test keep `.metal` files out. | binding |
| D23 | **Module graph** (new): `OverbrightPolicy` and the Foundation-only `OverbrightChannel` are nonisolated L0 targets next to `OverbrightCore`; `OverbrightTriggers` is split out of `OverbrightBoost`; `OverbrightDesign` is an L1 target that also owns the user-facing names and sentences of Core and Policy enums (Core and Policy stay UI-free and string-free); a test-only `OverbrightTestSupport` library; Cranny's `FeatureModule`/`ModuleRegistry` plug-in system is replaced by an explicit `OverbrightServices` hub and an ordered `ServiceLifecycle` so the safety-critical start and stop order (Boost starts last, stops first) is visible in one place. 17 library targets + 16 test targets. | UI, Boost and Settings all need the math and verdicts, and L1 modules may not import each other; window and GPU code needs hardware to test while the state machine does not; the dormant extension must link a static product that no phase-B package has to edit Core for; Overbright contributes no widgets or pages that a plug-in system would serve. | new |
| D24 | **Developing never changes the developer's display state** (new). `make smoke` runs only `--diagnostics`, which must report `gammaWrites == 0` and `triggerWindows == 0`. Exactly one source file may call the CoreGraphics table setters or the global restore (`noSecondDisplayStateWriter` test). `make run` defaults to `--off --qa-simulate builtin-xdr-lid-open` with a dev defaults suite. Agents always use `--qa-simulate`; only the owner's hardware session runs without it. Tests never construct a writing real port; hardware-gated tests may read only (`noWritesInHardwareTests`). | Unlike Cranny, launching Overbright can raise EDR headroom and write transfer tables, and a test process that writes a table resets every display when it exits. | new |
| D25 | **Out-of-process state without an App Group** (new, used only if the control ships): one publish point in the app writes a notifyd state word (valid, on, level ‰, generation) and a preferences snapshot; the extension reads them read-only, treats "app not running" as off, and turns on only through a token-protected `overbright://` URL; `reloadAllControls()` at launch fixes a stale "on" after a crash. All of it lives in `OverbrightChannel`, the only code the extension links. | Compiles in the probe; runtime is [HW]. | new |
| D26 | **Neutrality is judged against the display's profile base, never by the table maximum** (new). The expected base of a display is derived without the live table: its ColorSync profile's `vcgt` (public ColorSync / `CGDisplayCopyColorSpace` ICC data), identity when absent (`GammaPort.profileBase`). Policy's `TableClassifier` compares a read with it: `matchesBase`; `scaled(ratio)` for a uniform ratio ≥ 1.02 or ≤ 0.98 at sub-1 sample indices on every channel, or a plateau of ≥ 2 entries ≥ 0.9995 before the last index where the base has none; `foreign` for per-channel curves; `invalid` for non-monotonic or all-zero tables. That one test drives the launch rescue, the post-restore check, `--monitor`'s flag and baseline acceptance; a candidate baseline that is a uniform multiple of the previous baseline or of the profile base is never adopted. | v0.1 keyed every residue and safety check on "maximum > 1.0005" while also assuming read-back clamps at 1.0; both cannot hold. If read-back clamps, the old rescue never fired, `--monitor` never showed SCALED, and another booster's table was accepted as a neutral baseline and multiplied again. The classifier works under either read-back model, and HARDWARE-TEST §2.0 records which one is true. | new |
| D27 | **One engine per user session, writing only on the console** (new). Before the launch check, a process that is not a CLI mode (`--diagnostics`, `--monitor`, `--restore-gamma`) or a launch wired to the simulated ports (`--qa-simulate` in a Debug build) looks for another process with our bundle ID; if one runs, it sends that instance a reopen and exits. No table write and no launch rescue happen while `CGSessionCopyCurrentDictionary()[kCGSessionOnConsoleKey]` is false; they run on `sessionDidBecomeActive`. | Two engines (the installed copy plus a dev build, `open -n`, a Terminal launch) see each other's writes as resets or drift and fight; if read-back clamps, one captures the other's scaled table as its baseline and the boosts compound. Tables belong to the display, not the session: a login item of a switched-away user would otherwise wipe the console user's tables. | new |
| D28 | **Signals' full-screen and playback watch keeps its own 2 s timer** (new; WP14, C-SIGNALS-6). While the boost-only sources run (a display arming, boosted or dimmed), a full-screen or "while playing" rule is on and the screen is not shielded, `SignalsMonitor` re-runs the full-screen check every 2 s on its own `TimeSource.sleep` (§7.1 "Playing video", §7.3). It does not ride on the engine's drift tick through a re-check entry point on `SystemSignals`. Revisit in WP16 with H-S1: if the steady boosted state misses DESIGN.md §17's wake-up target, move the watch, and the per-display drift checks with it, onto one engine-wide tick through the contract lane. | The ride is not a small change: a new `SystemSignals` requirement (Core, and its four conformers `SignalsMonitor`, `FakeSystemSignals`, AppShell's `LaunchCheckSignals` and the shell tests' `TrapSignals`), a tick callback from each `DisplayController` to the engine, and coalescing in Signals, because each display's drift check has its own phase (two displays would re-check twice per 2 s) and runs only while `boosted` or `dimmed` (the watch also runs while arming, gating and ramping). That reshapes when the default-on full-screen-video rule re-checks, in three modules, to save one wake-up every 2 s; the sleeps' 10 % tolerance coalesces the two timers only when their phases happen to lie within 0.2 s. The cost while boosted with the rule on: drift check, hang ping and watch are 1.5 wake-ups/s on one display (§17's target) and 2.0 on two, which the ride would bring to 1.5. While off nothing changes: none of the three runs. | new (its phase: D29) |
| D29 | **Every steady 2 s activity wakes on one shared grid** (new, energy pass; revisits D28's phase). The per-display drift checks (§4.8), the hang watchdog's pings (D7), Signals' full-screen and playback watch and the OLED idle input poll (D28's own timers) each wait for the next multiple of 2 s since the origin of the one time source the composition root hands every service (`context.time`), strictly after now and at most 2 s away, so the system serves them with one wake-up. The watch stays Signals' own timer with no `SystemSignals` requirement: D28's reasons against the ride still hold, only its phase changes. No interval grows; a first tick can only come sooner. The watchdog keeps its first ping at activation, its 3 s timeout after the outstanding ping, its 50 ms leeway and its once-per-stall rule; while a ping waits for its answer its timer wakes at the earlier of that deadline and the next grid point, so a new ping follows every answer within 2 s. The OLED idle deadline before the poll and the 50 ms drift check after a process exit stay where their threshold or the exit puts them. As built (energy pass): `TimeSource.nextGridPoint(every:)` names the point (T1); the watchdog's pings (T2), Signals' watch and the OLED input poll (T3) wait for it; `startDriftWatch` sleeps until it on the engine's time source (`deps.time`; woken on a point, the next one is a whole period away, so a tick never runs twice on one; E4, `DriftGridTests`, `SharedGridTests`). The four parts ship as one: `energy/steady-timers` merges the engine lane's E4, and `energy/engine` merges `energy/steady-timers` back, so neither branch lands without the other. | D28's relative sleeps drift apart and coalesce only when their phases fall within 0.2 s. Measured on `9ef2587`: 0.50–1.02 own interrupt wake-ups/s in boosted windows with the simulated wiring, +0.45/s from the real watch, and D28's own worst case of 1.5 (one display) and 2.0 (two); a 301 s two-display timeline had 20 seconds with two wake-ups. A grid prototype held 0.50–0.55/s in every window with one or two displays and 1 such second. **Safety, equal:** no interval grows (a tick can only come sooner, so D9's 2 s is never exceeded); a stall is still caught 3–5 s after it starts (pings at most 2 s after an answer; the 3 s timeout, the 50 ms leeway and the once-per-stall rule unchanged); the post-exit check is not on the grid. Two variants were rejected: the prototype's "at least half an interval away" stretches a wait to almost 3 s (a first drift check past D9's 2 s, a hang caught after up to ≈ 6 s); moving only the pings onto the grid lets an answer that comes after a short first wait leave the next ping to the timeout deadline, so a stall right after it took almost 6 s (`anAnswerAfterAShortFirstWaitStillCatchesTheNextStallWithinFiveSeconds`). **The parts ship together:** relative timers lock onto one another once they coalesce (each restarts from the shared wake-up), but a relative timer never locks onto the grid, so a partial grid is worse than none: in the app the watchdog on it with relative drift loops measured 0.90–1.08 against 0.42–0.93 on `main`, and in a read-only probe with the real watch 0.92–1.45 against 0.43–1.32; the drift loop alone on it 0.90–1.04 against 0.77–1.02, no gain while the watchdog keeps its own phase. With a stand-in for the drift loop's part: 0.42–0.55 with one or two displays, a two-display 301 s timeline 185–281 → 161–163 wake-ups. CPU unchanged. Tests: `TimeSourceGridTests`, `DriftGridTests`, `HangWatchdogTests` (the 3–5 s window at five grid phases), `WatchGridTests`, `IdleSchedulerTests`, `make tsan FILTER='HangWatchdog|OffMain'`. | new |
| D30 | **Signals' boost-only sources follow boosting, not dimming** (new, energy pass). A display counts for `SystemSignals.setBoostActive` while it arms or gates, or ramps toward, holds or disarms from a boost (a boost target, or a table or overlay above its baseline, whatever the phase), and is not driven (`DisplayController.needsBoostSources`). A dimmed-only display keeps its drift check and the hang watchdog (they follow the phase and the safety ledger), but runs no full-screen watch, battery-percent source, OLED idle deadline or schedule sleep. | Policy evaluates every guard those sources feed only for boost levels (`DisplayReducer`, `level.isBoost`; D10: dimming always works), and while dimmed the watch cost 177 of 212 µs/s. **Safety, equal:** dim → boost always goes through arming, which counts, so `setBoostActive(true)` and its synchronous power read precede any boost write; a level request for the boost half while no display keeps the sources running reads the power source synchronously before it reduces (`refreshPowerBeforeABoost`); the conflicts snapshot stays current through the always-on running-list KVO (`BoostSourcesTests`). | new |

Review notes on findings that were refined rather than taken verbatim (each maps to a row of Appendix B):
- **#9/#10 (Safe without an SDR estimate):** the live bound `capNits × H_live ÷ panelPeak` is the default (`GainCeiling.safeBound = .worstCaseGrant`). If H-G1 shows that grants stay well below the panel peak, it makes Safe almost inert; WP16 then switches to `.sliderTopOnly` together with the copy without a nits claim (DESIGN.md §12.2 gives both). The Studio Display XDR row is "no Safe boost" (its SDR maximum already reaches 1000 nits), and its verdict quotes Peak.
- **#12 (single instance):** `--qa-simulate` runs are exempt as well as CLI modes, because they construct no real display port and agents need them while the owner's copy runs. The exemption is decided on the ports actually wired (`ports.fixture != nil`, `CompositionRoot.skipsSingleInstanceCheck`), never on the arguments alone, and a Release build refuses to start with `--qa-simulate` (§8.5), so no launch that got the real ports is ever exempt.
- **#29 (login launch detection):** `keyAELaunchedAsLogInItem` in the open-application event is the primary signal; whether `SMAppService.mainApp` sets it is [U] (WP0b verifies it); the fallback treats a launch as a login launch when the session dictionary still reports `kCGSessionLoginDoneKey` false or the system has been up for less than 120 s [HW: H-L2]. A misjudged login launch at worst opens the panel once.
- **#30 (hidden icon window):** the buttons follow the System Settings rule of #44 ("Open System Settings", the pane named in the sentence) instead of "Open Menu Bar Settings…".
- **#37 (steps in stops):** the ½-stop property covers arrows, scroll and Brighter / Less Bright; ⌥-arrow jumps between named stops (up to 1.3 stops on the dim side) are explicit and excluded.
- **#43 (headroom display):** the separate bar is replaced by the track marker plus the help tag, rather than kept with a second scale.
- **#51 (off/paused fill):** the hatch uses `secondaryLabelColor` lines (3.72:1 over the light track) instead of `tertiaryLabelColor` (1.84:1), so the state stays visible under WCAG 1.4.11.
- **#54 (preset merging):** merging walks down from Max, keeping a preset only if it is ≥ ×1.1 and ≥ 0.1 stop below the last kept one (OLED Safe keeps Bright room and Max; a DisplayHDR 600 panel in Safe keeps only Max).
- **#67 (target count):** OverbrightChannel gets its own test target to keep "one test target per library target", so the count is 33 (17 + 16), not 32.

---

## 1. Goals, non-goals and repository

### 1.1 Goals (v1)

1. **Everything the incumbent does, done better**, free: per-display boost above SDR maximum; dim below the macOS minimum, per display or for all displays at once with its own shortcut; an edge light for video calls; three launch-at-login behaviours; per-display enablement (instead of "all / only built-in / only external"); one level for all displays; an on-screen indicator for level changes and automatic stops; an automatic fallback trigger (instead of a hidden "fallback mode" switch); battery, Low Power and timer automations with the same ranges; Shortcuts actions; a short onboarding; detection of conflicting apps; an optional Dock icon with a Dock menu; a mover to the Applications folder; a hint when the menu bar icon is not visible.
2. **Reliability as a feature.** A per-display state machine that always lands on a neutral screen after sleep/wake, lid close, lock, fast user switching, hot-plug, preset changes, other apps quitting, crashes and hangs (§4, §7.4).
3. **Honesty.** A verdict per display with a fix; the headroom macOS grants now; a reason for every limit; estimates marked as estimates; nits only when we know them (§5.5, DESIGN.md §5).
4. **Safety by default.** Battery, Low Power, heat, OLED care, flicker safety, a Safe ceiling, Back to Standard from anywhere, a confirmation before very dark levels.
5. **Native and accessible** on macOS 14–27, 35 languages from day one, VoiceOver and full keyboard control.
6. **Private.** No network except an opt-in update check; no SDKs; no permissions.

### 1.2 Non-goals (v1)

- **Private display APIs** (DisplayServices, CoreDisplay, SkyLight): they break between releases and would make the private-API register non-empty. Consequences: no reading of the system brightness slider, no preset switching, no headroom request without a window.
- **Brightness-key integration** ("keep pressing Brightness Up past maximum"): it needs an Accessibility event tap, and v1 asks for no permission. It is the first v1.x candidate, opt-in, following Cranny's HUD-tap pattern (§11.3). The v1 taper (D11) already keeps the brightness keys' normal range.
- **Following the built-in display's brightness on external displays**: there is no public API to read it.
- **Screen-capture-based boosting** (Screen Recording permission) and camera-based ambient sensing.
- **The Control Center control in ad-hoc builds** until H-CC-1 passes (D18).
- **Undoing macOS's own limits** (thermal dimming, headroom throttling). Overbright follows them and says so.

### 1.3 Repository layout

Every path below is relative to the repository root.

```
Overbright/                                ← repo root
├─ Overbright.xcodeproj/                   ← hand-written, objectVersion 77; owner WP0a
│  ├─ project.pbxproj                         targets: Overbright (app) + OverbrightControls (appex, dormant; D18)
│  └─ xcshareddata/xcschemes/Overbright.xcscheme
├─ App/                                    ← synchronized folder of target "Overbright"; owner WP0a, except
│  │                                          App/Intents/**, App/Localizable.xcstrings, App/AppShortcuts.xcstrings (WP8)
│  ├─ OverbrightApp.swift                  ← @main → OverbrightAppShell; creates IntentRouter() and registers it (AppDependencyManager)
│  ├─ Intents/*.swift                      ← user-facing App Intents + Focus filter (one-line adapters, D18)
│  ├─ Info.plist                           ← partial plist (LSUIElement, CFBundleLocalizations ×35, URL scheme, repository key)
│  ├─ InfoPlist.xcstrings                  ← CFBundleDisplayName, CFBundleName, copyright (no usage strings)
│  ├─ Localizable.xcstrings                ← intent titles, parameters, summaries, Focus filter text (WP8)
│  ├─ AppShortcuts.xcstrings               ← App Shortcuts phrases (WP8)
│  ├─ Overbright.entitlements              ← empty dict (not sandboxed, no TCC resource)
│  ├─ AppIcon.icon/                        ← Icon Composer document; layers rendered by scripts/render-icon.swift
│  └─ Assets.xcassets/                     ← Contents.json only (no global accent colour)
├─ Controls/                               ← target "OverbrightControls" (sandboxed WidgetKit extension), built only with CONTROLS=1 (WP8)
├─ Shared/                                 ← BoostControlIntent.swift, member of both targets (D18/D25) (WP8)
├─ Packages/OverbrightKit/                 ← local Swift package with ALL other code
│  ├─ Package.swift                        ← owner WP0a (§2.2); nobody else edits it
│  ├─ Sources/<Target>/…                   ← one folder per target; every target with UI strings has Resources/*.xcstrings
│  │                                          (Policy, Channel and TestSupport have none)
│  └─ Tests/<Target>Tests/…                ← one test target per library target except TestSupport (Swift Testing)
├─ scripts/                                ← lib.sh build.sh run.sh smoke.sh dist.sh check-modules.sh sync-strings.sh name-probe.sh
│                                             render-icon.swift lint-copy.py merge-xcstrings.py check-lproj.py l10n/
│                                             qa-matrix.sh qa_check.py (WP13: the QA matrix and its judge)
│                                             soak.sh soak-control.swift soak_judge.py (WP13: the soak, its control app, its judge)
├─ docs/                                   ← DESIGN.md, ARCHITECTURE.md, HARDWARE-TEST.md, CONTRIBUTING.md and TRANSLATING.md (WP0b),
│                                             research/ (public-safe summaries), l10n/terms/<code>.md
├─ .github/workflows/                      ← ci.yml, release.yml
├─ VERSION · LICENSE (MIT, "Overbright contributors") · README.md · THIRD_PARTY_NOTICES.md · Makefile · .gitignore · .gitattributes
```

Git-ignored outputs: `build/`, `dist/`, `Packages/OverbrightKit/.build*/` (one scratch directory per target; `make distclean` removes them). `make clean` also unregisters `build/Overbright.app` and its extension from LaunchServices and PlugInKit, because every build registers them and a dev copy can otherwise appear in the Control Center gallery.

---

## 2. Package layout

### 2.1 Layers and dependency rules

```
 L3  OverbrightAppShell ───────────────────────────────────────── depends on everything below
       │ AppDelegate, CompositionRoot, status item + menu, panel/HUD/Help/Settings/Welcome/calibration windows,
       │ login item, single-instance and move-to-Applications checks, diagnostics report, QA hooks, shortcut wiring
 L2  OverbrightPanelUI      OverbrightSettingsUI      OverbrightOnboarding (+ PanelUI)
       │ L0 + Design          L0 + Design               L0 + Design + PanelUI
 L1  OverbrightDesign  OverbrightDisplays  OverbrightTriggers  OverbrightBoost  OverbrightSignals
     OverbrightFillLight  OverbrightHotKeys  OverbrightUpdates  OverbrightIntents (+ Channel)  ← each: L0 ONLY
 L0  OverbrightCore (contracts, settings keys, platform, fakes)   OverbrightPolicy (pure decisions; Core only)
     OverbrightChannel (Foundation only: the control's state channel, D25)
 --  OverbrightTestSupport (test targets only)
 App target: OverbrightApp.swift + App/Intents (adapters over OverbrightIntents' router) · Controls: dormant appex (links Channel only)
```

Rules (enforced by `Package.swift`; a pull request that adds an edge is rejected):

1. A layer-1 module imports `OverbrightCore`, `OverbrightPolicy` and Apple frameworks only (`OverbrightIntents` also `OverbrightChannel`). It never imports another layer-1 module, a UI module or the shell.
2. Anything two layer-1 modules must share goes into Core as a value type or a port, through the contract lane (§10.0). Pure decisions go into Policy.
3. The app target links only the static product `OverbrightAppShell`; the dormant extension links only the static product `OverbrightControlsKit` (= `OverbrightChannel`). No `.dynamic` product is ever linked.
4. All 17 library targets and 16 test targets exist from WP0a on, with placeholder sources, so nobody edits `Package.swift` during the parallel phase.
5. `OverbrightPolicy`, `OverbrightChannel` and `OverbrightTestSupport` have no String Catalog, and Core's catalog holds only ported Core strings. **The user-facing names and sentences of Core and Policy enums** (presets, verdicts, reasons, banners, strategies, HUD reasons) **live in `OverbrightDesign`** with their builders (`ChipModel`, `VerdictText`, `BannerModel`, `ReadoutText`, `HUDText`), owned by WP9 (§8.8, §10.0).
6. Exactly one file calls the CoreGraphics table setters and the global restore: `Sources/OverbrightDisplays/Gamma/CoreGraphicsGamma.swift` (D24). EDR layer properties (`preferredDynamicRange`, `wantsExtendedDynamicRangeContent`, `contentsHeadroom`) and `AVPlayerLayer` appear only under `Sources/OverbrightTriggers/`, `Sources/OverbrightFillLight/` and Design's `EDRPreviewSurface.swift`.
7. Networking APIs (`URLSession`, `NWConnection`, `CFSocket`, `Network`) appear only under `Sources/OverbrightUpdates/` (`noNetworkingOutsideUpdates`, D2).

### 2.2 `Packages/OverbrightKit/Package.swift` [VERIFIED: `swift package describe` lists 33 targets and two static products; `swift build -Xswiftc -warnings-as-errors` and `swift test` pass]

```swift
// swift-tools-version: 6.2
// OverbrightKit — ALL Overbright code except the app target's @main, its App Intents adapters (D18) and the
// dormant Controls extension. The Xcode project (Overbright.xcodeproj) links only the static product
// OverbrightAppShell (and, with CONTROLS=1, the extension links only the static OverbrightControlsKit).
//
// Layering (enforced by the dependency lists below — never add an edge that is not here):
//   L0  OverbrightCore       contracts (ports + value types), settings keys, platform utils, fakes      nonisolated
//       OverbrightPolicy     pure decisions: factor math, level mapping, eligibility, guard reducer,
//                            table classifier, conflict matcher (Core only)                             nonisolated
//       OverbrightChannel    Foundation-only state channel for the dormant control (D25): pack/unpack,
//                            notify name, CFPreferences snapshot, token, URL route parser (no Core)     nonisolated
//   L1  Design, Displays, Triggers, Boost, Signals, FillLight, HotKeys, Updates, Intents
//                            depend on L0 ONLY (Intents also on Channel), never on each other
//   L2  PanelUI, SettingsUI, Onboarding      L0 + Design (Onboarding may also use PanelUI)
//   L3  OverbrightAppShell   composition root, status item, windows (depends on everything)
//   --  OverbrightTestSupport  test helpers; test targets only, never linked into the app
//
// This file is owned by Work Package 0a (WP13 in phase C). Other packages never edit it.
import PackageDescription

let common: [SwiftSetting] = [
    .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
    .enableUpcomingFeature("InferIsolatedConformances"),
    .enableUpcomingFeature("MemberImportVisibility"),
    .enableUpcomingFeature("ExistentialAny"),
]
let mainActorByDefault: [SwiftSetting] = common + [.defaultIsolation(MainActor.self)]
let nonisolatedByDefault: [SwiftSetting] = common + [.defaultIsolation(nil)]

let core: Target.Dependency = "OverbrightCore"
let policy: Target.Dependency = "OverbrightPolicy"
let channel: Target.Dependency = "OverbrightChannel"

/// A layer-1 module: MainActor by default, depends on L0 only, owns a String Catalog.
func layer1(_ name: String) -> Target {
    let deps: [Target.Dependency] = name == "OverbrightIntents" ? [core, policy, channel] : [core, policy]
    return .target(name: name, dependencies: deps, resources: [.process("Resources")], swiftSettings: mainActorByDefault)
}
/// A layer-2/3 module.
func upperLayer(_ name: String, _ dependencies: [Target.Dependency]) -> Target {
    .target(name: name, dependencies: dependencies, resources: [.process("Resources")], swiftSettings: mainActorByDefault)
}
/// Every library target except TestSupport has exactly one test target, declared up front so nobody edits this file.
func tests(_ module: String, isolation: [SwiftSetting] = mainActorByDefault) -> Target {
    var deps: [Target.Dependency] = [.target(name: module), "OverbrightTestSupport"]
    if module == "OverbrightChannel" { return .testTarget(name: module + "Tests", dependencies: deps, swiftSettings: isolation) }
    if module != "OverbrightCore" { deps.append(core) }
    if module != "OverbrightCore" && module != "OverbrightPolicy" { deps.append(policy) }
    return .testTarget(name: module + "Tests", dependencies: deps, swiftSettings: isolation)
}

let layer1Modules = [
    "OverbrightDesign", "OverbrightDisplays", "OverbrightTriggers", "OverbrightBoost", "OverbrightSignals",
    "OverbrightFillLight", "OverbrightHotKeys", "OverbrightUpdates", "OverbrightIntents",
]
let ui: [Target.Dependency] = [core, policy, "OverbrightDesign"]

let package = Package(
    name: "OverbrightKit",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [
        // The app links only this product (static). It pulls in the whole graph. Never add a .dynamic product
        // to the app (a hardened ad-hoc Release dies with "different Team IDs").
        .library(name: "OverbrightAppShell", type: .static, targets: ["OverbrightAppShell"]),
        // The dormant Controls extension (D18) links only this: the Foundation-only state channel (D25).
        .library(name: "OverbrightControlsKit", type: .static, targets: ["OverbrightChannel"]),
    ],
    targets: [
        // L0
        .target(name: "OverbrightCore", resources: [.process("Resources")], swiftSettings: nonisolatedByDefault),
        .target(name: "OverbrightPolicy", dependencies: [core], swiftSettings: nonisolatedByDefault),   // no strings
        .target(name: "OverbrightChannel", swiftSettings: nonisolatedByDefault),                         // no strings
        // L1
    ] + layer1Modules.map(layer1) + [
        // L2
        upperLayer("OverbrightPanelUI", ui),
        upperLayer("OverbrightSettingsUI", ui),
        upperLayer("OverbrightOnboarding", ui + ["OverbrightPanelUI"]),
        // L3
        upperLayer("OverbrightAppShell", ui + ["OverbrightPanelUI", "OverbrightSettingsUI", "OverbrightOnboarding", channel]
                   + layer1Modules.filter { $0 != "OverbrightDesign" }.map { .target(name: $0) }),
        // Test helpers (no Resources folder: smoke counts Sources/*/Resources against the app's bundles)
        .target(name: "OverbrightTestSupport", dependencies: [core, policy], swiftSettings: mainActorByDefault),
        // Tests
        tests("OverbrightCore", isolation: nonisolatedByDefault),
        tests("OverbrightPolicy", isolation: nonisolatedByDefault),
        tests("OverbrightChannel", isolation: nonisolatedByDefault),
    ] + (layer1Modules + ["OverbrightPanelUI", "OverbrightSettingsUI", "OverbrightOnboarding", "OverbrightAppShell"])
        .map { tests($0) }
)
```

### 2.3 Isolation per target

| Target(s) | Default isolation | Notes |
|---|---|---|
| `OverbrightCore`, `OverbrightPolicy`, `OverbrightChannel` and their tests | nonisolated | Value types are `nonisolated … Sendable`. UI-facing classes and observable ports are explicitly `@MainActor` (`SettingsStore`, `OverbrightServices`, `OwnEDRSurfaces`, `ObservationToken`, the façade protocols). `GammaPort`, `TimeSource` and `DiagnosticsJournal` are nonisolated and `Sendable` because the hang watchdog, the signal queue and the journal are used off the main actor. |
| Every other Swift target and its tests | `MainActor` | Models that are persisted or cross threads are `nonisolated struct …: Codable, Sendable`; a plain `Codable` struct here would get a main-actor conformance that `@concurrent` code cannot use. Heavy work goes into `@concurrent` functions (HLG still generation, libproc scans, window-list snapshots, self-test log encoding). **Every entry point the system calls off the main thread is explicitly nonisolated** (§8.1 rule 2): under this default, an un-annotated closure or `@objc` method is main-actor isolated and traps at runtime when called from another thread. App Intents' `perform()` must be marked `@MainActor` explicitly [VERIFIED in the controls study]. |
| App target | `MainActor` (`SWIFT_DEFAULT_ACTOR_ISOLATION`) | Same rules. |

All targets enable `NonisolatedNonsendingByDefault`, `InferIsolatedConformances`, `MemberImportVisibility` and `ExistentialAny`. `MemberImportVisibility` consequences from Cranny: a file calling `String(localized:)` imports Foundation; `Logger` calls import `os`; `@Observable` imports Observation; `CGDisplayCreateUUIDFromDisplayID` needs `import ColorSync` [VERIFIED].

### 2.4 Building one module

Agent shells reset the working directory and the environment between commands, so every command is self-contained, with absolute paths (`<repo>` = the absolute path of the clone or worktree). Prefer the scripts, which locate Xcode themselves (`ensure_xcode` in `scripts/lib.sh`):

```zsh
<repo>/scripts/check-modules.sh OverbrightBoost        # one target alone, warnings as errors (own scratch dir)
make -C <repo> test FILTER=OverbrightBoostTests        # swift test --filter, scratch path .build-test
```

The same without the scripts:

```zsh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build --package-path <repo>/Packages/OverbrightKit --target OverbrightBoost --scratch-path <repo>/Packages/OverbrightKit/.build-overbrightboost -Xswiftc -warnings-as-errors
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --package-path <repo>/Packages/OverbrightKit --scratch-path <repo>/Packages/OverbrightKit/.build-test --filter OverbrightBoostTests
```

Run each command on its own and check its exit status. On the owner's Mac the zsh profile prints `GVM_ROOT not set` and can abort `a && b` chains silently, so never chain important commands.

---

## 3. Core contracts

Everything in this section is the contract between work packages. The listings are the files WP0a commits, compiled for this document (Appendix A): zero warnings under Swift 6.4 with the four upcoming features, at macOS 14 and 26, for arm64 and x86_64, under both nonisolated and MainActor default isolation, and free of name collisions with 21 Apple frameworks (131 public names). Changes after WP0a go through the contract lane (§10.0). In the repo each listing is split one type per file, as in Cranny; the grouping here is for reading.

### 3.1 Directory map of `Sources/OverbrightCore/`

```
OverbrightCore/
├─ OverbrightCore.swift            module overview
├─ Platform/                       ported from Cranny: Platform.swift (Log, LogCategory, AppPaths, JSONFileStore, AppInfo,
│                                  SemanticVersion, Haptics), Concurrency.swift (ObservationToken, observe, Debouncer),
│                                  JSONDocumentFile.swift, LaunchArguments.swift (+ --off/--restore-gamma/--diagnostics/--monitor),
│                                  SnapshotOutput.swift, AppIdentity.swift, ProtectedLocations.swift, SystemTimeSource.swift;
│                                  new: MachineIdentity.swift (sysctl hw.model, kern.osversion)
├─ Settings/                       SettingsStore.swift (§3.8, real port), SettingsUpgrades.swift (revision 0), InMemoryDefaults.swift
│  └─ Keys/                        SettingKey.swift + one file per namespace (§3.8)
├─ Model/                          §3.2–§3.5 value types, one per file
├─ Ports/                          §3.6 protocols, one per file
├─ Shortcuts/                      ShortcutID, KeyCombo, GlobalShortcut, ShortcutState, ShortcutCatalog (§3.7)
├─ Services/                       OverbrightServices.swift, OwnEDRSurfaces.swift (§3.9), Announcer.swift (ported),
│                                  DiagnosticsJournal (ring buffer)
├─ Fakes/                          one fake per port + Fixtures/ (§3.9) — public, used by every test target and #Preview
├─ Additions/                      new TYPES and extension methods only, staged by a contract-lane PR (§10.0)
└─ Resources/Localizable.xcstrings ported Core strings only (Announcer, platform errors); enum names live in Design
```

### 3.2 Value types: time, machine, displays, headroom, tables, levels, eligibility

```swift
// OverbrightCore — value types (nonisolated, Sendable). ARCHITECTURE.md §3.2.
import ColorSync
import CoreGraphics
import Foundation

// MARK: - Time

/// A point on the monotonic clock of a `TimeSource` (never wall-clock time).
public nonisolated struct MonotonicInstant: Hashable, Comparable, Sendable, Codable {
    /// Time since the time source's origin.
    public var sinceOrigin: Duration
    public init(sinceOrigin: Duration) { self.sinceOrigin = sinceOrigin }
    public static func < (a: Self, b: Self) -> Bool { a.sinceOrigin < b.sinceOrigin }
    public static func + (a: Self, d: Duration) -> Self { Self(sinceOrigin: a.sinceOrigin + d) }
    public static func - (a: Self, b: Self) -> Duration { a.sinceOrigin - b.sinceOrigin }
}

// MARK: - Machine identity (Platform; read once per launch)

/// The Mac and OS build, for the compatibility-model list, the strategy cache key and calibration validity (§7.5).
public nonisolated struct MachineIdentity: Hashable, Codable, Sendable {
    /// `hw.model`, e.g. "Mac16,5".
    public var model: String
    /// `kern.osversion`, e.g. "26A123" (the build).
    public var osBuild: String
    public var osMajor: Int
    public var osMinor: Int
    public var osPatch: Int
    public init(model: String, osBuild: String, osMajor: Int, osMinor: Int, osPatch: Int) {
        self.model = model; self.osBuild = osBuild; self.osMajor = osMajor; self.osMinor = osMinor; self.osPatch = osPatch
    }
    /// Reads sysctl and `ProcessInfo` (read-only). Fakes and tests construct values directly.
    public static func current() -> MachineIdentity {
        let v = ProcessInfo.processInfo.operatingSystemVersion
        return MachineIdentity(model: sysctlString("hw.model") ?? "unknown", osBuild: sysctlString("kern.osversion") ?? "unknown",
                               osMajor: v.majorVersion, osMinor: v.minorVersion, osPatch: v.patchVersion)
    }
    private static func sysctlString(_ name: String) -> String? {
        var size = 0
        guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 0 else { return nil }
        var bytes = [UInt8](repeating: 0, count: size)
        guard sysctlbyname(name, &bytes, &size, nil, 0) == 0 else { return nil }
        return String(decoding: bytes.prefix { $0 != 0 }, as: UTF8.self)
    }
}

// MARK: - Display identity

/// Stable identity of a display: the `CGDisplayCreateUUIDFromDisplayID` string. Persisted; never a name.
public nonisolated struct DisplayKey: Hashable, Comparable, Codable, Sendable, CustomStringConvertible {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue.uppercased() }
    public static func < (a: Self, b: Self) -> Bool { a.rawValue < b.rawValue }
    public var description: String { rawValue }
    /// The one way every module derives a key (read-only CoreGraphics call). Nil for IDs macOS no longer knows.
    public static func of(_ id: CGDirectDisplayID) -> DisplayKey? {
        guard let uuid = CGDisplayCreateUUIDFromDisplayID(id)?.takeRetainedValue(),
              let string = CFUUIDCreateString(nil, uuid) as String? else { return nil }
        return DisplayKey(rawValue: string)
    }
}

/// A connected display: its persistent key plus the transient CoreGraphics ID (valid until reconfiguration).
public nonisolated struct DisplayRef: Hashable, Sendable {
    public var key: DisplayKey
    public var id: CGDirectDisplayID
    public init(key: DisplayKey, id: CGDirectDisplayID) { self.key = key; self.id = id }
}

/// Coarse hardware class, derived from public facts only (built-in flag, vendor, IORegistry), never from names.
public nonisolated enum PanelClass: String, Codable, Sendable, CaseIterable {
    case builtInXDR        // built-in, potential > 2
    case builtInLCD        // built-in, potential ≤ 2
    case appleXDRExternal  // Apple vendor ID, external, panel peak ≥ 1000 nits
    case hdrExternal       // other external with PQ support
    case oledExternal      // external whose minimum luminance is ≤ 0.005 nits (self-emissive), or user override
    case sdrExternal       // external without PQ support
    case virtualDisplay    // Sidecar, AirPlay, placeholder vendor, no gamma table
}

/// Everything Overbright knows about one display, refreshed on every reconfiguration.
public nonisolated struct DisplayFacts: Hashable, Sendable {
    public var ref: DisplayRef
    /// `NSScreen.localizedName`. For the UI only; no logic may compare it (D8).
    public var name: String
    public var isBuiltIn: Bool
    /// Member of a hardware mirror set that does NOT own the set's NSScreen (`CGDisplayMirrorsDisplay` ≠ 0).
    /// It has its own table but no headroom reading of its own: dim only (verdict `.mirrored`).
    public var isMirrored: Bool
    /// `CGDisplayGammaTableCapacity`; 0 means the display has no transfer table.
    public var gammaCapacity: Int
    public var vendorID: UInt32?
    public var productID: UInt32?
    /// IORegistry `SupportsPQEOTF` (externals); nil when unknown.
    public var supportsPQ: Bool?
    /// Panel maximum luminance in nits (built-in: `EDRPotentialHeadroom` × 100; external: DisplayAttributes Luminance Max,
    /// else an Apple XDR product's; without either, potential × 100 on a display with extra range, D8).
    public var panelPeakNits: Double?
    /// External: DisplayAttributes Luminance MaxFrameAverage (the HDR-mode SDR white on the measured OLED; on an
    /// Apple XDR external the full-screen sustained HDR level, never an SDR white).
    public var panelFrameAverageNits: Double?
    /// External: DisplayAttributes Luminance Min.
    public var panelMinNits: Double?
    /// Highest SDR white the user can select without ambient boost (built-in `user-accessible-max-nits`; Apple XDR
    /// external: the product's, 500 or 1000 nits).
    public var sdrMaxNits: Double?
    /// `NSScreen.safeAreaInsets.top > 0`.
    public var hasNotch: Bool
    public var panelClass: PanelClass
    public init(ref: DisplayRef, name: String, isBuiltIn: Bool, isMirrored: Bool = false, gammaCapacity: Int,
                vendorID: UInt32? = nil, productID: UInt32? = nil, supportsPQ: Bool? = nil,
                panelPeakNits: Double? = nil, panelFrameAverageNits: Double? = nil, panelMinNits: Double? = nil,
                sdrMaxNits: Double? = nil, hasNotch: Bool = false, panelClass: PanelClass) {
        self.ref = ref; self.name = name; self.isBuiltIn = isBuiltIn; self.isMirrored = isMirrored
        self.gammaCapacity = gammaCapacity; self.vendorID = vendorID; self.productID = productID
        self.supportsPQ = supportsPQ; self.panelPeakNits = panelPeakNits
        self.panelFrameAverageNits = panelFrameAverageNits; self.panelMinNits = panelMinNits
        self.sdrMaxNits = sdrMaxNits; self.hasNotch = hasNotch; self.panelClass = panelClass
    }
}

// MARK: - Headroom and transfer tables

/// The three NSScreen EDR values of ONE display, read on the main actor, stamped with monotonic time.
public nonisolated struct HeadroomReading: Hashable, Sendable {
    /// The display the NSScreen belongs to. `TableWriter` refuses a reading whose display differs from the write target.
    public var display: CGDirectDisplayID
    /// `maximumExtendedDynamicRangeColorComponentValue` (current, granted headroom H).
    public var current: Double
    /// `maximumPotentialExtendedDynamicRangeColorComponentValue` (≈ preset peak ÷ 100 nits).
    public var potential: Double
    /// `maximumReferenceExtendedDynamicRangeColorComponentValue` (> 0 only in reference modes).
    public var reference: Double
    public var time: MonotonicInstant
    public init(display: CGDirectDisplayID, current: Double, potential: Double, reference: Double,
                time: MonotonicInstant) {
        self.display = display; self.current = current; self.potential = potential; self.reference = reference
        self.time = time
    }
}

/// One display transfer table (`CGGet/SetDisplayTransferByTable`), all three channels the same length.
public nonisolated struct GammaTable: Hashable, Sendable, Codable {
    public var red: [Float]
    public var green: [Float]
    public var blue: [Float]
    public init(red: [Float], green: [Float], blue: [Float]) { self.red = red; self.green = green; self.blue = blue }
    public var count: Int { red.count }
    /// Largest entry over all channels. Diagnostics only: read-back may clamp at 1.0 (D26), so neutrality and
    /// residue are judged by `TableClassifier` against the profile base, never by this value.
    public var maximum: Float { max(red.max() ?? 0, green.max() ?? 0, blue.max() ?? 0) }
    /// A neutral (identity) ramp: the base of a display whose profile has no `vcgt`.
    public static func identity(count: Int) -> GammaTable {
        let ramp = (0..<count).map { Float($0) / Float(max(count - 1, 1)) }
        return GammaTable(red: ramp, green: ramp, blue: ramp)
    }
}

/// What a read table is, compared with the display's expected base (Policy `TableClassifier`, D26).
public nonisolated enum TableClass: Hashable, Sendable {
    case matchesBase
    /// Every channel ≈ base × ratio at sub-1 sample indices (ratio ≥ 1.02 or ≤ 0.98), or a clamped plateau
    /// (≥ 2 entries ≥ 0.9995 before the last index where the base has none; ratio then unknown).
    case scaled(ratio: Double?)
    /// Neither: a per-channel curve (warm-light tool, calibration loader, accessibility filter).
    case foreign
    /// Not monotonic, starts above 0.1 or ends below 0.9 (e.g. an all-zero table from a failed restore).
    case invalid
}

public nonisolated enum GammaError: Error, Hashable, Sendable {
    case noTable                       // capacity 0 (virtual display)
    case coreGraphics(code: Int32)     // CGError raw value
    case displayGone                   // the ID is no longer online
    case writeRefused                  // the interlock refused a scaled write (stale epoch, stale or foreign reading)
}

// MARK: - Levels and per-display preferences

/// The one continuous per-display control (D11): −1 … 0 dims, 0 is the Standard detent, 0 … 1 boosts.
/// Boost half: linear in stops of the display's top. Dim half: stops = log₂(50) × |p|^2.5 (gentle near the detent).
/// ARCHITECTURE.md §5.3.
public nonisolated struct LevelPosition: Hashable, Comparable, Codable, Sendable {
    public var value: Double
    public init(_ value: Double) { self.value = min(max(value.isFinite ? value : 0, -1), 1) }
    public static let standard = LevelPosition(0)
    public static func < (a: Self, b: Self) -> Bool { a.value < b.value }
    public var isBoost: Bool { value > 0 }
    public var isDim: Bool { value < 0 }
}

/// Named stops on the boost half (slider ticks). Raw values are persisted; never rename.
/// A preset is hidden on a display when its gain is below ×1.1 or within 0.1 stop of the next kept one (§5.3).
public nonisolated enum LevelPreset: String, Codable, Sendable, CaseIterable {
    case standard, indoor, brightRoom, sunlight, max
    public var position: LevelPosition {
        switch self {
        case .standard: .standard
        case .indoor: LevelPosition(0.25)
        case .brightRoom: LevelPosition(0.5)
        case .sunlight: LevelPosition(0.75)
        case .max: LevelPosition(1)
        }
    }
}

/// The ceiling the boost half reaches (D15 "cap mode"; the UI calls the second one "Peak").
public nonisolated enum CapMode: String, Codable, Sendable, CaseIterable {
    case safe   // the full-screen sustained level (Apple XDR 1000 nits; other HDR min(1000, 0.6 × peak); OLED ×1.3)
    case peak   // up to 0.97 × the headroom macOS grants
}

/// How the transfer table maps to light (ARCHITECTURE.md §5.2). Only calibration with a positive linear
/// confirmation can select `.linear`; everything else, and any stale record, is `.encoded`.
public nonisolated enum TransferDomain: String, Hashable, Codable, Sendable {
    /// Display-encoded values: the sRGB curve at and below white (dimming); above white the conservative pure
    /// 2.4 power (`F = G^(1/2.4)`), so `F^k ≤ G` for every exponent k ≤ 2.4 and nothing clips under either model.
    case encoded
    /// Linear light: light gain = table factor.
    case linear
}

/// The mechanism that turns headroom into brightness for a display.
public nonisolated enum Mechanism: String, Codable, Sendable {
    case table           // EDR trigger + scaled transfer table (default)
    case overlay         // Compatibility mode: full-screen EDR overlay with multiply compositing (technique C)
}

public nonisolated enum MechanismPreference: String, Codable, Sendable, CaseIterable {
    case automatic, table, overlay
}

/// The outcome of the calibration step wedge (DESIGN.md §9). Valid only while `osBuild`, `mechanism` and
/// `potentialAtTest` (±5 %) match the current values; otherwise the effective domain is `.encoded` (§5.2).
public nonisolated struct CalibrationRecord: Hashable, Codable, Sendable {
    public enum Outcome: String, Codable, Sendable { case encoded, linear, inconclusive, notBrighter }
    /// `.linear` only after the confirmation frame at the linear-domain Peak factor was answered "distinguishable".
    public var outcome: Outcome
    /// The mechanism measured; a record never carries over to the other mechanism.
    public var mechanism: Mechanism
    /// The table factor at which the 0.95 patch merged with white (nil when the user stopped early).
    public var mergeFactor: Double?
    /// k̂ = ln H ÷ ln(0.95 · mergeFactor). Diagnostics only: never used to choose a domain.
    public var estimatedExponent: Double?
    /// SDR white typed from a colorimeter ("I have a colorimeter"); makes nits and the Safe cap exact.
    public var measuredSDRWhiteNits: Double?
    public var headroomAtTest: Double
    public var potentialAtTest: Double
    public var osBuild: String
    public var measuredAt: Date
    public init(outcome: Outcome, mechanism: Mechanism, mergeFactor: Double?, estimatedExponent: Double?,
                measuredSDRWhiteNits: Double?, headroomAtTest: Double, potentialAtTest: Double, osBuild: String,
                measuredAt: Date) {
        self.outcome = outcome; self.mechanism = mechanism; self.mergeFactor = mergeFactor
        self.estimatedExponent = estimatedExponent; self.measuredSDRWhiteNits = measuredSDRWhiteNits
        self.headroomAtTest = headroomAtTest; self.potentialAtTest = potentialAtTest
        self.osBuild = osBuild; self.measuredAt = measuredAt
    }
}

/// Trigger strategies of the escalation ladder (D4, ARCHITECTURE.md §4.7). Raw values are persisted.
public nonisolated enum TriggerStrategy: String, Codable, Sendable, CaseIterable {
    case taggedLayer        // T1: CALayer, preferredDynamicRange .high, headroom-tagged CGColor (macOS 26+)
    case metalOneShot       // T2: CAMetalLayer rgba16Float, one clear-only frame, re-presented on events
    case metalKeepAlive     // T3: T2 plus a slow keep-alive (5 s)
    case hlgSampleBuffer    // T4-alt: AVSampleBufferDisplayLayer with one in-memory HLG frame
    case hlgStill           // T4: our own generated HLG still in a paused AVPlayerLayer
}

/// Pixel value the trigger shows (ARCHITECTURE.md §4.7).
public nonisolated enum TriggerPixel: String, Codable, Sendable {
    case black        // 0.0 (T1: tag only)
    case sdrWhite     // 1.0 (lab only; not in the default ladder)
    case bright       // 1.6
    public var rawComponent: Double {
        switch self { case .black: 0; case .sdrWhite: 1; case .bright: 1.6 }
    }
}

public nonisolated enum OLEDOverride: String, Codable, Sendable { case automatic, oled, notOLED }

/// Per-display preferences, stored in `DisplaySettings.perDisplay` by `DisplayKey`.
public nonisolated struct DisplayPreferences: Hashable, Codable, Sendable {
    /// Gates the BOOST half only (D11, DESIGN.md §5.4); dimming never needs it. nil = the class default
    /// (D8: built-in XDR and Apple XDR on; other HDR and OLED externals off until the user moves into the boost half).
    public var boostEnabled: Bool?
    public var level: LevelPosition
    public var capMode: CapMode
    public var mechanism: MechanismPreference
    /// Advanced override of the trigger ladder; nil = automatic.
    public var triggerOverride: TriggerStrategy?
    /// The transfer domain is derived from this record (§5.2); there is no separate domain setting.
    public var calibration: CalibrationRecord?
    public var oled: OLEDOverride
    public var oledNoticeAcknowledged: Bool
    /// Last name seen, so a disconnected display can be listed and forgotten.
    public var lastKnownName: String?
    public init(boostEnabled: Bool? = nil, level: LevelPosition = LevelPreset.brightRoom.position,
                capMode: CapMode = .safe, mechanism: MechanismPreference = .automatic,
                triggerOverride: TriggerStrategy? = nil, calibration: CalibrationRecord? = nil,
                oled: OLEDOverride = .automatic, oledNoticeAcknowledged: Bool = false, lastKnownName: String? = nil) {
        self.boostEnabled = boostEnabled; self.level = level; self.capMode = capMode; self.mechanism = mechanism
        self.triggerOverride = triggerOverride; self.calibration = calibration
        self.oled = oled; self.oledNoticeAcknowledged = oledNoticeAcknowledged; self.lastKnownName = lastKnownName
    }
}

// MARK: - Eligibility (D8)

public nonisolated enum DisplayVerdict: Hashable, Codable, Sendable {
    case checking                                   // transient potential < 1 or no reading yet: re-check later
    /// Boost possible. `safeGain`/`peakGain`: the slider tops at full brightness (Safe may be nil: no Safe boost).
    case supported(safeGain: Double?, peakGain: Double)
    case noGainAtFullBrightness(peakGain: Double)   // even Peak adds < 10 % at full brightness
    case panelFactsUnknown                           // boosting class, panel peak or SDR maximum unknown: dim only (WP14)
    case presetLimits(presetPeakNits: Double, panelPeakNits: Double)
    case turnOnHDR                                   // external with PQ support, HDR off in macOS
    case switchPreset                                // built-in / XDR panel in an SDR preset
    case referencePreset                             // reference > 0
    case lcdClass                                    // potential ≤ 2
    case mirrored                                    // hardware-mirror member without its own NSScreen: dim only
    case virtualDisplay                              // Sidecar, AirPlay, placeholder
    case noGammaTable
    case notHDR                                      // SDR external without PQ
    public var allowsBoost: Bool {
        switch self { case .supported, .noGainAtFullBrightness, .presetLimits: true; default: false }
    }
    /// Dimming needs only a transfer table (or the overlay), never headroom or the per-display boost switch.
    public var allowsDim: Bool {
        switch self { case .virtualDisplay, .noGammaTable, .referencePreset, .checking: false; default: true }
    }
}

/// Facts that change how a supported display behaves, shown next to the verdict.
public nonisolated enum Advisory: String, Codable, Sendable, CaseIterable {
    case compatibilityModeAdvised    // model/OS where table writes are silently ignored (D4, `CompatibilityModels`)
    case oledCare                    // OLED: lower Safe cap, idle pause, black trigger only
    case autoBrightnessInteracts     // built-in XDR on macOS 26+: keep auto-brightness unchanged while boosted
    case notCalibrated               // no valid calibration record: readouts are estimates ("≈ ×1.29")
}

public nonisolated struct EligibilityResult: Hashable, Sendable {
    public var verdict: DisplayVerdict
    public var advisories: [Advisory]
    /// Class default of `DisplayPreferences.boostEnabled` (the OLED override is applied before classifying).
    public var defaultBoostEnabled: Bool
    public var defaultMechanism: Mechanism
    public init(verdict: DisplayVerdict, advisories: [Advisory], defaultBoostEnabled: Bool,
                defaultMechanism: Mechanism) {
        self.verdict = verdict; self.advisories = advisories
        self.defaultBoostEnabled = defaultBoostEnabled; self.defaultMechanism = defaultMechanism
    }
}

/// Estimated SDR white in nits and where it came from; nil hides nits (DESIGN.md §5.6).
public nonisolated struct SDRWhiteEstimate: Hashable, Sendable {
    public enum Source: String, Codable, Sendable { case colorimeter, panelReported, hdrFrameAverage }
    public var nits: Double
    public var source: Source
    public init(nits: Double, source: Source) { self.nits = nits; self.source = source }
}
```

### 3.3 System snapshot, events and conflicts

```swift
// OverbrightCore — system signals and conflicts (value types). ARCHITECTURE.md §3.3, §7.
import CoreGraphics
import Foundation

public nonisolated enum PowerSourceKind: String, Codable, Sendable { case adapter, battery, ups, unknown }

/// `ProcessInfo.ThermalState`, mirrored so Core and Policy stay testable without Foundation's class.
public nonisolated enum ThermalLevel: Int, Codable, Sendable, Comparable {
    case nominal, fair, serious, critical
    public static func < (a: Self, b: Self) -> Bool { a.rawValue < b.rawValue }
}

public nonisolated struct PowerState: Hashable, Sendable {
    public var source: PowerSourceKind
    /// 0…100; nil on Macs without a battery. Read synchronously whenever the boost turns on (§7.1), so it is never stale.
    public var batteryPercent: Int?
    public var isLowPowerMode: Bool
    public init(source: PowerSourceKind, batteryPercent: Int?, isLowPowerMode: Bool) {
        self.source = source; self.batteryPercent = batteryPercent; self.isLowPowerMode = isLowPowerMode
    }
}

/// The frontmost app as the guards need it. `bundleID` is matched exactly; names are never matched.
public nonisolated struct FrontmostApp: Hashable, Sendable {
    public var bundleID: String?
    public var processID: Int32
    /// Displays that show this app's topmost layer-0 window (empty: menu bar only).
    public var displays: Set<DisplayKey>
    /// Holds a display-sleep power assertion (playing video or presenting); nil when unknown.
    public var isPlaying: Bool?
    /// `LSApplicationCategoryType` is games (and not a launcher).
    public var isGame: Bool
    public init(bundleID: String?, processID: Int32, displays: Set<DisplayKey>, isPlaying: Bool?, isGame: Bool) {
        self.bundleID = bundleID; self.processID = processID; self.displays = displays
        self.isPlaying = isPlaying; self.isGame = isGame
    }
}

// MARK: - Conflicts (ARCHITECTURE.md §7.2)

/// Severity classes of apps that also change display colours or brightness.
public nonisolated enum ConflictSeverity: String, Codable, Sendable, CaseIterable {
    case booster        // S1: suspend every display; continuing is possible only in Compatibility mode (no table)
    case gammaWriter    // S2: suspend before starting; Continue Anyway allowed (the repair budget stays authoritative)
    case conditional    // S3: info chip; suspend a display at the first attributed drift
    case benign         // S4: diagnostics only
}

/// One catalogue entry. Holds identifiers only, never a product name (D3).
public nonisolated struct ConflictCatalogEntry: Hashable, Sendable {
    public var id: String
    public var severity: ConflictSeverity
    public var bundleIDs: [String]
    public var bundlePrefixes: [String]
    public var executableNames: [String]
    public var teamIDs: [String]
    public init(id: String, severity: ConflictSeverity, bundleIDs: [String], bundlePrefixes: [String] = [],
                executableNames: [String] = [], teamIDs: [String] = []) {
        self.id = id; self.severity = severity; self.bundleIDs = bundleIDs
        self.bundlePrefixes = bundlePrefixes; self.executableNames = executableNames; self.teamIDs = teamIDs
    }
}

/// A running app that matched the catalogue. `displayName` comes from `NSRunningApplication.localizedName`.
public nonisolated struct ConflictingApp: Hashable, Sendable {
    public var entryID: String
    public var severity: ConflictSeverity
    public var bundleID: String?
    public var processID: Int32
    public var displayName: String
    public init(entryID: String, severity: ConflictSeverity, bundleID: String?, processID: Int32, displayName: String) {
        self.entryID = entryID; self.severity = severity; self.bundleID = bundleID
        self.processID = processID; self.displayName = displayName
    }
}

/// What the active Focus filter asks for (D18). `leaveAlone` is the default and the "no filter" state.
public nonisolated enum FocusDirective: Hashable, Codable, Sendable {
    case leaveAlone
    case off
    case on(level: LevelPosition)
}

/// Everything the policy needs from the system, published by `SystemSignals`.
public nonisolated struct SystemSnapshot: Hashable, Sendable {
    public var power: PowerState
    public var thermal: ThermalLevel
    public var isScreenLocked: Bool
    public var isScreensaverRunning: Bool
    public var areDisplaysAsleep: Bool
    public var isSystemSleeping: Bool
    /// Our session is on the console (`CGSessionCopyCurrentDictionary`[`kCGSessionOnConsoleKey`] at launch, then
    /// session resign/become-active). False → no table write and no launch rescue at all (§7.4).
    public var isSessionActive: Bool
    public var frontmost: FrontmostApp?
    /// Displays that show a full-screen window (any owner except us), after the 0.6 s debounce.
    public var fullScreenDisplays: Set<DisplayKey>
    /// Subset of `fullScreenDisplays` whose full-screen window's owner holds a display-sleep assertion (video).
    public var fullScreenVideoDisplays: Set<DisplayKey>
    /// System idle time has passed the OLED idle threshold (sampled at deadlines, never polled while off).
    public var isIdleBeyondThreshold: Bool
    public var isCameraInUse: Bool
    public var reduceMotion: Bool
    public var conflicts: [ConflictingApp]
    public var focus: FocusDirective
    /// macOS 26+ asked apps to suppress HDR content (logged; shown as a reason, never escalated against).
    public var isHDRSuppressed: Bool
    public init(power: PowerState, thermal: ThermalLevel = .nominal, isScreenLocked: Bool = false,
                isScreensaverRunning: Bool = false, areDisplaysAsleep: Bool = false, isSystemSleeping: Bool = false,
                isSessionActive: Bool = true, frontmost: FrontmostApp? = nil, fullScreenDisplays: Set<DisplayKey> = [],
                fullScreenVideoDisplays: Set<DisplayKey> = [], isIdleBeyondThreshold: Bool = false,
                isCameraInUse: Bool = false, reduceMotion: Bool = false, conflicts: [ConflictingApp] = [],
                focus: FocusDirective = .leaveAlone, isHDRSuppressed: Bool = false) {
        self.power = power; self.thermal = thermal; self.isScreenLocked = isScreenLocked
        self.isScreensaverRunning = isScreensaverRunning; self.areDisplaysAsleep = areDisplaysAsleep
        self.isSystemSleeping = isSystemSleeping; self.isSessionActive = isSessionActive; self.frontmost = frontmost
        self.fullScreenDisplays = fullScreenDisplays; self.fullScreenVideoDisplays = fullScreenVideoDisplays
        self.isIdleBeyondThreshold = isIdleBeyondThreshold; self.isCameraInUse = isCameraInUse
        self.reduceMotion = reduceMotion; self.conflicts = conflicts; self.focus = focus
        self.isHDRSuppressed = isHDRSuppressed
    }
    /// The screen cannot be seen: lock shield, screensaver, sleep, or another session on the console.
    public var isShielded: Bool {
        isScreenLocked || isScreensaverRunning || areDisplaysAsleep || isSystemSleeping || !isSessionActive
    }
}

/// Discrete events that make the engine re-present triggers, re-capture baselines or re-check headroom.
/// Shield events (`willSleep`, `screensDidSleep`, `locked`, `screensaverStarted`, `sessionResigned`) and
/// `displayRemoved` are delivered to every controller synchronously, before the coalesced re-reduction (§4.1).
public nonisolated enum SystemEvent: Hashable, Sendable {
    case willSleep, didWake, screensDidSleep, screensDidWake
    case locked, unlocked, screensaverStarted, screensaverStopped
    case sessionResigned, sessionBecameActive
    case displayConfigurationBegan                   // begin-phase callback: overlays go to factor 1, nothing else
    case displayRemoved(CGDirectDisplayID)           // remove flag: immediate, not debounced (§4.3)
    case displaysReconfigured                        // debounced after-phase pass (0.5 s); the confirming pass at
                                                     // 2 s emits it again only when the facts changed (WP2 as built)
    case screenParametersChanged                     // NSApplication.didChangeScreenParametersNotification (also on H changes)
    case colorProfileChanged                         // distributed ColorSync display-profile notification
    case accessibilityDisplayOptionsChanged
    case activeSpaceChanged
    case appActivated(bundleID: String?)
    case appLaunched(bundleID: String?)
    case appTerminated(bundleID: String?, processID: Int32)   // any table writer's death resets every display (§4.8)
    case hdrSuppressionBegan, hdrSuppressionEnded
    case thermalChanged(ThermalLevel)
    case powerChanged
    case scheduleBoundary                            // contract lane (WP6): Signals' boost-only schedule timer
}
```

Displays emits `displayConfigurationBegan`, `displayRemoved`, `displaysReconfigured` and `screenParametersChanged` on
`SystemDisplayDirectory.addEventObserver` (the `DisplayDirectory` port has no event API); the composition root relays
them into `SignalsMonitor.post(_:)` synchronously (`CompositionRoot.relayDisplayEvents`, WP13), so they reach the
engine and Fill Light exactly like Signals' own events.

### 3.4 Policy inputs and outputs

```swift
// OverbrightCore — policy inputs and outputs (D10). The reducer itself lives in OverbrightPolicy.
import Foundation

public nonisolated enum BatteryGuard: String, Codable, Sendable, CaseIterable {
    case belowThreshold   // default: pause extra brightness on battery below `batteryThreshold`
    case onlyOnAdapter    // pause whenever on battery
    case off              // keep boosting on battery
}

/// A per-app pause rule (D10, ARCHITECTURE.md §6.5). Matches the exact bundle ID, case-insensitively.
public nonisolated struct PausedAppRule: Hashable, Codable, Sendable {
    public enum Mode: String, Codable, Sendable { case whileFrontmost, whilePlaying }
    public var bundleID: String
    public var mode: Mode
    public var isEnabled: Bool
    public init(bundleID: String, mode: Mode, isEnabled: Bool = true) {
        self.bundleID = bundleID; self.mode = mode; self.isEnabled = isEnabled
    }
}

/// "Only allow extra brightness during set hours". Minutes since local midnight; `end < start` spans midnight, and
/// `end == start` is the whole day (as built in WP14: the Settings pickers pass through equal ends).
public nonisolated struct ScheduleWindow: Hashable, Codable, Sendable {
    public var startMinute: Int
    public var endMinute: Int
    public init(startMinute: Int, endMinute: Int) {
        self.startMinute = min(max(startMinute, 0), 1439); self.endMinute = min(max(endMinute, 0), 1439)
    }
    public func contains(minuteOfDay m: Int) -> Bool {
        if startMinute == endMinute { return true }
        return startMinute < endMinute ? (m >= startMinute && m < endMinute) : (m >= startMinute || m < endMinute)
    }
}

/// The settings the reducer reads, flattened from the keys catalog (§3.8) by the engine.
public nonisolated struct PolicySettings: Hashable, Sendable {
    public var batteryGuard: BatteryGuard
    /// Percent, 5…95.
    public var batteryThreshold: Int
    public var pauseInLowPowerMode: Bool
    /// Full-screen window AND its owner holds a display-sleep assertion (default on, beta until H-P1).
    public var pauseForFullScreenVideo: Bool
    /// Any full-screen window, documents and games included (default off).
    public var pauseForAllFullScreen: Bool
    public var pauseInGames: Bool
    public var pauseForListedApps: Bool
    public var pausedApps: [PausedAppRule]
    public var schedule: ScheduleWindow?
    public var linkLevels: Bool
    /// The level every display uses while `linkLevels` is on.
    public var linkedLevel: LevelPosition
    /// Taper extra brightness towards ×1 as the user lowers system brightness (§5.4, default on).
    public var boostOnlyNearFullBrightness: Bool
    public var alwaysContinueEntryIDs: Set<String>
    public init(batteryGuard: BatteryGuard = .belowThreshold, batteryThreshold: Int = 20, pauseInLowPowerMode: Bool = true,
                pauseForFullScreenVideo: Bool = true, pauseForAllFullScreen: Bool = false, pauseInGames: Bool = false,
                pauseForListedApps: Bool = true, pausedApps: [PausedAppRule] = [], schedule: ScheduleWindow? = nil,
                linkLevels: Bool = false, linkedLevel: LevelPosition = LevelPreset.brightRoom.position,
                boostOnlyNearFullBrightness: Bool = true, alwaysContinueEntryIDs: Set<String> = []) {
        self.batteryGuard = batteryGuard; self.batteryThreshold = batteryThreshold
        self.pauseInLowPowerMode = pauseInLowPowerMode; self.pauseForFullScreenVideo = pauseForFullScreenVideo
        self.pauseForAllFullScreen = pauseForAllFullScreen; self.pauseInGames = pauseInGames
        self.pauseForListedApps = pauseForListedApps; self.pausedApps = pausedApps; self.schedule = schedule
        self.linkLevels = linkLevels; self.linkedLevel = linkedLevel
        self.boostOnlyNearFullBrightness = boostOnlyNearFullBrightness
        self.alwaysContinueEntryIDs = alwaysContinueEntryIDs
    }
}

/// Why the engine stopped a display on its own (fed back into the reducer so the UI can say so).
/// Only `headroomNeverArrived` is retried automatically (wake, unlock, reconfiguration, potential change); the
/// others clear only on Try Again / Continue Anyway, or when the attributed app terminates (§4.3).
public nonisolated enum TripCause: Hashable, Sendable {
    case oscillation                         // flicker-safety detector (D5)
    case repairBudgetExceeded                // 3 repairs in 6 s, or > 2 unexplained base adoptions in 60 s
    case attributedDrift(ConflictingApp)     // an identified app changed this display's table
    case headroomNeverArrived                // ladder exhausted / gate timed out (D6)
    case foreignTableAtLaunch                // session-level residue that rescue could not clear (D7)
}

public nonisolated struct EngineFeedback: Hashable, Sendable {
    public var trip: TripCause?
    public var lastReading: HeadroomReading?
    /// The taper's reference the writer uses (§5.4 `H_full`, the learned lowest ready H); nil → the seed (WP14).
    public var fullBrightnessHeadroom: Double?
    public init(trip: TripCause? = nil, lastReading: HeadroomReading? = nil, fullBrightnessHeadroom: Double? = nil) {
        self.trip = trip; self.lastReading = lastReading; self.fullBrightnessHeadroom = fullBrightnessHeadroom
    }
}

public nonisolated struct DisplayPolicyInput: Hashable, Sendable {
    public var facts: DisplayFacts
    public var preferences: DisplayPreferences
    public var feedback: EngineFeedback
    /// Trusted SDR white (colorimeter record, H-N1 panel value, or HDR frame average); nil → nits unknown.
    public var sdrWhite: SDRWhiteEstimate?
    public init(facts: DisplayFacts, preferences: DisplayPreferences, feedback: EngineFeedback,
                sdrWhite: SDRWhiteEstimate?) {
        self.facts = facts; self.preferences = preferences; self.feedback = feedback; self.sdrWhite = sdrWhite
    }
}

/// Everything the pure reducer needs. Building it is the engine's job; deciding is Policy's.
public nonisolated struct PolicyInput: Hashable, Sendable {
    public var isMasterOn: Bool
    /// "Pause for…" deadline (wall clock); nil when not paused.
    public var pausedUntil: Date?
    public var now: Date
    /// Local minute of day for the schedule (the engine computes it with the current calendar and time zone).
    public var minuteOfDay: Int
    /// Model and OS: the compatibility-model list and calibration validity (`CompatibilityModels`, §5.2).
    public var machine: MachineIdentity
    public var settings: PolicySettings
    public var system: SystemSnapshot
    public var displays: [DisplayPolicyInput]
    /// Conflict entries the user chose to continue with in this session (cleared at relaunch).
    public var continuedEntryIDs: Set<String>
    public init(isMasterOn: Bool, pausedUntil: Date?, now: Date, minuteOfDay: Int, machine: MachineIdentity,
                settings: PolicySettings, system: SystemSnapshot, displays: [DisplayPolicyInput],
                continuedEntryIDs: Set<String>) {
        self.isMasterOn = isMasterOn; self.pausedUntil = pausedUntil; self.now = now; self.minuteOfDay = minuteOfDay
        self.machine = machine; self.settings = settings; self.system = system; self.displays = displays
        self.continuedEntryIDs = continuedEntryIDs
    }
}

/// What one display should show. Gains are LIGHT gains (multiples of SDR white), never table factors.
public nonisolated enum BoostTarget: Hashable, Sendable {
    case neutral
    /// Light factor below 1 (dim below the macOS minimum). Needs no headroom.
    case dim(light: Double)
    /// Requested light gain after every static cap; the engine still applies `GainCeiling.liveCap` at write time.
    case boost(gain: Double)
}

/// Why a display is not at the level the user picked. Ordered by precedence; the first one is the chip.
public nonisolated enum LimitReason: Hashable, Sendable {
    case masterOff
    case notSupported(DisplayVerdict)
    case shielded                         // locked, screensaver, asleep, other session
    case conflict(ConflictingApp)
    case tripped(TripCause)
    case userPaused(until: Date)
    case focusOff
    case boostNotEnabled                  // the per-display "Use extra brightness" switch is off (boost half only)
    case thermalCritical
    case lowPowerMode
    case battery(percent: Int, threshold: Int)
    case onBattery                        // BatteryGuard.onlyOnAdapter
    case outsideSchedule
    case fullScreenVideo
    case fullScreenApp
    case pausedApp(bundleID: String)
    case game
    case oledIdle
    case hdrSuppressedByMacOS             // a reason only: never a stop, never a cue to escalate
    case thermalSerious                   // a cap, not a stop
    case safeLimit                        // CapMode.safe binds (static top or live bound)
    case oledLimit                        // OLED Safe cap binds
    case nearFullBrightnessOnly           // the taper binds: system brightness is below full (§5.4)
    case headroom                         // 0.97 × H_live binds ("Limited by macOS")
    case waitingForHeadroom               // gating (D6)
    /// True for reasons that stop the boost half only; dimming still applies (ARCHITECTURE.md §6.1).
    public var blocksBoostOnly: Bool {
        switch self {
        case .boostNotEnabled, .thermalCritical, .lowPowerMode, .battery, .onBattery, .outsideSchedule,
             .fullScreenVideo, .fullScreenApp, .pausedApp, .game, .oledIdle: true
        default: false
        }
    }
    /// Reasons that apply to every display at once: shown once as the banner, never as per-card chips (§6.3).
    public var isGlobal: Bool {
        switch self {
        case .userPaused, .focusOff, .thermalCritical, .lowPowerMode, .battery, .onBattery, .outsideSchedule: true
        case .conflict(let app): app.severity == .booster || app.severity == .gammaWriter
        default: false
        }
    }
}

public nonisolated struct DisplayDecision: Hashable, Sendable {
    public var key: DisplayKey
    public var target: BoostTarget
    public var reasons: [LimitReason]
    public var eligibility: EligibilityResult
    public var mechanism: Mechanism
    /// Effective transfer domain (a stale or unconfirmed calibration falls back to `.encoded`, §5.2).
    public var domain: TransferDomain
    /// Light gain the user's level asks for before any cap (for the readout and the "limited" chip).
    public var requestedGain: Double
    /// The level the reducer used: the display's own, the linked level or the Focus filter's (§6.1 step 3). The
    /// readout names the preset at this level. Contract lane (WP1, 460b2f5).
    public var level: LevelPosition
    public init(key: DisplayKey, target: BoostTarget, reasons: [LimitReason], eligibility: EligibilityResult,
                mechanism: Mechanism, domain: TransferDomain, requestedGain: Double, level: LevelPosition = .standard) {
        self.key = key; self.target = target; self.reasons = reasons; self.eligibility = eligibility
        self.mechanism = mechanism; self.domain = domain; self.requestedGain = requestedGain; self.level = level
    }
}

/// The one "Paused because…" banner the panel shows (DESIGN.md §5.8), highest precedence wins.
public nonisolated enum Banner: Hashable, Sendable {
    case userPaused(until: Date)
    case conflict(ConflictingApp)
    case foreignTableAtLaunch
    case flickerStop(display: DisplayKey)
    case unattributedDrift(display: DisplayKey)
    case attributedDrift(ConflictingApp, display: DisplayKey)
    case focusOff
    case thermalCritical
    case lowPowerMode
    case battery(percent: Int, threshold: Int)
    case onBattery
    case outsideSchedule(ScheduleWindow)
}

/// Menu bar symbol state (DESIGN.md §4.1).
public nonisolated enum StatusSymbolState: String, Sendable, CaseIterable {
    case off, on, preparing, dimming, paused, attention
}

public nonisolated struct PolicyDecision: Hashable, Sendable {
    public var displays: [DisplayKey: DisplayDecision]
    public var banner: Banner?
    public var symbol: StatusSymbolState
    public init(displays: [DisplayKey: DisplayDecision], banner: Banner?, symbol: StatusSymbolState) {
        self.displays = displays; self.banner = banner; self.symbol = symbol
    }
}
```

### 3.5 Engine status, HUD changes, triggers, self-test, journal

```swift
// OverbrightCore — engine status, triggers, self-test (value types). ARCHITECTURE.md §3.5, §4.
import CoreGraphics
import Foundation

/// Per-display engine phase (ARCHITECTURE.md §4.2). Mechanism-agnostic: the overlay walks the same phases.
public nonisolated enum EnginePhase: Hashable, Sendable {
    case idle                                  // neutral table, no trigger, zero work
    case dimmed                                // table (or overlay) below 1, no headroom needed
    case arming(rung: Int)                     // trigger rung shown, waiting for the first headroom movement
    case gating(rung: Int)                     // headroom moved (or was already held); waiting for a stable value (D6)
    case ramping                               // table factor moving towards the target
    case boosted                               // steady; drift watchdog every 2 s
    case suspended(SuspendCause)               // neutral written; trigger kept ≤ 10 s, then removed
    case failed(TripCause)                     // neutral, no trigger, reason shown (§4.3 says which trips auto-retry)
    case disarming                             // ramp down → baseline → remove trigger
}

public nonisolated enum SuspendCause: Hashable, Sendable {
    case shielded, policy, occluded, displayAsleep, reconfiguring, hungMainThread, notOnConsole
}

public nonisolated enum TriggerPlacement: String, Codable, Sendable { case topRightCorner, topLeftCorner, notch }
public nonisolated enum TriggerBlend: String, Codable, Sendable { case normal, softLight }

/// One rung of the ladder as the factory sees it.
public nonisolated struct TriggerRequest: Hashable, Sendable {
    public var strategy: TriggerStrategy
    public var pixel: TriggerPixel
    public var placement: TriggerPlacement
    public var blend: TriggerBlend
    /// Window edge in points (1 pt = 2 × 2 px on Retina).
    public var edgePoints: Double
    /// Headroom tag for tagged strategies (policy A: the display's potential; clamped to ≥ 1.01 by T1).
    public var headroomTag: Double
    public init(strategy: TriggerStrategy, pixel: TriggerPixel, placement: TriggerPlacement, blend: TriggerBlend,
                edgePoints: Double = 1, headroomTag: Double) {
        self.strategy = strategy; self.pixel = pixel; self.placement = placement; self.blend = blend
        self.edgePoints = edgePoints; self.headroomTag = headroomTag
    }
}

public nonisolated enum TriggerError: Error, Hashable, Sendable {
    case needsNewerMacOS(Int)
    case colorUnavailable
    case noMetalDevice
    case assetUnavailable
    case displayGone
}

/// What the UI, the menu, intents and diagnostics read about one display.
public nonisolated struct DisplayStatus: Hashable, Sendable {
    public var key: DisplayKey
    public var name: String
    public var phase: EnginePhase
    public var decision: DisplayDecision?
    /// Light gain on screen right now (1 = Standard; < 1 dimmed).
    public var appliedGain: Double
    /// Table factor written (or overlay factor) right now.
    public var appliedFactor: Double
    public var mechanism: Mechanism
    public var strategy: TriggerStrategy?
    public var lastReading: HeadroomReading?
    /// Trusted SDR white; nits are shown only with this AND a valid calibration record (DESIGN.md §5.6).
    public var sdrWhite: SDRWhiteEstimate?
    /// `failed(headroomNeverArrived)` episodes in this session (the chip changes after two, DESIGN.md §12.2).
    public var failedTries: Int
    /// The largest light gain macOS's grants allowed while boosting on this OS build (0.97 × the highest H seen, from
    /// the strategy cache), nil until seen: `VerdictText`'s `lastGrant` (DESIGN.md §12.1; WP14).
    public var lastGrant: Double?
    public init(key: DisplayKey, name: String, phase: EnginePhase, decision: DisplayDecision?, appliedGain: Double,
                appliedFactor: Double, mechanism: Mechanism, strategy: TriggerStrategy?, lastReading: HeadroomReading?,
                sdrWhite: SDRWhiteEstimate?, failedTries: Int = 0, lastGrant: Double? = nil) {
        self.key = key; self.name = name; self.phase = phase; self.decision = decision; self.appliedGain = appliedGain
        self.appliedFactor = appliedFactor; self.mechanism = mechanism; self.strategy = strategy
        self.lastReading = lastReading; self.sdrWhite = sdrWhite; self.failedTries = failedTries
        self.lastGrant = lastGrant
    }
}

/// Who asked for a change: decides HUD and announcements (DESIGN.md §6).
public nonisolated enum ControlSource: String, Sendable {
    case panel, menu, shortcut, intent, focusFilter, welcome, settings, automation, launch, statusItem
}

/// The last change the HUD may show (DESIGN.md §6). The shell shows it when `sequence` increases.
public nonisolated struct LevelChange: Hashable, Sendable {
    public enum Kind: Hashable, Sendable {
        case level                              // a level or on/off change by `source`
        case preparing                          // the requested boost waits for extra range (> 0.5 s)
        case blocked(LimitReason)               // a requested change was stopped by a guard
        case automationStopped(LimitReason)     // a guard stopped or capped the boost on its own
        case automationResumed                  // the boost came back after a guard cleared
        case timerEnded
    }
    public var sequence: UInt64
    public var kind: Kind
    public var source: ControlSource
    /// nil = every display.
    public var display: DisplayKey?
    public init(sequence: UInt64, kind: Kind, source: ControlSource, display: DisplayKey?) {
        self.sequence = sequence; self.kind = kind; self.source = source; self.display = display
    }
}

/// "Keep this level?" after a level below 10 % of Standard light was set (§5.9). Reverts at `deadline`.
public nonisolated struct LowLevelConfirmation: Hashable, Sendable {
    public var display: DisplayKey?
    public var previousLevels: [DisplayKey: LevelPosition]
    public var deadline: Date
    public init(display: DisplayKey?, previousLevels: [DisplayKey: LevelPosition], deadline: Date) {
        self.display = display; self.previousLevels = previousLevels; self.deadline = deadline
    }
}

public nonisolated struct BoostStatus: Hashable, Sendable {
    public var isOn: Bool
    /// The engine finished its launch work (launch check, first reduction); intents wait for this (≤ 5 s).
    public var isReady: Bool
    public var pausedUntil: Date?
    public var autoOffAt: Date?
    public var displays: [DisplayStatus]
    public var banner: Banner?
    public var symbol: StatusSymbolState
    public var lastChange: LevelChange?
    public var pendingLowLevel: LowLevelConfirmation?
    public init(isOn: Bool, isReady: Bool, pausedUntil: Date?, autoOffAt: Date?, displays: [DisplayStatus],
                banner: Banner?, symbol: StatusSymbolState, lastChange: LevelChange? = nil,
                pendingLowLevel: LowLevelConfirmation? = nil) {
        self.isOn = isOn; self.isReady = isReady; self.pausedUntil = pausedUntil; self.autoOffAt = autoOffAt
        self.displays = displays; self.banner = banner; self.symbol = symbol; self.lastChange = lastChange
        self.pendingLowLevel = pendingLowLevel
    }
    public static let initial = BoostStatus(isOn: false, isReady: false, pausedUntil: nil, autoOffAt: nil,
                                            displays: [], banner: nil, symbol: .off)
}

/// Brighter / Less Bright: one step in STOPS of light (`StepSize`), never crossing Standard in one press (§5.3).
public nonisolated enum StepDirection: Sendable { case brighter, lessBright }

/// What an intent or the menu asks for on the boost half (DESIGN.md §12.8).
public nonisolated enum ExtraBrightnessRequest: Hashable, Sendable {
    case preset(LevelPreset)
    /// A light multiplier, clamped to each display's own ceiling.
    case multiplier(Double)
}

public nonisolated struct SelfTestOptions: Hashable, Sendable {
    /// Test every rung of the ladder instead of stopping at the first that holds.
    public var everyStrategy: Bool
    public var secondsPerStrategy: Int
    public var displays: Set<DisplayKey>?
    public init(everyStrategy: Bool = false, secondsPerStrategy: Int = 30, displays: Set<DisplayKey>? = nil) {
        self.everyStrategy = everyStrategy; self.secondsPerStrategy = secondsPerStrategy; self.displays = displays
    }
}

public nonisolated struct SelfTestSample: Hashable, Codable, Sendable {
    public var seconds: Double
    public var current: Double
    public var potential: Double
    public var appliedFactor: Double
    public var event: String?
    public init(seconds: Double, current: Double, potential: Double, appliedFactor: Double, event: String?) {
        self.seconds = seconds; self.current = current; self.potential = potential
        self.appliedFactor = appliedFactor; self.event = event
    }
}

public nonisolated struct SelfTestStrategyResult: Hashable, Codable, Sendable {
    public enum Verdict: String, Codable, Sendable { case held, engagedButDropped, noEngage, invalidBaseline, skipped }
    public var strategy: TriggerStrategy
    public var pixel: TriggerPixel
    public var verdict: Verdict
    public var baselineHeadroom: Double
    public var secondsToFirstMovement: Double?
    public var secondsToStable: Double?
    public var heldFraction: Double
    public var samples: [SelfTestSample]
    public init(strategy: TriggerStrategy, pixel: TriggerPixel, verdict: Verdict, baselineHeadroom: Double,
                secondsToFirstMovement: Double?, secondsToStable: Double?, heldFraction: Double,
                samples: [SelfTestSample]) {
        self.strategy = strategy; self.pixel = pixel; self.verdict = verdict; self.baselineHeadroom = baselineHeadroom
        self.secondsToFirstMovement = secondsToFirstMovement; self.secondsToStable = secondsToStable
        self.heldFraction = heldFraction; self.samples = samples
    }
}

public nonisolated struct SelfTestReport: Hashable, Codable, Sendable {
    public var startedAt: Date
    public var machine: MachineIdentity
    public var appVersion: String
    public var displays: [String: [SelfTestStrategyResult]]   // DisplayKey.rawValue → results
    public var journal: [JournalEvent]
    public init(startedAt: Date, machine: MachineIdentity, appVersion: String,
                displays: [String: [SelfTestStrategyResult]], journal: [JournalEvent]) {
        self.startedAt = startedAt; self.machine = machine; self.appVersion = appVersion
        self.displays = displays; self.journal = journal
    }
}

public nonisolated enum RescueOutcome: Hashable, Sendable {
    case alreadyNeutral
    case restored(displays: Int)
    /// The global restore left an invalid table (e.g. all zeros); the profile base was written explicitly.
    case repairedInvalidRestore(displays: [DisplayKey])
    case skippedBecauseTableWriterRuns(ConflictingApp)
    case skippedNotOnConsole
    case residueRemains(displays: [DisplayKey])     // a session-level foreign write: preset change, logout or reboot
}

/// One line of the diagnostics journal. Codes and numbers only; no user content (names are added by the UI).
public nonisolated struct JournalEvent: Hashable, Codable, Sendable {
    public var seconds: Double            // monotonic seconds since launch
    public var category: String           // a LogCategory raw value
    public var display: String?           // DisplayKey.rawValue
    public var code: String               // stable machine code, e.g. "gate.ready", "watchdog.drift"
    public var values: [String: Double]
    public init(seconds: Double, category: String, display: String?, code: String, values: [String: Double] = [:]) {
        self.seconds = seconds; self.category = category; self.display = display; self.code = code; self.values = values
    }
}
```

### 3.6 Ports

```swift
// OverbrightCore — ports (one protocol per file in the repo). ARCHITECTURE.md §3.6.
// Contract rule (§10.0): a requirement added after WP0a lands only together with a default implementation in a
// protocol extension in the same file.
import CoreGraphics
import Foundation
import Observation

// MARK: - Coding keys for dictionary-keyed settings (JSON objects, not arrays)

extension DisplayKey: CodingKeyRepresentable {
    public var codingKey: any CodingKey { Key(stringValue: rawValue) }
    public init?<T: CodingKey>(codingKey: T) { self.init(rawValue: codingKey.stringValue) }
    private struct Key: CodingKey {
        var stringValue: String
        var intValue: Int? { nil }
        init(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { nil }
    }
}

extension ShortcutID: CodingKeyRepresentable {
    public var codingKey: any CodingKey { Key(stringValue: rawValue) }
    public init?<T: CodingKey>(codingKey: T) { self.init(codingKey.stringValue) }
    private struct Key: CodingKey {
        var stringValue: String
        var intValue: Int? { nil }
        init(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { nil }
    }
}

// MARK: - Small utilities

/// Keeps an observation alive; `cancel()` or deinit ends it (Cranny's Concurrency.swift).
@MainActor public final class ObservationToken {
    private var onCancel: (() -> Void)?
    public init(_ onCancel: @escaping () -> Void) { self.onCancel = onCancel }
    public func cancel() { onCancel?(); onCancel = nil }
    isolated deinit { onCancel?() }
}

// MARK: - Time (named TimeSource: `Clock` is an SDK type, D21)

public protocol TimeSource: Sendable {
    var now: MonotonicInstant { get }
    var wallClock: Date { get }
    /// Real: Task.sleep with 10 % tolerance (at most 1 s). Manual: suspends until `advance(by:)` passes the deadline.
    func sleep(for duration: Duration) async throws
}
extension TimeSource {   // energy pass (T1): an extension method, not a requirement, so no conformer changes
    /// The next multiple of `period` since the origin strictly after `now`: always in (now, now + period]. Services that
    /// share one time source (the composition root's `context.time`) and wait for it wake together. Pure form:
    /// `MonotonicInstant.nextGridPoint(after:every:)`; a period that is not positive returns the instant itself.
    public func nextGridPoint(every period: Duration) -> MonotonicInstant
}

// MARK: - Displays (implemented by OverbrightDisplays)

/// The ONLY path to `CGGet/SetDisplayTransferByTable` and `CGDisplayRestoreColorSyncSettings`.
/// Nonisolated and Sendable: the hang watchdog and the signal queue write ledger baselines off the main actor (D7).
public protocol GammaPort: Sendable {
    func capacity(of display: CGDirectDisplayID) -> Int
    func read(_ display: CGDirectDisplayID) throws -> GammaTable
    /// The table macOS restores for this display, derived WITHOUT the live table: the ColorSync profile's `vcgt`
    /// (public ColorSync / `CGDisplayCopyColorSpace` ICC data), resampled to `count`; identity when absent (D26).
    func profileBase(of display: CGDirectDisplayID, count: Int) -> GammaTable
    /// Writes as-is. Only Boost's `TableWriter` (normal, calibration and ledger-baseline paths) and `LaunchRescue`
    /// call it (§4.5 invariant 3).
    func write(_ table: GammaTable, to display: CGDirectDisplayID) throws
    /// Global ColorSync restore. Rescue paths only (D7, §7.4); a no-op unless this process wrote a table first.
    func restoreSystemColorSettings()
    /// Number of successful writes since launch (diagnostics `gammaWrites`; smoke asserts 0).
    var writeCount: Int { get }
}

@MainActor public protocol HeadroomPort: AnyObject {
    /// Fresh NSScreen read for exactly this display (NSScreen objects are re-fetched after every screen-parameters
    /// change). Nil for a display without its own NSScreen (mirror member, gone).
    func reading(for display: DisplayRef) -> HeadroomReading?
}

@MainActor public protocol DisplayDirectory: AnyObject, Observable {
    /// Online displays, built-in first, then by key. Changes after the debounced reconfiguration callback, and at
    /// once (without the debounce) when a display is removed.
    var displays: [DisplayFacts] { get }
    /// Increments on every change of `displays`; observers re-read `displays`.
    var generation: Int { get }
    func facts(for key: DisplayKey) -> DisplayFacts?
}

// MARK: - Triggers (implemented by OverbrightTriggers)

@MainActor public protocol TriggerHandle: AnyObject {
    var request: TriggerRequest { get }
    var isOccluded: Bool { get }
    var onOcclusionChange: ((Bool) -> Void)? { get set }
    /// Called when AppKit moves the window to another screen (`NSWindow.didChangeScreenNotification`): the
    /// controller removes the trigger at once if the new screen is not its display (§4.3).
    var onScreenChange: ((CGDirectDisplayID?) -> Void)? { get set }
    /// Shows the pixel. T2/T3 retry the first present every 50 ms for up to 2 s; false = never presented.
    func present(_ pixel: TriggerPixel) async -> Bool
    /// Event-driven re-present (wake, unlock, occlusion → visible, screen parameters). Re-places the window.
    func represent()
    /// Re-tags in place (tag policy B, ARCHITECTURE.md §4.7). No-op for HLG strategies.
    func requestHeadroom(_ headroom: Double)
    func remove()
}

/// Technique C: one full-screen multiply overlay per display (Compatibility mode).
@MainActor public protocol OverlayHandle: AnyObject {
    var isOccluded: Bool { get }
    var onOcclusionChange: ((Bool) -> Void)? { get set }
    var onScreenChange: ((CGDirectDisplayID?) -> Void)? { get set }
    /// `factor` < 1 dims without EDR; > 1 multiplies and requests at least `headroomRequest`.
    func setFactor(_ factor: Double, headroomRequest: Double) throws
    func represent()
    func remove()
}

@MainActor public protocol TriggerFactory: AnyObject {
    func isAvailable(_ strategy: TriggerStrategy) -> Bool
    func makeTrigger(_ request: TriggerRequest, on display: DisplayRef) throws -> any TriggerHandle
    func makeOverlay(on display: DisplayRef) throws -> any OverlayHandle
    /// Open trigger + overlay windows (diagnostics `triggerWindows`; smoke asserts 0).
    var openWindowCount: Int { get }
}

// MARK: - System (implemented by OverbrightSignals)

@MainActor public protocol SystemSignals: AnyObject, Observable {
    var snapshot: SystemSnapshot { get }
    func addEventObserver(_ handler: @escaping @MainActor (SystemEvent) -> Void) -> ObservationToken
    /// Starts the per-boost sources (battery percent, idle deadlines, watchdog full-screen re-check). D22.
    /// `true` also reads the power source and battery percent synchronously before returning.
    func setBoostActive(_ active: Bool)
    /// Synchronous `IOPSCopyPowerSourcesInfo` read into `snapshot.power` (master on, adapter → battery switch).
    func refreshPowerNow()
    /// The Focus filter's sink (IntentRouter → Signals); persisted so a launch reads the last directive.
    func setFocusDirective(_ directive: FocusDirective)
}

@MainActor public protocol ConflictProbe: AnyObject {
    func runningConflicts() -> [ConflictingApp]
    /// On-demand libproc scan to name the app behind an unexplained drift (≈ 14 ms, off the main actor).
    func attributeDrift() async -> ConflictingApp?
}

// MARK: - Engine façade (implemented by OverbrightBoost)

/// A running calibration (DESIGN.md §9). The view drives it; the engine owns every table write.
/// Starting one returns every display to Standard first (triggers removed, neutral tables).
@MainActor public protocol CalibrationSession: AnyObject {
    var display: DisplayKey { get }
    var currentFactor: Double { get }
    var headroom: Double? { get }
    /// True while the sweep waits at 1.15 × the encoded prediction for "Keep Going" (DESIGN.md §9).
    var isSweepPausedAtLimit: Bool { get }
    func showComparison(boosted: Bool)          // "Did it get brighter?" (≤ 1 flip per 1.5 s)
    func startSweep()                            // 1.00 → cap in 0.02 steps every 400 ms, black surround
    func continueSweep()                         // past the 1.15 × encoded-prediction pause
    func markMerged()                            // Space: the 0.95 patch merged with white
    /// Shows the patches for 2 s at the LINEAR-domain Peak factor; only "distinguishable" can record `.linear`.
    func showLinearConfirmation()
    func answerLinearConfirmation(distinguishable: Bool)
    func setMeasuredSDRWhite(nits: Double?)
    func finish(brighter: Bool?) -> CalibrationRecord?
    func cancel()                                // Esc: neutral at once
    /// The step the session is in (preparing, ready, sweeping, swept, confirming, aborted(reason), finished), so the
    /// window can show it. Contract lane (WP5): default `.ready` in a protocol extension.
    var state: CalibrationState { get }
}

@MainActor public protocol BoostControl: AnyObject, Observable {
    var status: BoostStatus { get }
    func setOn(_ on: Bool, source: ControlSource)
    func toggle(source: ControlSource)
    /// nil display = every display (or the linked level). Moving a slider also turns the master on and ends a pause.
    func setLevel(_ level: LevelPosition, for display: DisplayKey?, source: ControlSource)
    func setExtraBrightness(_ request: ExtraBrightnessRequest, for display: DisplayKey?, source: ControlSource)
    /// Dim to `light` (0.02…0.99 of Standard light). nil display = every display that can dim.
    func setDimLight(_ light: Double, for display: DisplayKey?, source: ControlSource)
    func step(_ direction: StepDirection, source: ControlSource)
    /// "Dim All Displays" ⇄ "Stop Dimming": every display that can dim goes to `lastDimLight`, or back to its level.
    func toggleDim(source: ControlSource)
    /// Back to Standard: master off within 120 ms, dims undone, stored levels KEPT. Always available.
    func returnToStandard(source: ControlSource)
    func keepLowLevel()
    func revertLowLevel()
    /// The engine owns the pause deadline (`automations.pausedUntil`) and its single sleep.
    func pause(until deadline: Date?, source: ControlSource)
    func resume(source: ControlSource)
    /// S2/S3 only; for S1 boosters it is honoured only on Compatibility-mode displays (§7.2).
    func continueAnyway(_ app: ConflictingApp)
    /// Try Again: clears any trip on this display (the only way to clear flicker, repair and drift trips).
    func retry(_ display: DisplayKey)
    func runSelfTest(_ options: SelfTestOptions) async -> SelfTestReport
    func beginCalibration(of display: DisplayKey) -> (any CalibrationSession)?
    /// Advanced ▸ Reset Display Colors (dirty-then-restore, D7).
    func rescueDisplayColors() async -> RescueOutcome
    /// Advanced ▸ Forget Learned Methods: clears the strategy cache (§4.7).
    func forgetLearnedMethods()   // contract lane (WP11): default no-op in a protocol extension
}

// MARK: - Other features

@MainActor public protocol FillLightControl: AnyObject, Observable {
    var isOn: Bool { get }
    var isAutomatic: Bool { get }   // turned on by the camera rule
    func setOn(_ on: Bool, source: ControlSource)
}

@MainActor public protocol ShortcutCenter: AnyObject, Observable {
    func state(_ id: ShortcutID) -> ShortcutState
    @discardableResult func set(_ id: ShortcutID, _ combo: KeyCombo?) -> ShortcutState
    /// The recorder pauses every hot key while it listens.
    func setRecording(_ recording: Bool)
    /// The key caps of a registered shortcut in the CURRENT keyboard layout (the same code as the menu's live key
    /// equivalents), e.g. "⌃⌥⌘B"; nil when cleared or not registered. Copy never hard-codes key caps (DESIGN §16).
    func displayString(_ id: ShortcutID) -> String?
}

public nonisolated enum UpdateState: Hashable, Sendable {
    case idle, checking, upToDate(checkedAt: Date), available(version: String, url: URL), failed(message: String)
}

@MainActor public protocol UpdateChecking: AnyObject, Observable {
    /// False while the Info.plist repository key is empty: no network at all (D2).
    var isConfigured: Bool { get }
    /// https://github.com/owner/repo from the same validated slug; nil while not configured (Settings ▸ About's link).
    var repositoryURL: URL? { get }   // contract lane (WP0b): default nil in a protocol extension
    var state: UpdateState { get }
    func checkNow()
}

public nonisolated enum LoginItemState: Hashable, Sendable { case enabled, disabled, requiresApproval, unavailable }

/// Result of the status-item visibility check (DESIGN.md §4.4), run 3 s after launch and on every screen change.
public nonisolated enum MenuBarIconVisibility: Hashable, Sendable {
    case visible
    case hiddenByUser                // General ▸ Show menu bar icon is off
    case notVisible                  // no window, not visible, occluded, or behind the notch
}

@MainActor public protocol AppControl: AnyObject, Observable {
    var loginItem: LoginItemState { get }
    var iconVisibility: MenuBarIconVisibility { get }
    func showPanel()
    func openSettings(_ pane: String?)          // "pane" or "pane#row" (Cranny deep links)
    func showWelcome()
    /// The local Help window, optionally scrolled to an anchor ("no-extra-range", "control-center", …).
    func showHelp(anchor: String?)
    func showCalibration(for display: DisplayKey)
    func setLaunchBehavior(_ behavior: LaunchBehavior)
    func setMenuBarIconVisible(_ visible: Bool)
    func copyDiagnostics()
    func saveSelfTestLog(_ report: SelfTestReport)
    func resetAllSettings()                      // with Undo until the Settings window closes
    func undoResetAllSettings()
    func quit()
}

/// Ordered start/stop, owned by the composition root (Boost starts last and stops first, D7).
@MainActor public protocol ServiceLifecycle: AnyObject {
    var serviceName: String { get }
    func start() async
    /// The normal stop (ramps). A user quit awaits it with a 1 s timeout before terminating (§7.4).
    func stop() async
    /// Synchronous fallback from `applicationWillTerminate`: no ramp, baselines written at once.
    func stopNow()
}

/// In-memory ring buffer (last 500 events) behind self-test logs and Copy Diagnostics.
public protocol DiagnosticsJournal: Sendable {
    func record(_ event: JournalEvent)
    func snapshot() -> [JournalEvent]
}
```

`AppPaths`, `Announcer` and `Log` are ported from Cranny verbatim apart from the renames; the typecheck used stand-ins with the same names and signatures. `SettingsStore` is the real port (§3.8).

### 3.7 Shortcuts

```swift
// OverbrightCore — shortcut identifiers and the default catalog (D17).
import Foundation

public nonisolated struct ShortcutID: Hashable, Codable, Sendable, CustomStringConvertible {
    public let rawValue: String
    public init(_ rawValue: String) { self.rawValue = rawValue }
    public var description: String { rawValue }
    public static let toggle = ShortcutID("boost.toggle")
    public static let brighter = ShortcutID("boost.brighter")
    public static let lessBright = ShortcutID("boost.lessBright")   // one step down; never crosses Standard in one press
    public static let max = ShortcutID("boost.max")
    public static let standard = ShortcutID("boost.standard")       // Back to Standard (fast off, levels kept)
    public static let dimToggle = ShortcutID("boost.dimToggle")     // "Dim Below Minimum On or Off", all displays
    public static let fillLight = ShortcutID("fillLight.toggle")
}

/// A key code plus Carbon-independent modifier flags (ported from Cranny).
public nonisolated struct KeyCombo: Hashable, Codable, Sendable {
    public struct Modifiers: OptionSet, Hashable, Codable, Sendable {
        public let rawValue: UInt8
        public init(rawValue: UInt8) { self.rawValue = rawValue }
        public static let command = Modifiers(rawValue: 1 << 0)
        public static let option = Modifiers(rawValue: 1 << 1)
        public static let control = Modifiers(rawValue: 1 << 2)
        public static let shift = Modifiers(rawValue: 1 << 3)
    }
    public var keyCode: UInt16
    public var modifiers: Modifiers
    public init(keyCode: UInt16, modifiers: Modifiers) { self.keyCode = keyCode; self.modifiers = modifiers }
}

public nonisolated enum ShortcutState: Hashable, Sendable {
    case off                    // no combo
    case registered(KeyCombo)
    case conflict(KeyCombo)     // RegisterEventHotKey failed (another app owns it)
}

public nonisolated struct GlobalShortcut: Hashable, Sendable {
    public var id: ShortcutID
    public var defaultCombo: KeyCombo?
    public init(id: ShortcutID, defaultCombo: KeyCombo?) { self.id = id; self.defaultCombo = defaultCombo }
}

/// Defaults avoid ⌃⌥Space (input sources), ⌃⌥⌘8 and ⌃⌥⌘,/. (accessibility) and ⌃⌥⌘V / ⌃⌥⌘D, another booster's
/// defaults (D17). Key codes are kVK_ANSI_* POSITIONS (B = 11, Equal = 24, Minus = 27, 9 = 25, 0 = 29); the key caps
/// shown in copy and menus come from the current keyboard layout (`ShortcutCenter.displayString`).
public nonisolated enum ShortcutCatalog {
    static let hyper: KeyCombo.Modifiers = [.control, .option, .command]
    public static let all: [GlobalShortcut] = [
        GlobalShortcut(id: .toggle, defaultCombo: KeyCombo(keyCode: 11, modifiers: hyper)),     // ⌃⌥⌘B
        GlobalShortcut(id: .brighter, defaultCombo: KeyCombo(keyCode: 24, modifiers: hyper)),   // ⌃⌥⌘= (US)
        GlobalShortcut(id: .lessBright, defaultCombo: KeyCombo(keyCode: 27, modifiers: hyper)), // ⌃⌥⌘- (US)
        GlobalShortcut(id: .max, defaultCombo: nil),
        GlobalShortcut(id: .standard, defaultCombo: KeyCombo(keyCode: 29, modifiers: hyper)),   // ⌃⌥⌘0 (US)
        GlobalShortcut(id: .dimToggle, defaultCombo: KeyCombo(keyCode: 25, modifiers: hyper)),  // ⌃⌥⌘9 (US)
        GlobalShortcut(id: .fillLight, defaultCombo: nil),
    ]
}
```

### 3.8 Settings keys catalog and the settings store

```swift
// OverbrightCore — the settings keys catalog (ARCHITECTURE.md §3.8). Every key lives here because almost all are shared
// (UI writes, Boost/Signals read). Never rename a key after a release; a changed default needs a SettingsUpgrades step.
import Foundation

/// Namespaces (Cranny's `ModuleID` idea). The stored key is "overbright.<namespace>.<name>".
public nonisolated enum SettingsNamespace: String, Sendable, CaseIterable {
    case general, displays, automations, shortcuts, fillLight = "filllight", advanced, onboarding, updates, engine
}

/// A typed key with its default, ported from Cranny's `SettingKey` (`module` → `namespace`). `SettingsStore`
/// stores it as JSON under "overbright." + `id`; equality and hashing use `id`.
public nonisolated struct SettingKey<Value: Codable & Sendable & Equatable>: Sendable, Hashable {
    public let namespace: SettingsNamespace
    public let name: String
    public let defaultValue: Value
    /// "<namespace>.<name>", built once: every read, hash and `==` uses it.
    public let id: String
    public init(_ namespace: SettingsNamespace, _ name: String, default defaultValue: Value) {
        self.namespace = namespace; self.name = name; self.defaultValue = defaultValue
        id = "\(namespace.rawValue).\(name)"
    }
    public static func == (a: Self, b: Self) -> Bool { a.id == b.id }
    public func hash(into h: inout Hasher) { h.combine(id) }
}

public nonisolated enum LaunchBehavior: String, Codable, Sendable, CaseIterable {
    case launchAndEnable   // open at login and turn on
    case launchOnly        // open at login, keep off (default)
    case dontLaunch        // not a login item
}

public nonisolated enum StatusClickAction: String, Codable, Sendable, CaseIterable {
    case openPanel         // default: click = panel, right/Control-click = menu
    case toggle            // click = on/off, right/Control-click = menu (which then starts with "Show Panel")
}

/// Brighter / Less Bright step, in STOPS of light (§5.3). Arrow keys always move 1/12 stop.
public nonisolated enum StepSize: String, Codable, Sendable, CaseIterable {
    case regular   // ¼ stop (≈ 19 % light)
    case fine      // 1/12 stop (≈ 6 % light)
    public var stops: Double { self == .regular ? 0.25 : 1.0 / 12 }
}

public nonisolated enum CameraFilter: String, Codable, Sendable { case anyCamera, builtInAndUSB }

public nonisolated enum GeneralSettings {
    public static let launchBehavior = SettingKey(.general, "launchBehavior", default: LaunchBehavior.launchOnly)
    public static let showsMenuBarIcon = SettingKey(.general, "showsMenuBarIcon", default: true)
    public static let clickAction = SettingKey(.general, "clickAction", default: StatusClickAction.openPanel)
    public static let showsHUD = SettingKey(.general, "showsHUD", default: true)
    public static let haptics = SettingKey(.general, "haptics", default: true)
    /// Shows a Dock icon (activation policy .regular) with a Dock menu. Off: a pure menu bar app.
    public static let showsDockIcon = SettingKey(.general, "showsDockIcon", default: false)
}

public nonisolated enum DisplaySettings {
    /// Per-display preferences by display UUID (the same dictionary-by-UUID pattern as Cranny).
    public static let perDisplay = SettingKey(.displays, "perDisplay", default: [DisplayKey: DisplayPreferences]())
    /// "Same level on all displays".
    public static let linkLevels = SettingKey(.displays, "linkLevels", default: false)
    /// The level used for every display while `linkLevels` is on.
    public static let linkedLevel = SettingKey(.displays, "linkedLevel", default: LevelPreset.brightRoom.position)
    /// The dim level of "Dim All Displays", the Dim shortcut and the menu's "Dimmed", as LIGHT (0.02…0.99).
    public static let lastDimLight = SettingKey(.displays, "lastDimLight", default: 0.25)
    /// "Add extra brightness only near full brightness" (§5.4).
    public static let boostOnlyNearFullBrightness = SettingKey(.displays, "boostOnlyNearFullBrightness", default: true)
}

public nonisolated enum AutomationSettings {
    public static let batteryGuard = SettingKey(.automations, "batteryGuard", default: BatteryGuard.belowThreshold)
    /// Percent, 5…95 in steps of 5.
    public static let batteryThreshold = SettingKey(.automations, "batteryThreshold", default: 20)
    public static let pauseInLowPowerMode = SettingKey(.automations, "pauseInLowPowerMode", default: true)
    /// Minutes; nil = never. Allowed: 5, 10, 15, 20, 30, 45, 60, 90, 120.
    public static let autoOffMinutes = SettingKey(.automations, "autoOffMinutes", default: Int?.none)
    /// Full-screen window whose owner holds a display-sleep assertion (beta until H-P1).
    public static let pauseForFullScreenVideo = SettingKey(.automations, "pauseForFullScreenVideo", default: true)
    /// Any full-screen window, documents and games included.
    public static let pauseForAllFullScreen = SettingKey(.automations, "pauseForAllFullScreen", default: false)
    public static let pauseInGames = SettingKey(.automations, "pauseInGames", default: false)
    /// Master switch for the list below (the panel's Auto-pause chip toggles it without losing the list).
    public static let pauseForListedApps = SettingKey(.automations, "pauseForListedApps", default: true)
    public static let pausedApps = SettingKey(.automations, "pausedApps", default: PausedAppDefaults.rules)
    public static let schedule = SettingKey(.automations, "schedule", default: ScheduleWindow?.none)
    /// Minutes without input before an OLED display pauses extra brightness. Allowed: 1, 2, 5, 10, 15, 30.
    public static let oledIdleMinutes = SettingKey(.automations, "oledIdleMinutes", default: 5)
    /// "Pause for…" deadline. Written only by BoostEngine (`pause`/`resume`, §4.9).
    public static let pausedUntil = SettingKey(.automations, "pausedUntil", default: Date?.none)
}

/// Default per-app pause list (ARCHITECTURE.md §6.5). Bundle IDs only; the UI shows Finder's names.
public nonisolated enum PausedAppDefaults {
    public static let rules: [PausedAppRule] = [
        PausedAppRule(bundleID: "com.apple.QuickTimePlayerX", mode: .whilePlaying),
        PausedAppRule(bundleID: "com.apple.TV", mode: .whilePlaying),
        PausedAppRule(bundleID: "com.apple.Photos", mode: .whileFrontmost),
        PausedAppRule(bundleID: "com.colliderli.iina", mode: .whilePlaying),
        PausedAppRule(bundleID: "com.firecore.infuse", mode: .whilePlaying),
        PausedAppRule(bundleID: "org.videolan.vlc", mode: .whilePlaying),
        PausedAppRule(bundleID: "com.apple.FinalCut", mode: .whileFrontmost),
        PausedAppRule(bundleID: "com.blackmagic-design.DaVinciResolve", mode: .whileFrontmost),
        PausedAppRule(bundleID: "com.blackmagic-design.DaVinciResolveLite", mode: .whileFrontmost),
        PausedAppRule(bundleID: "com.blackmagic-design.DaVinciResolveAppStore", mode: .whileFrontmost),
        PausedAppRule(bundleID: "tv.plex.desktop", mode: .whilePlaying),
        PausedAppRule(bundleID: "tv.plex.htpc", mode: .whilePlaying),
    ]
}

public nonisolated enum ShortcutSettings {
    /// nil value = the user cleared that shortcut; a missing key = the catalog default.
    public static let bindings = SettingKey(.shortcuts, "bindings", default: [ShortcutID: KeyCombo?]())
    public static let stepSize = SettingKey(.shortcuts, "stepSize", default: StepSize.regular)
}

public nonisolated enum FillLightSettings {
    /// nil = the built-in display, else the main display.
    public static let display = SettingKey(.fillLight, "display", default: DisplayKey?.none)
    /// Points, 16…120.
    public static let width = SettingKey(.fillLight, "width", default: 48.0)
    /// 0 = 6500 K (cool) … 1 = 3000 K (warm).
    public static let warmth = SettingKey(.fillLight, "warmth", default: 0.4)
    /// 0.2…1.
    public static let brightness = SettingKey(.fillLight, "brightness", default: 0.8)
    public static let autoWithCamera = SettingKey(.fillLight, "autoWithCamera", default: false)
    public static let cameraFilter = SettingKey(.fillLight, "cameraFilter", default: CameraFilter.anyCamera)
}

public nonisolated enum AdvancedSettings {
    public static let detailedLogging = SettingKey(.advanced, "detailedLogging", default: false)
    /// Conflict catalogue entry IDs the user always continues with (S2/S3 only; ARCHITECTURE.md §7.2).
    public static let alwaysContinue = SettingKey(.advanced, "alwaysContinue", default: Set<String>())
}

public nonisolated enum OnboardingSettings {
    public static let completedVersion = SettingKey(.onboarding, "completedVersion", default: String?.none)
    /// The one-time "Check that it works" calibration tip after the first boost (DESIGN.md §8).
    public static let calibrationTipShown = SettingKey(.onboarding, "calibrationTipShown", default: false)
    /// The app version for which the "icon isn't visible" window was last shown (DESIGN.md §4.4).
    public static let hiddenIconNoticeVersion = SettingKey(.onboarding, "hiddenIconNoticeVersion", default: String?.none)
    /// "Not Now" in the move-to-Applications alert (DESIGN.md §12.4); asked again after an update.
    public static let declinedMoveVersion = SettingKey(.onboarding, "declinedMoveVersion", default: String?.none)
}

public nonisolated enum UpdateSettings {
    public static let automatic = SettingKey(.updates, "automatic", default: false)
    public static let prereleases = SettingKey(.updates, "prereleases", default: false)
    public static let lastCheck = SettingKey(.updates, "lastCheck", default: Date?.none)
}

/// Records, not preferences: excluded from Reset All.
public nonisolated enum EngineRecords {
    /// Diagnostic marker written while any display is scaled or dimmed (D7). Present at launch + every table
    /// `matchesBase` means "we died and WindowServer restored"; present + a `scaled` table means "run the rescue".
    public static let boostMarker = SettingKey(.engine, "boostMarker", default: BoostMarker?.none)
}

public nonisolated struct BoostMarker: Hashable, Codable, Sendable {
    public var since: Date
    public var displays: [DisplayKey]
    public var maxFactor: Double
    public init(since: Date, displays: [DisplayKey], maxFactor: Double) {
        self.since = since; self.displays = displays; self.maxFactor = maxFactor
    }
}
```

**The store** is Cranny's file with the renames, typechecked as such for this document. Its API, which every package codes against: `settings[Key]` (get and set; setting the default removes the stored value), `isDefault(_:)`, `reset(_:)`, `reset(namespace:)`, `resetAll()`, `snapshot()` / `restore(_:)` (the Undo of Reset All). It is **not** `@Observable`; each key has its own observable box, so a view or `observe` closure that reads `settings[K]` is invalidated by that key only. `binding(_:)` for SwiftUI controls lives in Design (`SettingsStore+Binding.swift`), so Core imports no SwiftUI.

```swift
// OverbrightCore/Settings/SettingsStore.swift — ported from Cranny's CrannyCore/Settings/SettingsStore.swift
// (the owner's MIT code): "cranny." → "overbright.", ModuleID → SettingsNamespace. One change: `binding(_:)` moved to
// OverbrightDesign (`SettingsStore+Binding.swift`) so Core imports no SwiftUI (D23).
import Foundation
import Observation
import os

/// One observable box per key, so a view reading `settings[DisplaySettings.linkLevels]` is invalidated
/// only by that key (fine-grained Observation; no global "settings changed" storms).
@MainActor @Observable final class SettingBox<Value: Codable & Sendable & Equatable> {
    var value: Value
    init(_ value: Value) { self.value = value }
}

/// Typed, namespaced, observable settings (`services.settings`): reading a key inside a SwiftUI body or `observe`
/// tracks that key only. The store itself is NOT `@Observable`; each key's box is.
@MainActor public final class SettingsStore {
    /// Prefix of every stored key ("overbright.displays.linkLevels").
    public static let keyPrefix = "overbright."
    /// The store's `UserDefaults` (internal: the one-time upgrades in SettingsUpgrades.swift read it directly).
    let defaults: UserDefaults
    private var boxes: [String: AnyObject] = [:]
    private var reloadHandlers: [String: @MainActor () -> Void] = [:]
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    /// The app passes the shell's choice (`ShellDefaults`); tests and previews pass `InMemoryDefaults()`.
    public init(defaults: UserDefaults) { self.defaults = defaults }

    /// The value of `key`; setting the default removes it from disk.
    public subscript<V>(key: SettingKey<V>) -> V {
        get { box(key).value }
        set {
            let b = box(key)
            guard b.value != newValue else { return }
            b.value = newValue
            if newValue == key.defaultValue {
                defaults.removeObject(forKey: Self.keyPrefix + key.id)
            } else if let data = try? encoder.encode(newValue) {
                defaults.set(data, forKey: Self.keyPrefix + key.id)
            }
        }
    }

    /// Drives the "changed from default" dot and per-row "Reset to Default".
    public func isDefault<V>(_ key: SettingKey<V>) -> Bool { self[key] == key.defaultValue }
    /// Restores the default of one key.
    public func reset<V>(_ key: SettingKey<V>) { self[key] = key.defaultValue }
    /// "Reset ‹Pane›…": every key of a namespace.
    public func reset(namespace: SettingsNamespace) { reset(prefix: Self.keyPrefix + namespace.rawValue + ".") }
    /// "Reset All Settings…" (EngineRecords are restored by the caller: they are records, not settings).
    public func resetAll() { reset(prefix: Self.keyPrefix) }

    /// Opaque copy of every persisted key: taken before "Reset All" so Undo can restore it.
    public nonisolated struct Snapshot: Sendable { fileprivate let values: [String: Data] }
    public func snapshot() -> Snapshot {
        var values: [String: Data] = [:]
        for (key, value) in defaults.dictionaryRepresentation() where key.hasPrefix(Self.keyPrefix) {
            if let data = value as? Data { values[key] = data }
        }
        return Snapshot(values: values)
    }
    /// Replaces every key with `snapshot` and updates the live values (Undo of "Reset All").
    public func restore(_ snapshot: Snapshot) {
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix(Self.keyPrefix) && key != Self.revisionKey {
            defaults.removeObject(forKey: key)
        }
        for (key, data) in snapshot.values { defaults.set(data, forKey: key) }
        for handler in reloadHandlers.values { handler() }
    }

    private func reset(prefix: String) {
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix(prefix) && key != Self.revisionKey {
            defaults.removeObject(forKey: key)
        }
        for (id, handler) in reloadHandlers where (Self.keyPrefix + id).hasPrefix(prefix) { handler() }
    }

    private func box<V>(_ key: SettingKey<V>) -> SettingBox<V> {
        if let b = boxes[key.id] as? SettingBox<V> { return b }
        let b = SettingBox(load(key))
        boxes[key.id] = b
        reloadHandlers[key.id] = { [weak self, weak b] in
            guard let self, let b else { return }
            let v = self.load(key)
            if b.value != v { b.value = v }
        }
        return b
    }

    /// The persisted value, or the default (undecodable data is logged and ignored).
    private func load<V>(_ key: SettingKey<V>) -> V {
        guard let data = defaults.data(forKey: Self.keyPrefix + key.id) else { return key.defaultValue }
        if let v = try? decoder.decode(V.self, from: data) { return v }
        Log.logger(.settings).error("undecodable value for \(key.id, privacy: .public); using default")
        return key.defaultValue
    }
}
```

As built (energy, E7): `SettingBox` is observable by hand, with its key path made once per box, instead of `@Observable`. The macro's accessors evaluate `\.value` on every access, and in a generic class that instantiates the key path each time (its generic argument demangled, `swift_getTypeByMangledName`): ≈ 750 ns per read against ≈ 25 ns, ≈ 75 ns while tracked (`-O` micro-benchmark, M4 Max). That, not the conditional cast `as? SettingBox<V>` (a typed lookup measured within 2 %), was the settings getter's cost in every view body (78 of 1 411 busy samples in the panel drag, R-runtime-baseline C6). Observation stays per key, and writing the value a box holds notifies nobody, as the macro's setter does for an `Equatable` value (`aBoxObservesOnlyItsKey`).
As built (energy, E6): `setDeferringWrite(_:_:)` sets a key for every reader and observer at once, exactly as the subscript, but owes its `defaults` write (a JSON encode and a cfprefsd message) until `writeDeferred()`; a plain write of the key writes at once and settles what was owed, and a reset or Undo drops it. Only the engine uses it, for levels (§4.9).

**Defaults at a glance** (the Settings rows that edit them are in DESIGN.md §7):

| Key | Default | Range / values | Read by |
|---|---|---|---|
| `general.launchBehavior` | `launchOnly` | launchAndEnable / launchOnly / dontLaunch | Shell (login item), Boost (start state) |
| `general.showsMenuBarIcon` | true | — | Shell |
| `general.clickAction` | `openPanel` | openPanel / toggle | Shell |
| `general.showsHUD` | true | — | Shell (HUD) |
| `general.haptics` | true | — | Design (slider detent) |
| `general.showsDockIcon` | false | — | Shell (activation policy, Dock menu) |
| `displays.perDisplay[key].boostEnabled` | nil → class default | built-in XDR, Apple XDR on; other HDR and OLED externals off; gates the boost half only | Policy |
| `displays.perDisplay[key].level` | 0.5 (Bright room) | −1 … 1 | Policy |
| `displays.perDisplay[key].capMode` | `safe` | safe / peak | Policy |
| `displays.perDisplay[key].mechanism` | `automatic` | automatic / table / overlay | Policy, Boost |
| `displays.perDisplay[key].calibration` | nil | `CalibrationRecord` (the domain is derived from it, §5.2) | Policy |
| `displays.perDisplay[key].triggerOverride` | nil | any `TriggerStrategy` (Advanced) | Boost |
| `displays.perDisplay[key].oled` | `automatic` | automatic / oled / notOLED | Policy |
| `displays.linkLevels` | false | — | Policy, UI |
| `displays.linkedLevel` | 0.5 | −1 … 1 | Policy |
| `displays.lastDimLight` | 0.25 (light) | 0.02 … 0.99 | Boost (Dim All, Dim shortcut, menu "Dimmed") |
| `displays.boostOnlyNearFullBrightness` | true | — | Boost (taper, §5.4) |
| `automations.batteryGuard` | `belowThreshold` | belowThreshold / onlyOnAdapter / off | Policy |
| `automations.batteryThreshold` | 20 | 5 … 95 step 5 | Policy |
| `automations.pauseInLowPowerMode` | true | — | Policy |
| `automations.autoOffMinutes` | nil (never) | 5 / 10 / 15 / 20 / 30 / 45 / 60 / 90 / 120 | Boost (deadline) |
| `automations.pauseForFullScreenVideo` | true | — (beta until H-P1) | Policy, Signals |
| `automations.pauseForAllFullScreen` | false | — | Policy, Signals |
| `automations.pauseInGames` | false | — | Policy |
| `automations.pauseForListedApps` | true | — (the panel's Auto-pause chip) | Policy |
| `automations.pausedApps` | 12 rules (QuickTime Player, TV, Photos, IINA, Infuse, VLC, Final Cut Pro, DaVinci Resolve ×3, Plex ×2) | add / remove / mode | Policy |
| `automations.schedule` | nil | start/end minute | Policy, Signals (boundary timer) |
| `automations.oledIdleMinutes` | 5 | 1 / 2 / 5 / 10 / 15 / 30 | Signals |
| `automations.pausedUntil` | nil | Date | Policy (written only by BoostEngine) |
| `shortcuts.bindings` | catalog defaults (§3.7) | any `KeyCombo` or cleared | HotKeys |
| `shortcuts.stepSize` | `regular` (¼ stop) | regular / fine (1/12 stop) | Boost |
| `fillLight.display` | nil (built-in, else main) | any display key | FillLight |
| `fillLight.width` | 48 pt | 16 … 120 | FillLight |
| `fillLight.warmth` | 0.4 (≈ 5 100 K) | 0 (6 500 K) … 1 (3 000 K) | FillLight |
| `fillLight.brightness` | 0.8 | 0.2 … 1 | FillLight |
| `fillLight.autoWithCamera` | false | — | FillLight |
| `fillLight.cameraFilter` | `anyCamera` | anyCamera / builtInAndUSB | Signals, FillLight |
| `advanced.detailedLogging` | false | — | journal |
| `advanced.alwaysContinue` | [] | S2/S3 conflict entry IDs | Policy |
| `onboarding.completedVersion` | nil | version string | Shell |
| `onboarding.calibrationTipShown` / `hiddenIconNoticeVersion` / `declinedMoveVersion` | false / nil / nil | — | Shell, PanelUI |
| `updates.automatic` / `prereleases` / `lastCheck` | false / false / nil | — | Updates |
| `engine.boostMarker` | nil | record, excluded from Reset All | Boost (launch) |

The master on/off state is **not** persisted: every launch starts from `launchBehavior` (on only for `launchAndEnable`), and `--off` wins over it. A deliberate, simple rule: after a restart, nothing boosts unless the user chose it. Stored levels are never reset by turning off or by Back to Standard.

### 3.9 Services hub and fakes

```swift
// OverbrightCore — the services hub, ARCHITECTURE.md §3.9 (replaces Cranny's ModuleRegistry, D23).
import Foundation
import Observation

/// Displays on which Overbright's OWN EDR content is on screen (Fill Light, the Welcome card, the calibration
/// window). Boost treats them as headroom that is already held (§4.3 "pre-held"), never as idle headroom.
@MainActor @Observable public final class OwnEDRSurfaces {
    public private(set) var displays: [DisplayKey: Int] = [:]
    public init() {}
    /// Call when the surface is ordered in on `display`; cancel the token when it is ordered out.
    public func hold(_ display: DisplayKey) -> ObservationToken {
        displays[display, default: 0] += 1
        return ObservationToken { [weak self] in
            guard let self, let n = self.displays[display] else { return }
            self.displays[display] = n > 1 ? n - 1 : nil
        }
    }
    public func isHeld(_ display: DisplayKey) -> Bool { displays[display] != nil }
}

/// Every port, typed as its protocol. Constructing services does no I/O, hardware or network access;
/// `ServiceLifecycle.start()` does. `preview()` (in Fakes/) wires every fake with in-memory settings.
@MainActor @Observable public final class OverbrightServices {
    public let settings: SettingsStore
    public let paths: AppPaths
    public let machine: MachineIdentity
    public let time: any TimeSource
    public let journal: any DiagnosticsJournal
    public let announcer: Announcer
    public let ownEDRSurfaces: OwnEDRSurfaces
    public let displays: any DisplayDirectory
    public let signals: any SystemSignals
    public let boost: any BoostControl
    public let fillLight: any FillLightControl
    public let shortcuts: any ShortcutCenter
    public let updates: any UpdateChecking
    /// Set by the shell after construction (it owns the windows that implement it).
    public var app: (any AppControl)?

    public init(settings: SettingsStore, paths: AppPaths, machine: MachineIdentity, time: any TimeSource,
                journal: any DiagnosticsJournal, announcer: Announcer, ownEDRSurfaces: OwnEDRSurfaces,
                displays: any DisplayDirectory, signals: any SystemSignals, boost: any BoostControl,
                fillLight: any FillLightControl, shortcuts: any ShortcutCenter, updates: any UpdateChecking) {
        self.settings = settings; self.paths = paths; self.machine = machine; self.time = time; self.journal = journal
        self.announcer = announcer; self.ownEDRSurfaces = ownEDRSurfaces; self.displays = displays
        self.signals = signals; self.boost = boost; self.fillLight = fillLight; self.shortcuts = shortcuts
        self.updates = updates
    }
}
```

**Fakes** (`Sources/OverbrightCore/Fakes/`, public, compiled into the app but used only by tests, previews and `--qa-simulate`). Packages may add test-only fakes under their own `Tests/<Target>Tests/Fakes/` (WP4 does, §10.6); fakes every package needs go through the contract lane.

| Fake | Behaviour |
|---|---|
| `FakeGammaPort` | Holds a table and a **profile base** per display behind a lock; records every write with a timestamp; `ignoresWrites` (the models where writes are silently ignored); `clampsReadBack` (both read-back models, D26); `simulateProcessDeath()` restores every display's base as WindowServer would; `simulateOtherWriterDeath()` resets every display to its base (§4.8); `foreignWrite(_:)` simulates another app; `changeBase(_:for:)` simulates a profile, preset or HDR change; `restoreWritesZeros` simulates a failed global restore; `stallNextWrite(until:)` blocks a write to simulate a stuck WindowServer call; `recordLimit` bounds the recorded history (nil in tests; 256 under `--qa-simulate`, WP13). `Sendable`. |
| `ScriptedHeadroom` | Per display: idle H (1.0, 1.2, or **pre-held** e.g. 2.6 from another source that can leave at a scripted time), potential, reference; responds to `FakeTriggerFactory` presents after a scripted delay with a scripted ramp (or never, per strategy); drops on scripted events (lock shield, thermal, brightness keys moving H monotonically). Driven by `ManualTimeSource`. |
| `FakeDisplayDirectory` + `Fixtures` | Fixtures: `builtinXDRLidOpen` (M4 Max, P3-1600, SDR max 600, notch), `builtinXDRPreset600`, `mpg322uxHDROn` (potential 4.6549, frame average 265.05, min 0.0003 nits, PQ), `mpg322uxHDROff`, `proDisplayXDR`, `studioDisplayXDR`, `lcdOnly`, `sidecar`, `hardwareMirror` (a projector mirroring the built-in), `neoIgnoresWrites` (Mac17,5 on 26.3), `calibratedProfile` (a non-identity `vcgt` base), `russianNames` (the same displays with ru-RU names). |
| `FakeTriggerFactory` | Records requests, placements and presents; couples to `ScriptedHeadroom`; can fail per strategy; can move a window to another screen (`onScreenChange`); reports `openWindowCount`; `recordLimit` as `FakeGammaPort`'s (removed handles and their records only). |
| `ManualTimeSource` | `advance(by:)` releases sleepers whose deadlines passed, in order; no real sleeping in tests. |
| `FakeSystemSignals`, `FakeConflictProbe` | Settable snapshot; `emit(_:)` for events (delivered synchronously, like the real one, §4.1); scripted launch/terminate sequences; records `setFocusDirective` and `refreshPowerNow` calls. |
| `PreviewBoostControl`, `PreviewFillLightControl`, `PreviewShortcutCenter`, `PreviewUpdateChecking`, `PreviewAppControl` | In-memory state and recorded calls. The named panel states of DESIGN.md §5.13 are WP10's `ScriptedStatuses` (in PanelUI), which drive `PreviewBoostControl`. |

`OverbrightServices.preview(fixture:)` wires every fake with `InMemoryDefaults` and temporary paths. The Cranny test `registersEveryContributionWithoutSideEffects` becomes **`constructingServicesTouchesNoHardware`**: the composition root is built with fakes that fail on any call before `start()`.

### 3.10 Policy API (`OverbrightPolicy`)

WP0a ships these signatures; the small math bodies are real (they are what the engine and its tests need from day one), the rest are stubs that WP1 implements. Boost never calls `BoostPolicy.reduce` directly: `BoostEngine` takes the reducer as an injected function (§4.1), so WP4's tests run against TestSupport's reference reducer before WP1 lands.

```swift
// OverbrightPolicy — pure decisions (nonisolated, Foundation + Core only). ARCHITECTURE.md §3.10, §5, §6.
// WP0a ships the small math bodies below as written (FactorMath, LevelMapping, StepMath, PresetVisibility,
// GainCeiling.liveCap, TransferDomainResolver, CompatibilityModels) and stubs for the rest; WP1 implements the stubs.
import Foundation
import OverbrightCore

/// Light ↔ table-factor conversion per transfer domain (D5, §5.2). A plain multiply of the baseline is correct under
/// every domain; only the factor chosen for a wanted light gain differs.
public nonisolated enum FactorMath {
    /// sRGB encode, extended above 1 (`1.055·g^(1/2.4) − 0.055`).
    public static func encodeSRGB(_ g: Double) -> Double {
        g <= 0.0031308 ? 12.92 * g : 1.055 * pow(g, 1 / 2.4) - 0.055
    }
    public static func decodeSRGB(_ f: Double) -> Double {
        f <= 0.04045 ? f / 12.92 : pow((f + 0.055) / 1.055, 2.4)
    }
    /// Above white, `.encoded` uses this pure power: `F^k ≤ G` for every truth exponent k ≤ 2.4 (incl. the sRGB curve).
    public static let boostExponent = 2.4
    /// The table (or overlay) factor that yields light gain `g` on this display.
    public static func tableFactor(forLightGain g: Double, domain: TransferDomain) -> Double {
        switch domain {
        case .encoded: g <= 1 ? encodeSRGB(g) : pow(g, 1 / boostExponent)
        case .linear: g
        }
    }
    public static func lightGain(forTableFactor f: Double, domain: TransferDomain) -> Double {
        switch domain {
        case .encoded: f <= 1 ? decodeSRGB(f) : pow(f, boostExponent)
        case .linear: f
        }
    }
    /// Writes target at most `headroomMargin × H` …
    public static let headroomMargin = 0.97
    /// … and an applied gain is lowered only when it exceeds `lowerThreshold × H` (≈ 1 % dead band, §5.7).
    public static let lowerThreshold = 0.98
}

/// The slider (D11, §5.3). Boost half linear in stops of `top`; dim half stops = log₂(50) · |p|^2.5.
public nonisolated enum LevelMapping {
    /// Darkest dim level: 2 % of the current SDR light (≈ −5.6 stops).
    public static let minimumDimLight = 0.02
    /// Shape of the dim half: the first half of its travel covers −1 stop, the second half the remaining −4.6.
    public static let dimCurveExponent = 2.5
    /// Light gain the boost half asks for: `top ^ p` for p in 0…1.
    public static func requestedGain(for level: LevelPosition, top: Double) -> Double {
        level.isBoost ? pow(max(top, 1), level.value) : 1
    }
    /// Light factor the dim half asks for: `0.02 ^ (|p| ^ 2.5)` for p in −1…0.
    public static func dimLight(for level: LevelPosition) -> Double {
        level.isDim ? pow(minimumDimLight, pow(-level.value, dimCurveExponent)) : 1
    }
    public static func position(forDimLight light: Double) -> LevelPosition {
        let l = min(max(light, minimumDimLight), 1)
        return LevelPosition(-pow(log(l) / log(minimumDimLight), 1 / dimCurveExponent))
    }
    public static func position(forGain gain: Double, top: Double) -> LevelPosition {
        guard top > 1.0001, gain > 1 else { return .standard }
        return LevelPosition(log(min(gain, top)) / log(top))
    }
    /// The nearest preset within ±0.02, for readouts and VoiceOver values.
    public static func preset(at level: LevelPosition) -> LevelPreset? {
        LevelPreset.allCases.first { abs($0.position.value - level.value) <= 0.02 }
    }
}

/// Keyboard, scroll and Brighter / Less Bright steps, in stops of light (§5.3).
public nonisolated enum StepMath {
    public static let arrowKeyStops = 1.0 / 12
    /// Property-tested bound for every arrow, scroll and Brighter / Less Bright step (named-stop jumps excluded).
    public static let maximumSingleStepStops = 0.5
    /// Signed stops of light relative to Standard at `level`.
    public static func stops(at level: LevelPosition, top: Double) -> Double {
        if level.isBoost { return log2(LevelMapping.requestedGain(for: level, top: top)) }
        if level.isDim { return log2(LevelMapping.dimLight(for: level)) }
        return 0
    }
    public static func level(atStops s: Double, top: Double) -> LevelPosition {
        if s > 0 { return top > 1.0001 ? LevelPosition(min(s / log2(top), 1)) : .standard }
        if s < 0 { return LevelMapping.position(forDimLight: pow(2, s)) }
        return .standard
    }
    /// One step; a step that would cross Standard stops at Standard first.
    public static func step(from level: LevelPosition, by delta: Double, top: Double) -> LevelPosition {
        let current = stops(at: level, top: top)
        var next = current + delta
        if (current > 0 && next < 0) || (current < 0 && next > 0) { next = 0 }
        return self.level(atStops: next, top: top)
    }
}

/// Which presets a display shows (§5.3): Max always; a lower preset only if its gain is ≥ ×1.1 and it sits ≥ 0.1 stop
/// below the next kept one. Hidden presets are neither drawn nor offered in menus or to VoiceOver.
public nonisolated enum PresetVisibility {
    public static let minimumGain = 1.1
    public static let minimumSpacingStops = 0.1
    public static func visiblePresets(top: Double) -> [LevelPreset] {
        var kept: [LevelPreset] = [.max]
        var lastGain = max(top, 1)
        for preset in [LevelPreset.sunlight, .brightRoom, .indoor] {
            let g = LevelMapping.requestedGain(for: preset.position, top: top)
            if g >= minimumGain && log2(lastGain / g) >= minimumSpacingStops {
                kept.insert(preset, at: 0); lastGain = g
            }
        }
        return kept
    }
}

/// Ceilings per display. Static ones in the reducer; live ones (`liveCap`) at write time in Boost's TableWriter.
public nonisolated enum GainCeiling {
    public static let safeNitsAppleXDR = 1000.0
    public static let safeGainOLED = 1.3
    public static let thermalSeriousGain = 1.2
    /// How Safe is bounded without a trusted SDR white (§5.4). WP16 may switch to `.sliderTopOnly` after H-G1.
    public enum SafeBound: Sendable { case worstCaseGrant, sliderTopOnly }
    public static let safeBound = SafeBound.worstCaseGrant
    /// Taper of "Add extra brightness only near full brightness": full gain while H ≤ 1.15 × the full-brightness
    /// headroom, none at ≥ 2 × (system brightness about halved). Tuned in WP16 (H-B1).
    public static let taperStart = 1.15
    public static let taperEnd = 2.0

    /// Safe nits for the class (nil for OLED, whose Safe cap is the relative ×1.3).
    public static func capNits(facts: DisplayFacts, isOLED: Bool) -> Double? {
        if isOLED { return nil }
        switch facts.panelClass {
        case .builtInXDR, .appleXDRExternal: return safeNitsAppleXDR
        case .hdrExternal: return facts.panelPeakNits.map { min(safeNitsAppleXDR, 0.6 * $0) }
        default: return nil
        }
    }
    /// As built (WP1): the highest SDR white the user can pick without ambient boost (`sdrMax`, §5.1): the facts' value
    /// (the built-in's IORegistry value, an Apple XDR external's product value), else `frameAverageSDRWhite`.
    public static func sdrMaxNits(facts: DisplayFacts) -> Double? {
        let value = facts.sdrMaxNits ?? frameAverageSDRWhite(facts: facts)
        return value.flatMap { $0 > 0 ? $0 : nil }
    }
    /// As built (WP14): an external's frame-average luminance as its HDR-mode SDR white (§5.5); never on a built-in or
    /// an Apple XDR external, whose `MaxFrameAverage` is the full-screen sustained HDR level. Boost's `SDRWhiteSource`
    /// uses the same rule.
    public static func frameAverageSDRWhite(facts: DisplayFacts) -> Double? {
        guard !facts.isBuiltIn, facts.panelClass != .appleXDRExternal, let nits = facts.panelFrameAverageNits,
              nits > 0 else { return nil }
        return nits
    }
    /// The gain at the top of the boost half for this display and cap mode, at full SDR brightness (§5.3 table).
    /// Below 1.05 the boost half is disabled for that cap mode.
    public static func sliderTop(facts: DisplayFacts, capMode: CapMode, isOLED: Bool) -> Double {
        _ = (facts, capMode, isOLED)
        return 1   // WP1
    }
    /// Seed of the full-brightness headroom (`panelPeak ÷ sdrMax`); Boost replaces it with the lowest ready H seen.
    public static func fullBrightnessHeadroomSeed(facts: DisplayFacts) -> Double? {
        guard let peak = facts.panelPeakNits, let sdr = facts.sdrMaxNits, sdr > 0 else { return nil }
        return peak / sdr
    }
    /// Exponent applied to the static gain by the taper: 1 near full brightness, 0 at about half brightness.
    public static func taperExponent(headroom: Double, fullBrightnessHeadroom: Double) -> Double {
        let r = headroom / max(fullBrightnessHeadroom, 1)
        return min(max((taperEnd - r) / (taperEnd - taperStart), 0), 1)
    }

    public struct LiveCap: Hashable, Sendable {
        public var gain: Double
        /// The live term that bound, if any (`nearFullBrightnessOnly`, `safeLimit` or `headroom`).
        public var reason: LimitReason?
    }
    /// The ONE function behind the interlock (§5.4): taper, the live Safe bound and 0.97 × H, in that order.
    public static func liveCap(staticGain: Double, reading: HeadroomReading, facts: DisplayFacts, capMode: CapMode,
                               isOLED: Bool, sdrWhite: SDRWhiteEstimate?, taper: Bool,
                               fullBrightnessHeadroom: Double?) -> LiveCap {
        let h = reading.current
        var g = staticGain
        var reason: LimitReason?
        if taper, let ref = fullBrightnessHeadroom {
            let tapered = pow(g, taperExponent(headroom: h, fullBrightnessHeadroom: ref))
            if tapered < g { g = tapered; reason = .nearFullBrightnessOnly }
        }
        if capMode == .safe, sdrWhite == nil, safeBound == .worstCaseGrant,
           let cap = capNits(facts: facts, isOLED: isOLED), let peak = facts.panelPeakNits, peak > 0 {
            let bound = cap * h / peak          // sdrNow = grant ÷ H ≤ panelPeak ÷ H, so light ≤ cap
            if bound < g { g = bound; reason = .safeLimit }
        }
        let margin = FactorMath.headroomMargin * h
        if margin < g { g = margin; reason = .headroom }
        return LiveCap(gain: max(g, 1), reason: reason)
    }
}

/// The domain actually used (§5.2): `.linear` only from a confirmed, still-valid record; else `.encoded`.
public nonisolated enum TransferDomainResolver {
    public static func effectiveDomain(_ record: CalibrationRecord?, mechanism: Mechanism, machine: MachineIdentity,
                                       potential: Double?) -> TransferDomain {
        guard let r = record, r.outcome == .linear, r.mechanism == mechanism, r.osBuild == machine.osBuild,
              let p = potential, abs(p - r.potentialAtTest) <= 0.05 * r.potentialAtTest else { return .encoded }
        return .linear
    }
}

/// Macs where table writes succeed, read back correctly and change nothing on screen (§7.5). Updatable list.
public nonisolated enum CompatibilityModels {
    public static let models: Set<String> = ["Mac17,5", "Mac17,6", "Mac17,7", "Mac17,8", "Mac17,9"]
    public static func tableWritesIgnored(_ machine: MachineIdentity) -> Bool {
        models.contains(machine.model) && (machine.osMajor, machine.osMinor) >= (26, 3)
    }
}

/// D26: classifies a read table against the display's expected (profile) base. Never uses the table maximum.
/// `.scaled` = a uniform ratio ≥ 1.02 or ≤ 0.98 at sub-1 sample indices on all channels, or a plateau of ≥ 2 entries
/// ≥ 0.9995 before the last index where the base has none; `.invalid` = not monotonic or all ≈ 0; else `.foreign`.
public nonisolated enum TableClassifier {
    public static func classify(_ read: GammaTable, expectedBase: GammaTable) -> TableClass {
        _ = (read, expectedBase)
        return .matchesBase   // WP1
    }
    /// Post-restore check (§7.4): monotonic, first entry ≤ 0.1 and last ≥ 0.9, or `matchesBase`.
    public static func isPlausibleRestore(_ read: GammaTable, expectedBase: GammaTable) -> Bool {
        _ = (read, expectedBase)
        return true   // WP1
    }
}

/// D8 classifier: tolerant comparisons, no name strings in logic, IORegistry inputs optional. `preferences` carries
/// the OLED override and the calibration record; `machine` decides `compatibilityModeAdvised`.
public nonisolated enum EligibilityClassifier {
    public static func classify(_ facts: DisplayFacts, preferences: DisplayPreferences, reading: HeadroomReading?,
                                machine: MachineIdentity) -> EligibilityResult {
        _ = (facts, preferences, reading, machine)
        return EligibilityResult(verdict: .checking, advisories: [], defaultBoostEnabled: false, defaultMechanism: .table)
    }
}

/// D10: the pure guard reducer. Exhaustively tested; no clocks, no I/O, no randomness.
public nonisolated enum BoostPolicy {
    public static func reduce(_ input: PolicyInput) -> PolicyDecision {
        _ = input
        return PolicyDecision(displays: [:], banner: nil, symbol: .off)   // WP0a stub: everything neutral
    }
}

/// Pure numbers behind a card's readout; Design formats them (DESIGN.md §5.6).
public nonisolated struct ReadoutValues: Hashable, Sendable {
    public enum State: Hashable, Sendable { case off, standard, preparing, boost, dim }
    public var state: State
    public var appliedGain: Double
    /// Set when the applied gain is below the request ("×1.21 · asked ×1.47").
    public var requestedGain: Double?
    /// Only with a trusted SDR white AND a valid calibration record for the current mechanism.
    public var nits: Double?
    public var preset: LevelPreset?
    /// No valid calibration: the multiplier is shown as an estimate ("≈ ×1.29").
    public var isEstimate: Bool
    /// Dim light as a percentage of Standard (2…99).
    public var dimPercent: Int?
    public init(state: State, appliedGain: Double, requestedGain: Double?, nits: Double?, preset: LevelPreset?,
                isEstimate: Bool, dimPercent: Int?) {
        self.state = state; self.appliedGain = appliedGain; self.requestedGain = requestedGain; self.nits = nits
        self.preset = preset; self.isEstimate = isEstimate; self.dimPercent = dimPercent
    }
}

public nonisolated enum Readout {
    public static func values(for status: DisplayStatus, isMasterOn: Bool) -> ReadoutValues {
        _ = (status, isMasterOn)
        return ReadoutValues(state: .off, appliedGain: 1, requestedGain: nil, nits: nil, preset: nil, isEstimate: true,
                             dimPercent: nil)   // WP1
    }
}

/// Conflict matcher (ARCHITECTURE.md §7.2): exact bundle ID (+ "-setapp" twin), vendor prefix, executable name, optional team ID.
public nonisolated enum ConflictMatcher {
    public struct RunningApp: Hashable, Sendable {
        public var bundleID: String?
        public var executableName: String?
        public var teamID: String?
        public var processID: Int32
        public var localizedName: String
        public init(bundleID: String?, executableName: String?, teamID: String?, processID: Int32, localizedName: String) {
            self.bundleID = bundleID; self.executableName = executableName; self.teamID = teamID
            self.processID = processID; self.localizedName = localizedName
        }
    }
    public static func match(_ app: RunningApp, in catalog: [ConflictCatalogEntry], ownBundleID: String)
        -> ConflictingApp? {
        _ = (app, catalog, ownBundleID)
        return nil   // WP1
    }
}
```

### 3.11 Who talks to whom

| From → to | Through |
|---|---|
| UI (Panel, Settings, Onboarding, HUD, Help) → engine | `BoostControl`, `FillLightControl`, `ShortcutCenter`, `UpdateChecking`, `AppControl` (all on `OverbrightServices`), `SettingsStore` keys |
| UI → math, verdicts and copy | `OverbrightPolicy` (pure numbers: `ReadoutValues`, `PresetVisibility`, `StepMath`) → `OverbrightDesign` (strings and view models) |
| Boost → displays | `GammaPort` (incl. `profileBase`), `HeadroomPort`, `DisplayDirectory` |
| Boost → triggers | `TriggerFactory` |
| Boost → system | `SystemSignals`, `ConflictProbe`, `TimeSource`, `OwnEDRSurfaces` |
| Boost → decisions | the injected reducer (`BoostPolicy.reduce` in the app), `GainCeiling.liveCap`, `LevelMapping`, `StepMath`, `FactorMath`, `TableClassifier`, `TransferDomainResolver` |
| FillLight → system | `SystemSignals` (camera), `HeadroomPort`, `DisplayDirectory`, `OwnEDRSurfaces` (registers its windows) |
| Intents (package) → engine | `IntentRouter`, created empty in `OverbrightApp.init`, registered with `AppDependencyManager`, connected by `CompositionRoot` (`connect(boost:displays:signals:)`); calls wait for `BoostStatus.isReady` (≤ 5 s) |
| Focus filter → Signals | `IntentRouter.focus(_:)` → `SystemSignals.setFocusDirective(_:)` |
| App/Intents (app target) → router | `@Dependency var router: IntentRouter` (macOS 13+) |
| Engine → HUD | `BoostStatus.lastChange` (the shell's `HUDController` observes its `sequence`) |
| Shell → everything | `CompositionRoot` (the only place that knows concrete types) |
| Anything → journal | `DiagnosticsJournal.record` |
| Controls extension → app | `OverbrightChannel`: notifyd state word + preferences snapshot (read) and `overbright://` URL (write), D25 |

---

## 4. The per-display engine (`OverbrightBoost`)

### 4.1 Structure

| Type (Boost, internal unless noted) | File (owner) | Isolation | Job |
|---|---|---|---|
| `BoostEngine` (public; implements `BoostControl`, `ServiceLifecycle`) | `Engine/BoostEngine.swift` (WP4) | MainActor | Master state; the pause deadline (the only writer of `automations.pausedUntil`) and auto-off deadline; linked levels; Dim All; the low-level confirmation; the policy loop over an **injected reducer** `reduce: (PolicyInput) -> PolicyDecision` (default `BoostPolicy.reduce`); one `DisplayController` per online display; synchronous shield delivery; status publication including `lastChange` for the HUD; self-test, calibration and rescue entry points (through the WP5 seams). |
| `DisplayController` | `Engine/` (WP4) | MainActor | The state machine of §4.3 for one display: trigger or overlay handle, baseline, expected base, applied factor, generation, epoch stamp, its tasks (gate poll, poll burst, ramp, drift check). |
| `TableWriter` | `Writer/TableWriter.swift` (seeded by WP0a, body WP4) | nonisolated final class, `Sendable` | **The interlock (§5.4).** The only code that turns a light gain into a table and calls `GammaPort.write`, on three paths: `write(_:to:reading:epoch:)` (main; enforces `GainCeiling.liveCap`, reading age ≤ 150 ms, reading of the same display, current epoch), `writeCalibrationFactor(_:of:to:reading:maxFactor:epoch:)` (as built, WP14: the session's bound and the reading's calibration ceiling instead of `liveCap`, which the sweep must pass; reading age and display, the current epoch, the ledger marked in the same critical section, §5.2), and the nonisolated `writeBaselines(fromLedger:)` used by the hang watchdog and the signal queue. |
| `SafetyLedger` | `Writer/SafetyLedger.swift` (seeded by WP0a, body WP4) | nonisolated final class, `NSLock`, `Sendable` | Per display: CG ID, captured baseline, "scaled or dimmed" flag; plus `hangEpoch`. `TableWriter` holds the lock across every write, so a write already in flight always lands before the watchdog's baseline; an `NSLock` (not an unfair lock) because the lock is held across a WindowServer call. |
| `HangWatchdog` | `Safety/HangWatchdog.swift` (seeded by WP0a, body WP5) | **nonisolated final class** with its own utility queue | Ping-pong with the main thread every 2 s, on the shared 2 s grid (D29), while any display is scaled (as built, WP14: while the safety ledger holds any display, switched by the ledger itself, `SafetyLedger.observeOccupancy`); if a ping goes unanswered for 3 s, under the ledger lock it increments `hangEpoch` and writes every ledger baseline through `TableWriter.writeBaselines(fromLedger:)` (§7.4). |
| `SignalHandlers` | `Safety/SignalHandlers.swift` (WP5) | nonisolated, dedicated serial queue | TERM/INT/HUP: ledger baselines, then the main-actor stop with a 1 s timeout, then exit (§7.4). |
| `LadderPlanner` | `Ladder/` (WP4) | nonisolated, pure | The rung list for a display (OS, class, cache, override, backoff) — §4.7. |
| `StrategyCache` | `Ladder/` (WP4) | MainActor, `JSONDocumentFile` in Caches | Per display UUID + `kern.osversion`: winning rung, failure record, lowest ready headroom (the full-brightness headroom of §5.4). |
| `RampPlanner`, `FlickerGuard`, `DriftCheck`, `GateEvaluator` | `Engine/` (WP4) | nonisolated, pure (`FlickerGuard` takes instants and readings as input) | Ramps (§5.7), rate limiter and oscillation detector (§5.8), read-back classification (§4.8), gate rules incl. the pre-held path (§4.4). Exhaustively unit-tested. |
| `LaunchRescue` | `Safety/LaunchRescue.swift` (seeded, body WP5) | MainActor | Launch check and dirty-then-restore with verification (§7.4). |
| `SelfTestRunner`, `CalibrationController` (implements `CalibrationSession`) | `SelfTest/`, `Calibration/` (seeded, bodies WP5) | MainActor | §8.4 and DESIGN.md §9–§10. Both drive a `DisplayController` through `DisplayControllerDriving`; neither writes tables except through `TableWriter`. |

`BoostEngine` builds a `PolicyInput` from settings, `SystemSignals.snapshot`, `DisplayDirectory.displays`, `MachineIdentity`, each display's trusted SDR white and each controller's feedback, calls the injected reducer, and hands each controller its `DisplayDecision`. **Shield and safety events first:** `locked`, `screensaverStarted`, `willSleep`, `screensDidSleep`, `sessionResigned`, `displayRemoved` and `displayConfigurationBegan` are delivered to every controller **synchronously inside the event handler** (each writes its baseline, or sets its overlay to factor 1, before the handler returns); only then is the coalesced re-reduction scheduled. Re-reduction is coalesced to one per run-loop turn (a screen-parameters notification's to one per 100 ms, `screenParametersReduceInterval`; its headroom check is synchronous). It is triggered by settings observation, the signals snapshot, directory generation, `OwnEDRSurfaces`, controller feedback and deadlines (pause end, auto-off, schedule boundary, low-level confirmation), never by polling.

As built (energy, E1): `publish()` assigns `status` only when it differs, and every assignment re-arms every observer of `status` (the status item, the HUD, the prompt, the panel), so an event that changes nothing visible must not change it. Each `DisplayStatus.lastReading` is therefore a stable copy (`DisplayController.stableReading()`): it is replaced only when the display changes or `current`, `potential` or `reference` moves by ≥ 0.0005, never for the reading's timestamp alone. The controller's own `lastReading`, `feedbackReading()` (what the reducer sees) and every reading handed to `TableWriter` stay fresh; nothing in the engine reads `status` (§4.5 invariant 1 uses the ≤ 150 ms reading the writer is handed). `.appLaunched` returns early from `handle` like a termination that ends no continuation: no publish and no reduction, because a conflicting app reaches the reducer through the observed snapshot, which Signals updates before it posts the event (`aLaunchedBoosterStillSuspendsABoostedDisplayThroughTheSnapshot`, `StatusPublicationTests`).

As built (energy, E3): DESIGN.md §17's "allowed-now marker ≤ 4 Hz". `publish()` compares the next status with the published one (`BoostEngine+Publication.swift`): when only minor fields differ (each display's reading and the grant learned from readings, `lastGrant`, and, while a display is `ramping` or `disarming`, its applied gain and factor) it arms one trailing `TimeSource.sleep` of `minorPublishInterval` (250 ms) that publishes whatever changed by then; any major difference (phase, target, decision, symbol, banner, `lastChange`, `pendingLowLevel`, on, ready, pause, auto-off, the display set) publishes at once with the latest minor values and drops the waiting publish. Stopping publishes at once and leaves no task (§4.5 invariant 4 holds once a waiting publish has fired, at most 250 ms after the event that armed it). Nothing in the engine reads `status`, so no decision or safety write waits for it. With headroom moving (one screen-parameters notification per frame, up to 122/s), a boosted display republished on every notification; it now republishes at most 4 times a second (`MinorPublishTests`: 200 → 8 publishes in 2 s). A level change publishes twice (→ ramping with its decision, → boosted with its gain), not per ramp step, so the per-step panel cost of R-api-costs §9 is not the engine's status.

### 4.2 States

| Phase | Table | Trigger / overlay | Work while in it |
|---|---|---|---|
| `idle` | baseline (or untouched if never captured) | none | **none** |
| `dimmed` | baseline × dim factor (< 1) | none (overlay mechanism: overlay at factor < 1, no EDR request) | 2 s drift check |
| `arming(rung)` | baseline | rung shown | H poll 10 Hz; rung timeout 2.5 s |
| `gating(rung)` | baseline | shown | H poll 10 Hz until stable; 12 s timeout |
| `ramping` | moving | shown | ramp steps (≈ 60 Hz for ≤ 400 ms) |
| `boosted` | baseline × F, F > 1 | shown | 2 s drift check + headroom check; a 10 Hz poll burst of ≤ 3 s only while a raise waits for headroom; event re-presents |
| `suspended(cause)` | baseline | kept ≤ 10 s, then removed (`notOnConsole`, `reconfiguring`: removed at once) | none except the linger timer |
| `failed(cause)` | baseline | none | none; §4.3 says which causes retry by themselves |
| `disarming` | ramping down → baseline | removed last | ramp steps |

### 4.3 Transition table

`T` = the policy target for this display. "Write B" = write the captured baseline. "liveCap" = `GainCeiling.liveCap` with a reading taken now (§5.4). Every row that starts async work stamps it with the controller's current generation (§4.6). Nothing writes while the session is not on the console (D27).

| From | Event / condition | Action | To |
|---|---|---|---|
| idle | T = boost(G) | capture the baseline (§4.8); read H0 (3 reads, 100 ms apart, take the max). **Pre-held** when `OwnEDRSurfaces` holds the display, or `H0 ≥ max(1.3, G / 0.97)`, or `H0 ≥ 1.25` and stable over the three reads: arm the cheapest rung (the cached one, else the ladder start) and gate with the absolute rule. Otherwise arm rung n = cached rung or ladder start | gating(n) (pre-held) / arming(n) |
| idle | T = dim(L) | capture the baseline; ramp the table to F(L) | dimmed |
| dimmed | T = boost(G) | as idle → boost (the dim factor ramps back to 1 while arming) | gating / arming |
| dimmed | T = neutral | ramp to 1; write B | idle |
| dimmed | T = dim(L′) | ramp to F(L′) (rate limiter applies) | dimmed |
| arming(n) | first present failed (T2/T3 after 2 s of retries) or factory threw | journal; next rung (not during a wake or unlock backoff, §4.7) | arming(n+1) or failed(headroomNeverArrived) |
| arming(n) | H ≥ H0 + 0.05 (movement) | record rung; keep polling | gating(n) |
| arming(n) | 2.5 s after first successful present without movement | make-before-break: arm rung n+1, then remove rung n | arming(n+1) |
| arming(last) | rung timeout | remove trigger; write B | failed(headroomNeverArrived) |
| arming / gating | macOS suppresses HDR (macOS 26+) | **keep the current rung**; stop escalating (rung timeouts pause); the interlock follows whatever H remains; reason `hdrSuppressedByMacOS` | same |
| arming / gating | potential ≤ 1 + ε | stop escalating; remove trigger; write B | failed (reason from the verdict) |
| gating(n) | ready. Normal: `H ≥ max(1.1, H0 + 0.1)` and stable ±0.05 for 1.5 s. Pre-held: `H ≥ 1.1` and stable ±0.05 for 1.5 s | cache rung n (normal path only); learn the lowest ready H; ramp 1 → F(liveCap) | ramping |
| gating(n) | 12 s since the first movement (pre-held: since arming), not stable | rung failure: next rung (make-before-break) | arming(n+1) / failed |
| ramping | ramp finished | publish applied gain | boosted |
| boosted | T = boost(G′), G′ < applied | ramp down (300 ms) | ramping → boosted |
| boosted | T = boost(G′), G′ > applied, **requested by the user** (slider, preset, step, intent, Focus) | read H now; ramp at once to min(G′, liveCap); if liveCap < G′, start a 10 Hz poll burst (≤ 3 s) and raise again as headroom arrives | ramping → boosted |
| boosted | liveCap rose above applied **by headroom recovery** | raise only if the new target is ≥ 1.05 × applied and H has been stable ±0.05 for 1.5 s (a 10 Hz poll burst while waiting, ≤ 3 s); then ramp up | ramping → boosted |
| boosted | a fresh reading shows `applied > 0.98 × H` (≈ 1 % dead band above the 0.97 target) | **one step** to F(0.97 × H), or to B if H < 1.03 (safety; not rate-limited). Counted by the oscillation detector only if the H readings since the last reversal did not move monotonically (§5.8) | boosted / suspended(occluded) |
| boosted (armed pre-held) | H stays below the needed headroom for 2.5 s with no shield or policy cause (the other source left and our rung does not hold) | the interlock has already lowered; escalate from the current rung with H0 := current H (make-before-break) | arming(n+1) |
| boosted / dimmed | drift check (2 s; or 50 ms after any app terminated) | §4.8: matches → nothing; reset → reapply with a ramp and count a repair; explained base change → adopt and reapply with a ramp; else foreign → count a repair and attribute | same, or failed(repairBudgetExceeded / attributedDrift) |
| boosted | trigger occluded (shield) | write B at once, keep trigger | suspended(occluded) |
| arming / gating / ramping / boosted | `onScreenChange`: AppKit moved the trigger or overlay window to another display | write B (if the display still exists); remove that window at once; wait for the reconfiguration pass | suspended(reconfiguring) |
| any scaled or dimmed | shield event: locked, screensaver, screens asleep, will sleep, session resigned | **synchronously in the handler**: write B | suspended(shielded) |
| any | session not on the console | write B if anything is scaled or dimmed; remove triggers; no writes until `sessionBecameActive` | suspended(notOnConsole) |
| suspended | cause cleared (unlock, screensaver stop, wake + 1 s settle, session active, occlusion → visible) | `represent()`; re-gate from the cached rung (wake and unlock use the backoff rule of §4.7) | gating / arming |
| suspended | 10 s elapsed | remove trigger | suspended (no trigger) |
| boosted / dimmed / ramping | T = neutral (policy, master off, pause, guard) | ramp to 1 (300 ms; Reduce Motion 160 ms) | disarming |
| any | `returnToStandard` (Back to Standard) | ramp to 1 in 120 ms; write B; remove trigger; master off; stored levels kept | idle |
| disarming | ramp finished | write B; **then** remove trigger | idle |
| any | **display removed** (`kCGDisplayRemoveFlag`, handled at once on main, not debounced) | order out its trigger and overlay windows first; drop the controller and its ledger entry (its table went with the display; calls with a removed ID would fail) | — |
| overlay mechanism | configuration began (`kCGDisplayBeginConfigurationFlag`) | overlay factor → 1 at once (no display queries in the begin phase) | same |
| any | reconfiguration after-phase (debounced 0.5 s, confirmed at 2 s) | re-read facts; re-place the trigger; **recompute the expected base and adopt it** whether or not the display is scaled (§4.8), updating the ledger in the same step; reapply (with a ramp) once a read differs from our last write, or after 1 s; re-gate | same / arming |
| any | ColorSync profile change, accessibility display options | the same base recomputation, adoption and ramped reapply | same |
| any | wake or lid open | wait 1 s; re-arm **the cached rung only**, with backoff 1, 3, 10, 30 s while headroom refuses; never escalate during the backoff | arming / failed |
| any | hang watchdog fired | (on recovery) every queued scaled write is refused by the stale epoch; journal `hang.restored`; re-gate, which re-stamps the epoch | suspended(hungMainThread) → gating |
| failed(headroomNeverArrived) | Retry, unlock, wake, reconfiguration, potential change | clear the trip; start over from the cached rung (else the top) | arming |
| failed(oscillation / repairBudgetExceeded / attributedDrift) | **only** Try Again, Continue Anyway, or termination of the attributed app | clear the trip; re-arm | arming |
| failed(foreignTableAtLaunch) | the display classifies `matchesBase` again (checked on reconfiguration and profile events), or Try Again | clear the trip | idle |

The `overlay` mechanism walks the same table with `OverlayHandle` instead of trigger + table: arming shows the overlay at factor 1 with `headroomRequest = G / 0.97`; ramps call `setFactor`; dimming uses `setFactor(< 1)` without any EDR request; the drift check checks headroom only (there is no table to drift). Because it writes no table, it is the one mechanism that may continue next to an S1 booster (§7.2).

### 4.4 Timing and threshold constants (`EngineTiming`, one nonisolated enum, every value named and tested)

| Constant | Value | Source |
|---|---|---|
| `baselineReads` | 3 reads, 100 ms apart, maximum taken | D6 |
| `gatePollInterval` | 100 ms (only while arming, gating or a poll burst) | D6 |
| `movementThreshold` | H0 + 0.05 | trigger study |
| `preHeldThreshold` | `H0 ≥ max(1.3, G / 0.97)`, or `H0 ≥ 1.25` stable over the three reads, or an own EDR surface on the display | D6 |
| `rungTimeout` | 2.5 s after the rung's first successful present | trigger study |
| `firstPresentRetry` | every 50 ms for ≤ 2 s (T2/T3) | trigger study |
| `readyThreshold` | normal `max(1.1, H0 + 0.1)`; pre-held `1.1` | D6 |
| `stabilityBand`, `stabilityWindow` | ±0.05 over 1.5 s | D6 |
| `gateTimeout` | 12 s from the first movement (pre-held: from arming) | D6 |
| `readingMaxAge` | 150 ms (`TimeSource.now − reading.time`) | §5.4 |
| `headroomMargin`, `lowerThreshold` | writes ≤ 0.97 × H; lower when applied > 0.98 × H | D5 |
| `raiseHysteresis` | headroom-recovery raises need ≥ 1.05 × applied gain and 1.5 s stable; user raises none | §5.7 |
| `pollBurst` | 10 Hz for ≤ 3 s while a raise waits for headroom | §5.7 |
| `rampDuration` | 300 ms (user, policy, every reapply); 160 ms (Reduce Motion); 120 ms (Back to Standard); one step (safety) | D5 |
| `minimumOpposingInterval` | 500 ms between opposing transitions | §5.8 |
| `oscillationTrip` | ≥ 4 non-user reversals within 10 s (monotonic headroom tracking excluded) | §5.8 |
| `watchdogInterval` | 2 s, tolerance 0.5 s, only while scaled or dimmed; each tick at the next multiple of 2 s of the time source (as built, energy E4: the shared grid of D29, at most 2 s away) | D9, D29 |
| `appTerminationCheckDelay` | 50 ms after `appTerminated` while scaled or dimmed | §4.8 |
| `driftTolerance` | 0.01 at the sample index; classification needs a separation ≥ 2 × tolerance | §4.8 (refined from 0.03: with 0.03, Indoor's ×1.055 could never be told from ×1; WP16 confirms read-back noise ≤ 0.003) |
| `repairBudget` | 3 repairs in 6 s | D9 |
| `adoptionWindow`, `adoptionBudget` | an adoption counts as a base change only within 2 s of a ColorSync, reconfiguration or accessibility event and after 2 identical reads; > 2 unexplained adoptions in 60 s trip | §4.8 |
| `reapplyWait` | until a read differs from our last write, at most 1 s | §4.8 |
| `triggerLinger` | 10 s in `suspended` | §4.3 |
| `minorPublishInterval` | 250 ms: a status change of minor fields only (readings, `lastGrant`, the applied gain while a ramp runs) is published at most this often, on the trailing edge; any other change at once (as built, energy E3) | DESIGN.md §17 |
| `screenParametersReduceInterval` | 100 ms: the re-reduction a screen-parameters notification asks for runs on the trailing edge, at most once per interval; the headroom check and its safety drop stay synchronous, and any other reduction runs at once (as built, energy E2) | §4.3, D5 |
| `reconfigurationDebounce` | 0.5 s, then a confirming pass at 2 s (display removal: immediate) | D9 |
| `wakeSettle`, `wakeBackoff` | 1 s; 1, 3, 10, 30 s, cached rung only | §4.3 |
| `escalationQuarantine` | 60 s after a wake or unlock: failures do not count against a cached rung | §4.7 |
| `hangPing`, `hangTimeout` | 2 s (the first ping when the ledger fills, every later one at the next 2 s grid point of the engine's time source; while a ping is out, the timer also wakes at the next grid point before its deadline); 3 s after the outstanding ping | D7, D29 |
| `quitTimeout`, `signalStopTimeout` | 1 s; 1 s | D7 |
| `levelPersistDelay` | 500 ms: levels reach UserDefaults this long after the last change (every reader sees them at once), and at once on stop, quit and every turn-off; settings only (as built, energy E6) | §4.9 |
| `lowLevelThreshold`, `lowLevelConfirmTimeout` | 10 % of Standard light; 10 s | §4.9 |
| `pausedAppResumeSettle` | 1 s | D10 |
| `fullScreenDebounce` | 0.6 s (Signals) | D10 |

### 4.5 Invariants (each has at least one test with fakes and a property test where it applies)

1. **Interlock.** A table entry above the baseline is written only through `TableWriter.write`, and only when (a) the reading is of the same display (`reading.display == target`) and at most 150 ms old by `TimeSource`, (b) the controller's epoch stamp equals `SafetyLedger.hangEpoch`, checked under the ledger lock that is held across the write, and (c) `G_applied ≤ GainCeiling.liveCap(…)` (taper, live Safe bound, `0.97 × H`). A stale epoch or a foreign reading refuses the write (`GammaError.writeRefused`); a binding cap clamps to `F(liveCap)` (or the baseline when H < 1.03) and journals `interlock.clamped`.
2. **Order.** Un-scale before removing a trigger or overlay in every path (stop, quit, Back to Standard, suspend, reconfiguration). Display removal is the exception: the display and its table are gone, so its windows are ordered out at once.
3. **Single writer.** Only `CoreGraphicsGamma.swift` calls the CoreGraphics setters (lint). Only `TableWriter` (normal, calibration and `writeBaselines(fromLedger:)` paths) and `LaunchRescue` call `GammaPort.write`; `HangWatchdog` and `SignalHandlers` write only through `TableWriter.writeBaselines(fromLedger:)` (lint test `onlyTableWriterAndRescueWrite`).
4. **Zero work while off.** With the master off and no display dimmed, there is no trigger window, no overlay, no Metal device, no timer and no task in Boost (test: `offMeansNoTasksNoWindows`).
5. **Baselines judged against the profile base (D26).** A baseline is captured or adopted only from a read that `TableClassifier` classifies `matchesBase` or `foreign` against the expected base (never `scaled` or `invalid`), and never when it is a uniform multiple of the previous baseline or of the profile base. The expected base never comes from the live table.
6. **Shielded means neutral.** On lock, screensaver, screens asleep, will-sleep or session resign, every scaled or dimmed display is at its baseline **when the event handler returns** (test: `shieldIsNeutralWhenEmitReturns`, with the fake table checked right after `emit`).
7. **Generations and epochs.** Every async continuation (poll, ramp step, rung timeout, settle, retry) compares its generation with the controller's and does nothing when stale. Every scaled write carries the controller's epoch stamp; only the re-gate path re-stamps it after a hang.
8. **Flicker safety.** No two opposing transitions within 500 ms on one display; the oscillation detector suspends a display that keeps reversing (§5.8). Safety drops are exempt from the rate limiter; they count towards the detector unless the headroom readings moved monotonically.
9. **Ledger before write.** The `SafetyLedger` marks a display scaled, with its baseline, before the scaled write is issued, under the lock held across the write, and unmarks it after the baseline write returns. As built (WP14): a scaled write that WindowServer refuses keeps the mark (the table may have taken it), so every landing (`writeBaselineNow`, the at-rest retry, a disarm or Back to Standard with nothing applied, the end of a calibration) treats a marked display as possibly off its baseline and writes the baseline, which empties the entry; while WindowServer refuses that baseline too, a disarm or Back to Standard with nothing applied keeps the trigger as long as the ledger marks the display and the table does not read back as the baseline (the rule of invariant 2's failed landings, keyed on the ledger because the failed write never became our last write: `keepsWindowsWhileMarked`), and the at-rest retry removes it after the baseline; a write the port refused before any WindowServer call (`displayGone`, `noTable`) puts the ledger back as it was (`StaleLedgerTests`, `TableWriterTests`).
10. **No name logic.** No code path compares `DisplayFacts.name` (lint test over `Sources/` for `.name ==`, `.name.contains` and `localizedName` comparisons).
11. **One engine, on the console (D27).** No write happens while the session is not on the console; a second engine instance exits before its launch check.
12. **Every reapply ramps.** A reapply after a reset, a base adoption or another app's termination ramps over ≤ 300 ms and journals its cause.

### 4.6 Generation numbers and the hang epoch

Each `DisplayController` holds `generation: UInt64`. It increments on every new decision that changes the intended outcome (target class change, suspend, disarm, rung change, reconfiguration, retry). Each async unit captures it at start: `let g = generation; … guard g == generation else { return }`. Ramp steps carry it per step, so a superseded ramp stops mid-way without a final write, and the new ramp starts from the last factor actually written (read from the controller, not assumed). The same pattern guards the HLG asset generation, the calibration sweep and the self-test, each with its own counter.

Generations cannot protect against a **hang**: only the main actor bumps them, and the work queued behind a stall still holds the current one. So the ledger carries a process-wide `hangEpoch`. Each controller stamps its scaled writes with the epoch it last gated under. The hang watchdog increments the epoch and writes the baselines while holding the ledger lock; `TableWriter` checks the stamp under the same lock and refuses stale writes, so nothing queued during the stall (a ramp step, a rate-limited raise, a write blocked inside WindowServer) can re-scale a display before the engine has re-gated with a fresh reading. Test: stall the main thread mid-ramp with `FakeGammaPort.stallNextWrite`, fire the watchdog, resume, and assert that no scaled write lands before the re-gate (`hangEpochBlocksQueuedWrites`). As built (WP14): the calibration path carries the epoch too (`writeCalibrationFactor(…, epoch:)`): a driven session stamps it when it starts, so a sweep step queued behind a stall is refused until a new session starts (`aHangRestoreEndsTheSweepUntilANewSession`), and the watchdog runs exactly while the ledger holds a display (`EngineWatchdogTests`).

### 4.7 The trigger ladder and its cache

**Rungs** (`LadderPlanner.rungs(for:os:cache:override:backoff:)`):

| # | Strategy | Pixel | When |
|---|---|---|---|
| 1 | T1 `taggedLayer` | black (tag only) | macOS 26+ |
| 2 | T1 `taggedLayer` | 1.6 | macOS 26+ |
| 3 | T2 `metalOneShot` | black | always |
| 4 | T2 `metalOneShot` | 1.6 | always |
| 5 | T3 `metalKeepAlive` (5 s) | 1.6 | always |
| 6 | T4-alt `hlgSampleBuffer` if H-T4d passed, else T4 `hlgStill` | black | always |
| 7 | T4 `hlgStill` | peak | always |

- **Placement:** built-in with a notch: top-right corner (outside the panel's rounded active area; `.notch` is the alternative if H-W2 shows the corner leaks). Externals: top-right corner; black first, then non-black with soft-light blending (a bright pixel nearly vanishes on pure black and pure white, not on mid-grey). **OLED externals:** black rungs only by default; if only a bright rung holds, the trigger moves one point along the top edge every 10 minutes (burn-in hygiene).
- **Screen changes:** every trigger and overlay window observes `NSWindow.didChangeScreenNotification`; when AppKit moves it to a screen whose display ID is not its target (a display unplugged or the lid closed with an external attached), it is removed at once (§4.3), so it never requests EDR on another display.
- **Headroom tag policy A (default):** tagged strategies are tagged at the display's potential, so the tag can never cap the grant. Policy B (tag = target gain ÷ 0.97, raised before raising G and lowered after lowering it) may save backlight power if macOS grants only what is asked; it is switched on only if H-T1c/H-T2c show the tag caps the grant. `requestHeadroom(_:)` re-tags in place.
- **T1 tag precision:** tags ≤ 1.0001 read back as 1.0, so T1 clamps its tag to ≥ 1.01 [VERIFIED off screen].
- **EDR colours start from `CGColor`.** `NSColor(colorSpace:components:count:)` stores 8-bit components and wraps values above 1.0 (1.6 becomes 0.596) [VERIFIED off screen]; a lint rule forbids it in Triggers, FillLight and Design.
- **Make before break:** rung n+1 is armed before rung n is removed; two requests at once are harmless and avoid a headroom dip.
- **Pre-held displays** (D6) start at the cheapest rung and escalate only while H is below what the level needs; escalation from a pre-held arm never replaces the cache unless the rung also fails in a normal arm.
- **Cache:** key = display UUID + `kern.osversion` → winning rung, plus the lowest ready headroom seen (the full-brightness headroom of the taper, §5.4). The next arm starts at the cached rung. **During a wake or unlock backoff, only the cached rung is retried and the ladder never escalates.** A cached rung is replaced by a heavier one only after it failed in **two separate arms**, neither within 60 s of a wake or unlock (`escalationQuarantine`); otherwise a slow grant after wake would cache whatever rung happened to be armed when the refusal ended (for example T3's 5 s render or the bright HLG still) for the whole OS build. Advanced ▸ Trigger method pins a strategy (`triggerOverride`); "Forget learned methods" clears the cache.
- **Escalate only when it can help:** the verdict must allow boosting, potential must be > 1, and macOS must not be suppressing HDR (then the current rung is kept). Otherwise the reason is shown and the ladder does not move.
- **First arm worst case:** 7 rungs × 2.5 s ≈ 18 s, once per display and OS build. The card, the menu bar symbol (`preparing`) and, for icon, shortcut and intent turn-ons, the HUD show "Preparing…" when the gate is not ready within 0.5 s.
- **HLG still asset (T4):** generated at runtime into `~/Library/Caches/app.overbright.Overbright/hlg-still-v1-<codec>-<level>-16.mov` (16 × 16 px, HEVC Main10 with the Dolby Vision side box disabled, ProRes 422 fallback, about 1 KB, BT.2020 / BT.2100 HLG / BT.2020), written under a temporary name, verified by reading frame 0 back, then moved into place. No binary asset in the repo [VERIFIED: 24/24 codec × level × size combinations, also with the software encoder].

### 4.8 Expected base, baselines and the drift check

- **Expected base (D26).** `GammaPort.profileBase(of:count:)` derives what macOS restores for the display without touching the live table: the ColorSync profile's `vcgt` resampled to the table length, identity when the profile has none. It is recomputed at every capture and on every reconfiguration, ColorSync profile, preset (seen as reconfiguration and screen-parameter changes) and accessibility event.
- **Capture:** read → `TableClassifier.classify(read, expectedBase:)`:
  - `matchesBase` → baseline := read;
  - `foreign` → baseline := read (a calibration loader or a continued S2 app; journal `baseline.foreign`), unless it is a uniform multiple of the previous baseline or the profile base;
  - `scaled` or `invalid` → do not arm; ask `ConflictProbe.attributeDrift()`; attributed → `failed(attributedDrift(app))`, else `failed(foreignTableAtLaunch)` with the "Reset Display Colors" action.
- **Event-driven re-base** (reconfiguration, ColorSync profile, accessibility; scaled, dimmed or idle alike): recompute the expected base E′ → wait until a read differs from our last write, at most 1 s (the event may arrive before WindowServer applies the new table) → read R twice; if both reads are identical and R classifies `matchesBase` against E′, adopt R as the baseline; if R still equals our own last write (WindowServer kept our table), adopt E′ only when the profile base moved, i.e. E′ differs from the expected base the baseline was captured or adopted against (the controller's `expectedBase`; the old baseline only for a baseline that has none) → update the `SafetyLedger` in the same step → reapply the current target with a ramp. Without this, a display boosted or dimmed across an HDR toggle, a preset change or a calibrated profile switch would carry the old curve into the new mode, and the hang watchdog would restore that stale baseline. As built (WP14): comparing E′ with the old baseline, as this rule first read, replaced a foreign baseline (a continued S2 app's curve, an S3 tool, a calibration loader) with the profile base on every reconfiguration that changed no profile; it now survives one, at rest and boosted (C-BOOST-17, `RebaseAtRestTests`). A table that is neither ours nor adoptable means no write of ours is on screen any more: the last write and the display's ledger entry are forgotten (`forgetOwnWrite`), so another writer that puts our old table back is a foreign writer whose table the next arm captures, and a failed landing that WindowServer's new base replaced leaves neither the hang watchdog nor the boost marker on (C-BOOST-18). A new base that cannot be written now (off the console, D27, or a refused write) keeps the event pending until it can (C-BOOST-16). At rest (idle or failed) the same rules run at once on one read (`settlePendingRebase`): idle does no work, so nothing waits for WindowServer.
- **Drift check** (`DriftCheck`, pure; every 2 s while scaled or dimmed, on the shared 2 s grid of D29, and 50 ms after any `appTerminated`, because WindowServer resets every online display when any process that wrote a table dies). As built (WP14, C-SIGNALS-1): "any" includes background-only processes (an XPC service, a bundle-less tool such as a catalogue entry matched by executable name), which reach Signals only through the running list and come and go every few seconds; Signals posts each one, because whether a process wrote a table cannot be known, and the cost is bounded by the engine instead: only a boosted or dimmed controller schedules the check, and the engine re-reduces after a termination only when it ended a continuation (the conflicts reach the reducer through the observed snapshot), so with nothing scaled or dimmed a termination runs nothing (`anUnrelatedTerminationCostsNothingUnlessADisplayIsScaled`):
  1. **Sample** the highest index `i*` with `B[i] × F ≤ 0.98` on each channel (where ×F and ×1 are furthest apart, and below any possible read-back clamp). Hypotheses at `i*`: our write `W = B × F`, our baseline `B`, and a freshly recomputed profile base `E″` when it differs from `B`. If `|W − B| < 2 × tolerance` (and `|W − E″|` likewise), skip the reset classification this tick; only the headroom check runs (at ×1.02 the two are visually indistinguishable anyway). As built (energy, E5): `E″` is computed only when the evaluation reaches it, after the skip, (a) and (b) below have failed (`DriftCheck.evaluate` takes it as a closure), so it is still recomputed fresh whenever it is consulted and every verdict is unchanged, while a steady tick (fine, reset or indistinguishable) costs no ColorSync profile copy, `vcgt` parse or resample: on the real port a tick went from 71 to 36 µs of CPU per display (read-only probe, M4 Max; `DriftProfileBaseTests`).
  2. **Evaluate in this order:** (a) every channel within tolerance of `W` → fine; (b) nearest hypothesis is `B` → the system reset our table: reapply with a ramp after 250 ms, count a repair; (c) nearest is `E″` (R classifies `matchesBase` against a profile base that changed without our seeing an event) → an **adoption candidate**: it is a base change only within 2 s of a ColorSync, reconfiguration or accessibility event and after two identical reads; otherwise it counts as a repair and as a non-user reversal, and more than 2 unexplained adoptions in 60 s trip the display as a foreign writer (attributed if `ConflictProbe` names one); (d) anything else → a foreign writer: count a repair and ask `ConflictProbe` to attribute it.
  3. **Headroom:** a fresh reading; if `applied > 0.98 × H`, lower at once (§4.3).
  4. **Trips:** 3 repairs within 6 s → `failed(repairBudgetExceeded)`; an attributed S3 app → `failed(attributedDrift(app))` at its first drift; adoption budget → as above. These trips clear only by a user action or when the attributed app terminates.
  - `DriftCheckTests` cover factors 1.02–1.06 and dim factors 0.95–0.99, under both read-back models (`FakeGammaPort.clampsReadBack`), with a calibrated (non-identity) base, and with a base change during a reconfiguration while boosted and while dimmed (`rebaseWhileBoosted`, `rebaseWhileDimmed`).

### 4.9 Master switch, levels, dimming, pause, Back to Standard

- `setOn(true)` calls `SystemSignals.refreshPowerNow()` (a synchronous power-source read) and re-reduces with the master on; each display then follows its own decision. `setOn(false)` disarms every display (ramp, baseline, triggers removed); stored levels stay.
- Moving any slider while the master is off turns the master on; while a user pause is active it also ends the pause (one rule: direct manipulation is intent). A guard (battery, Low Power, heat, schedule, Focus) is not lifted by moving a slider: the level is stored and the chip or banner says why.
- With `linkLevels` on, `setLevel(_, for: nil)` writes `linkedLevel`; each display maps that one level through its own ceilings (§5.3), so "Max" means each display's own maximum.
- `setExtraBrightness(.preset)` sets that preset's position; `.multiplier(g)` sets `LevelMapping.position(forGain: g, top:)` per display, clamped to each display's top.
- `step(_:)` moves by `shortcuts.stepSize` **in stops** (`StepMath.step`, ¼ or 1/12 stop) from the level of the display under the pointer (or the linked level); a step that would cross Standard stops at Standard first; it turns the master on.
- **Dim All / Stop Dimming** (`toggleDim`, the menu's first group, the Dock menu, the Dim shortcut): if any display that can dim is above Standard light, every such display goes to `lastDimLight` and its previous level is remembered (in memory); otherwise every display returns to its remembered level (or Standard). `setDimLight(_:for:)` dims one display or all; any dim level set by any path updates `lastDimLight`. The master turns on if it was off.
- **Keep this level?** When a level change made from the panel (on release), a shortcut, an intent or the menu takes any display from ≥ 10 % to < 10 % of Standard light, the engine publishes `status.pendingLowLevel` (previous levels, deadline now + 10 s). `keepLowLevel()` confirms; without it, the engine reverts at the deadline by itself (one `TimeSource.sleep`), so the revert does not depend on the UI being readable.
- **Level persistence** (as built, energy E6): a level set by a drag, a step, a preset or Dim All is stored at once for every reader (the reducer, the panel and HUD, the low-level rule, Signals), but written to UserDefaults once, `levelPersistDelay` (0.5 s) after the last change, and at once by `stop()`, `stopNow()` and every turn-off (so quit, Back to Standard and the auto-off write first): a drag of ten steps a second encodes every display's preferences and messages cfprefsd once instead of ten times (one task per pause in the steps, which sleeps again for the rest of the delay while steps keep coming). A crash loses at most the last 0.5 s of level changes; no safety state waits for it. A step also costs one reduction instead of two: the engine skips the re-reduction of an observed-inputs change when the last reduction already read exactly those inputs (`lastReducedInputs`), which is what a level step's own settings change is (`LevelPersistenceTests`).
- **Back to Standard** (`returnToStandard`): master off with a 120 ms ramp, dims undone, stored levels kept, `lastChange` shows "Off" in the HUD. It never depends on the panel, the policy or a fresh reading.
- **Pause:** `pause(until:)` and `resume()` are the engine's; it is the only writer of `automations.pausedUntil` and keeps one `TimeSource.sleep` until the deadline. There is no shell pause controller. As built (WP14), every wall-clock deadline (pause, auto-off, schedule boundary) is one task that sleeps in chunks of at most 5 min and re-reads the wall clock after each (`BoostEngine.sleep(until:)`, the chunking of Signals' `ScheduleTimer`), so neither a timer's tolerance nor a clock or time-zone change stretches it; the schedule boundary is calendar arithmetic (`Calendar.nextDate`), right on daylight-saving days.
- **Auto-off:** when the master turns on with `autoOffMinutes` set, the engine sets `autoOffAt` and sleeps once until then (one `TimeSource.sleep`, no repeating timer); at the deadline it turns the master off and publishes `lastChange = .timerEnded`.
- **HUD changes** (`status.lastChange`, `sequence` increasing): `.level` for changes by shortcut, intent, Focus or Back to Standard (from any source; so the shell's `HUDPolicy` shows a `.level` change from any other source, the Dock menu's Back to Standard, as built in WP14); `.preparing` when an icon, shortcut or intent turn-on is not ready within 0.5 s; `.blocked(reason)` when such a request is stopped by a guard; `.automationStopped(reason)` / `.automationResumed` when the timer, battery, Low Power, heat or the schedule stops, caps or resumes the boost on a visible display; never for full-screen, app or game pauses.
- **Calibration and self-test entry:** `beginCalibration` first returns every display to Standard (triggers removed, neutral tables) and holds the master off until the session ends; `runSelfTest` does the same.

---

## 5. Brightness math (`OverbrightPolicy` + Boost's `TableWriter`)

### 5.1 Quantities

| Symbol | Meaning | Source |
|---|---|---|
| `H` | Current (granted) EDR headroom: brightest renderable value ÷ SDR white = granted peak ÷ `sdrNow` | `NSScreen.maximumExtendedDynamicRangeColorComponentValue`, re-read on events, at 10 Hz while gating or in a poll burst, and before every scaled write |
| `H0` | `H` before we arm (often 1.0, often ≈ 1.2 on macOS 27; near the grant ceiling when something already holds EDR) | three reads, maximum |
| `H_full` | Headroom at full system brightness, the reference of the taper | the lowest ready H seen on this display and OS build (StrategyCache), seeded with `panelPeak ÷ sdrMax` |
| `p` (potential) | ≈ preset or panel peak ÷ 100 nits; 16 on the M4 Max built-in in the 1600-nit preset; 1.0 for presets or displays without EDR | `maximumPotential…` |
| `r` (reference) | > 0 only in reference modes | `maximumReference…` |
| `G` | Light gain: multiple of the current SDR white. 1 = Standard. | policy |
| `F` | Table factor: every baseline entry is multiplied by `F` | `F = tableFactor(G, domain)` |
| `L` | Dim light factor (< 1) | policy |
| `panelPeak` | Panel maximum luminance (built-in `EDRPotentialHeadroom` × 100; external DisplayAttributes Max) | IORegistry; an Apple XDR external without attributes: the product (`AppleXDRProducts`); without either, potential × 100 when the potential is above 2 (D8's verified rule; the backlight's `BrightnessMilliNits` maximum is never used) |
| `capNits` | The Safe level in nits: 1000 on Apple XDR panels, `min(1000, 0.6 × panelPeak)` on other HDR externals; none on OLED (Safe is ×1.3 there) | `GainCeiling.capNits` |
| `sdrMax` | Highest SDR white the user can pick without ambient boost (600 nits on M3–M5 MacBook Pro built-ins indoors, 500 on M1/M2 and Pro Display XDR, 1000 on Studio Display XDR, the frame-average luminance on another HDR external) | built-in: IORegistry; Apple XDR external: the product (`AppleXDRProducts`, keyed by vendor 0x610 and product ID), never its frame average, which is the full-screen sustained HDR level there; other externals: the frame average, §5.5 |
| `sdrNow` | Actual SDR white right now | **no public API**; trusted estimates only (§5.5); always `≤ panelPeak ÷ H`, because the grant never exceeds the panel peak |

### 5.2 Transfer domains

The transfer table sits after compositing. A plain multiply of the captured baseline (`T[i] = B[i] × F`) is the correct operation whether the table works on linear light or on display-encoded values: for a power-law curve, scaling encoded values by `F` scales light by `F^k`. What differs between the models is only which `F` delivers a wanted light gain, and where whites clip. Nobody has published a measurement; the circumstantial evidence leans towards encoded (≈ 65–70 %). Overbright therefore derives the domain per display and mechanism from its calibration record:

| `TransferDomain` | Light gain from factor | Factor for light gain `G` | Selected by |
|---|---|---|---|
| `.encoded` (**default**) | `G ≤ 1`: `decodeSRGB(F)`; `G > 1`: `F^2.4` | `G ≤ 1`: `encodeSRGB(G)`; `G > 1`: `G^(1/2.4)` | everything except a confirmed, valid linear record |
| `.linear` | `F` | `G` | a calibration record with outcome `.linear` (only after the linear confirmation, DESIGN.md §9) whose `osBuild`, `mechanism` and `potentialAtTest` (±5 %) match the current ones (`TransferDomainResolver`) |

**Why the default is safe, and for which truths.** Above white, `.encoded` writes `F = G^(1/2.4)`. If the truth is any power curve with exponent `k ≤ 2.4`, the light delivered is `F^k ≤ G ≤ 0.97 × H`; the sRGB curve delivers less than its 2.4 power above 1, so it is covered too; a linear truth delivers `F < G`. Property-tested over H in (1, 16] and k in {1, 1.8, 2.0, 2.2, 2.33, 2.4} plus the sRGB curve: the worst case is 0.981 × H. A truth exponent above 2.4 would need a curve steeper than the display's own profile, for which there is no evidence; if H-D1 ever showed one, the boost exponent becomes a per-display constant. The price is brightness, not clipping: under the sRGB truth the delivered light is 0.6–4 % below `G` (×1.627 instead of ×1.667 at Safe on the M4 Max; ×2.482 instead of ×2.587 at Peak). The v0.1 default, `encodeSRGB(G)` above white, was safe only for `k` up to about 2.33: at H 3.2 it wrote 1.636, and `1.636^2.4 = 3.26 > 3.2`.

**Calibration can only make the domain more aggressive with proof.** The step wedge (DESIGN.md §9) reports where the 0.95 patch merges with white: `F ≈ 1.61` if encoded and `≈ 3.00` if linear at H 2.667. A merge near the encoded prediction records `.encoded`. A merge near the linear prediction is only a candidate: Overbright then shows the patches for 2 s at the linear-domain Peak factor (`F = 0.97 × H`, 2.587 at H 2.667) on a black surround, and records `.linear` only if the user can still tell the 0.95 and 1.0 squares apart, which is impossible under the encoded truth (every code above 0.59 clips there). A late press, a missed press, a run that reaches the sweep's end, or a "no" records `.inconclusive`, and the default stays. `k̂ = ln H ÷ ln(0.95 × mergeFactor)` is kept in the record for diagnostics only; it never chooses a domain (late presses bias it low: a press at 1.70 instead of 1.613 gives `k̂ ≈ 2.05`, which would have allowed ×2.91 light at H 2.667).

The overlay (Compatibility mode) uses the same rule with its own record: whether the compositor multiplies in linear light is unknown (H-C2), and assuming encoded is the conservative choice. As built (WP14), a calibration of a Compatibility-mode display measures the overlay itself: the session shows the overlay at factor 1 with the display's potential as its EDR request and sweeps its factor under `TableWriter.checkCalibrationFactor`; it writes no table and makes no trigger, so a display moved to Compatibility mode to stay clear of table writes stays clear of them.

**The sweep's bound (as built, WP14).** The sweep must pass `0.97 × H` (it ends at 1.15 × the linear prediction, about 1.29 × H; the display clips the light at H either way), so `TableWriter.writeCalibrationFactor` does not apply the boost interlock. It bounds each factor by the session's `maxFactor` (from a fresh reading), by a ceiling of the reading itself (`CalibrationMath.writeCeiling`: the sweep's cap ÷ 0.95, about 1.36 × H, and nothing above 1 below H 1.03), by the reading's age and display, and by the hang epoch the session stamped when it started, checked in the ledger's critical section.

### 5.3 Level mapping (the slider) and steps

`LevelPosition` is one number `p` in −1 … 1 with a detent at 0 (Standard).

- **Boost half** (`0 < p ≤ 1`): `G_req = top ^ p`, linear in stops of the display's top, where `top = GainCeiling.sliderTop(facts, capMode, isOLED)`.
- **Dim half** (`−1 ≤ p < 0`): `L = 0.02 ^ (|p| ^ 2.5)`, i.e. `stops = log₂(50) × |p|^2.5`. The first half of the travel covers −1 stop, so the area next to the detent changes as gently as the boost half (a quarter of the dim travel is −0.18 stop, a quarter of the M4 Max's Safe boost half +0.18 stop); the second half reaches the floor of 2 % of the current SDR light (−5.6 stops).
- **Presets** (ticks): Indoor 0.25 · Bright room 0.5 · Sunlight 0.75 · Max 1.0. The default level for a newly enabled display is Bright room. **Preset visibility** (`PresetVisibility`): Max is always shown; walking down from it, a preset is shown only if its gain is ≥ ×1.1 and ≥ 0.1 stop below the last shown one. Hidden presets are not drawn, not in menus and not VoiceOver stops; when Max itself is at most ×1.3 (the OLED Safe top of exactly ×1.3 included, DESIGN.md §5.13; settled by WP13 to match the built `DisplayCardModel.hasSmallGain`), the value tag adds "small gain on this display".
- **Named dim stops** (⌥-arrows, menus, VoiceOver): 50 %, 25 %, 10 %, 5 %, 2 % of Standard light (positions −0.500, −0.660, −0.809, −0.899, −1).
- **Steps are in stops, not travel** (`StepMath`): arrow keys and scroll 1/12 stop (≈ 6 % light); Brighter / Less Bright ¼ stop (≈ 19 %) or, with the fine step size, 1/12 stop; a step that would cross Standard stops at Standard first; ⌥-arrows jump to the previous or next named stop (detent, shown presets, named dim stops). Property: no arrow, scroll or Brighter / Less Bright step exceeds ½ stop.

`sliderTop` is a property of the display, **not** of the moment: it is the multiplier the top of the slider asks for. The table multiplies whatever macOS shows; live limits (§5.4) then cut it down where needed, and the taper makes the boost fade out as the user lowers system brightness.

| Display class | Safe `top` | Peak `top` |
|---|---|---|
| Built-in XDR, Apple XDR external | `min(1000 / sdrMax, 0.97 · peak / sdrMax)` | `0.97 · peak / sdrMax` |
| OLED external | `min(1.3, 0.97 · peak / sdrMax)` | `0.97 · peak / sdrMax` |
| Other HDR external | `min(min(1000, 0.6 · peak) / sdrMax, 0.97 · peak / sdrMax)` (0.6 × peak ≈ the full-screen sustained level DisplayHDR tiers require) | `0.97 · peak / sdrMax` |

A `top` below 1.05 disables the boost half for that cap mode; the card says why ("Safe limit reached: choose Peak for more" or "Little gain at full brightness"). A display of a boosting class whose panel peak or SDR maximum no source gives (every fallback of §5.1 exhausted) has a top of 1 and the verdict `panelFactsUnknown`: the boost half is off and the dim half stays (`EligibilityTests.anUnbackedTopStillDims`: an HDR external on an Intel Mac, one without MaxFrameAverage, the built-in without `user-accessible-max-nits`, an Apple XDR external `AppleXDRProducts` does not list). **As built (WP14, C-PLATFORM-3, through the contract lane):** the case allows dimming but not boost and claims no gain; its sentence (DESIGN.md §12.1, "Range unknown") says that Overbright cannot tell how much brighter the display can get. Before it, these displays got `noGainAtFullBrightness(peakGain: 1)`, whose "gains less than 10 %" no number backed; `.checking` was not the answer either, since `allowsDim` is false for it (tried in WP14 and reverted). The classifier answers it after the preset rule (a known peak still decides that) and before "little gain", wherever `GainCeiling.sliderTop`'s guard fails for a class in `GainCeiling.boostClasses` (`GainCeiling.lacksPanelFacts`).

**Presets per class** (gain at full brightness):

| Class and mode | top | Shown presets |
|---|---|---|
| M4 Max built-in, Safe | 1.667 | Indoor 1.14 · Bright room 1.29 · Sunlight 1.47 · Max 1.67 |
| M4 Max built-in, Peak | 2.587 | 1.27 · 1.61 · 2.04 · 2.59 |
| M1/M2 built-in or Pro Display XDR, Safe / Peak | 2.000 / 3.104 | 1.19 · 1.41 · 1.68 · 2.00 / 1.33 · 1.76 · 2.34 · 3.10 |
| Studio Display XDR, Peak (Safe: no boost) | 1.940 | 1.18 · 1.39 · 1.64 · 1.94 |
| MSI MPG322UX OLED, Safe | 1.300 | Bright room 1.14 · Max 1.30 (Indoor < ×1.1; Sunlight within 0.1 stop of Max) |
| MSI MPG322UX OLED, Peak | 1.704 | 1.14 · 1.31 · 1.49 · 1.70 |
| DisplayHDR 600 external at SDR 300, Safe | 1.200 | Max 1.20 only, "small gain on this display" |

**Steps per class:**

| | Span | Brighter presses Standard → top (¼ stop) | Arrow presses (1/12 stop) |
|---|---|---|---|
| M4 Max built-in, Safe / Peak | 0.74 / 1.37 stops | 3 / 6 | 9 / 17 |
| Pro Display XDR, Safe | 1.00 stop | 4 | 12 |
| MSI OLED, Safe / Peak | 0.38 / 0.77 stops | 2 / 4 | 5 / 10 |
| Dim half, every display | 5.64 stops | 23 Less Bright presses | 68 |

### 5.4 Ceilings and the interlock

```
G_req     = top ^ p                                                                          // Policy
G_static  = min(G_req, sdrTrusted ? capNits / sdrNow : ∞, thermal == .serious ? 1.2 : ∞)     // Policy
G_applied = GainCeiling.liveCap(G_static, reading)                                           // Boost, at write time:
              1. taper:      G ← G ^ t,  t = clamp((2 − H/H_full) / (2 − 1.15), 0, 1)        //   if the option is on
              2. Safe bound: G ≤ capNits × H / panelPeak                                     //   Safe, no trusted sdrNow
              3. headroom:   G ≤ 0.97 × H
F         = tableFactor(G_applied, domain)                                                    // TableWriter
```

- **Taper** ("Add extra brightness only near full brightness", default on): `H ≈ granted peak ÷ sdrNow` rises as the user lowers system brightness, so `H ÷ H_full` is a public proxy for how far brightness was lowered. Full gain while `H ≤ 1.15 × H_full`, none at `H ≥ 2 × H_full` (about half brightness), in stops between. On the M4 Max at Safe: 1000 nits at full brightness, ≈ 670 nits at 75 % (SDR 450), the plain 300 nits at half. The brightness keys keep their normal range and the boost only extends the top; the constants are tuned in WP16 (H-B1). With the option off, the multiplier applies at every brightness, which at half brightness gives less light (500 nits at Safe) than simply raising brightness to 600. As built (WP14): the reducer gets the engine's reference through `EngineFeedback.fullBrightnessHeadroom` (the seed only without feedback), so "Below full brightness" is reported exactly when the writer's `liveCap` applies the taper.
- **Live Safe bound** (`GainCeiling.safeBound = .worstCaseGrant`, default): because `sdrNow = grantedPeak ÷ H ≤ panelPeak ÷ H`, capping `G ≤ capNits × H ÷ panelPeak` keeps the light at or below `capNits` whatever macOS granted, with no SDR estimate: ×1.667 indoors at a full 1600-nit grant, ×1.0 (no Safe boost) outdoors where macOS raises SDR white to 1000 nits. If H-G1 shows grants usually well below the panel peak, this bound becomes too conservative (a 986-nit grant at SDR 600 gives H 1.64 and a bound of ×1.03); WP16 then switches to `.sliderTopOnly`, which keeps only the static top, and DESIGN.md uses the Safe copy without a nits claim until H-N1 supplies `sdrNow`. With a trusted SDR white the Policy term `capNits ÷ sdrNow` is exact and the live bound is skipped.
- **Headroom:** `G ≤ 0.97 × H` for writes; lower once the applied gain exceeds `0.98 × H`.

`TableWriter.write(display:target:reading:epoch:)` is the only function that writes a table other than the baseline. It:

1. requires a `HeadroomReading` of the same display (`reading.display == target`) whose age `TimeSource.now − reading.time` is ≤ 150 ms, and the controller's epoch stamp equal to `SafetyLedger.hangEpoch` (§4.6), checked under the ledger lock it then holds across the write;
2. computes `G_applied` through `GainCeiling.liveCap`, journals `interlock.clamped` whenever a live term binds;
3. writes the baseline when `G_applied < 1.005` (a no-op boost) or when `H < 1.03`;
4. updates the `SafetyLedger` before issuing a scaled write (§4.5 rule 9);
5. never writes an entry above `F × max(B)`; dim writes (`F < 1`) need no reading but still respect the epoch lock.

`TableWriter.writeBaselines(fromLedger:)` is nonisolated: it takes the ledger lock, writes every scaled or dimmed display's baseline and clears the flags; the hang watchdog and the signal queue call nothing else. The drift check compares only entries where `B × F ≤ 0.98` (§4.8), so it works whether or not read-back clamps at 1.0. The exact-curve variant `T[i] = encode(G · decode(B[i]))` would give the near-black toe the same gain; it changes less than 2 % of the code range and would discard a calibrated baseline's shape, so v1 uses the plain multiply.

### 5.5 SDR white: what we can and cannot know

No public API reports the SDR white level in nits. The engine keeps an `SDRWhiteEstimate` only from sources it trusts:

| Source | When | Trust |
|---|---|---|
| `colorimeter` | The user typed a colorimeter reading in the calibration sheet (`CalibrationRecord.measuredSDRWhiteNits`) | exact while the record is valid (§5.2) and, as built (WP14), only while a reading's H is within ±5 % of `headroomAtTest` (the same SDR white: macOS moves SDR white with brightness and ambient light, and H with it); otherwise the live worst-case bound applies, checked again at every write (§5.6's outdoor row) |
| `hdrFrameAverage` | External in HDR mode, except an Apple XDR external (its MaxFrameAverage is the full-screen sustained HDR level, 1000 nits on the Pro Display XDR): IORegistry `DisplayAttributes` MaxFrameAverage (`GainCeiling.frameAverageSDRWhite`) | Matched WindowServer's own SDR value on the MSI (265.05 nits) [VERIFIED]; whether the HDR-mode SDR brightness slider changes it is H-N2 |
| `panelReported` | Built-in: IORegistry `AppleARMBacklight` `BrightnessMilliNits` | Only if H-N1 shows it tracks SDR white while EDR is active; otherwise never used |

Consequences:

- **The nits readout** ("≈ 800 nits") appears only with a trusted estimate **and** a valid calibration record for the display's mechanism, because nits are `G × sdrNow` and `G` is only as right as the domain. Without a record the multiplier is an estimate and is shown as one ("≈ ×1.29", DESIGN.md §5.6). Never a number we cannot back (DESIGN.md principle 2).
- **Safe without an estimate** uses the live worst-case bound of §5.4; Safe's copy then names the multiplier, not nits (DESIGN.md §12.2).
- `panelPeak ÷ H` is used only as an **upper bound** of `sdrNow` (inside the Safe bound), never as an estimate shown to anyone: macOS often grants less than the panel peak (WindowServer logs on the owner's Mac showed granted peaks of 889–986 nits while the brightness limit read 1600), so as an estimate it would be wildly high.

### 5.6 Worked numbers (default `.encoded`; computed, not measured)

Ceilings (G = light gain, F = table factor written, nits = G × SDR white). The grant is assumed to reach the panel peak ("H at full request"). "If linear" shows what the same F would deliver if the table turns out to be linear; under the sRGB truth the delivered light is 0.6–4 % below G.

| Display and situation | SDR white | H at full request | Safe G → F | Peak G → F | Taper (default on) | If linear (Safe / Peak) |
|---|---|---|---|---|---|---|
| M4 Max built-in, indoors at full brightness | 600 | 2.667 | 1.667 → **1.237** (1000 nits) | 2.587 → **1.486** (1552 nits) | none (t = 1) | 742 / 892 nits |
| M4 Max built-in, outdoors (macOS at 1000 nits SDR) | 1000 | 1.6 | live bound 1000 × 1.6 ÷ 1600 = ×1.0 → **no Safe boost** (chip "Safe limit"); the same with a trusted SDR estimate | 1.552 → **1.201** (1552 nits) | none | — / 1201 nits |
| M4 Max built-in at half brightness | 300 | 5.33 | taper off: 1.667 → **1.237** (500 nits) | taper off: 2.587 → **1.486** (776 nits) | **no boost** (t = 0): the brightness keys keep their range | 371 / 446 nits |
| M1/M2 MacBook Pro or Pro Display XDR, full brightness | 500 | 3.2 | 2.000 → **1.335** (1000 nits) | 3.104 → **1.603** (1552 nits) | none | 667 / 802 nits |
| Studio Display XDR, full brightness (P3-2000 preset) | 1000 | 2.0 | **no Safe boost** at any brightness: its SDR maximum already reaches 1000 nits (static top 1.0) | 1.940 → **1.318** (1940 nits) | none | — / 1318 nits |
| Studio Display XDR at half brightness | 500 | 4.0 | no Safe boost | taper off: 1.940 → **1.318** (970 nits) | **no boost** (t = 0) | — / 659 nits |
| MSI MPG322UX OLED, macOS HDR on | 265.05 | 1.756 | 1.300 → **1.116** (≈ 345 nits in small areas) | 1.704 → **1.249** (≈ 452 nits) | none (SDR white is fixed in HDR mode) | 296 / 331 nits |
| MSI MPG322UX OLED, macOS HDR off | — | 1.0 | verdict "Turn on High Dynamic Range" | — | — | — |

The OLED's full-screen white stays near 265 nits whatever we do (automatic brightness limiting); the gain shows in text, highlights and partial-screen content.

Preset gains (G → F) for the M4 Max built-in indoors:

| Preset | p | Safe (top 1.667) | Peak (top 2.587) |
|---|---|---|---|
| Indoor | 0.25 | 1.136 → 1.055 | 1.268 → 1.104 |
| Bright room | 0.50 | 1.291 → 1.112 | 1.608 → 1.219 |
| Sunlight | 0.75 | 1.467 → 1.173 | 2.040 → 1.346 |
| Max | 1.00 | 1.667 → 1.237 | 2.587 → 1.486 |

Dim half: p −0.25 → L 0.885 (F 0.948) · −0.5 → 0.501 (F 0.736) · −0.75 → 0.149 (F 0.422) · −1 → 0.020 (F 0.152).

Calibration predictions for the 0.95 patch merging with white: H 2.667 → F 1.613 (encoded) vs 2.997 (linear); H 3.2 → 1.745 vs 3.595; H 1.6 → 1.293 vs 1.798. The sweep pauses at 1.15 × the encoded prediction (1.855 at H 2.667) and asks before going on; the linear confirmation frame uses `F = 0.97 × H` (2.587 at H 2.667, where every code above 0.592 clips under the encoded truth).

### 5.7 Ramps

- Every user and policy change ramps: 300 ms by default (the allowed band is 250–400 ms), 160 ms under Reduce Motion, 120 ms for Back to Standard. **Every reapply** (after a system reset, a base adoption or another app's termination) ramps too (≤ 300 ms) and journals its cause. A ramp never has fewer than 6 steps; "snap" is reserved for safety drops (§4.3), which happen in one write.
- Easing: smoothstep in log₂-gain space (equal perceived steps), one table write per step at ≈ 60 Hz (an 18-write ramp at 300 ms). Each step carries the generation and the epoch stamp (§4.6).
- **User raises** (slider, preset, step, intent, Focus) apply at once, up to what a reading taken now allows; when more headroom is needed, a 10 Hz poll burst (≤ 3 s) raises further as it arrives. **Raises driven by headroom recovery** wait for 1.5 s of stable headroom and move only when the new target is ≥ 5 % above the applied gain (hysteresis against headroom wobble). Lowering for policy reasons ramps immediately; lowering for safety writes at once, once the applied gain exceeds `0.98 × H`.
- Slider drags are applied continuously (each change is a small step of the user's own finger), with the rate limiter of §5.8 for direction reversals.
- Master on and off ramp all displays together; displays never ramp in visible sequence.

### 5.8 Flicker safety (WCAG 2.3.1)

WCAG 2.3.1 forbids more than three general flashes in any one-second period; a flash is a pair of opposing luminance changes of 10 % or more. Overbright guarantees, per display:

- **Rate limiter.** At least 500 ms between opposing transitions (a raise followed by a lowering or the reverse). A request that would violate it is coalesced and applied when allowed, so at most one flash per second can occur, and only from repeated user action.
- **Oscillation detector.** Four or more direction reversals within 10 s from non-user sources (policy, guards, headroom, watchdog repairs, base adoptions) trip the display into `failed(.oscillation)`; the banner says "Overbright stopped on ‹Display› to prevent flicker" and offers Try Again. User drags do not count. Headroom-tracking clamps do not count while consecutive H readings move monotonically (a user pressing the brightness keys, or ambient light changing, moves H in one direction; that is following, not flicker); with the 1 % dead band, a level where `0.97 × H` binds no longer flips between "lower" and "raise" on every small wobble.
- **Repair budget.** Three repairs in 6 s, or more than two unexplained base adoptions in 60 s, trip the display even with "Continue anyway", because fighting another writer is what flickers.
- These trips clear only on Try Again, Continue Anyway, or when the attributed app quits; unlock and wake do not restart a fight (§4.3).
- The calibration comparison flips at most once per 1.5 s; the welcome card's before/after divider changes only our own window's content.

### 5.9 Dim below minimum

`.dim(light: L)` writes `B × tableFactor(L, domain)` with no trigger and no headroom: it works on any display with a transfer table, HDR or not, with no per-display switch, and on Compatibility-mode displays through `setFactor(L)` without an EDR request. Power and heat guards never block it (dimming saves power). The floor is 2 % of the current SDR light, which at a low system brightness is effectively black; therefore any change that takes a display below 10 % of Standard light asks "Keep this level?" and returns to the previous level after 10 s without an answer (§4.9), and Back to Standard always returns to 1.

---

## 6. The policy reducer (`BoostPolicy.reduce`)

### 6.1 Per-display algorithm and precedence

For each `DisplayPolicyInput`:

1. `eligibility = EligibilityClassifier.classify(facts, preferences: preferences, reading: feedback.lastReading, machine: input.machine)` (the OLED override and calibration come from `preferences`; `compatibilityModeAdvised` from `CompatibilityModels.tableWritesIgnored(machine)`).
2. `boostEnabled = preferences.boostEnabled ?? eligibility.defaultBoostEnabled`.
3. `level = settings.linkLevels ? settings.linkedLevel : preferences.level`; a Focus directive `.on(level:)` replaces it for every display.
4. `mechanism`: `automatic` → `.overlay` when the advisory `compatibilityModeAdvised` is present or a valid calibration record says `notBrighter`, else `.table`; explicit preferences win.
5. `domain = TransferDomainResolver.effectiveDomain(preferences.calibration, mechanism:, machine:, potential: feedback.lastReading?.potential)`.
6. Walk the precedence list. The first **stop** that matches sets `.neutral` with its reason; **boost-only** stops apply only when `level > 0` (dimming passes).

| # | Condition | Kind | Reason | Scope |
|---|---|---|---|---|
| 1 | master off | stop | `masterOff` | all |
| 2 | verdict forbids the requested half | stop | `notSupported(verdict)` | display |
| 3 | shielded (locked, screensaver, asleep, sleeping, not on the console) | stop | `shielded` | all |
| 4 | S1 or S2 conflict running and not continued (S1: continued only on overlay displays; "always continue" exists only for S2/S3) | stop | `conflict(app)` | all |
| 5 | engine trip on this display | stop | `tripped(cause)` | display |
| 6 | `pausedUntil > now` | stop | `userPaused(until)` | all |
| 7 | Focus directive `.off` | stop | `focusOff` | all |
| 8 | the per-display boost switch is off | boost-only | `boostNotEnabled` | display |
| 9 | thermal critical | boost-only | `thermalCritical` | all |
| 10 | Low Power Mode and `pauseInLowPowerMode` | boost-only | `lowPowerMode` | all |
| 11 | on battery and `onlyOnAdapter` | boost-only | `onBattery` | all |
| 12 | on battery, `belowThreshold`, percent < threshold (percent read synchronously when the boost turns on) | boost-only | `battery(percent, threshold)` | all |
| 13 | schedule set and minute outside it | boost-only | `outsideSchedule` | all |
| 14 | `pauseForFullScreenVideo` and this display is in `fullScreenVideoDisplays` | boost-only | `fullScreenVideo` | display |
| 15 | `pauseForAllFullScreen` and a full-screen window on this display | boost-only | `fullScreenApp` | display |
| 16 | `pauseForListedApps` and an enabled rule matches the frontmost app, whose window is on this display (`whilePlaying` needs `isPlaying == true`; unknown falls back to `whileFrontmost`) | boost-only | `pausedApp(bundleID)` | display |
| 17 | `pauseInGames` and the frontmost app is a game on this display | boost-only | `game` | display |
| 18 | OLED display and idle beyond the threshold | boost-only | `oledIdle` | display |
| 19 | macOS suppresses HDR | **reason only** (no stop: the interlock follows whatever headroom remains, the current rung is kept and the ladder does not escalate) | `hdrSuppressedByMacOS` | all |

7. If nothing stopped it: `level == 0` → `.neutral` (no reason); dim → `.dim(light: LevelMapping.dimLight(level))`; boost → `.boost(gain: G_static)` with **cap reasons** appended when they bind: `thermalSerious`, `safeLimit` (Safe and the static top binds at `p ≥ 0.98`, or the feedback reading shows the live Safe bound binding), `oledLimit`, `nearFullBrightnessOnly` and `headroom` (the feedback reading through `GainCeiling.liveCap`). An S3 app running adds a non-blocking `conflict(app)` after them.
8. `requestedGain` records `G_req` for the readout.

The reducer has no clock, no I/O and no randomness: `now`, `minuteOfDay`, `machine` and the snapshot are inputs. Its tests are a table of hundreds of cases plus property tests (§9.1).

### 6.2 Reasons → status chip

The chip shows the first **per-display** reason (`LimitReason.isGlobal == false`); global reasons are never chips, because the banner already says them once (§6.3), and a card shows no chip for the reason the banner currently shows (a trip on that display). A display whose verdict forbids boosting but allows dimming shows its verdict badge as a neutral chip with the verdict's fix. The engine phase wins while preparing: `arming`/`gating` → "Preparing…"; `failed(headroomNeverArrived)` → "No extra range" (after two failed tries in a session, the popover changes, DESIGN.md §12.2). DESIGN.md §12 holds every chip's exact copy, colour and symbol. A display at Standard with no reason shows no chip; a boosted display with no limiting reason shows no chip (calm by default).

### 6.3 Banner precedence

**A reason that applies to all displays is shown once, as the banner; cards show chips only for per-display reasons.** At most one banner, chosen among the reasons that currently stop at least one display that would otherwise change (a display whose own boost switch is off would not; a user pause and a foreign table at launch show at any level): `userPaused` > `conflict` (S1/S2) > `foreignTableAtLaunch` > `flickerStop` / `unattributedDrift` > `attributedDrift` > `focusOff` > `thermalCritical` > `lowPowerMode` > `battery` > `onBattery` > `outsideSchedule`. Banner copy and actions: DESIGN.md §12.3. When the banner's reason clears, the next one in this order takes its place.

### 6.4 Menu bar symbol state

`off` when the master is off; `attention` when a conflict, trip or foreign-table banner is up; `preparing` while a display that should boost is arming or gating and none is boosted yet; `paused` when a user pause is active or every display that should boost is stopped by a global stop or a boost-only guard; `dimming` when every changed display is dimmed; otherwise `on`. The reducer cannot see engine phases: it never returns `preparing`, and the engine sets it in `BoostStatus.symbol` (`BoostEngine.symbol()`) [as built, WP1/WP4]. A display "should boost" only when its level is on the boost half, its verdict and cap mode give it a top above ×1, **and its own Use extra brightness switch is on**: a display whose switch is off would not change, so it neither makes the symbol `paused` nor lets a guard raise a banner (§6.3); its chip says `boostNotEnabled` [ruling of the contract owner, WP13].

### 6.5 Per-app rules, games and full screen

- Rules match the exact bundle ID, case-insensitively (LaunchServices treats bundle IDs that way). Defaults are in §3.8; the editor seeds them and offers suggestions: installed apps whose `LSApplicationCategoryType` is video, Prime Video, Infuse Enterprise, GeForce NOW, Moonlight.
- **Scope per display:** a rule pauses only the display(s) that show the app's topmost layer-0 window; others keep boosting. An app frontmost with only its menu bar pauses nothing.
- **`whilePlaying`** (players, beta): frontmost and holding a display-sleep power assertion (`PreventUserIdleDisplaySleep` / `NoDisplaySleepAssertion`, read with `IOPMCopyAssertionsByProcess` in ≈ 1.2 ms, no permission [VERIFIED]). If the read fails, the rule behaves as `whileFrontmost`. Which assertion each player holds is H-P1.
- **Full-screen video** (default on, beta): a full-screen window (§7.3) whose owning process holds such an assertion. It covers browsers and players in full screen without pausing people who read or write in full screen. **Every full-screen app** (default off) pauses for any full-screen window, documents and games included.
- **Not on the list:** browsers (they would disable the boost all day; full-screen video in a browser is covered by the full-screen video rule, if H-P1 confirms that browsers hold the assertion while playing), Netflix and Disney+ (no Mac apps), game launchers (the launcher is not the game; games are covered by the optional games rule, which reads the category key and excludes Apple's Games app, and by the every-full-screen rule).
- Pauses ramp down; resuming waits 1 s after the app leaves the front so app switching does not pump the brightness.

---

## 7. System integration, safety, compatibility mode and surfaces

### 7.1 Event wiring

Every source below is started by its owner's `start()` and stopped by `stop()`. Sources marked **boost-only** run only while at least one display prepares, holds or leaves a boost (`SystemSignals.setBoostActive`, D30), so nothing runs while Overbright is off or only dims. As built (WP14, narrowed by D30 in the energy pass): a display that is arming or gating, or ramping toward, holding or disarming from a boost (a boost target, or a table or overlay above its baseline), counts; a dimmed-only display does not (every guard these sources feed applies to the boost half only, D10), nor does a suspended one whose baseline is written (a lock, display sleep or fast user switch can last all night; the resume reads the power source again), and neither does one the self-test or a calibration drives; all but the schedule boundary also stop while the screen is shielded (`SystemSnapshot.isShielded`: locked, screensaver, displays or system asleep, another session on the console) and resume when the last shield lifts, with a fresh power and idle read. The "Entry point" column says how the callback is declared: in a module whose default isolation is `MainActor`, **every entry point the system may call off the main thread must be explicitly nonisolated** (§8.1 rule 2).

| Signal | API | Entry point → main | Owner | Effect |
|---|---|---|---|---|
| Display reconfiguration | `CGDisplayRegisterReconfigurationCallback` | `nonisolated static` C function, context via `Unmanaged`; `DispatchQueue.main.async`. Begin flag: overlays to factor 1. **Remove flag (and the disabled flag): handled at once** (no debounce). After phase: debounce 0.5 s + confirm at 2 s; a begin with no after phase settles by itself after 5 s | Displays (relayed into Signals' stream by the composition root) | `displayConfigurationBegan`, `displayRemoved(id)` (immediate), `DisplayDirectory.generation += 1`, `displaysReconfigured` (at 0.5 s; the 2 s confirming pass emits it again only when the facts changed, WP2 as built: the drift check and the ColorSync event cover a late `vcgt`) |
| Screen parameters (also fires when current headroom changes) | `NSApplication.didChangeScreenParametersNotification` (string name; the typed message is macOS 27-only) | `NotificationCenter` with `queue: .main` | Displays | re-fetch `NSScreen.screens`; `screenParametersChanged`; Boost re-reads H: each controller's headroom check (and the safety drop of §4.3) runs inside the handler, and the re-reduction is coalesced to at most one per `screenParametersReduceInterval` (100 ms, trailing edge; as built, energy E2: macOS posts one notification per frame while headroom moves, 3.8–4.9/s on average and bursts of up to 122/s with every lock, unlock and HDR screensaver transition) |
| System sleep / wake | `NSWorkspace.willSleep/didWakeNotification` | `queue: .main` | Signals | `willSleep` → neutral synchronously; `didWake` → settle 1 s, re-arm the cached rung |
| Display sleep / wake | `NSWorkspace.screensDidSleep/screensDidWakeNotification` | `queue: .main` | Signals | same |
| Lock / unlock | distributed `com.apple.screenIsLocked` / `com.apple.screenIsUnlocked`; launch check `CGSessionCopyCurrentDictionary` `CGSSessionScreenIsLocked` (undocumented, launch only) | `DistributedNotificationCenter` with `queue: .main` | Signals | shielded (synchronous delivery) |
| Screensaver | distributed `com.apple.screensaver.didstart` / `didstop` | `queue: .main` | Signals | shielded |
| Fast user switching, console | `NSWorkspace.sessionDidResignActive/BecomeActive`; at launch `CGSessionCopyCurrentDictionary()[kCGSessionOnConsoleKey]` | `queue: .main` | Signals | `isSessionActive`; no writes while false (D27); rescue and re-arm on become-active |
| Active Space, app activation, launch, termination | `NSWorkspace` notifications (need a real `NSApp.run()`), plus KVO of `NSWorkspace.runningApplications` (`.old`/`.new`) for launches and terminations: as built (WP14), macOS 27.0.1 posts no did-launch or did-terminate for an `LSUIElement` app, and only will-launch for one that switches to the accessory policy before it finishes launching, which covers most boosters and gamma writers [VERIFIED, WP14 probe] | `queue: .main`; the KVO handler is built nonisolated and hops through `MainHop` (AppKit changes the list on the main run loop) | Signals | full-screen re-check after 0.6 s (event-driven, also while off: it is what ends a full-screen or per-app pause; one-shot, never periodic; after a termination only a regular app's, because another app's window counts only while it is frontmost and the next app's activation follows a frontmost app's exit: as built, WP14, C-SIGNALS-1); frontmost app; conflicts (re-read on every report, before the event); `appLaunched` and `appTerminated(bundleID:processID:)` once per process, whichever source reports it first (`AppEventFilter`), background-only processes included → drift check after 50 ms while scaled or dimmed (§4.8) |
| Accessibility display options | `NSWorkspace.accessibilityDisplayOptionsDidChangeNotification` | `queue: .main` | Signals | expected-base recomputation, ramped reapply (§4.8) |
| ColorSync profile change | distributed `com.apple.ColorSync.DisplayProfileNotification` | `queue: .main` | Signals | expected-base recomputation, adoption once WindowServer applied the new table (≤ 1 s), ramped reapply |
| Trigger occlusion, screen change | `NSWindow.didChangeOcclusionStateNotification`, `NSWindow.didChangeScreenNotification` on our trigger, overlay and Fill Light windows only | `queue: .main` | Triggers, FillLight | hidden → neutral at once; visible → re-present; moved to another display → removed at once |
| Thermal | `ProcessInfo.thermalStateDidChangeNotification` (posted on any thread) | `{ @Sendable notification in … }` block observer, then `Task { @MainActor in … }`; never a main-actor `@objc` selector | Signals | cap at serious, stop at critical |
| Low Power | `NSProcessInfoPowerStateDidChange` (any thread) | same | Signals | guard |
| Adapter ↔ battery | `IOPSCreateLimitedPowerNotification` (fires only on source switches) | `nonisolated static` C callback on the main run loop, then a synchronous `IOPSCopyPowerSourcesInfo` read | Signals | guard |
| Battery percent (**boost-only, on battery**) | `IOPSNotificationCreateRunLoopSource` | `nonisolated static` C callback, main run loop | Signals | guard. **Also read synchronously** in `setBoostActive(true)`, `refreshPowerNow()` (master on), on every adapter → battery switch, before reducing, and when the last shield lifts while boosting (the source stops behind a shield) |
| HDR suppression (macOS 26+) | `NSApplication` should-begin/end-suppressing-HDR messages, `applicationShouldSuppressHighDynamicRangeContent` | main (delegate) | Signals | reason only; logged; the current rung is kept; never escalated against |
| Idle time (**boost-only, OLED**) | `CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: CGEventType(rawValue: ~0)!)` (guarded, never force-unwrapped) — no permission [VERIFIED] | main | Signals | one timer for `threshold − idle`; once idle, re-read for input at every point of the shared 2 s grid (D29; the deadline before it ends exactly at the threshold). Behind a shield no deadline runs and an idle pause keeps its flag; the idle time is read again when the shield lifts |
| Camera in use (Fill Light rule on) | CoreMediaIO `kCMIODevicePropertyDeviceIsRunningSomewhere` per device + listeners, hot-plug via the devices list; transport type filters virtual cameras | as built (WP6): `CMIOObjectAddPropertyListener` with a `nonisolated` C proc and client data (the block variant cannot be removed from Swift), hopping to main through `MainHop`; debounce 1 s on / 3 s off here, so Fill Light adds no delay of its own | Signals | `isCameraInUse`; no TCC prompt expected [HW: H-F1] |
| Playing video | `IOPMCopyAssertionsByProcess` (≈ 1.2 ms, no permission) [VERIFIED] | main, on the same triggers as full screen, including Signals' 2 s watch while boosted with a full-screen or "while playing" rule on. As built and kept (WP14 decision, D28): the watch is Signals' own timer (`DeadlineTimer` on `TimeSource.sleep`), not a ride on the drift-check tick; the drift check runs per display inside Boost and the full-screen state is one system-wide read in Signals. As built (energy pass, D29): each tick waits for the next point of the shared 2 s grid of the one time source, the points the hang watchdog's pings and the drift checks wait for too, so it shares their wake-up instead of costing one of its own; the first tick comes at most 2 s after the watch starts (`WatchGridTests`). Not while shielded | Signals | `FrontmostApp.isPlaying`, `fullScreenVideoDisplays` |
| Full screen | `CGWindowListCopyWindowInfo` bounds/layer/PID/alpha (no Screen Recording needed; names withheld) [VERIFIED] | `@concurrent` snapshot (≈ 2 ms) → main | Signals | `fullScreenDisplays`, and with the owner's assertion `fullScreenVideoDisplays` |
| Schedule boundary (**boost-only**) | one `TimeSource.sleep` until the next boundary, `SystemEvent.scheduleBoundary` | main | Signals | re-reduce. **As built, two owners on purpose** (WP13 ruling): Signals' timer runs only while a display boosts (D30), so it cannot end a schedule pause that made every display neutral; the engine keeps its own boundary deadline while the master is on (§4.9, `BoostEngine.armSchedule`). A boundary that both see costs one extra coalesced reduction. |
| Hang watchdog | `DispatchSourceTimer` on its own utility queue | `nonisolated final class HangWatchdog`, `{ @Sendable in … }` handler | Boost (WP5) | §7.4 |
| Signals (TERM/INT/HUP) | `signal(SIG_IGN)` + `DispatchSource.makeSignalSource` on a **dedicated serial queue** (not main) | nonisolated `{ @Sendable in … }` | Boost (WP5) | ledger baselines, main-actor stop with a 1 s timeout, exit (§7.4) |

Each such file starts with a header comment naming its thread, and has one test that invokes the entry point from a background queue (`<Source>OffMainTests`): the CMIO block, the IOPS callbacks, the reconfiguration callback, the thermal and Low Power observers, the hang watchdog's handler and the signal handler.

### 7.2 Conflicting apps

A pure matcher (`ConflictMatcher`, Policy) over `NSWorkspace.runningApplications` (0.04 ms, no permission [VERIFIED]), re-read on its launch/terminate notifications and on every change of the list itself (KVO: agent and accessory apps post no notification, §7.1):

1. exact bundle ID, case-insensitively, plus its automatic `-setapp` twin;
2. vendor prefixes for families whose IDs vary;
3. executable names for bundle-less command-line tools (an `NSApplication` without a bundle still appears, with a nil bundle ID and its executable URL [VERIFIED]);
4. optionally, a signing team ID read from the bundle on disk, to confirm a prefix match.

Our own bundle ID, helper and extension IDs are ignored by the matcher; a second Overbright process is handled before that, by the single-instance check (D27). Names are never matched; the UI shows `localizedName` at runtime.

| Class | Meaning | Action |
|---|---|---|
| S1 Booster | Another EDR trigger plus its own table or overlay boost (12 entries) | Suspend every display before boosting; banner "‹App› also changes display brightness". **No Continue Anyway on the table mechanism**: multiplying another booster's table compounds the two (and, if read-back clamps, flattens the top of the tonal range). The banner offers **Use Compatibility Mode** instead, which writes no table, and Quit ‹App› guidance. |
| S2 Continuous gamma writer | Colour-temperature or dimming tools that re-assert tables (4 entries) | Suspend before boosting; banner with Continue Anyway; suggest Night Shift as the warm-light alternative |
| S3 Conditional | Tools that write tables or boost only in some modes (4 entries) | Info chip only; suspend a display at the **first** drift attributed to it |
| S4 Benign | Overlay shades, resolution and preset managers (3 entries) | Diagnostics only |

- **Use Compatibility Mode** (the S1 banner's action) switches the displays that can boost to the overlay and continues that booster for the session (`continueAnyway`); Policy lets an S1 app through only on overlay displays it was continued for. After a relaunch the banner asks again: an S1 continuation is never persisted [as built, WP1/WP10; confirmed by WP13].
- A drift stop attributed to an S1 booster offers **Use Compatibility Mode** too, never Continue Anyway, in the banner, the chip and the status menu (as built, WP14): continuing would clear the trip while both tables still run. Each also continues the booster, so the S1 rule lets the display through: the chip's switches its own display to the overlay, the banner's and the menu's every display that can boost.
- "Continue anyway" (S2, S3) lasts until that app quits or Overbright relaunches. Advanced ▸ Other apps offers a persistent "Always continue" per S2/S3 catalogue entry. The repair budget, the adoption budget and the oscillation detector stay authoritative either way: a continued app that keeps re-asserting trips the display within seconds instead of pumping the boost (§4.8).
- S1 ∪ S2 ∪ S3 is the "known table writer" set for the launch rescue: a non-base table while one of them runs belongs to that app and is never rescued.
- The catalogue lives in **one file**, `Sources/OverbrightPolicy/Conflicts/ConflictCatalog.swift`, holding identifiers only. It is the path-allowlisted exception of the D3 lint, and inside it only bundle-ID-shaped literals (`^[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)+$`) and the bundle-less executable names may match the denylist. Sources: Homebrew casks, the apps' own project files, Apple's App Store lookup API and local Info.plists. Guessed IDs seen in other projects are not shipped. Tests use synthetic IDs or entry ids (D3).
- **Drift attribution:** at an unexplained drift, a running S1–S3 app is named; otherwise a one-off libproc scan (≈ 14 ms off the main actor) looks for a culprit; otherwise the generic "Another app keeps changing the colors of ‹Display›".
- Calibration loaders (profile loaders of colorimeter software) are not catalogued; they write the profile's own curve, which the expected base already is, or are caught by the repair budget if they keep re-asserting something else.

### 7.3 Full screen, games, idle, camera, playback

- **Full screen** (ported from Cranny's `FullScreenDetector`, the owner's own MIT code, verified with a real full-screen transition on macOS 27): per display, a layer-0 window of a regular app (not ours, not the Dock) whose bounds equal the display's (±1 pt) while it is frontmost or the menu bar is absent; on a notched built-in, a window that covers the display below the notch band while the menu bar is absent; Split View when the union of two or more layer-0 windows covers ≥ 98 % with the menu bar absent. The menu bar window is matched by the WindowServer's PID, not by name; "absent" is sticky for 3 s to ride out hover. With "Displays have separate Spaces" off (`NSScreen.screensHaveSeparateSpaces`, read on every check), only the main display (at the origin of the global display space) has a menu bar, so the others never count it as absent: there the frontmost app's window is the only evidence, for an exact cover and, on a notched built-in that is not the main display, for one below the notch band (C-SIGNALS-5: without the second, a native full-screen app on such a built-in was never detected). Known limits there [as built, WP14]: a frontmost zoomed window counts too wherever its frame equals a full-screen one: one that fills such a display exactly (nothing reserves space on a display without a menu bar but the Dock) and, on that built-in, one that macOS keeps below the notch band (H-FS2 measures where its top edge sits), and Split View is never detected, since two tiled windows look the same without a menu bar to tell them apart. Debounced 0.6 s. While scaled and either full-screen rule is on, Signals' own 2 s watch also re-runs it (≈ 2 ms; its own timer by decision, D28), which catches borderless games.
- **Full-screen video:** a display is in `fullScreenVideoDisplays` when its full-screen window's owning PID holds a display-sleep assertion (read for that PID, not only the frontmost app). Beta until H-P1 confirms which browsers and players hold one while playing and release it on pause.
- **Games:** optional rule on the frontmost app's `LSApplicationCategoryType` being games (read from its Info.plist, no permission); Apple's Games launcher excluded.
- **Idle:** only for OLED displays with boost active; while a display-sleep assertion is held (video), idle does not count. Behind a shield (displays asleep, locked, screensaver, off the console) the 2 s input poll stops and the pause holds until the shield lifts [as built, WP14]. The poll waits for the shared 2 s grid (D29), at most 2 s per read [as built, energy pass].
- **Camera:** "Any camera" or "Built-in and USB cameras only" (virtual cameras and Continuity Camera also report "running"). No stream is opened, so no TCC prompt is expected; if the hardware session shows one, the rule becomes "manual only" (H-F1).
- **Locked screen:** while locked, the frontmost app is `loginwindow` and its windows sit at layers 2001/2004, so the full-screen heuristic ignores them [VERIFIED]; lock is handled by the lock signals.

### 7.4 Safety: launch, stop, quit, crash, hang, signals, rescue, Back to Standard

**Launch order** (the shell, before any display work; `AppDelegate`'s file header gives the same order): a Release build given a Debug-only switch exits with `EX_USAGE` (§8.5) → `ShellDefaults` → the composition root builds the services hub (no I/O; `--diagnostics` reads through it) → CLI modes (`--diagnostics`, `--monitor`, `--restore-gamma` run and exit here, before any service starts, any window opens or any preference is written) → **single instance** (D27: another Overbright process with our bundle ID and a different PID, and this launch is not wired to the simulated ports (`ports.fixture == nil`) → send it a reopen with `NSRunningApplication` / `NSWorkspace.open` of our bundle URL, then exit; test `secondInstanceHandsOverAndExits`) → **move to Applications** offer (DESIGN.md §12.4) → settings upgrade → controllers, router connection, status item, Dock menu and HUD → `LaunchGate` installs the signal handlers, runs the **launch check**, then starts the services in `ServiceStack` order (Displays → Triggers → Signals → FillLight → HotKeys → Updates → Intents → Boost; the check's outcome reaches the engine right before it starts, when the directory lists the displays) → QA hooks (Debug) → launch UI (§7.6). As built (WP13) the order is one data type, `LaunchSequence` (`LaunchOrderTests`), which runs right after the delegate has read what opened the app (§7.6), and the services' start and stop live in `ServiceRunner` (`LifecycleOrderTests`). The launch check reads the console state itself until Signals has started (`LaunchCheckSignals`, D27; `LaunchCheckSignalsTests`): the monitor's snapshot holds only a default before `start()`.

**Launch check** (`LaunchRescue`; always, before any other display work):
1. If the session is not on the console (`kCGSessionOnConsoleKey` false): skip everything, return `skippedNotOnConsole`, and run this check on `sessionDidBecomeActive`. As built (WP14): a return to the console between the skipped check and Signals' start posts nothing Signals hears (`SignalsMonitor` reads the session state when it starts), so the launch work runs the check again right before the engine starts when it was skipped, no deferred check is under way and Signals then says the session is on the console (`CompositionRoot.launchCheckBeforeBoost`, `LaunchCheckSignalsTests`); otherwise a leftover table would only trip the engine (`foreignTableAtLaunch`) and the boost marker would stay.
2. Read every online display's table and its profile base (read-only) and classify (D26).
3. Every display `matchesBase` or `foreign` → neutral. As built (WP5, accepted by WP13): a `foreign` table is never rescued, whether or not a catalogued writer runs: a per-channel curve is a calibration loader's or a warm-light tool's (baseline adoption accepts it too, §4.8), and no residue of ours can classify `foreign` (ours are uniform multiples, D26). If the boost marker is present, journal `launch.recoveredByWindowServer` (we died; macOS restored).
4. Any display `scaled` (up or down) or `invalid`, and a known table writer (S1 ∪ S2 ∪ S3) runs → it is theirs: show the conflict UI, touch nothing (`skippedBecauseTableWriterRuns`).
5. Otherwise **dirty-then-restore:** write the read-back table unchanged to one affected display (this marks our connection as a table writer), call `CGDisplayRestoreColorSyncSettings()`, re-read every display and **verify**: each must classify `matchesBase`, or at least be monotonic, start ≤ 0.1 and end ≥ 0.9 (`TableClassifier.isPlausibleRestore`). A display that fails (for example an all-zero table, which a third-party FAQ reports the global restore can produce) gets its profile base written explicitly (identity when the profile has no `vcgt`), and the outcome is `repairedInvalidRestore` with a journal entry. A display that still classifies `scaled` after that is a session-level foreign write: banner `foreignTableAtLaunch`, no boost on that display until it reads `matchesBase`.
6. Never call the global restore alone: from a process that wrote no table it does nothing on macOS 27.0.1.

**Stop order (every path).** Ramp to 1 → write each display's baseline → update the ledger → remove triggers and overlays → clear the boost marker.

**Quit.** A quit from inside the app (⌘Q, the panel, the menu, `NSApp.terminate`): `applicationShouldTerminate` returns `.terminateCancel` once, keeps Cranny's `LaunchGate` wait (≤ 3 s), runs the ramped `ServiceLifecycle.stop()` of every service in reverse order (Boost first) with a 1 s timeout, then calls `NSApp.terminate` again, which now returns `.terminateNow`. Not `.terminateLater`: while AppKit waits for `reply(toApplicationShouldTerminate:)`, neither the main dispatch queue nor the main actor is served, so no ramp step could run [VERIFIED in WP0a on macOS 27.0.1: a `DispatchQueue.main.async` block and a main-actor `Task` scheduled in `applicationShouldTerminate` never ran during the wait]. A quit Apple Event (`kAEQuitApplication`: another app, a script, the Dock, Activity Monitor, log out, restart, shut down) is never cancelled, so its sender never gets "User canceled" (-128) and a logout is never held up; it terminates at once and `stopNow()` writes the baselines without a ramp. That includes one that arrives while a user quit is stopping (its `LaunchGate` wait or its ramped stop): only a second quit from inside the app waits for the first (`aQuitEventWhileStoppingTerminatesAtOnce`). `applicationWillTerminate` calls `stopNow()` as the synchronous fallback: it writes the ledger baselines without a ramp (nothing if the async stop already did). Quit does not call the global restore; WindowServer's teardown restore follows our exit anyway. As built: `QuitFlow` (the state machine, `QuitTests`) over `ServiceRunner.stop(within:)`, whose 1 s limit holds even when a service's stop never returns (the wait races the stop instead of joining it); the services that did not finish get `stopNow()` in `applicationWillTerminate`. A stop that arrives while a service's `start()` is suspended (the engine awaits its strategy cache before it counts as started, and ignores a stop until then) reaches that service too early, so `ServiceRunner.start` gives it `stopNow()` once its start returns and starts nothing after it (`aStopDuringAStartStopsThatServiceOnceItStarted`). This is the design WP0a verified and WP13 kept; nothing in it waits inside `applicationShouldTerminate`.

**What macOS does when a process dies** (static inspection of macOS 27.0.1's display server; `kill -9` run is H-K1):

| Event | Scaled table survives? |
|---|---|
| Quit, crash, SIGKILL, jetsam, removal of a MenuBarExtra | No: WindowServer restores every online display when the process's connection dies |
| **Another** table-writing process quits or crashes (f.lux, another booster, a `--restore-gamma` run) | No: the same restore resets **every** online display to its base, ours included → we notice within 50 ms (`appTerminated`) or at the next drift check and reapply with a ramp |
| Death while a display is captured (`CGDisplayCapture`) | Yes, until the next reconfiguration, preset change or our launch rescue (rare; we never capture) |
| A hung but living process | Yes: the connection is alive → our hang watchdog |
| Logout, reboot | No |
| Sleep/wake, display sleep, lid close/open | The system resets our table (the boost is lost, not left behind) → we re-arm |
| Fast user switching | Our process and table stay; we un-scale on resign and write nothing while off the console |
| A foreign tool writing at session level through private API | Yes, even after our restore → the UI explains (preset change, logout or reboot) |

**Hang watchdog** (`HangWatchdog`, a `nonisolated final class`). While any display is scaled (as built, WP14: from the write that marks the first display in the safety ledger to the write that empties it, switched inside the ledger lock, so a ramp from neutral, a dim and a reapply after a reset are guarded from their first step; phases lag behind ramp steps), a `DispatchSourceTimer` on its own utility queue pings the main queue every 2 s (`DispatchQueue.main.async { pong = now }`, stored under a lock). As built (energy pass, D29): every ping after the first waits for the next point of the shared 2 s grid of `writer.time` (`HangWatchdog.gridStep`, `nextPingDelay`), so the ping and its pong share the wake-up of the other 2 s activities; while a ping waits for its answer the timer wakes at the earlier of its timeout deadline and the next grid point, so a new ping follows every answer within 2 s and a stall is still caught 3–5 s after it starts. If a ping has had no pong for 3 s, it takes the ledger lock, **increments `hangEpoch`**, writes every ledger baseline through `TableWriter.writeBaselines(fromLedger:)` and records `hangFired`. Because `TableWriter` holds the same lock across every write and checks the epoch stamp, a scaled write already in flight lands before the baselines, and every scaled write queued behind the stall is refused until the engine re-gates (§4.6). When the main thread returns, the engine journals `hang.restored` and re-gates; a running calibration ends first (as built, WP14), and its session's own epoch stamp keeps any queued sweep step from scaling again until a new session starts. CG transfer calls are plain messages to WindowServer; WP2 confirms they are safe from a background thread [U]. Never `DispatchQueue.main.sync`. Help text: "If Overbright ever stops responding, Force Quit it; macOS restores your displays at once."

**Signals.** `SignalHandlers` installs `signal(SIG_IGN)` and `DispatchSource.makeSignalSource` for TERM, INT and HUP on a dedicated serial queue. On a signal it bumps the hang epoch and writes the ledger baselines through `TableWriter.writeBaselines(fromLedger:)` at once (as built, WP5: the epoch keeps the ramped stop that follows from re-scaling a restored display), then asks the main actor for the normal stop (`ServiceRunner.stop`, every service in reverse) and waits at most 1 s, then `exit(0)`. A hung main thread therefore no longer makes `kill` ineffective. The composition root builds the handlers over the engine's writer, the launch work installs them, and the shell keeps them for the life of the process (their `deinit` cancels the sources but does not restore the earlier dispositions).

**Back to Standard.** `returnToStandard` (⌃⌥⌘0 by default, the Dock menu, the intent): master off within a 120 ms ramp, dims undone, baselines written, triggers removed, stored levels kept. It never depends on the panel, the policy or a fresh reading.

**`--restore-gamma`** runs the launch check's dirty-then-restore and verification on every display regardless of the boost marker, prints the result and quits. Its own exit then makes WindowServer restore every display once more, which is harmless. It is the documented Terminal recipe in the README.

**Auto-brightness interplay (built-in XDR, macOS 26+).** A developer-forum report describes a persistent bad picture after toggling auto-brightness while a table is applied; only a preset change cleared it, and it survived app termination. No table logic can fix that state, and no heuristic can catch it before it happens (the state is created at the moment of the toggle). Overbright therefore (1) shows the `autoBrightnessInteracts` advisory in Displays; (2) offers "Display looks wrong?" in Help (change the preset and back, or log out); (3) returns every display to Standard before calibration, whose checklist asks the user to change these settings (DESIGN.md §9). The v0.1 "fade out on a 30 % headroom jump" heuristic is removed: ordinary brightness-key presses and ambient changes move H that much, so it fired during routine use and had no defined way back. Whether the state reproduces on the owner's M4 Max / 27.0.1 is H-A1.

### 7.5 Compatibility mode (technique C)

- **When:** automatically suggested (advisory `compatibilityModeAdvised`, mechanism `automatic` → overlay) when `CompatibilityModels.tableWritesIgnored(MachineIdentity.current())` is true (`hw.model` Mac17,5 and Mac17,6–Mac17,9 with macOS ≥ 26.3, where table writes return success, read back correctly and have no visible effect; developer-forum reports with feedback numbers); when the calibration answer "Did the screen get brighter?" is No; by choice in Settings ▸ Displays ▸ Method; and offered as **Use Compatibility Mode** when an S1 booster runs (§7.2) or after two failed tries (DESIGN.md §12.2).
- **How:** one borderless, click-through window per display covering the whole frame including the menu bar, level `.screenSaver`, all Spaces, full-screen auxiliary, `sharingType = .none`. Its layer is a headroom-tagged `CALayer` colour on macOS 26+ (or a 4 × 4 px clear-only `CAMetalLayer` drawable stretched with nearest filtering on 14/15) with `compositingFilter = "multiplyBlendMode"`. The overlay is its own EDR request, so no trigger window exists in this mode. **Request first, then boost:** show at factor 1 with `headroomRequest = target ÷ 0.97`, wait for the gate, then ramp `setFactor`. A factor below 1 dims without any EDR request, so dimming works on these Macs too. The overlay goes to factor 1 at the begin phase of every reconfiguration and is removed at once if AppKit moves it to another screen (§4.3). The multiply-overlay idea is credited to xdr-boost (MIT); our code is independent.
- **Costs and limits** (say them in Settings): the pointer is not brightened (it is drawn on its own hardware plane); Mission Control and Space switches can flicker; every recomposition under the overlay costs a full-screen blend; full-screen video and games may lose direct-to-display scan-out; screen recordings through ScreenCaptureKit may show the overlay. If H-C1 fails on a Mac, Compatibility mode there becomes "dim only".
- The full-screen detector ignores our own PID, so the overlay never pauses itself.

### 7.6 Windows and surfaces (all owned by `OverbrightAppShell` except triggers, overlays and Fill Light)

| Window | Class and recipe | Level / behaviour | Notes |
|---|---|---|---|
| Status item | `NSStatusItem` square, template image drawn in code | — | Accessibility label "Overbright, ‹state›". Panel anchored to the button's window frame, never `NSStatusBar.system.thickness` (22 pt while the bar is 30 pt on macOS 27). The frame counts only once it overlaps a screen (`PanelPlacement`): on macOS 27.0.1 MenuBarAgent places the item after launch, and until then the in-process window reports (0, 0, 38, 0), (0, −33, 38, 33) and (0, 1440, 38, 33) [VERIFIED in WP0a]. The launch UI waits up to 1 s for a placed frame; an unplaced one puts the panel at the top-right of the main screen's visible frame, and the open panel follows the button's window (`NSWindow.didMoveNotification`, `didChangeScreenNotification`). **Visibility check** 3 s after launch and on every screen change: the button's window exists, `isVisible`, its `occlusionState` contains `.visible`, and its frame lies inside `NSScreen.auxiliaryTopLeftArea` or `auxiliaryTopRightArea` on a notched screen (not behind the notch) → `AppControl.iconVisibility`. |
| Panel | `NSPanel(.borderless, .nonactivatingPanel)` (style passed at init), `isFloatingPanel` then level `.popUpMenu`, `hidesOnDeactivate = false`, `becomesKeyOnlyIfNeeded`, `canBecomeKey` override, hosting view with `acceptsFirstMouse` | closes on outside click, Esc, status-item click | Cranny's `NotchPanel` patterns. Keyboard focus on open only when opened by keyboard or VoiceOver. |
| HUD | non-activating `NSPanel`, `ignoresMouseEvents = true`, `sharingType = .none` | `.statusBar`, all Spaces, full-screen auxiliary | DESIGN.md §6. Never two at once. |
| Keep-this-level prompt | non-activating `NSPanel` in the HUD's place that can become key (Return = Keep), `sharingType = .none` | `.statusBar` | DESIGN.md §6; the revert itself is the engine's deadline (§4.9). |
| Icon-not-visible window | small `NSWindow` (Cranny's alert-window recipe) | normal, activates the app | DESIGN.md §4.4; at most once per app version. |
| Help | small `NSWindow` hosting PanelUI's `HelpView`, anchors per entry | normal | DESIGN.md §12.6; opened from the panel, the menu, Settings and Welcome; needs no other window. |
| Trigger windows | `WindowRecipes.makePanel` (Triggers): borderless non-activating, clear, no shadow, `ignoresMouseEvents = true`, `.screenSaver`, `[.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary, .canJoinAllApplications]`, `sharingType = .none`, `hidesOnDeactivate = false`, `canHide = false`, not in the Windows menu, `animationBehavior = .none`, accessibility element off; observes occlusion and screen changes | below the lock shield, so locking hides it and headroom drops | 1 pt. Layer-hosting view (`view.layer = layer` before `wantsLayer = true`). Counted for `triggerWindows`. |
| Compatibility overlay | same recipe, full frame | same | §7.5 |
| Fill Light | same recipe, full frame, one per chosen display, frame-shaped `CAShapeLayer` (even-odd, rounded inner corners); holds `OwnEDRSurfaces` while the frame requests EDR headroom (ordered in, on a display with extra range; an SDR frame holds nothing) [WP7 as built] | same | EDR colour when headroom allows: value = brightness × min(0.97 × H, 2.0), else ≤ 1.0; the colour is tagged at min(2 ÷ 0.97, potential), at least 1.01 [WP7; H-F tag grant in WP16]. Warmth → colour by a pure CCT function (6 500–3 000 K) in linear sRGB. Acts on Signals' debounced `isCameraInUse` with no delay of its own. Ignored by the full-screen detector. `--qa-simulate`: `SystemFillLightSurfaces(mode: .sdrStandIn)`, never EDR. |
| Settings | Cranny's `SettingsWindowController` (AppKit `NSWindow` + `NSHostingController`, `sizingOptions = []`) | normal | 860 × 620 default, 780 × 560 minimum; released on close, session kept; handles ⌘Q (Quit) and ⌘Z (Undo Reset). |
| Welcome | Cranny's `WelcomeWindowController` (container view around the hosting view) | normal | 640 × 480; close counts as Skip; the before/after card registers with `OwnEDRSurfaces`. |
| Calibration | `NSWindow`, borderless full-screen on the display under test, our colour space set to the screen's (`NSScreen.colorSpace`) so code values reach the framebuffer unchanged; black surround | `.screenSaver − 1` | Esc always restores at once; registers with `OwnEDRSurfaces`. As built (WP14): whether the displays are simulated is read from the services (`FakeDisplayDirectory`, what `--qa-simulate` wires), never guessed from the screen list, because fixture IDs 1–6 can equal real screen numbers: a simulated display always gets an ordinary titled window (normal level, no colour space, no occlusion watch); a real display without an `NSScreen` of its own begins no session and shows the "can't be calibrated right now" step (`CalibrationWindowTests`). |

**Launch UI** (`applicationDidFinishLaunching` and `applicationShouldHandleReopen`): a launch is a **login launch** when the open-application Apple event carries `keyAELaunchedAsLogInItem` (whether `SMAppService.mainApp` sets it is verified in WP0b [U]; fallback: the session dictionary still reports `kCGSessionLoginDoneKey` false, or system uptime is under 120 s [HW: H-L2]). Login launches and launches by an intent or URL show nothing. As built (WP13): the delegate reads the current Apple event first thing in `applicationDidFinishLaunching`, before `LaunchSequence` runs (AppKit dispatches the open-application event only after `applicationWillFinishLaunching`, where the current event is nil [VERIFIED on macOS 27.0.1 with a probe app launched through LaunchServices]); it logs `launch opening: <login|user|url> (event <class>/<id>, login-item flag …, login done …, uptime … s)` and journals `launch.<login|user|url>` with the event's class and ID when the launch UI decides, so H-L2 can tell the flag from the fallback. A URL launch is one whose first Apple event is a get-URL event, or during which `application(_:open:)` delivers a URL before the launch UI decides; an intent launch is one during which `IntentRouter.requestCount` (intents, Focus deliveries and control URLs, never the launch-time Focus read) rises before it decides. The launch UI decides once the status item is placed (at most 1 s) and at least 0.5 s after launch, so the request that launched the app has arrived [HW: H-AI-1 confirms Shortcuts' timing]. Every other launch, and every reopen (Finder, Spotlight, `open`, the Dock icon, a second instance's hand-over), shows: Welcome while it is unfinished; else the panel under the icon when `iconVisibility == .visible`; else Settings ▸ General. The visibility check runs 3 s after launch and only then follows occlusion and screen changes (an earlier check, before MenuBarAgent places the item, reads "not visible"). Tests: `coldLaunchShowsUI`, `loginLaunchIsSilent`, `ReopenTests` (`theFirstEventIsReadOnceLaunchingFinished`, `theLoginItemFlagIsReadFromTheOpenApplicationEvent`).

### 7.7 Out-of-process surfaces: App Intents, Focus filter, Controls

- **Intents (v1, app target):** `ToggleOverbrightIntent` ("Turn Overbright On or Off"), `TurnOnOverbrightIntent`, `TurnOffOverbrightIntent`, `SetExtraBrightnessIntent(level: ExtraBrightnessEntity = preset or multiplier, display: DisplayEntity?)`, `DimDisplaysIntent(percent: 2…99, display: DisplayEntity?)`, `PauseOverbrightIntent(duration)`, `ResumeOverbrightIntent`, `GetOverbrightStateIntent → ReturnsValue<Bool> & ProvidesDialog` (on/off plus the panel's value text, e.g. "Bright room · ×1.29" or "Dimmed · 25%" (the locale's percent: "25 %" in Russian, German and French)), `ReturnToStandardIntent` ("Back to Standard"); `DisplayEntity` + `DisplayQuery` keyed by `DisplayKey` (names for presentation only). All: `supportedModes = .background` (26+, computed `@available` static), `allowedExecutionTargets = .main` (27+; this is why the minimum toolchain is Xcode 27), `@MainActor perform()` that is **one line** forwarding to `IntentRouter`. Exact titles, summaries and parameter names: DESIGN.md §12.8.
- **Router seam:** `OverbrightApp.init` creates `IntentRouter()` (no arguments) and registers it with `AppDependencyManager.shared.add(dependency:)`, so an intent that launches the app can resolve it before `applicationDidFinishLaunching`; `CompositionRoot` later calls `router.connect(boost:displays:signals:)`. Every router method waits for the connection and for `BoostStatus.isReady` (at most 5 s, then fails with a localized "Overbright is still starting" error); as built (WP14) the router observes the readiness only while an intent waits, so the engine's status changes cost it nothing otherwise. An intent that turns Overbright **on** overrides "Launch, keep off" (explicit user action); the launch check runs first. Pause Overbright hands the router the duration as plain seconds (`pause(forSeconds:)`; `Duration.seconds(Double)` traps on an infinite, not-a-number or huge value a crafted shortcut can pass): negative is no pause, longer or infinite is 24 h (`longestPause`), not a number is the default hour (WP14). Get State's dialog joins its sentences with the Intents catalog's two-sentence joiner, so Japanese and Chinese get no space after "。".
- **Focus filter:** `OverbrightFocusFilter: SetFocusFilterIntent` with `mode` (Leave alone [default] / Off / On) and `level` (as built, WP8: a preset only; `FocusDirective.on(level:)` carries one slider position, and a multiplier is a different position on each display). `perform()` calls `IntentRouter.focus(_:)`, which calls `SystemSignals.setFocusDirective(_:)` (the sink port; Signals persists the last directive). At launch the app reads `OverbrightFocusFilter.current`, because v1 has no extension to receive it while Overbright is quit. No entitlement is needed.
- **Shortcuts phrases:** an `AppShortcutsProvider` in the app target (a provider in a package is silently dropped [VERIFIED]) with two phrases using `\(.applicationName)`; `App/AppShortcuts.xcstrings`.
- **Localization:** extracted metadata stores bare keys and is localized against the bundle that carries it, so intent strings live in `App/Localizable.xcstrings`, which `lint-copy.py` and `validate.py` include. H-AI-2 checks German and Russian.
- **Testing:** the adapters cannot be unit-tested (the app target has no test target), so they stay one-line forwards; `OverbrightIntentsTests` tests `IntentRouter`, and `OverbrightChannelTests` the channel and URL parsers. The adapters are verified by the metadata smoke check (`smoke.sh` lists every intent and the Focus filter in `Metadata.appintents`) and by H-AI-1.
- **Controls (dormant, D18):** target `OverbrightControls` (`Controls/`, macOS 26, sandboxed, entitlements `app-sandbox` + `temporary-exception.shared-preference.read-only = [app.overbright.Overbright]` and nothing else), `StaticControlConfiguration(kind: "app.overbright.Overbright.BoostToggle")` with a `ControlWidgetToggle` using `sun.max` / `sun.max.fill`; the shared `Shared/BoostControlIntent.swift` (`SetValueIntent`, split by `OVERBRIGHT_APP` / `OVERBRIGHT_CONTROLS`). It links only `OverbrightControlsKit` (= `OverbrightChannel`). `scripts/build.sh` removes `Contents/PlugIns/OverbrightControls.appex` and re-signs unless `CONTROLS=1` (default 1 when `TEAM_ID` is set); `smoke.sh` checks that the PlugIns folder matches the flag. Project-level `COPY_PHASE_STRIP = NO` is required for zero warnings with an embedded appex [VERIFIED].
- **State channel (D25, only with the control):** `OverbrightChannel` holds the pack/unpack of the notify state word for `app.overbright.Overbright.state` (valid bit, on, level ‰, generation), the preferences snapshot, the token and the URL route parser (`URLRoute.parse(_:)`). One publish point (`ControlStatePublisher` in `OverbrightIntents`, started by the composition root, observing `BoostControl.status`) writes the word → the snapshot → `ControlCenter.shared.reloadControls(ofKind:)`; `reloadAllControls()` at launch and quit. The extension reports "off" when no process with our bundle ID runs. URL `overbright://control?set=off` is always accepted; `set=on` needs the random token the app keeps in its own preferences; both still go through the policy.
- **URL scheme** `overbright` is registered in every build; besides the control route it accepts `overbright://settings[/<pane>]`, which opens Settings. Nothing else.
- **Without the control:** Help and the Welcome "Where to find it" step explain the system's Run Shortcut control: make a shortcut with Overbright's "Turn Overbright On or Off" action, then Control Center ▸ Edit Controls ▸ Run Shortcut.

---

## 8. Concurrency, persistence, logging, diagnostics, build and localization

### 8.1 Concurrency model (Swift 6, strict)

1. **Core, Policy and Channel are nonisolated; everything else is `MainActor` by default.** UI, engine state machines, AppKit windows, NSScreen reads and settings are on the main actor. `NSScreen` and `CAMetalLayer` are not annotated in the SDK, so the compiler will not stop an off-main read: keep them on main by convention, enforced by review and `dispatchPrecondition(condition: .onQueue(.main))` in Debug at every entry point that reads them.
2. **Every entry point the system may call off the main thread is explicitly nonisolated.** Under `defaultIsolation(MainActor)`, an un-annotated closure or `@objc` method is inferred `@MainActor`, and the compiler inserts an executor check at its entry: called from another thread it **traps at runtime** before any hop inside it can run. It compiles without a diagnostic. [VERIFIED with Swift 6.4, `-default-isolation MainActor`, macOS 14 target: a `DispatchSourceTimer` handler on a utility queue and a main-actor `@objc` notification observer posted from a background thread both crash with SIGTRAP; a `{ @Sendable in … }` handler and an observer in a `nonisolated` class run fine.] So: C callbacks are `nonisolated static` functions with context through `Unmanaged.passUnretained(...).toOpaque()`; closures handed to Dispatch, CoreMediaIO, IOKit or `NotificationCenter` without `queue: .main` are `{ @Sendable … }`; selector-based observers live in a `nonisolated` class or use the block API; glue that needs more lives in nonisolated Core. Inside, hop with `DispatchQueue.main.async` or `Task { @MainActor in … }`. Where the API can deliver on main, deliver on main: `NotificationCenter`/`DistributedNotificationCenter` with `queue: .main`, CMIO listeners with `DispatchQueue.main` as the listener queue, run-loop sources added to the main run loop; `MainActor.assumeIsolated` only there, with a comment. `HangWatchdog` and `SignalHandlers` are `nonisolated final class`es. Every such entry point has a test that calls it from a background queue (§7.1).
3. **Leave the main actor explicitly** with `@concurrent` functions: HLG still writing and verification, libproc scans, window-list snapshots (≈ 2 ms each), JSON encoding of self-test logs, IORegistry walks at reconfiguration. With `NonisolatedNonsendingByDefault`, a plain `nonisolated async` function still runs on the caller's actor.
4. **The only background executors that touch displays** are the hang watchdog's utility queue and the signal queue, both only through `TableWriter.writeBaselines(fromLedger:)`, the nonisolated `Sendable` `GammaPort` and the `SafetyLedger` (an `NSLock`, held across each write so the order of writes is the order of lock acquisition; the hang epoch lives under the same lock). `FakeGammaPort` is lock-protected the same way.
5. **No repeating timers.** Every periodic activity is a stored `Task` with `TimeSource.sleep(for:)` (10 % tolerance, at most 1 s as built in WP14), cancelled on stop: gate polls, poll bursts, ramps, the drift check, the keep-alive (T3), deadlines (pause, auto-off, schedule, idle, low-level confirmation). The hang watchdog's `DispatchSourceTimer` is the exception, because it must run when the main actor is stuck.
6. No `DispatchQueue.main.sync`, no semaphores waiting on the main thread, no Combine. Observation for UI; Cranny's `observe(_:onChange:)` for non-view code.
7. `@unchecked Sendable` only for lock-protected boxes with the argument in a comment.

### 8.2 Persistence

| What | Where | Format | Notes |
|---|---|---|---|
| Preferences | `UserDefaults` standard domain, keys `overbright.<namespace>.<name>` | JSON per key (`SettingsStore`) | `SettingsUpgrades` revision 0; bump with the first changed default after a release. Tests use `InMemoryDefaults`; no code creates a preferences suite except `QAHooks+Defaults.swift` (lint test). |
| Boost marker | `engine.boostMarker` | JSON | Diagnostic record, excluded from Reset All. |
| Strategy cache | `~/Library/Caches/app.overbright.Overbright/strategy-cache.json` | `JSONDocumentFile` | Key: display UUID + `kern.osversion`: winning rung, failure record (for the two-arm replacement rule), lowest ready headroom, highest granted headroom (WP14, DESIGN.md §12.1's grant sentence). Only the running build's records are read, so `attach(file:osBuild:)` drops the others and writes the pruned map back once (as built, WP14). Safe to delete. |
| HLG stills | `~/Library/Caches/app.overbright.Overbright/hlg-still-v1-*.mov` | QuickTime | Verified before use, versioned name. |
| Self-test logs | `~/Library/Application Support/app.overbright.Overbright/SelfTest/<ISO date>.json` | `SelfTestReport` | Last 10 kept. Saved elsewhere only through a Save panel. |
| Calibration | inside `DisplayPreferences.calibration` | JSON | Per display UUID; carries the OS build, mechanism, potential and an optional colorimeter value; ignored (domain `.encoded`, no nits) when any of them no longer matches, and re-offered. |
| Focus directive | Signals, `overbright.engine.focusDirective` (a record, not a preference) | JSON | The last directive from the Focus filter; read at launch together with `OverbrightFocusFilter.current`. |
| Update check cache | `~/Library/Caches/app.overbright.Overbright/updates/` | Cranny's | Only when configured. |
| Controls snapshot and token | standard preferences domain via `CFPreferences` | plist | Only with `CONTROLS=1`. |

### 8.3 Logging and the journal

- `os.Logger`, subsystem `app.overbright.Overbright`, categories (`LogCategory`): `app, settings, storage, updates, onboarding, displays, gamma, trigger, engine, policy, signals, conflicts, fillLight, hotKeys, intents, menuBar, panel, diagnostics, selfTest`.
- `.error` for failures with context, `.info` for state transitions (every phase change, rung change, interlock clamp, repair, adoption, trip, rescue), `.debug` for poll samples (only with Advanced ▸ Detailed logging). Codes and numbers `.public`; display names and app names `.private`. No `print`.
- `DiagnosticsJournal`: an in-memory ring of the last 500 `JournalEvent`s (codes, display keys, numbers; never names or paths). It feeds Copy Diagnostics and the self-test log. Stable codes such as `gate.ready`, `gate.preHeld`, `rung.escalated`, `interlock.clamped`, `interlock.refusedStaleEpoch`, `watchdog.drift`, `watchdog.reset`, `drift.reapplied`, `baseline.adopted`, `baseline.foreign`, `adoption.unexplained`, `repair.trip`, `flicker.trip`, `hang.fired`, `hang.restored`, `launch.rescued`, `launch.repairedInvalidRestore`, `launch.recoveredByWindowServer`, `launch.notOnConsole`, `launch.secondInstance`.
- Live watching for the hardware session: `log stream --level info --predicate 'subsystem == "app.overbright.Overbright"'`.

### 8.4 Diagnostics and Self-Test

**Diagnostics report** (`DiagnosticsReport`, AppShell; the same builder serves `--diagnostics <file|->` and Advanced ▸ Copy Diagnostics, the latter without bundle facts). It is **read-only**: it may read tables, profile bases and EDR values, never write, arm or open a window.

| Key | Content |
|---|---|
| `app` | version, build, bundle id, signing (ad-hoc / team), `CONTROLS` |
| `machine` | `MachineIdentity` (`hw.model`, `kern.osversion`, OS version), `compatibilityModeAdvised` |
| `preferredLanguages`, `mainPreferredLocalizations`, `resourceBundles`, `mainMenu` | as in Cranny (smoke reads them) |
| `designString.ru` | a Design key (a verdict sentence) looked up in Russian (catalog wiring check) |
| `displays` | per display: key, name, built-in, virtual, mirrored, gamma capacity, **table class against the profile base** (and ratio), table max and mid entry, whether the profile has a `vcgt`, potential, current, reference, supports PQ, panel peak / frame average / min nits, SDR max, `backlightMilliNits` (built-in, for H-N1), panel class, verdict, advisories, boost enabled, mechanism, effective domain, cached rung, lowest ready headroom, calibration outcome and validity |
| `strategyCache` | entries |
| `settingsRevision`, `nonDefaultSettings` | keys only |
| `conflicts` | running catalogue matches (entry IDs and severity; names omitted) |
| `signals` | power source and percent, Low Power, thermal, locked, on console, frontmost bundle ID, `isPlaying`, `isGame`, full-screen and full-screen-video displays, camera in use, HDR suppression, Focus directive |
| `menuBarIcon` | `iconVisibility` |
| `boostMarker` | present / absent |
| `journal` | last 500 events (Copy Diagnostics only) |
| `services` | the services that start and stop, in start order (as built, WP13: shows the wiring) |
| `simulatedFixture` | the `--qa-simulate` fixture, null on real ports |
| **`gammaWrites`**, **`triggerWindows`** | `GammaPort.writeCount`, `TriggerFactory.openWindowCount`; smoke asserts both are 0 |

As built (WP13): `strategyCache` and each display's `cachedRung` / `lowestReadyHeadroom` come from the engine's cache once it started (Copy Diagnostics) and from the cache file, decoded read-only and never set aside, for `--diagnostics`; `backlightMilliNits` is the built-in's `BrightnessMilliNits.value` (null on other displays and under `--qa-simulate`); the calibration's validity is Policy's `EligibilityClassifier.hasValidCalibration`; `signals` and `conflicts` are the real ones (no placeholders remain). The inputs are built by `DiagnosticsReport.Inputs.of(_:forClipboard:)`.

**Self-Test** (Advanced ▸ Run Self-Test…, DESIGN.md §10): for each chosen display, with the master held off and the user's consent, it arms the ladder from the top (ignoring the cache), records H at 10 Hz plus every event for `secondsPerStrategy`, and reports per rung: baseline H0, time to first movement, time to stable, held fraction, verdict (held / engaged but dropped / no engage / invalid baseline — the last when H0 was already pre-held). "Test every strategy" runs all available rungs (≈ 3 minutes per display); its bright rungs may show a tiny dot in an unmasked corner, which the sheet says. The self-test **never writes a scaled table**: it measures triggers only. Its triggers report occlusion and screen moves like an armed one (as built, WP14, §4.7): one that AppKit moves to another screen is removed at once, and a hidden or moved trigger ends that display's measurement (`SelfTestRunner.stop(_:)`, journal `selftest.displayStopped`) while the others go on; the same loss ends a calibration of that display (`.occluded`, `.displayGone`). It ends with every trigger removed and the display neutral, then saves a `SelfTestReport` JSON the user can save or copy. It is the in-app successor of the research probes and the main tool of `docs/HARDWARE-TEST.md`.

### 8.5 Launch arguments

| Argument | Build | Effect |
|---|---|---|
| `--off` | all | Start with the master off whatever the launch behaviour. |
| `--restore-gamma` | all | Dirty-then-restore with verification on every display, print the result, quit (§7.4). |
| `--diagnostics <file\|->` | all | Write the read-only report and quit before any service starts. |
| `--monitor [seconds]` | all | **Read-only.** Print one JSON line per display every 250 ms (key, **table class against the profile base and its ratio**, table max, mid entry, H, potential, reference) until Ctrl-C or the duration; starts no service, opens no window. `class != matchesBase` is what HARDWARE-TEST calls SCALED; it does not depend on whether read-back clamps. Used for the `kill -9` test. |
| `--qa-defaults-suite <name>` | Debug | Keep the run's settings in that suite (Cranny). Nothing of the run writes the app's own preferences domain: on the real ports too, the control's channel is silent (`CompositionRoot.controlOutlet(for:)`, WP14). |
| `--qa-simulate [fixture]` | Debug | Swap Displays, Triggers, Signals and every EDR surface (welcome card, Fill Light, HUD) for Core fakes and SDR stand-ins. Fixtures: §3.9. The switch alone selects the fakes (`CompositionRoot.simulatedFixture(for:)`, in every build): a missing name (the switch last, or another switch after it) or an unknown one is logged and falls back to `builtin-xdr-lid-open`, never to the real ports. **Mandatory for agents.** Exempt from the single-instance check (D27), decided on the ports actually wired (`ports.fixture != nil`). |
| `--qa-panel`, `--qa-menu`, `--qa-hud <level>` | Debug | Open the surface (the `--qa-panel` panel stays open on clicks elsewhere, and every close of the panel is logged with its cause); the menu's rows are dumped to `qa-trace.txt` next to `--qa-snapshot`'s PNGs (menus cannot be rendered), and the menu closes by itself after 3 s (a tracking menu holds the main actor, so the snapshot and `--qa-exit-after` waited for it forever, WP14); `--qa-hud` under `--qa-simulate` sets every display to that level as a shortcut would (`bright-room`, `max`, `-0.5`, …), so the HUD shows it; on the real ports (a Debug launch without `--qa-simulate`) it only opens the HUD with its generic level change and sets no display, like `--qa-script`, which runs only over the simulated ports (`QAHUDTests`). |
| `--qa-script "<steps>"`, `--qa-status <file>` | Debug | Run a scenario over the simulated ports once the engine is ready (`ScenarioScript`: on/off/levels/steps, guards, shields, events, conflicts, `wait`, `dump <label>`, `panel open\|close`, `loop`, `quit`; refused without `--qa-simulate`); each `dump` appends one JSON line (symbol, banner sentence, each card's chip in English, phases, gains, `gammaWrites`, `triggerWindows`) to the file. The same script drives `EndToEndScenarioTests`, the QA matrix and the soak (WP13). |
| `--qa-settings <pane[#row]>`, `--qa-welcome <step>`, `--qa-calibration <display>`, `--qa-help <anchor>` | Debug | Open at a place. Like the panel, the menu, the HUD and the snapshot, they wait for the launch work (every service started and `BoostStatus.isReady`, at most 10 s; `QAHooks.isLaunchWorkDone`), so the calibration window has an engine to ask and Help a registered shortcut; under `--qa-state`, whose scripted status is ready at once, the services' start decides (WP14). |
| `--qa-state <scripted status>` | Debug | Drive `PreviewBoostControl` with a named status from PanelUI's `ScriptedStatuses` (every chip, banner, phase and HUD of DESIGN.md §5.13), and show the rest of the state: its settings (levels, cap modes, linked levels, the per-display switch, calibration records) go into the run's suite after the ones any state writes are reset (`ScriptedStatuses.apply(named:to:)`; without `--qa-defaults-suite` the run keeps its settings in memory), Fill Light is a `PreviewFillLightControl` (`fillLightOn(named:)`), and the panel opens with the state's "Why?" row (`expandsWhy(named:)`). `QAScriptedStateTests` checks every state's readouts against its thumbs and HUD bars (WP14). A scripted status is ready at once (`isReady` true), so under `--qa-state` the surfaces wait only for the services to start (`ServiceRunner.phase`): Help, for example, shows once the shortcuts are registered (`QASnapshotTests.aScriptedStateWaitsForTheServicesToStart`). |
| `--qa-snapshot <dir>` [`--qa-snapshot-at <s>`], `--qa-exit-after <s>`, `--qa-update-check` | Debug | As in Cranny; the snapshot draws each window's SwiftUI root again in an opaque, non-vibrant host in the window's appearance, as the snapshot suites do (`cacheDisplay` cannot draw vibrancy or glass), and is taken 3 s after the launch work by default, 2 s with `--qa-hud` and 1 s for a HUD state, while a level HUD shows (WP14). Settings' sidebar and toolbar are not faithful in it (the selected row black without its label, no search field or pane title; `QAHooks+Snapshot.swift`): `SettingsChromeSnapshotTests` covers the sidebar. |
| `--qa-hang-main <delay>,<duration>` | Debug | After `delay` seconds, block the main thread for `duration` seconds (hang-watchdog test H-X1; the owner's session only). |
| `-OverbrightQAAppearance`, `-OverbrightQASnapshot`, `-OverbrightQASearch`, `-OverbrightQAKeyboardLayout <id>` | Debug | Settings-window defaults (Cranny), except `-OverbrightQAAppearance light\|dark`, which pins the whole app's appearance (`NSApp.appearance`: the panel, the HUD, Welcome, Help and Settings follow it, WP14); the last renders key caps in another keyboard layout for snapshots (DESIGN.md §16). |

A **Release build refuses every Debug-only switch** (`--qa-…`, `-OverbrightQA…`; `LaunchArguments.debugOnlySwitches`, `CompositionRoot.refusedSwitches`): before anything else it logs them, prints them to standard error and exits with `EX_USAGE` (64), so a command meant for the simulated ports never runs silently on the real ones; `make smoke` checks it on the Release build. QA hooks never synthesize input and never ask for permissions. `make run` passes `--off --qa-simulate builtin-xdr-lid-open --qa-defaults-suite app.overbright.Overbright.dev` unless arguments follow `--`; the owner's hardware session uses `scripts/run.sh -- --qa-defaults-suite app.overbright.Overbright.hw` with the installed copy quit (the single-instance check would otherwise hand over to it).

### 8.6 Xcode project and build settings

The project is hand-written (objectVersion 77, synchronized folders) with fresh object IDs `0B21E7` + 14 zeros + 4 digits: `0001` project · `0002` main group · `0003` Products · `0004` Overbright.app · `0005` App group · `0006` exception set · `0010` app target · `0011–0013` phases · `0020` build file · `0030` product dependency · `0040` package reference · `0050–0052` project configs · `0060–0062` target configs · `0070–0089` the Controls extension (appex target, `Controls` and `Shared` groups, "Embed Foundation Extensions" copy phase with `dstSubfolderSpec = 13`, item proxy, target dependency, configs, `OverbrightControlsKit` product dependency).

Kept verbatim from Cranny: `CODE_SIGN_IDENTITY = "-"`, `CODE_SIGN_STYLE = Manual`, `MACOSX_DEPLOYMENT_TARGET = 14.0`, `CLANG_WARN_UNGUARDED_AVAILABILITY = YES_AGGRESSIVE`, `LOCALIZATION_PREFERS_STRING_CATALOGS`, `DEAD_CODE_STRIPPING`, `ENABLE_USER_SCRIPT_SANDBOXING`, `SWIFT_COMPILATION_MODE = wholemodule` (Release), `CODE_SIGN_INJECT_BASE_ENTITLEMENTS = NO` (Release), hardened runtime, `GENERATE_INFOPLIST_FILE` + `INFOPLIST_FILE`, `STRING_CATALOG_GENERATE_SYMBOLS`, `SWIFT_EMIT_LOC_STRINGS`, `SWIFT_VERSION = 6.0`, `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, `SWIFT_APPROACHABLE_CONCURRENCY`, `SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY`, the `Info.plist` membership exception, `knownRegions` (en, Base + 34). New: `COPY_PHASE_STRIP = NO` (project), `SWIFT_ACTIVE_COMPILATION_CONDITIONS = OVERBRIGHT_APP` (app) / `OVERBRIGHT_CONTROLS` (extension), no `ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME` (system controls follow the user's accent; the warm colour is a Design token). As built (WP14): `SWIFT_TREAT_WARNINGS_AS_ERRORS` and `GCC_TREAT_WARNINGS_AS_ERRORS` = YES in both configurations of both targets (App/, Shared/ and Controls/ compile only in the Xcode build, where `check-modules.sh` cannot see them), and `ENABLE_DEBUG_DYLIB = NO` in both Debug configurations: a Debug binary split into `<name>.debug.dylib` and `__preview.dylib` links twice into one dependency file, and when the preview dylib finishes last the App Intents extraction finds no AppIntents dependency and skips the intents and the Focus filter (neither target has previews of its own). `ProjectLintTests` (Core) reads both from `project.pbxproj`. The project needs Xcode 27 (the intent declarations use `allowedExecutionTargets`); `scripts/lib.sh` sets `MIN_XCODE_MAJOR=27`.

`App/Info.plist`: `LSUIElement` true; `LSApplicationCategoryType` utilities; `NSHumanReadableCopyright` "Copyright © 2026 Overbright contributors. MIT License."; `CFBundleLocalizations` with all 35 codes; `NSSupportsAutomaticGraphicsSwitching` true (T2/T3 never wake a discrete GPU; each Metal device comes from `CGDirectDisplayCopyCurrentMetalDevice`, never `MTLCreateSystemDefaultDevice`); `OverbrightGitHubRepository` = `$(OVERBRIGHT_GITHUB_REPOSITORY)`, a build setting that is empty in the project (no update check, no network) and that `build.sh` passes from the environment ("owner/repo", checked); `release.yml` builds with `github.repository`, so every published release can offer the check, and smoke requires the value to be empty or owner/repo (and equal to the variable when it is set) (as built in WP14); `CFBundleURLTypes` scheme `overbright`. **No `*UsageDescription` key** and an empty entitlements dictionary (smoke fails on either).

### 8.7 Scripts and make targets

Ported from Cranny with the renames and these changes: `ensure_metal_toolchain` and every Metal CI step are deleted; `MIN_XCODE_MAJOR=27`; `build.sh` handles the Controls extension flag and its re-signing, fails when `Metadata.appintents/extract.actionsdata` is missing or empty ("run make clean"), rebuilds the package's resource bundles, their intermediates and the app from scratch when any String Catalog differs from the last build of that configuration (a SHA-256 stamp of every `*.xcstrings` in `build/DerivedData/catalogs-<configuration>.sha256`; an incremental build never clears a removed language's `.lproj`), and runs `check-lproj.py` (as built in WP14); `smoke.sh` asserts `gammaWrites == 0`, `triggerWindows == 0`, no usage strings, no entitlements except Debug `get-task-allow`, `LSUIElement` true, `CFBundleLocalizations` ⇔ `languages.json`, the Edit menu, the PlugIns folder matching `CONTROLS`, that `Contents/Resources/Metadata.appintents` lists every intent of §7.7 and the Focus filter (written by WP0a against the names in DESIGN.md §12.8, so WP8 never edits `scripts/`), that a Release build refuses `--qa-simulate` with exit 64 (it passes `--qa-defaults-suite` only to a Debug build, recognised by its `get-task-allow` entitlement), and, as built in WP14, that every translation ships: `check-lproj.py` requires, for every catalog (package tables in `OverbrightKit_<T>.bundle`, `App/*.xcstrings` except InfoPlist in the app, `Controls/*.xcstrings` in a kept extension) and every non-source language with a translated or needs_review unit, `<lang>.lproj/<Table>.strings` and, when that localization has variations, `<Table>.stringsdict`, and refuses an empty or orphaned `.lproj`; the report's `designString.ru` must be Russian (not "(missing)", "(no ru localization)", "(no bundle)" or the English key), because each package bundle falls back to English on its own while `Locale.current` follows the app's language; `run.sh` gets the safe default arguments of §8.5; `clean` unregisters build products from LaunchServices and PlugInKit; `dist.sh` makes the DMG with `diskutil image create from` where `diskutil image` exists (macOS 27 deprecates `hdiutil create`) and with `hdiutil create` on older systems, printing the tool's progress only when it fails (as built in WP14); `name-probe.sh` probes Core **and** Policy against AppIntents, AppKit, AVFoundation, Carbon, ColorSync, CoreGraphics, CoreMedia, CoreMediaIO, CoreVideo, Foundation, IOKit, Metal, QuartzCore, ServiceManagement, SwiftUI, UniformTypeIdentifiers, WidgetKit, Observation and os; `lint` = copy check + the no-shader check (`find Packages -name '*.metal'` must be empty) + the scripts' self-tests (`check-lproj.py --self-test`, `scripts/l10n/validate.py --self-test` for the width classifier of §8.8, `soak_judge.py --self-test`; WP14); the copy and l10n tools read every `Resources/*.xcstrings` (not only `Localizable.xcstrings`).

```zsh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
make help                         # every target
make check                        # every target alone, zero warnings (JOBS=4; TEST=1 adds swift test)
make test [FILTER=<Suite>]        # swift test --scratch-path .build-test [--filter]
make tsan FILTER='HangWatchdog|OffMain|GammaWriteGate|BoostColorTests|StatusSymbolTests'  # swift test --sanitize=thread --filter (CI runs this filter)
make lint                         # copy denylist and rules + no .metal files + the self-tests of check-lproj.py, l10n/validate.py and soak_judge.py
make strings                      # sync catalogs from .stringsdata
make l10n-pending                 # mark new English keys pending in every shipped language
make strings-check                # CHECK=1 sync + lint-copy + validate --shipped (pending keys are warnings)
make probe-check                  # SDK name-collision probe (Core + Policy)
make build                        # universal Release → build/Overbright.app (+ dSYM), stripped, signature verified; CONTROLS=1 keeps the appex
make smoke                        # --diagnostics only: bundles and their translations, Edit menu, privacy none, intents metadata, gammaWrites == 0, triggerWindows == 0
SIMULATE=1 make smoke             # agents: a Debug build reports over --qa-simulate's fakes; a Release build gets the static and refusal checks only
make qa-matrix                    # after make debug: every fixture's scripted scenario under --qa-simulate, symbol/banner/chips checked; Welcome writes nothing
make soak [MINUTES=30]            # after make debug (MINUTES ≥ 17): scripted cycles under --qa-simulate; footprint growth per cycle, and idle wake-ups while off against a control app
make dist                         # zip + dmg + sha256 (+ notarization with SIGN_IDENTITY/TEAM_ID/NOTARY_PROFILE=overbright-notary)
make run                          # Debug with --off and --qa-simulate; never boosts by default
make icon                         # render AppIcon.icon layers from scripts/render-icon.swift
make distclean                    # also remove every .build-* scratch dir (a worktree can hold several GB)
```

New English strings follow Cranny's flow: `make strings` → `make l10n-pending` → `make strings-check`. `validate.py --shipped` fails on a key with no translation and no pending mark; `release.yml`'s `validate.py --shipped --release` is the gate that fails on pending keys.

Cranny's documented gotchas carry over (CONTRIBUTING repeats them): set `DEVELOPER_DIR`; universal builds need `-destination 'generic/platform=macOS'`; Debug ≠ Release hardening; never link a `.dynamic` product; launch with `open`; scripts run on `/bin/bash` 3.2; `xcodebuild` never adds catalog keys; building in the IDE rewrites catalogs; a changed default needs an upgrade step; the CI runner labels were never confirmed by a real run.

### 8.8 Localization

The pipeline is Cranny's, unchanged in shape:

- **Catalogs per target and per co-tenant.** Every target with UI has `Sources/<T>/Resources/Localizable.xcstrings`. Where two work packages share a target, the second gets **its own table** so they never edit the same file: `Sources/OverbrightBoost/Resources/Safety.xcstrings` (WP5's, reserved; as built it holds no key and no code names the table, because Boost shows no text of its own, and Boost's `Localizable.xcstrings` is empty too), `Sources/OverbrightAppShell/Resources/StatusMenu.xcstrings` (WP10: menu, HUD, panel window, Help window) and `Sources/OverbrightAppShell/Resources/Calibration.xcstrings` (WP11: calibration window, self-test sheet). Plus `App/InfoPlist.xcstrings`, `App/Localizable.xcstrings` (intents) and `App/AppShortcuts.xcstrings`; `Controls/Localizable.xcstrings` when the extension ships. `lint-copy.py`, `validate.py` and `catalog_paths()` glob `Resources/*.xcstrings`. Always `bundle: .module` in the package; components take already-localized `String`s; names inside sentences are bidi-isolated (`String.overbrightIsolated`).
- **Where enum copy lives:** the localized names and sentences of Core and Policy enums (presets, verdicts, advisories, limit reasons, banners, strategies, HUD reasons) are keys of **Design's** catalog, built by Design's view-model builders (WP9). Core's catalog holds only ported Core strings.
- **Key caps are never literal.** Copy that mentions a shortcut takes it as a placeholder filled from `ShortcutCenter.displayString(_:)`, which renders the live binding through the current keyboard layout (the same code as the menu's key equivalents); when a shortcut is cleared or failed to register, the sentence variant without it is used (DESIGN.md §16). The one key-cap word, "Space" (HotKeys' and SettingsUI's catalogs), is AppKit's own `FunctionKeyNames.loctable` value in every language, so Settings and Welcome draw the same caps as the menu (as built, WP14; `TerminologyTests.theSpaceKeyCapIsAppKitsWord`, each terms sheet).
- **All 35 languages from day one** (`scripts/l10n/languages.json` copied from Cranny with all entries `"shipped": true`; six translator notes that used "Cranny" as an example word are rewritten). The brand is never translated or transliterated.
- Keys are the English text with one comment each, `"<Surface>: <purpose>"`. Surfaces: `Panel: …`, `Panel ▸ Display card: …`, `Panel ▸ Footer chip: …`, `Menu: …` (title case), `HUD: …`, `Help: …`, `Settings ▸ <Pane>: …`, `Welcome ▸ <Step>: …`, `Calibration: …`, `Self-test: …`, `Shortcuts app: …`, `Focus filter: …`, `Control Center: …`, `VoiceOver: …`.
- **Width rules** (`SURFACE_RULES` in `l10n.py`, measured by tests, never by counting characters): `chip` (status chip ≤ 280 pt on its own line; footer chips together ≤ 304 pt, the cards' width, glyphs included, dropping to glyph + value on overflow), `readout` (≤ 200 pt, rounded monospaced digits), `valueTag` (≤ 240 pt, the track width; a "small gain" suffix may wrap), `hud` (≤ 200 pt of text), `segment` (Safe/Peak), `control` (Control Center titles ≈ 14 columns, review only), `menu` (unconstrained). As built (WP14): a comment names a chip's label only as a "status chip", a `Panel ▸ Footer chip:` label or a "chip label" (a chip's popover, actions, buttons, menu items and submenus are not), `Menu: …` comments and help tags are unconstrained, and the export's column budget is ≈ 36 for a status chip and 16 for a footer chip; `validate.py --self-test` (in `make lint`) checks the rules, and `validate.py --shipped` dropped from 969 warnings to 273. Fit tests per L2 target run every catalog language; phase B runs them in English and a pseudo-long locale (+40 %), WP15 in all 35.
- Plurals for every shown count ("≈ %lld nits" is a count: ru нит/нита/нит). The multiplier "×%@" is preformatted with `FormatStyle` (locale decimal separator) and needs no plural. Percentages and durations go through `FormatStyle`/`Measurement`.
- **Apple terms** (`apple-terms.py`): Displays-pane names must match macOS exactly in every language when we point to them: "Brightness", "Automatically adjust brightness", "True Tone", "High Dynamic Range" (German "Hochkontrastbild"), "Preset", "Night Shift…", "Color profile", "Refresh rate" [VERIFIED on macOS 27], plus System Settings, Displays, Battery, Low Power Mode, Focus, Login Items, Control Center, Menu Bar, Allow in the Menu Bar, Shortcuts, QuickTime Player, Photos, TV, Applications, and the space bar's key cap "Space" (AppKit's `FunctionKeyNames.loctable`, so `validate.py --glossary` catches key-cap drift; WP14).
- **Denylist** (D3) in `lint-copy.py` and `l10n.py`, over keys, values and comments, in every language.
- **Merge driver:** `.gitattributes` declares `*.xcstrings merge=xcstrings`; every clone and worktree runs the two `git config merge.xcstrings.*` lines of §10.0.
- **Seeding:** ported keys (search, Reset All, Undo, Reset to Default, the recorder, update-check errors, About, login item, welcome navigation) are copied from Cranny's catalogs by a throwaway script that replaces the brand, skips Cranny's two ambient-light "Vivid" keys explicitly, and marks every brand-bearing form `needs_review` (Finnish, Hungarian and Turkish suffixes change). <!-- denylist-ok -->
- Russian is the owner's review language and the pivot for the others (Cranny's export column). The terminology test (`TerminologyTests`) checks the glossary: Standard «Стандарт», Extra brightness «Дополнительная яркость», Dim below minimum «Затемнение ниже минимума», Safe «Безопасно», Peak «Пик», Compatibility mode «Режим совместимости», Fill Light «Подсветка лица», Less Bright «Менее ярко» (confirmed in WP15, `docs/l10n/terms/ru.md`).

### 8.9 CI, release, signing

`ci.yml` (Cranny's, minus the Metal step). **xcode-27 job:** lint-copy → validate → `JOBS=3 TEST=1 check-modules` → `make tsan FILTER='HangWatchdog|OffMain|GammaWriteGate|BoostColorTests|StatusSymbolTests'` (the hang watchdog, the gamma write gate and the off-main tests of §9.2 rule 9: every `<Source>OffMainTests` suite, the warm colour's provider and the status item's drawing handler; as built in WP14, all green locally with `SignalStopTests` too, which join the filter when C-BOOST-14 makes their timeouts robust under the sanitizer) → `CHECK=1 name-probe` → `CHECK=1 sync-strings` → build (`CONTROLS=1` compile-check of the extension, then the default build) → smoke (incl. the intents metadata) → dist → upload. **macos-26 job (Xcode 26, Swift 6.2):** the package only (`swift build` and `swift test` of `OverbrightKit`; the app's intent declarations need Xcode 27). CI runners are VMs with virtual displays: no test may need a real display, and smoke passes with `displays: []`. UI snapshots are rendered locally only, on 27 (the opt-in `OVERBRIGHT_SNAPSHOT_DIR` suites never run in CI; the macos-26 job runs plain `swift build` and `swift test`); macOS 14/15 are compile-checked (deployment target 14) plus an availability review in WP14. `release.yml`: tag ⇔ `VERSION`, optional Developer ID import, `validate.py --shipped --release` (fails on pending keys), build and smoke with `OVERBRIGHT_GITHUB_REPOSITORY` = `github.repository` (the update check's repository, §8.6), dist, `gh release create`. Ad-hoc builds need Gatekeeper's "Open Anyway" or `xattr -dr com.apple.quarantine` (README); notarized builds do not.

---

## 9. Testing, engineering rules, definition of done

### 9.1 Testing strategy

| Layer | What | How |
|---|---|---|
| Policy | Factor math, level mapping, steps, preset visibility, ceilings and `liveCap`, eligibility, table classifier, domain resolver, reducer, conflict matcher | Table-driven cases from every row of §5.3, §5.6, §6.1 and D8; **property tests** with a seeded generator (TestSupport): for all G in [1, 16] and every domain `lightGain(tableFactor(G)) ≈ G`; `tableFactor` is monotonic; **for H in (1, 16], `F = tableFactor(0.97·H, .encoded)` satisfies `F^k ≤ H` for k in [1, 2.4] and `decodeSRGB(F) ≤ H`** (worst case 0.981·H); no arrow, scroll or Brighter / Less Bright step exceeds ½ stop; `liveCap` never exceeds `0.97·H`, nor `capNits·H/panelPeak` in Safe without an SDR estimate; `TableClassifier` gives the same class whether or not read-back clamps; a uniform multiple of a base is never `matchesBase`; the reducer never returns `.boost` while shielded, off, paused or tripped; every stop yields neutral; guards and the boost switch never block dimming; per-display rules never touch other displays; Russian-name fixtures give identical verdicts (no name logic). |
| Boost | State machine, ladder, gate (incl. pre-held), ramps, interlock, hang epoch, drift check, re-base, rescue, hang watchdog, flicker guard, Dim All, low-level confirmation, pause | `FakeGammaPort` + `ScriptedHeadroom` + `FakeTriggerFactory` + `FakeSystemSignals` + `ManualTimeSource` + TestSupport's **reference reducer** (master on + boost enabled → `.boost(top^p)`; shield → neutral): deterministic scenarios (arm → escalate twice → gate → ramp; **pre-held at H 2.6 with the other source leaving later**; headroom drop mid-ramp; user raise with a poll burst; lock during gating; **shield neutral when `emit` returns**; wake with refusal and cached-rung-only backoff; stale generations; **hang epoch blocks queued writes**; drift reset vs explained adoption vs unexplained adoption vs foreign, at F 1.02–1.06 and dim 0.95–0.99, under both read-back models; **re-base during reconfiguration while boosted and while dimmed**; another writer's death; repair and adoption budgets; oscillation trip with and without monotonic headroom; Back to Standard from every phase; **display removed while boosted, window moved to another screen**; process death simulated → base; second launch-rescue cases incl. an all-zero restore). Property: across 10 000 random event sequences, at every write `G_written ≤ 0.97·H_reading` with a reading ≤ 150 ms old of the same display, every sequence ending in "off" leaves every table equal to its baseline, and at least 30 % of sequences reach `boosted` (so the property is not vacuous). |
| Triggers | Geometry, tagged colours, HLG asset, Metal clear pass, screen-change removal | Pure geometry and colour tests; HLG write + verify into a temp dir (ProRes always, HEVC when an encoder exists); the off-screen Metal clear (1.6 reads back ≈ 1.5996) only with `OVERBRIGHT_HARDWARE=1`; a regression test for the `NSColor` 8-bit wrap. **No test ever orders a window in.** |
| Displays | IORegistry parsing, virtual-display and mirror rules, UUID keys, profile base (`vcgt` parse, identity fallback), reconfiguration flags | Saved IORegistry and ICC fixtures (16.16 fixed point, the MSI's values, a calibrated profile); `GammaPortContractTests` run their **write and restore cases only against `FakeGammaPort`**; the real-port variant (`OVERBRIGHT_HARDWARE=1`) is read-only (capacity, read, profile base, and `writeCount` unchanged). |
| Signals | Full-screen `evaluate`, full-screen video, matcher inputs, idle scheduling, assertion parsing, schedule boundaries, off-main entry points | Pure functions with window-list and assertion fixtures (layers 0/24/2001/2004, Split View, notch band); one background-queue test per entry point (§7.1). |
| UI | Panel, HUD, Help, Settings, Welcome, calibration | `ImageRenderer` / `NSHostingView.cacheDisplay` snapshots behind `OVERBRIGHT_SNAPSHOT_DIR`, for every scripted status (`ScriptedStatuses` names), Light/Dark/Increase Contrast, plus German and French keyboard layouts where key caps appear; **measured-width fit tests** (English + pseudo-long in phase B, every language in WP15) for chips, readouts, value tags, HUD, footer row, segments, and banners (`BannerFitTests`, as built in WP14 for all 35 languages: the whole sentence, never cut, at most six lines); VoiceOver labels and values present on every control (`accessibilityLabel` non-empty test); a keyboard-only walk of the panel's Tab order (DESIGN.md §5.12). |
| Shell | Launch order, single instance, move-to-Applications, launch UI (login vs cold), LaunchGate, login item, QA parsing, menu rows, icon visibility, diagnostics read-only, quit (cancel once, stop, terminate; quit Apple Events at once) | Cranny's ported tests plus `secondInstanceHandsOverAndExits`, `offersOnlyOutsideApplicationsOrWhenTranslocated` (the move offer, `ApplicationsMoverTests`), `coldLaunchShowsUI`, `loginLaunchIsSilent`, `diagnosticsNeverWrites` (fake ports fail on write) and `constructingServicesTouchesNoHardware`; WP13's `EndToEndScenarioTests` (every fixture through the simulated wiring with the real engine and Policy), `LifecycleOrderTests`, `LaunchOrderTests`, `ReopenTests`, `QuitTests`, `DockMenuTests`, `DiagnosticsReportTests`. |
| Lint tests (Core) | `noCodeCreatesAPreferencesSuite`, `noDenylistedNamesOutsideAllowlist` (allowlist of D3), `noSecondDisplayStateWriter` (code, tests and `scripts/`), `onlyTableWriterAndRescueWrite`, `noWritesInHardwareTests` (no `write(`/`restoreSystemColorSettings(` in suites gated by `OVERBRIGHT_HARDWARE`, and no real display port (`CoreGraphicsGamma(`, `SystemHeadroomPort(`, `SystemDisplayDirectory(`, `livePorts(`) outside them; both write scans follow a call over lines and through nested parentheses, find implicit `self` and method references, and skip declarations, comments and strings, `gammaWriteScanFindsEveryShape`), `noEDRPropertiesOutsideAllowedModules`, `noNetworkingOutsideUpdates`, `bundleShipsNoShaderSources`, `noNameComparisons`, `noNSColorComponentInitForEDR`, `noLiteralKeyCapsInCatalogs` (⌃⌥⌘ followed by a key outside a placeholder), `noSettingsDestinationLabels` (DESIGN.md §16) | Source scans. |
| Intents, Channel | `IntentRouter` (each intent against `PreviewBoostControl`, connection and readiness wait, Focus sink), state-channel pack/unpack properties, URL parser (token, on/off, malformed) | Swift Testing in `OverbrightIntentsTests` and `OverbrightChannelTests`. The app-target adapters stay one-line forwards and are verified by the smoke metadata check and H-AI-1, not by unit tests. |

Opt-in suites: `OVERBRIGHT_SNAPSHOT_DIR` (snapshots), `OVERBRIGHT_INTEGRATION` (windows on screen without EDR), `OVERBRIGHT_HARDWARE` (read-only real ports, owner only, never CI). Never bound main-actor scheduling with a short real-time wait; use `ManualTimeSource` or `eventually` (30 s, and at least 3,000 checks: a main actor busy with other tests' work, such as the snapshot suites under the Thread Sanitizer, checks less often).

### 9.2 Engineering rules

1. Swift API Design Guidelines; small files (≈ ≤ 300 lines), one primary type per file, doc comments on every `public` declaration.
2. No `fatalError`, `try!`, `as!` or force unwraps in production code.
3. Views use tokens only (`@Environment(\.overbright)`, `Space`, `Radius`, `theme.animation(_:)`, `OverbrightSymbol`), never literal colours, sizes or animations; every view file has `#Preview`s over `OverbrightServices.preview(fixture:)`.
4. Never give a public type a name an Apple framework exports (`make probe-check`).
5. Every display-state write goes through `TableWriter` → `GammaPort` (D24), except `LaunchRescue`'s restore. Every EDR surface lives in the allowed modules and registers with `OwnEDRSurfaces`.
6. No private API (the register in README stays empty). IORegistry property reads are public IOKit calls; their keys are undocumented, so every IORegistry input is optional and has a fallback.
7. No third-party code, no new targets, no edits outside your package's folders (§10.0).
8. User data (display names, app names, paths) never enters the journal or `.public` logs.
9. Every system callback that can arrive off the main thread is declared nonisolated (§8.1 rule 2) and has an off-main test; CI runs those tests under the Thread Sanitizer (§8.9 names the filter; a new off-main suite outside `<Source>OffMainTests` is added to it).

### 9.3 Definition of done (every work package)

All commands are run one by one, with absolute paths (§2.4); `<repo>` is the package's worktree.

1. `<repo>/scripts/check-modules.sh <Target>` passes (warnings as errors); `make -C <repo> test FILTER=<Target>Tests` passes; for new strings: `make -C <repo> strings`, then `make -C <repo> l10n-pending`, then `make -C <repo> strings-check` passes (English source strings and a comment for every new key; translations come from WP15).
2. `make -C <repo> build` and `make -C <repo> smoke` pass; `gammaWrites == 0` and `triggerWindows == 0` in smoke. Agents, who launch the app only under `--qa-simulate`, run `SIMULATE=1 make smoke` on the Release build (static and refusal checks) and on a Debug build (`make debug`; the report over the fakes); the read-only report on the real ports is CI's and the owner's (WP13).
3. Every view has previews, accessibility labels and values, and Reduce Motion / Transparency / Increase Contrast behaviour; energy rules hold (no work while off).
4. New settings keys are in §3.8's catalog (through the contract lane) with defaults matching DESIGN.md §7; no edits outside the package's folders.
5. The package's acceptance criteria (§10) are demonstrated in the pull request (snapshots for UI; test names for logic).
6. **No display state was changed while developing** (`--qa-simulate` for every run; hardware tests only in the owner's session).
7. Before handing the worktree back: `make -C <repo> distclean`; after the merge, `git worktree remove <repo>` (§10.0).

---

## 10. Work packages

### 10.0 Process

**Phases.**

| Phase | Packages | Runs |
|---|---|---|
| A | **WP0a** Foundation and contracts | alone, first; must merge before anything else starts |
| B | **WP0b** Ports and docs, **WP1–WP10**; then **WP11** and **WP12** once WP0b has merged | **in parallel**, one agent each, each in its own git worktree |
| C | **WP13** Integration, then **WP14** Review and **WP15** Localization in parallel | after B |
| D | **WP16** Hardware session and tuning | the owner runs `docs/HARDWARE-TEST.md`; an agent analyses and tunes |
| E | **WP17** Release | last |

**Worktrees and branches.** WP0a lands on `main` from `wp/00a-foundation`. Each phase-B package runs in its own worktree, set up with absolute paths, one command at a time:

```zsh
git -C <repo> worktree add <repo>-wp04 -b wp/04-boost-engine
git -C <repo>-wp04 config merge.xcstrings.name "String Catalog union merge"
git -C <repo>-wp04 config merge.xcstrings.driver "python3 scripts/merge-xcstrings.py %O %A %B"
```

Pull requests go into `main`, merged with `--no-ff` (Cranny's habit); `main` is always green (CI: lint, `check-modules`, tests, TSan suite, strings-check, universal build, smoke, dist). Rebase daily, and the same day a contract-lane PR merges. Every commit ends with the project's co-author trailer.

**Disk budget.** A worktree holds up to 17 per-target scratch directories (`.build-<target>`, 56–700 MB each in Cranny), `.build-test` and an Xcode DerivedData under `build/`: about 4–6 GB, so 13 parallel worktrees could take 60 GB or more on the owner's laptop. During development run `scripts/check-modules.sh <OwnTarget>` (one target), not the full `make check`; share one SwiftPM cache (`--cache-path <repo>/../.swiftpm-cache`, set in `scripts/lib.sh`); run `make -C <worktree> distclean` before handing a worktree back and `git -C <repo> worktree remove <worktree>` after its merge.

**Ownership is by path** (all paths from the repo root; `Pkg/` = `Packages/OverbrightKit/`). A package edits only the paths listed under it. The shared files belong to WP0a during phase A, to the **contract owner** (the WP0a/WP13 maintainer) during phase B, and to WP13 in phase C:

- `Pkg/Package.swift`, `Pkg/Sources/OverbrightCore/**` (except `Additions/`), `Pkg/Sources/OverbrightBoost/Shared/**`, `Pkg/Sources/OverbrightTestSupport/**`;
- `App/**` except `App/Intents/**`, `App/Localizable.xcstrings` and `App/AppShortcuts.xcstrings` (WP8); `Overbright.xcodeproj/**`, `scripts/**`, `.github/**`, `THIRD_PARTY_NOTICES.md`, `LICENSE`, `VERSION`, `docs/ARCHITECTURE.md`, `docs/DESIGN.md`, `docs/HARDWARE-TEST.md`;
- the shell's shared files: `Pkg/Sources/OverbrightAppShell/App/AppDelegate.swift`, `…/App/CompositionRoot.swift`, `…/App/ShellPorts.swift`, `…/App/Shell.swift`, `…/App/OverbrightScenes.swift`, `…/App/LaunchUI.swift`, `…/App/DiagnosticsReport.swift`, `…/App/QAHooks.swift`, `…/Services/ShellAppControl.swift`. During phase B, `Pkg/Sources/OverbrightAppShell/Resources/Localizable.xcstrings` belongs to WP0b (the only phase-B writer of that table).

**Contract changes after WP0a: the contract lane.** Swift cannot add an enum case, a protocol requirement or a stored property through an extension, and a new case in a public enum breaks every exhaustive `switch` in other modules. So contract changes are not staged additively; they go through **one serialized lane**:

1. A package that needs a change opens a short **contract PR** against `main` (title `contract: …`), or asks the contract owner to; the contract owner reviews and merges it within one working day, one at a time.
2. The PR edits the Core file (or `Boost/Shared`, `Package.swift`, `TestSupport`) **in place**. It may add enum cases; it then updates **every** exhaustive `switch` over that enum in the repo in the same PR with a mechanical fallback (the owning package refines it later; this is the one sanctioned cross-folder edit). A new protocol requirement lands only together with a default implementation in a protocol extension in the same file. A new stored property on a struct needs a default in every initializer.
3. After the merge, every worktree rebases the same day.
4. `Pkg/Sources/OverbrightCore/Additions/<WPnn>-<Topic>.swift` may hold **only new types and extension methods** (never cases, requirements or stored properties), when a package needs them before the lane has merged its PR; WP13 folds them into their final files.
5. Changes to Policy's public signatures are requests to WP1's owner, through the same lane.

The cases that were foreseeable are already in the v0.2 contracts (not reserved, real): `LimitReason.boostNotEnabled / fullScreenVideo / nearFullBrightnessOnly`, `Banner.focusOff / outsideSchedule / flickerStop / unattributedDrift`, `StatusSymbolState.preparing`, `SystemEvent.displayRemoved / displayConfigurationBegan / appTerminated(processID:)`, `DisplayVerdict.mirrored`, `TableClass`, `LevelChange.Kind`, `RescueOutcome.repairedInvalidRestore / skippedNotOnConsole`, `SuspendCause.notOnConsole`.

**Seams WP0a fixes so phase B can code against each other.** Each is a stub file at its final path with fixed initializers and method signatures; the owning package fills the body. Changing a signature is a contract-lane change.

- **Design** (`Pkg/Sources/OverbrightDesign/`, bodies WP9): `OverbrightTheme` + `.overbrightThemeRoot(_:)`; token enums `Space`, `Radius`, `StrokeWidth`, `HitTarget`, `OverbrightMotion.Kind`, `BoostColor`, `SemanticColor`, `OverbrightSymbol`; components `BoostSlider(level: Binding<LevelPosition>, top: Double, allowedNow: Double?, presets: [LevelPreset], dimEnabled: Bool, boostHalf: BoostHalfState, accessibilityName: String, valueText: (LevelPosition) -> String, onCommit: (LevelPosition) -> Void)` (the "allowed now" marker is part of the slider), `StatusChip(_ model: ChipModel, actions: [ChipAction])` (WP14 adds `init(_:actions:isPresented:)`, so the panel's keyboard map opens the popover), `GuardChip(_ model: GuardChipModel, menu: [GuardChipMenuItem])`, `PausedBanner(_ model: BannerModel, primary: (() -> Void)?, secondary: (() -> Void)?)`, `ReadoutText(_ values: ReadoutValues)`, `EDRPreviewSurface(gain: Double, divider: Binding<Double>, simulated: Bool)`, `StepWedgeView(patches: [Double], surround: Double)`, `KeyCap(_ text: String)`, `ChipButtonStyle`, `IconButtonStyle`, `OverbrightLinkButtonStyle` (renamed from `LinkButtonStyle` by WP13: SwiftUI exports that name, §9.2 rule 4), `.overbrightFocusRing`, `SettingRowConventions`, `SettingsStore.binding(_:)`; the **copy builders** `ChipModel.make(reason:phase:failedTries:)`, `VerdictText.make(_:advisories:lastGrant:)`, `BannerModel.make(_:)`, `HUDText.make(_ change: LevelChange, status:)`, `ValueText.make(_ values: ReadoutValues)` with their keys in Design's catalog.
- **Boost** (`Pkg/Sources/OverbrightBoost/`): shared, WP0a-owned: `Shared/EngineTiming.swift` (§4.4), `Shared/DisplayControllerDriving.swift` (`arm(rung:)`, `readHeadroom()`, `disarm()`, `returnToStandard()`, `writeCalibrationFactor(_:maxFactor:)`). Seeded, then owned by WP4: `Writer/TableWriter.swift` (`init(gamma:ledger:time:journal:)`, `write(_:to:reading:epoch:)`, `writeCalibrationFactor(_:to:reading:maxFactor:)` (WP14: `writeCalibrationFactor(_:of:to:reading:maxFactor:epoch:)`, the epoch and the baseline added, plus `checkCalibrationFactor(_:on:reading:maxFactor:)`), `writeBaselines(fromLedger:)`), `Writer/SafetyLedger.swift` (`hangEpoch`, `withLock(_:)`, `markScaled(_:baseline:)`, `unmark(_:)`, `entries()`), `Engine/BoostEngine.swift` (`init(services:gamma:headroom:triggers:conflicts:reduce:)`, plus `useStrategyCache(at:)`, `applyLaunchCheck(_:)`, `writer` and `ledger` for the composition root, with `reduce: @escaping (PolicyInput) -> PolicyDecision = BoostPolicy.reduce`, for tests and previews over an existing hub; the composition root uses the designated `init(settings:machine:time:journal:ownEDRSurfaces:displays:signals:gamma:headroom:triggers:conflicts:reduce:)`, because `OverbrightServices` needs the engine before the hub exists). Seeded, then owned by WP5: `Safety/LaunchRescue.swift` (`init(gamma:conflicts:signals:journal:)`, which reads the online displays from CoreGraphics and keeps no marker, and, as built through the contract lane, `init(gamma:conflicts:signals:journal:time:displays:settings:)`, which the composition root uses: the read-only display snapshot, the settings holding the boost marker and the journal's clock; `runLaunchCheck() async -> RescueOutcome`, `rescueNow() async -> RescueOutcome`, `lastOutcome`, `onDeferredOutcome`), `Safety/HangWatchdog.swift` (`init(writer:ledger:journal:)`, `setActive(_:)`, `consumeFiredFlag() -> Bool`), `Safety/SignalHandlers.swift` (`init(writer:stop:)`, `install()`), `SelfTest/SelfTestRunner.swift` (`init(drivers:time:journal:machine:)`, `run(_:) async -> SelfTestReport`), `Calibration/CalibrationController.swift` (`init(display:driver:writer:time:machine:)`, conforming to `CalibrationSession`). BoostEngine calls only these signatures, so WP4 and WP5 compile without each other.
- **Displays** (WP2): `Monitor/DisplayMonitor.swift` — `DisplayMonitor.run(interval: Duration, duration: Duration?, output: (String) -> Void) async`, called by the shell for `--monitor` (the shell quits when it returns).
- **PanelUI** (WP10): `Card/DisplayCardView(status: DisplayStatus, isMasterOn: Bool, services: OverbrightServices)` (meant for Welcome; as built, Welcome draws its own rows over `DisplayCardModel`, §10.14), `Help/HelpView(anchor: String?)` (as built also `init(anchor:shortcuts:)`, which the shell's Help window hosts since WP14 so a late registration, a rebind or a cleared shortcut shows at once, and `init(anchor:backToStandardKeys:)` for tests and previews), `QA/ScriptedStatuses` (`static var names: [String]`, `static func status(named:) -> BoostStatus?`, read by the shell's `--qa-state`; as built also `expandsWhy(named:)`, `services(named:)` for the snapshot suites and previews and `hudNames`, and from WP14 `apply(named:to:)` and `fillLightOn(named:)`, so `--qa-state` shows a state's settings and Fill Light too).
- **Intents and Channel** (WP8): `IntentRouter()` (`@MainActor`, no-argument init), `connect(boost: any BoostControl, displays: any DisplayDirectory, signals: any SystemSignals)`, one method per intent, `focus(_ directive: FocusDirective)`; `ControlStatePublisher(boost:)` (no-op unless the control ships); in Channel: `BoostChannel` (pack/unpack, notify name, snapshot, token) and `URLRoute.parse(_ url: URL) -> URLRoute?`.
- **Shell controllers** (`Pkg/Sources/OverbrightAppShell/`): `StatusItemController(services:)`, `PanelController(services:)` + `toggle(from:)`, `HUDController(services:)` (observes `status.lastChange`), `LowLevelPromptController(services:)`, `IconVisibilityMonitor(statusItem:)`, `HelpWindowController(services:)` + `show(anchor:)`, `SettingsWindowController(services:)` + `show(pane:)`, `WelcomeWindowController(services:)` + `show(step:)`, `CalibrationWindowController(services:)` + `show(display:)`, `SelfTestSheetPresenter`, `ShellAppControl` (implements `AppControl`, `connect(...)`; as built by WP13 `init(settings:loginItems:)` and `installIcon()`), `DockMenuController(services:)` + `menu()` + `start()`, `IconNotVisibleWindowController(services:)` + `showIfNeeded(_:)`, `SingleInstance.handOverIfRunning(arguments: LaunchArguments = .current) -> Bool` (static), `ApplicationsMover(settings:)` + `offerIfNeeded()` (an instance, so it can remember Not Now in `settings`).

**Acceptance for every package** = §9.3 plus the package's list below. "Tests" names the suites a reviewer expects to see.

### 10.1 WP0a — Foundation and contracts (phase A, serial)

- **Owns:** everything shared (above), placeholders for all other targets, and the seams.
- **Creates:** the repository of §1.3: project (app target + the dormant Controls target with placeholder sources, IDs of §8.6), scheme, `App/*` (except WP8's files, which it creates as placeholders), `Package.swift` exactly as §2.2, every target with a placeholder source, a catalog where it has UI and a test target; scripts and l10n tooling (§8.7–§8.8: `MIN_XCODE_MAJOR=27`, `make tsan`, `make test FILTER=`, `make l10n-pending`, catalogs globbed as `Resources/*.xcstrings`, the smoke check of `Metadata.appintents` against DESIGN.md §12.8's intent names; rename rules: `app.cranny.Cranny` → `app.overbright.Overbright`, `CrannyKit` → `OverbrightKit`, `CRANNY_` → `OVERBRIGHT_`, `'CRNY'` → `'OVBR'`, pbxproj ID prefix `0B21E7`); both workflows (xcode-27 job with the TSan step, macos-26 package job); `LICENSE`, `VERSION` 0.1.0, `THIRD_PARTY_NOTICES.md` (the rows of D2), a minimal `README.md` (WP0b completes it).
- **Core and Policy:** every file of §3 (split one type per file), the real `SettingsStore` port and the other ported platform files, `MachineIdentity`, settings upgrades (revision 0), fakes and fixtures of §3.9 (with the v0.2 behaviours: profile bases, both read-back models, pre-held headroom, stalls, mirror and calibrated-profile fixtures), `OverbrightServices.preview(fixture:)`, the Policy file of §3.10 (real math bodies, stubs elsewhere). `make probe` generates `SDKNameCollisionProbe.swift`.
- **TestSupport:** the seeded generator and the **reference reducer** (`ReferenceReducer.reduce`: master on and boost enabled → `.boost(top ^ p)` with a fixture top; dim levels → `.dim`; shielded, off or paused → neutral), so WP4 can test the engine before WP1 lands.
- **Seams:** every stub of §10.0.
- **Lint tests:** the full list of §9.1.
- **Acceptance:** every command of §8.7 green on a fresh clone (`make check`, `make test`, `make lint`, `make strings-check`, `make probe-check`, `make build`, `CONTROLS=1 make build`, `make smoke` with `gammaWrites == 0` and `triggerWindows == 0`); `make run` shows the status item with the off symbol and a placeholder panel under `--qa-simulate`; the app has never written a table on this Mac (`--diagnostics` shows every display `matchesBase` against its profile base and `gammaWrites == 0`).
- **Tests:** the lint tests, `constructingServicesTouchesNoHardware`, `diagnosticsNeverWrites`, and Cranny's ported Core suites (InMemoryDefaults, SettingsUpgrade, Observation, JSONDocumentFile, AppIdentity, Platform, SettingsStore).

### 10.2 WP0b — Ports and docs (phase B, parallel; gates WP11 and WP12)

- **Owns:** `Pkg/Sources/OverbrightHotKeys/**`, `Pkg/Sources/OverbrightUpdates/**`, `Pkg/Sources/OverbrightSettingsUI/{Root,Components,Search}/**`, `Pkg/Sources/OverbrightOnboarding/Chrome/**`, the shell's `Pkg/Sources/OverbrightAppShell/{Launch,LoginItem}/**`, `…/Windows/Settings*`, `…/Windows/Welcome*` and its `Resources/Localizable.xcstrings`, the matching tests, `README.md`, `docs/CONTRIBUTING.md`, `docs/TRANSLATING.md`, `docs/l10n/terms/*.md`.
- **Delivers:** `OverbrightHotKeys` and `OverbrightUpdates` (ported whole; HotKeys adds `displayString(_:)` through the current keyboard layout); the bodies of the shell's launch helpers `SingleInstance` (D27) and `ApplicationsMover` (DESIGN.md §12.4), whose seams WP0a put in `Launch/`; the shell's ported files: `LoginItemController`, and Cranny's `SettingsWindowController` and `WelcomeWindowController` bodies behind the §10.0 seams WP0a put in `Windows/`. WP0a already ported `Launch/LaunchGate.swift`, `Launch/ShellDefaults.swift` and `Launch/QAHooks+Defaults.swift`, because its launch order and `make run` need them: WP0b owns and refines these files (and their tests `LaunchGateTests`, `QADefaultsTests`) instead of porting them again; SettingsUI infrastructure (root, sidebar, search, components, the recorder view, About/Updates section) with empty panes; Onboarding chrome with empty steps; README (pitch, "Free and open source (MIT), no account, no analytics", install, build without Metal Toolchain, "Permissions: none", **Safety and recovery** with `--restore-gamma` and Back to Standard, privacy, credits), CONTRIBUTING (clean-room rules with `denylist-ok` markers where the incumbent is named, zero dependencies, ownership and the contract lane, the GVM `&&` warning, `--qa-simulate` mandatory for agents, disk hygiene), TRANSLATING, terms sheets (language sections carried from Cranny, notch rows and the ambient-light rows deleted), translation seeding (§8.8).
- **Verifies the open shape questions:** (1) the SwiftUI `App` with an empty `Settings {}` scene plus an `NSStatusItem` opens no window at launch, routes ⌘, to our window and survives closing Settings; (2) `applicationShouldHandleReopen` arrives for a relaunched `LSUIElement` app; (3) whether a launch by `SMAppService.mainApp` carries `keyAELaunchedAsLogInItem` (else the fallback of §7.6); (4) `swift package describe` lists `OverbrightTestSupport` and the app's resource-bundle count equals the number of `Sources/*/Resources` folders.
- **Tests:** Cranny's ported suites (LaunchGate and QADefaults already ported by WP0a, LoginItemController, SettingsWindow, WelcomeWindowPolicy, HotKeys, UpdateChecker, SearchAndNavigation, KeyboardAndReset, WelcomePlan) + `KeyCapLayoutTests` (US, German, French), `SingleInstanceTests`, `ApplicationsMoverTests` (offers only outside `/Applications` or when translocated, remembers Not Now per version).
- **As built (WP14 review fixes, C-SHELL and C-ONBOARD):** Esc in the Move to Applications alert is Not Now (`ApplicationsMover.askAlert()`; an `NSAlert` gives Escape only to a button titled Cancel; `escapeAnswersNotNow`); `BundleMove.perform` returns where the Trash put an older copy, and a failed move, copy or relaunch brings it back (whatever the failure left in its place goes to the Trash, never deleted); a copy that can neither start nor go back says so (DESIGN.md §12.4) before this copy quits (`aFailedCopyBringsTheOlderCopyBack`, `aFailedMoveBringsTheOlderCopyBackAndSaysSo`, `aFailedRelaunchBringsTheOlderCopyBackFromTheTrash`). The Onboarding chrome opens a language's strings from its `.lproj` folder by URL (§10.14).

### 10.3 WP1 — Policy · `OverbrightPolicy`

- **Owns:** `Pkg/Sources/OverbrightPolicy/**`, `Pkg/Tests/OverbrightPolicyTests/**` (including `Conflicts/ConflictCatalog.swift`, the D3 path-allowlisted file).
- **Depends on:** WP0a. **Builds against:** Core only.
- **Delivers:** the stubs of §3.10: `GainCeiling.sliderTop` (§5.3 table), `TableClassifier` and `isPlausibleRestore` (D26), `EligibilityClassifier` (D8 order, ε = 0.01, transient potential < 1 → `.checking`, mirror members → `.mirrored`, OLED by minimum luminance or the override in `preferences`, advisories incl. `compatibilityModeAdvised` from `CompatibilityModels`, verdict gains from the default ceiling), `BoostPolicy.reduce` (§6.1–§6.4), `Readout.values` (pure numbers: applied, requested, nits only with a trusted SDR white and a valid record, preset, estimate flag, dim percent), `ConflictMatcher` + `ConflictCatalog` (S1–S4 entries from public sources; `-setapp` twins; prefix confirmation by team ID); tests for the bodies WP0a shipped (`FactorMath`, `LevelMapping`, `StepMath`, `PresetVisibility`, `liveCap`, `TransferDomainResolver`, `CompatibilityModels`). No localized strings (Design formats).
- **Acceptance:** every row of §5.3 and §5.6 reproduced to 3 decimals; every precedence row of §6.1 has a test; property tests of §9.1 pass with 10 000 seeds; the Russian-names fixture gives identical verdicts; no `Foundation` API with I/O or clocks is used (lint: no `Date()`, no `ProcessInfo` in Policy); matcher tests use synthetic IDs or entry ids.
- **Tests:** `FactorMathTests`, `LevelMappingTests`, `StepMathTests`, `PresetVisibilityTests`, `GainCeilingTests`, `TableClassifierTests` (both read-back models, calibrated bases, uniform multiples, all-zero tables), `DomainResolverTests`, `EligibilityTests`, `ReducerPrecedenceTests`, `ReducerPropertyTests`, `BannerAndSymbolTests`, `ReadoutValuesTests`, `ConflictMatcherTests` (exact, case, `-setapp`, prefix, executable, team, own ID ignored, helper ignored, no false positive on a sibling app of the same vendor prefix).

### 10.4 WP2 — Displays · `OverbrightDisplays`

- **Owns:** `Pkg/Sources/OverbrightDisplays/**`, its tests and catalog.
- **Depends on:** WP0a.
- **Delivers:** `SystemDisplayDirectory` (online list, `DisplayKey.of`, built-in first; the reconfiguration callback as a `nonisolated static` C function: begin flag → `displayConfigurationBegan`, **remove flag → `displayRemoved(id)` at once**, after phase debounced 0.5 s + 2 s; clamshell handling; hardware-mirror detection), `SystemHeadroomPort` (fresh NSScreen per read, stamped with its display ID; nil for mirror members), `CoreGraphicsGamma` (the **only** file with the CG setters and the global restore; write counter; thread-safe for the watchdog and signal queues; `profileBase(of:count:)` from the ColorSync profile's `vcgt`, table and formula types, identity when absent), `IORegistryFacts` (built-in `EDRPotentialHeadroom`, `user-accessible-max-nits`; externals `DisplayAttributes` Luminance Max / MaxFrameAverage / Min (16.16 fixed point), `SupportsPQEOTF`, vendor/product; virtual-display detection: capacity 0, failed read, placeholder vendor `0x756e6b6e`, no framebuffer service), `PanelClass` derivation, the read-only `DisplayMonitor` behind `--monitor` (table class against the profile base).
- **Acceptance:** fixtures from the owner's IORegistry (MSI: 465.49 / 265.05 / 0.0003 nits, PQ yes, HLG no; built-in: potential 16, SDR max 600) and an ICC fixture with a `vcgt` parse exactly; no code compares names; real ports run only with `OVERBRIGHT_HARDWARE=1` and only read; `--monitor` never writes (a fake-port test and a lint test).
- **Tests:** `IORegistryParsingTests`, `ProfileBaseTests`, `VirtualAndMirrorTests`, `DisplayKeyTests`, `ReconfigurationFlagsTests` (manual time; remove flag immediate; begin flag), `ReconfigurationCallbackOffMainTests`, `GammaPortContractTests` (write and restore cases only against `FakeGammaPort`; a read-only real-port variant), opt-in `RealDisplayReadTests`.
- **As built (WP14 review fixes):** a panel peak falls back to potential × 100 (D8) when neither the IORegistry nor the product gives one and the potential is above 2; the built-in's `BrightnessMilliNits.max` is no longer a peak (undocumented; parsed for diagnostics only). The IORegistry has no SDR white for Apple's XDR externals (their `MaxFrameAverage` is the full-screen sustained HDR level), so `AppleXDRProducts` gives it by vendor 0x610 and product ID: 500 nits for the Pro Display XDR (0xAE21–0xAE23, 0xAE2D–0xAE2F), 1000 for the Studio Display XDR (0xAE42–0xAE43), the IDs macOS's own display overrides list; the same entry gives the panel peak (1600 / 2000) when the attributes carry none. Policy never takes an Apple XDR external's frame average as its SDR white (`GainCeiling.frameAverageSDRWhite`, also used by Boost's `SDRWhiteSource`: `SDRWhiteSourceTests`), and an Apple XDR external is never OLED by its black level. Core's Apple XDR fixtures carry exactly what the builder makes of them (`PanelClassTests.theAppleXDRExternalsEqualCoresFixtures`). The "no framebuffer service" rule applies only on the walk's positive evidence: framebuffer services exist, at least one external's attributes parse, and fewer external framebuffers carry `DisplayAttributes` than there are external displays the CoreGraphics rules leave standing (`IORegistryFacts.attributedExternalCount`); a renamed key or attributes that arrive late leave a monitor real (`VirtualAndMirrorTests.aMissingFramebufferNeedsTheWalksEvidence`). With `OVERBRIGHT_HARDWARE=1` on Apple silicon, `RealDisplayReadTests` require the framebuffer services, the built-in's panel while the built-in is online, and every online non-placeholder external paired with its attributes and not virtual.

### 10.5 WP3 — Triggers · `OverbrightTriggers`

- **Owns:** `Pkg/Sources/OverbrightTriggers/**`, its tests and catalog.
- **Depends on:** WP0a.
- **Delivers:** `WindowRecipes` + `TriggerHost` (layer hosting, occlusion reporting, **screen-change reporting**, re-placement), `TriggerGeometry` (corners, notch with global/local auxiliary areas), `TaggedColor`, T1 `TaggedLayerTrigger` (tag ≥ 1.01; legacy 14–25 path compiled behind a flag, off), T2/T3 `MetalClearTrigger` (per-display device from `CGDirectDisplayCopyCurrentMetalDevice`, `rgba16Float`, extended linear sRGB, 2 drawables, `allowsNextDrawableTimeout`, first-present retry, keep-alive as a stored `Task`, device released on remove), T4 `HLGStillTrigger` + `HLGStillAsset` (runtime generation, verification, atomic move), T4-alt `HLGSampleBufferTrigger`, `CompatibilityOverlay` (tagged colour on 26+, Metal 4 × 4 on 14+, `multiplyBlendMode`, request-then-boost, factor 1 at configuration begin), `SystemTriggerFactory` with `openWindowCount`.
- **Acceptance:** builds at the macOS 14 floor for both architectures with zero warnings; no `.metal` file; no library, function or pipeline API referenced (a test greps the module's symbols); nothing orders a window in during tests; `NSColor` component initialisers absent.
- **Tests:** `TriggerGeometryTests`, `TaggedColorTests` (26+: tag round trip, 1.01 clamp, components > 1 survive, the 8-bit wrap regression), `HLGStillAssetTests` (ProRes always, HEVC when available, cache reuse, corrupt file replaced; temp dir only), `WindowRecipeTests` (configured but never shown; screen-change callback wiring), opt-in `MetalClearPassTests`.
- **As built (WP14 review fixes):** `TriggerModuleLintTests` checks `.public` log interpolations against an allowlist (a `LoggedError` summary, inline or a name that every binding in the file binds to one, a raw value, an asset file name, an ID, a count) instead of matching error shapes on one line, so a description bound to a name first is caught; the lint has its own positive and negative cases. It scans each file as one text, so an interpolation split across lines is judged whole, and a `privacy: .public` it cannot attribute to an interpolation's last argument is a violation too (WP14 leftovers, C-PLATFORM-10). A summary is one whole call that nothing continues: `LoggedError.publicSummary(error) + detail` or `….appending(detail)`, inline, in a binding or on the binding's next line, is none, and a name that a compound assignment extends (`summary += detail`) is no summary either (WP14 final nits; the scan is `Support/PublicLogLint.swift`, with a self-test case for each). `HLGStillTriggerTests` no longer ties the manual clock to real time: it waits (up to 30 s) for AVFoundation to load the item, then advances one poll interval.

### 10.6 WP4 — Boost engine · `OverbrightBoost` (`Engine/`, `Ladder/`, `Writer/`)

- **Owns:** `Pkg/Sources/OverbrightBoost/{Engine,Ladder,Writer}/**`, `Pkg/Sources/OverbrightBoost/Resources/Localizable.xcstrings`, `Pkg/Tests/OverbrightBoostTests/{Engine,Ladder,Writer,Fakes}/**`. `Shared/` stays the contract owner's.
- **Depends on:** WP0a. **Builds against:** the Core fakes, its own test fakes under `Tests/OverbrightBoostTests/Fakes/`, TestSupport's reference reducer and the WP5 seams (stubs until WP5 lands); WP1's real Policy once merged.
- **Delivers:** `BoostEngine` (implements `BoostControl`, `ServiceLifecycle`; the injected reducer; master, linked levels, steps in stops, Dim All, low-level confirmation, pause ownership, resume, continue anyway rules, retry, auto-off, `lastChange` for the HUD, synchronous shield delivery, readiness), `DisplayController` (§4.3 complete, both mechanisms, pre-held path, user-raise poll bursts, screen-change removal, re-base), `TableWriter` and `SafetyLedger` bodies (interlock via `liveCap`, reading age and display checks, hang epoch, ledger-before-write, `writeBaselines(fromLedger:)`), `LadderPlanner` and `StrategyCache` (cached-rung-only backoff, two-arm replacement, lowest ready headroom), `GateEvaluator`, `RampPlanner`, `FlickerGuard` (monotonic-headroom exclusion), `DriftCheck` (sampling, separation, evaluation order, adoption window and budget, app-termination check).
- **Acceptance:** every transition row of §4.3 has a scenario test; every invariant of §4.5 has a test; the 10 000-sequence property test of §9.1 passes with at least 30 % of sequences reaching `boosted`; `offMeansNoTasksNoWindows`; `shieldIsNeutralWhenEmitReturns`; `hangEpochBlocksQueuedWrites`; ramps have ≥ 6 steps and the right durations; stale generations never write.
- **Tests:** `TransitionTableTests`, `InvariantTests`, `EngineFuzzTests`, `PreHeldTests`, `LadderTests` (order by OS and class, OLED black-only, cache key, backoff and replacement rules, override), `GateTests`, `RampTests`, `UserRaiseTests`, `FlickerGuardTests`, `DriftCheckTests`, `RebaseTests`, `LinkedLevelTests`, `DimAllTests`, `LowLevelConfirmationTests`, `PauseTests`, `AutoOffTests`, `HUDChangeTests`.

### 10.7 WP5 — Boost safety and instruments · `OverbrightBoost` (`Safety/`, `SelfTest/`, `Calibration/`)

- **Owns:** `Pkg/Sources/OverbrightBoost/{Safety,SelfTest,Calibration}/**`, `Pkg/Sources/OverbrightBoost/Resources/Safety.xcstrings`, `Pkg/Tests/OverbrightBoostTests/{Safety,SelfTest,Calibration}/**`.
- **Depends on:** WP0a (the seeded stubs and `Shared/`); integrates with WP4 through `DisplayControllerDriving` and `TableWriter`'s seeded signatures only.
- **Delivers:** `LaunchRescue` (console check, classification against profile bases, known-table-writer rule, boost-marker handling, dirty-then-restore with verification and explicit profile-base repair, `--restore-gamma` entry point), `HangWatchdog` (nonisolated; ping-pong, epoch bump and baselines under the ledger lock, fired flag), `SignalHandlers` (dedicated queue: baselines, main-actor stop with a 1 s timeout, exit), `SelfTestRunner` (§8.4; never a scaled write), `CalibrationController` (implements `CalibrationSession`: every display to Standard first, comparison flips ≤ 1 per 1.5 s, black surround, sweep 1.00 → cap in 0.02 steps every 400 ms with `TableWriter.writeCalibrationFactor`, pause at 1.15 × the encoded prediction, Space marks, linear confirmation frame at `0.97 × H`, decision rule of DESIGN.md §9, colorimeter value, record keyed by OS build, mechanism and potential, auto-abort on occlusion, lock, headroom drop or 60 s).
- **Acceptance:** the launch-rescue decision table (not on console; neutral; marker + neutral; residue + table writer; residue alone → cleared; restore leaves zeros → profile base written; residue that stays → banner) fully tested with `FakeGammaPort`; the hang watchdog restores within 3–5 s of a simulated stall from a background thread under Thread Sanitizer (`make tsan`, already in CI); calibration decisions reproduce §5.2 and §5.6 (1.61 → encoded; 3.00 → linear only after "distinguishable"; late, missed or capped → inconclusive).
- **Tests:** `LaunchRescueTests`, `RestoreVerificationTests`, `HangWatchdogTests` (TSan), `HangWatchdogOffMainTests`, `SignalStopTests`, `SelfTestRunnerTests` (scripted headroom → each verdict, incl. pre-held → invalid baseline), `CalibrationDecisionTests`, `CalibrationSafetyTests` (sweep pause, black surround, linear confirmation required, stale record ignored), `CalibrationAbortTests`.

### 10.8 WP6 — Signals and conflicts · `OverbrightSignals`

- **Owns:** `Pkg/Sources/OverbrightSignals/**`, tests, catalog.
- **Depends on:** WP0a (the matcher signature in Policy; WP1's real catalogue once merged).
- **Delivers:** `SignalsMonitor` (ported `ShellEnvironment` plus system sleep/wake, screensaver, console state, ColorSync, HDR suppression, thermal and Low Power through `@Sendable` block observers, power source with synchronous reads in `setBoostActive(true)`, `refreshPowerNow()` and adapter → battery switches, boost-only battery percent, synchronous event delivery), `FullScreenDetector` (ported and extended: Split View, regular-app filter, our PID, menu-bar-by-PID, 3 s sticky absence, 0.6 s debounce, full-screen video via the owner's assertion), `IdleScheduler`, `CameraMonitor` (CMIO on the main queue, transport filter, debounce), `PlaybackAssertions`, `GameCategory` reader, `ScheduleTimer`, `RunningAppsConflictProbe` (+ libproc fallback off main), `FocusDirectiveStore` (behind `setFocusDirective`, persisted).
- **Acceptance:** zero sources running while boost is inactive except the always-on cheap notifications (a test enumerates active sources in each state); every evaluator is pure and tested with fixtures from the owner's Mac (layers 0/24/2001/2004, the 30-pt menu bar window, notch band); every off-main entry point has a background-queue test.
- **Tests:** `FullScreenEvaluateTests`, `FullScreenVideoTests`, `SplitViewTests`, `IdleSchedulerTests`, `CameraDebounceTests`, `AssertionParsingTests`, `ScheduleBoundaryTests`, `PowerReadTests`, `ConflictProbeTests` (scripted launch/terminate), `RunningAppsTests` (launches and terminations seen only by the running list's KVO, posted once per process; WP14), `SnapshotPublicationTests`, `<Source>OffMainTests`.

### 10.9 WP7 — Fill Light · `OverbrightFillLight`

- **Owns:** `Pkg/Sources/OverbrightFillLight/**`, tests, catalog.
- **Depends on:** WP0a.
- **Delivers:** `FillLightController` (implements `FillLightControl`), the frame window per display (§7.6 recipe; holds `OwnEDRSurfaces` while the frame requests EDR headroom, as built), EDR colour with headroom (tagged `CALayer` 26+, clear-only `CAMetalLayer` 14–25, SDR fallback; tag min(2 ÷ 0.97, potential), at least 1.01), `ColorTemperature` (pure CCT → linear sRGB, 3 000–6 500 K), camera rule (acts on Signals' debounced `isCameraInUse`, which is on after 1 s and off 3 s after the camera stops, with no delay of its own; manual off wins until the camera stops), live updates from settings, capture exclusion.
- **Acceptance:** zero work while off; never ordered in during tests; the CCT function matches reference values within 1 %; the window ignores mouse events and is excluded from the full-screen detector.
- **Tests:** `ColorTemperatureTests`, `FillLightRuleTests` (camera on/off/manual), `FrameGeometryTests` (width, rounded inner corners, notch), `OwnSurfaceRegistrationTests`.
- **As built (WP14 review fixes):** `FillLightLayers` takes the Metal path's present as a closure (`MetalPresent`, the real one wraps `MetalFrameContent.present`), so `FrameWindowTests.theMetalPathPresentsADrawableOnlyWhenAsked` shows, with no device and no window, that `apply` and `showColor` with `presentsDrawable` false never ask for a drawable (whose `nextDrawable()` can block the main thread for 1 s).

### 10.10 WP8 — Intents, Focus filter, channel, dormant Controls · `OverbrightIntents` + `OverbrightChannel` + `App/Intents/` + `Shared/` + `Controls/`

- **Owns:** `Pkg/Sources/OverbrightIntents/**`, `Pkg/Sources/OverbrightChannel/**`, their tests and the Intents catalog, `App/Intents/**`, `App/Localizable.xcstrings`, `App/AppShortcuts.xcstrings`, `Shared/**`, `Controls/**` (sources and catalog; the pbxproj entries are WP0a's).
- **Depends on:** WP0a.
- **Delivers:** `IntentRouter` (no-argument init, `connect`, readiness wait with timeout, every intent of §7.7 in canonical units, launch-policy override, `focus(_:)` → `setFocusDirective`), `DisplayEntity`/`DisplayQuery`, the extra-brightness parameter (preset `AppEnum` or multiplier), the Focus filter and its launch-time `.current` read, `AppShortcutsProvider` (two phrases), `BoostChannel` and `URLRoute` (Channel), `ControlStatePublisher` (Intents), the dormant control (`BoostToggleControl`, value provider with the liveness gate), every string of DESIGN.md §12.8.
- **Acceptance:** `CONTROLS=1 make build` and the default `make build` both pass with zero warnings; `make smoke`'s metadata check (written by WP0a) finds every intent and the Focus filter with `FocusConfiguration`; every `perform()` is `@MainActor` and one line; no App Group anywhere; the extension links only `OverbrightControlsKit`.
- **Tests:** `IntentRouterTests` (each intent against `PreviewBoostControl`, connection, readiness timeout, Focus sink), `BoostChannelTests` (pack/unpack properties), `URLRouteTests` (token, off always, malformed), `CatalogParityTests` (every intent and control key exists in the app and extension catalogs).
- **As built (WP14 review fixes, C-SHELL; §7.7, DESIGN.md §12.8):** Get State joins its sentences with the catalog's two-sentence joiner (`theSentencesJoinAsTheLanguageWritesThem`); Pause takes plain seconds and bounds them (`pause(forSeconds:)`, `longestPause` 24 h, `fallbackPause` 1 h; `everyPauseLengthIsSafe`); the router observes the engine's readiness only while an intent waits (`theRouterObservesReadinessOnlyWhileAnIntentWaits`, `aRequestBeforeTheConnectionWatchesOnceConnected`); the Display type has its plural "Displays", a plain `%lld Displays` literal both the compiler and the App Intents metadata key the same way (`CatalogParityTests`). Suites as built: `IntentRouterTests`, `IntentReadinessTests`, `StateReportTests`, `ControlStatePublisherTests`, `CatalogParityTests`, and Channel's.

### 10.11 WP9 — Design system · `OverbrightDesign`

- **Owns:** `Pkg/Sources/OverbrightDesign/**`, its tests and catalog.
- **Depends on:** WP0a (component signatures fixed there).
- **Delivers:** tokens of DESIGN.md §2–§3 (colour incl. `BoostColor`, `tick`, `neutral`, the headroom marker, with the full contrast audit; typography, spacing, radii, strokes, hit targets, materials with the 14/15 fallback and Reduce Transparency, motion table and `reducedSpec`), `OverbrightTheme` root, `OverbrightSymbol` allow-list, RTL helpers, every component listed in §10.0 with previews, `SettingsStore.binding(_:)`, **the copy builders and every user-facing name and sentence of Core and Policy enums** (DESIGN.md §12, including the Safe-limit variants and the HUD texts), haptics at the detent and presets, `EDRPreviewSurface` (EDR content in our own view, registered with `OwnEDRSurfaces` by its host; SDR stand-in when simulated).
- **Acceptance:** contrast audit table of DESIGN.md §2.1 reproduced by tests for every token; `SymbolTests` (every symbol exists on macOS 14, none restricted, the moon used only for Focus); `BoostSlider` keyboard and VoiceOver behaviour (adjustable action, named stops in canonical units, detent, steps in stops, allowed-now marker); snapshots in Light, Dark and Increase Contrast.
- **Tests:** `ContrastAuditTests`, `SymbolTests`, `RightToLeftTests`, `BoostSliderTests`, `ChipModelTests` (every `LimitReason` → copy, colour, symbol; per-display only), `VerdictTextTests`, `HUDTextTests`, `MotionTests`, component snapshots; as built also `ValueTextTests`, `ThemeTests`, `BoostColorTests`, `NamesTests`, `DesignSeamTests`, `BoostSliderHostedTests` (keyboard and scrolling in an off-screen window, every wait an `eventually` on its condition), `ScrollWheelStepsTests` and, from the WP14 review, `BoostSliderDrawingTests` (rendered pixels: the allowed-now marker over the thumb, the thumb inside the track at both ends, the Increase Contrast ring), `BannerFitTests`, `BannerModelTests` (the middle cut of an app name) and `EDRPreviewSurfaceKeyTests` (← / → move the Welcome divider).
- **As built (WP14 review, C-DESIGN):** DESIGN.md says what is built: the banner sentence is never cut (§2.2, §5.8); every readout state, "Off" included, is `labelColor` (§5.6); the allowed-now marker is 2 × 24 pt over the thumb in a 1-pt `panelBackground` halo, the thumb's centre travels the track inset by its radius, and Increase Contrast rings the thumb (`thumbRing`) (§2.1, §2.3, §5.5, §15); scrolling follows the hand with natural scrolling on or off (§5.5, §15); the Welcome card's divider takes ← / → (§8, App. A).

### 10.12 WP10 — Panel, status item, menu, HUD, Help · `OverbrightPanelUI` + shell `StatusItem/`, `Panel/`, `HUD/`, `Help/`, `Dock/`

- **Owns:** `Pkg/Sources/OverbrightPanelUI/**` (incl. `QA/ScriptedStatuses.swift`, `Help/HelpView.swift`), its tests and catalog, `Pkg/Sources/OverbrightAppShell/{StatusItem,Panel,HUD,Help,Dock}/**`, `Pkg/Sources/OverbrightAppShell/Resources/StatusMenu.xcstrings` and `Pkg/Tests/OverbrightAppShellTests/{StatusItem,Panel,HUD,Help,Dock}*`.
- **Depends on:** WP0a (Design seams; WP9's visuals when merged).
- **Delivers:** DESIGN.md §4–§6 and §12.6: the code-drawn status symbol (six states, template, accessibility label), click routing (panel / toggle mode, right- and ⌃-click menu), the `NSMenu` (first-line status sentence, Dim All Displays, title case, live key equivalents, per-display quick levels with visible presets, pause line + Resume, Update Available), the panel window and its SwiftUI content (header, cards, slider with the allowed-now marker, readout, chips on their own line, banner, footer chips, non-capable row and "Why?", the Fill Light card, overflow menu, keyboard map), the HUD (levels, preparing, blocked, automation variants), the Keep-this-level prompt, the icon visibility monitor and its window, the Help window and view, the Dock menu (wired by WP13), the `ScriptedStatuses` of DESIGN.md §5.13.
- **Acceptance:** a snapshot per scripted status in Light/Dark/Increase Contrast; menu rows dumped and tested; a keyboard-only walk of the Tab order in a test; measured-width fit tests for chips, readouts, value tags, the footer row and the HUD in English and a pseudo-long locale (Russian and all 35 in WP15).
- **Tests:** `StatusSymbolTests`, `ClickRoutingTests`, `StatusMenuTests`, `PanelLayoutTests`, `PanelKeyboardTests`, `HUDPolicyTests` (sources that show it, automation variants, never two), `LowLevelPromptTests`, `IconVisibilityTests`, `HelpAnchorTests`, `ChipFitTests`, `ReadoutFitTests`, `FooterFitTests`, `HUDFitTests`, snapshots.
- **As built (WP14 review fixes, C-PANEL; behaviour in DESIGN.md §4.3, §5.3–§5.12, §6, §12.2–§12.4, §15, §16 and §4.9, §7.2, §8.8 here):** a card shows `DisplayCardModel.displayedLevel` (Standard for a boost level in a switched-off or unavailable half; the stored level stays for the next turn-on), on its thumb, value tag, VoiceOver value, the menus' checkmark and the HUD (`HUDContent`, never the lagging on-screen state; a turn-on's "Preparing…" line holds until the display is ready, at most 3 s, then the level reached for 1.5 s); the allowed-now marker stops at the decision's binding cap in ×0.01 steps; one `panelCard` style (304 pt) for display cards, the tip, the Fill Light card and the Why rows, with a 280-pt slider row and a footer inset like the cards (`FooterFitTests` measure the drawn row in every language); `CardChipLine` puts Turn on under the chip when both do not fit; every focused element has keys, and footer chips, the overflow menu and the Fill Light display pop-up open as AppKit menus at the control (`KeyboardMenu`; `StatusChip`'s `isPresented` binding); a booster's drift stop offers Use Compatibility mode on the chip, the banner and the menu (`CardAction.continueInCompatibilityMode`: that display switches to the overlay and the app is continued, so the reducer's S1 rule lets it through, `CardMenuTests`); the banner and the menu's first line name the display a stop happened on; the master switch draws its on state in the accent colour (`PanelSwitchStyle`); the card list ends on a card boundary with a faded peek and shrinks first (`PanelScrollFade`); the Fill Light card is a grid whose controls column takes the rest of the inner width (`FillLightCardTests`); `OLEDBoostGate` drops a waiting boost level below the detent; Help observes the shortcut center (`HelpView(anchor:shortcuts:)`); named menu keys come from the combo's key code; the icon-not-visible window is titled with its heading; `PanelContainer` delegates to `SurfaceMaterial.makeContainer`; VoiceOver hears every qualifying HUD change with the window off or the Keep-this-level prompt up, a change to every display shows on the display under the pointer, and the Dock menu's Back to Standard shows the HUD. The fit tests open PanelUI's table of each language from its `.lproj` URL and `#require` it (`PanelWords`). Suites as built: `StatusItemSymbolTests`, `StatusItemClickRoutingTests`, `StatusItemMenuTests`, `StatusItemVisibilityTests`, `StatusItemIconWindowTests`, `PanelLayoutTests`, `PanelKeyboardTests`, `PanelAccessibilityTests`, `PanelSnapshotTests`, `CardMenuTests`, `DisplayCardModelTests`, `FillLightCardTests`, `HelpAnchorTests`, `ChipFitTests`, `ReadoutFitTests`, `FooterFitTests`, `HUDPolicyTests`, `HUDFitTests`, `HUDContainerTests`, `HUDLowLevelPromptTests`, `HUDSnapshotTests`, `HelpWindowTests`, `DockMenuTests`.

### 10.13 WP11 — Settings UI · `OverbrightSettingsUI` + shell `Windows/Calibration*`, `Windows/SelfTest*`

- **Owns:** `Pkg/Sources/OverbrightSettingsUI/{Panes,Calibration,SelfTest}/**` and tests; the shell's `Pkg/Sources/OverbrightAppShell/Windows/{Calibration,SelfTest}*` and `Pkg/Sources/OverbrightAppShell/Resources/Calibration.xcstrings`.
- **Depends on:** WP0b (the SettingsUI infrastructure).
- **Delivers:** every pane and row of DESIGN.md §7 with defaults, ranges, footnotes, search keywords and deep links (incl. Quit Overbright, Undo Reset, the full-screen video and every-full-screen rows, the timer and battery ranges, "Add extra brightness only near full brightness", the hidden-icon warning row); the paused-apps editor (from Cranny's excluded-apps editor, with suggestions and modes); per-display sections with verdicts and fixes; the calibration view (Standard first, checklist, comparison, black-surround sweep with its pause, linear confirmation, results with the "turn them back on" line) and the self-test sheet (progress, results table, Save, Copy); Reset per row, per pane and Reset All with Undo.
- **Acceptance:** search finds every row by its label and keywords ("HDR", "XDR", "nits", "brighter", "dim", "battery", "shortcut", "camera", "login", "quit"); every row with a value has Reset to Default; snapshots of every pane; segment fit tests (Safe/Peak) in English and pseudo-long.
- **Tests:** `PaneRowsTests`, `SearchAndNavigationTests`, `PausedAppsEditorTests`, `CalibrationViewModelTests`, `SelfTestSheetTests`, `UndoResetTests`, `TerminologyTests`, `SettingsSegmentFitTests`, snapshots. As built (WP14): "every row with a value has Reset to Default" is also checked on the views, not only on the panes' `RowValue` lists: `everyRenderedValueRowCarriesItsReset` renders each changed row in its pane with a `SettingRowAudit` in the environment (rows report the reset of their `settingRow` through an empty background view) and runs that reset; the pane snapshots look up the listed apps first, so no row renders as a pending lookup.
- **As built (WP14 review fixes, C-SETTINGS):** search follows row state: `SearchIndexCache` observes what building the rows reads, so rows that appear with a setting or app state (From / To, Battery level, OLED idle, the icon warning) are found at once (`theIndexFollowsTheStateItsRowsDependOn`); only a fresh deep link to Run Self-Test… opens the sheet, never a search hit (`SettingsNavigator`); a colorimeter value outside 20–4,000 nits is refused inline; calibration step 1 announces each flip (at most once per 1.5 s); the shortcut recorder speaks what it shows and never beeps, a paused app's mode pop-up and each Always continue switch are named after their app, and names in "Remove ‹App›" and the calibration window title are bidi-isolated; Copy encodes the self-test log off the main actor (§8.1 rule 3); `SliderRow` settles on whole steps without per-step ticks, with captions under the track; the calibration model is split (`ComparisonSequence`, `CalibrationModel+Step`); the calibration window decides simulated from the services (§7.6). The paused apps' add control is DESIGN.md §7.5's **+** menu (`OverbrightSymbol.plus`, "Add App" to VoiceOver and as its help tag; WP14 C-SETTINGS-11). Open, for the contract lane (WP14 C-SETTINGS-11): every switch from Safe to Peak asks (DESIGN.md §7.4 and §12.4: asking only the first time needs a "Peak acknowledged" settings key, and §3.8 keeps no record of an earlier answer); and `FillLightPane` reads `CGDisplayBounds` for a real display's width until `DisplayDirectory` exposes bounds (a simulated display is never looked up and uses the 14-inch width, since fixture IDs can equal real display numbers).

### 10.14 WP12 — Welcome · `OverbrightOnboarding`

- **Owns:** `Pkg/Sources/OverbrightOnboarding/{Steps,Model}/**` and tests.
- **Depends on:** WP0b (the Onboarding chrome); uses PanelUI's `DisplayCardView` seam (WP10's body when merged).
- **Delivers:** DESIGN.md §8: five steps (hello with the before/after card, displays with live re-evaluation, defaults, where to find Overbright with live key caps and the Run Shortcut recipe, done with the update toggle and a Turn On button only when a display can boost); Quit Overbright on every step and in the Skip alert; Skip applies every default including the login item; `WelcomePlan` (update toggle only when configured).
- **Acceptance:** every step reachable with ↩, ⌘[ and Esc; launch behaviour applied on Done or Skip; snapshots per step (US, German and French key caps on step 4); nothing writes a table (the card is our own EDR content, `gammaWrites` stays 0 in a welcome run under `--qa-simulate`).
- **Tests:** `WelcomePlanTests`, `WelcomeFlowTests`, `SkipAppliesDefaultsTests`, `CopyGlossaryTests`, snapshots.
- **As built (WP12), deviations confirmed by the contract owner in WP14** (DESIGN.md §8 "As built"): step 2 has a compact stage, a band of display glyphs with the headline at its boundary and the rows under it, instead of the half-height stage (C-ONBOARD-1; WP12 had given the rows the whole page); its rows are built from `DisplayCardModel` with Welcome's own row view rather than through the `DisplayCardView` seam (no slider in Welcome, the same limit, default and top as the panel); step 2's switches wait in `WelcomeChoices` until Done and Skip drops them; `WelcomeDisplayRow.showsInWelcome` hides `notCalibrated` (and `autoBrightnessInteracts`, Settings only). Tests: `WelcomeFlowTests`, `SkipAppliesDefaultsTests`.
- **Shown at app level (WP14):** `make qa-matrix` opens Welcome with `--qa-welcome hello` and `--qa-welcome displays` in fresh defaults suites (Welcome never finished) under `--qa-simulate builtin-xdr-lid-open`, dumps the status after 3 s (`--qa-script 'wait 3; dump welcome; …'`) and fails unless `gammaWrites` and `triggerWindows` are 0 (`qa_check.py`); both were 0 on macOS 27.0.1.
- **As built (WP14 review fixes, C-ONBOARD; DESIGN.md §8):** one split on every step (`StepLayout`; steps 2 and 3 a compact `StepStage`), so the headline always sits at the stage boundary; the progress dots centred in the window (`CentredRow`), in the footer row or on their own line just above it where the buttons reach the centre (the last step with Turn On Overbright, in English and 32 other languages; ar, ko and tr keep them in the row: dots above the row on every step were measured and not kept, since they cost 10 pt and step 2 with three displays would then scroll in Russian); step 5 sums up the defaults Done applies (`DoneSummary`); a display row puts its switch on its own line when the name would wrap beside it (`DisplayNameLine`); the focused login card draws the focus ring, selected or not (C-ONBOARD-2); a language's strings open from its `.lproj` folder by URL, never through `path(forResource:ofType:)`, which can fail under load (C-ONBOARD-3); step 1's card shows only the light of the window's own display (`WelcomeCard.otherDisplay` when that display has no extra range and another has; `.checking` while it is unread; C-ONBOARD-4); Skip and the close button register the default login item on a later Welcome too (C-ONBOARD-5); the hosted step asserts its EDR view (C-ONBOARD-6). Tests: `WelcomeLayoutTests`, `WelcomeFooterFitTests`, `WelcomeStepFitTests`, `SelectableCardFocusTests`, `HelloStepHoldTests`, `WelcomePlanTests.everyLanguageResolvesUnderParallelLoad`, `SkipAppliesDefaultsTests.aLaterRunKeepsWhatSettingsHold`.

### 10.15 WP13 — Integration (phase C)

- **Owns:** the shared files (from the contract owner), `Additions/` folding.
- **Depends on:** WP0b, WP1–WP12.
- **Delivers:** `CompositionRoot` with the real implementations and the ordered lifecycle (Displays → Triggers → Signals → FillLight → HotKeys → Updates → Intents → **Boost last**; stop in reverse, **Boost first**), the router connection; `AppDelegate` order (§7.4: Release refusal of Debug-only switches → `ShellDefaults` → services hub → CLI modes (`--diagnostics`, `--monitor`, `--restore-gamma`) → single instance → move to Applications → settings upgrade → windows and status item → `LaunchGate`: launch check, then the services start); launch UI (§7.6); the quit of §7.4 (cancel once, ramped stop, terminate); Dock icon wiring; the controls publish point; diagnostics report filled; HUD wiring; end-to-end tests with every fake; the QA matrix under `--qa-simulate`.
- **Acceptance:** every fixture of §3.9 runs `make run`-style scripted scenarios end to end with correct chips, banners and symbol; smoke green; a 30-minute soak under `--qa-simulate` with scripted events shows no leak and zero periodic work while off. As the gate is built (WP14, `scripts/soak_judge.py`, whose header has every rule):
  - **Leak: threshold and baseline.** The baseline is the footprint after cycle 3 (`vmmap`'s physical footprint, in tenths of a MB), not the launch: the first cycles fill caches that then stay, so the footprint before the cycles and after cycles 1 and 2 is reported and never judged, and growth that stops by cycle 3 passes unseen (WP13's 30-minute run: 31 MB off before the cycles, 42 after cycle 1, 46 after cycle 2, 47 after cycle 3, 48 at the end; WP14's first 17-minute run, the **settling run**: 42.4 after cycle 1, 46.5 after cycle 3). From the baseline on, a leak is a least-squares growth over cycles 3…N above **100 KB per cycle** (`LEAK_KB`) even at its lower 2-standard-error bound (± figures here are 2 standard errors, as the judge prints them: the settling run read 129 ± 142 KB, a lower bound of −13, and passes; a 0.29 MB-per-cycle leak reads 288 ± 102, at least 186, even in a short run), or a footprint at the end more than **5 MB** (`LEAK_MB`) above cycle 3's. A run is judged only with 5 or more cycles after cycle 3 (one cycle is 66 s, so `MINUTES` ≥ 17).
  - **Wake-ups while off.** Overbright's own idle wake-ups are those the control app does not share in the same 10 s sample. In the final off phase (6 minutes after the cycles) **any own idle wake-up fails the run**, whatever its rhythm (DESIGN.md §17: off is 0 wake-ups/s). In the first off phase, right after the launch, own wake-ups fail only when they beat periodically: a run of 4 or more in a row spanning 30 s or more is scored by how evenly it beats ((L − 2) · ln((2d + 10 s) / m) for median gap m and gaps straying at most d from it) and is a timer when as many wake-ups at random samples of the phase beat as evenly less than 2 % of the time (2 000 seeded placements). In either phase the samples the app shares with the control must not hide such a rhythm (3 in a row suffice in the final phase) when the control's own samples have none.
  - **History and evidence.** WP14's first gate allowed own wake-ups in the final phase at one a minute or fewer that did not beat periodically (its fixed tolerance, gaps within 25 % of their median, had called 3, 4 and 5 wake-ups at random times periodic 31, 55 and 73 % of the time and brought back WP13's flaky soak; the chance test that replaced it still let a slow timer that shows only 3 or 4 times pass unless it beat nearly exactly). WP14's last round made the final phase strict: every run beside the control (WP13's fix round, WP14's) counted 0 own wake-ups there, and its own second `MINUTES=17 make soak`, the **strict-judge run**, passed (8 cycles: 0 idle wake-ups for both apps in the first 96 s and the final 373 s off; footprint 27.4 MB off before the cycles, 37.1 after cycle 1, 42.0 after cycle 3, 41.9 at the end, a slope of −29 ± 72 KB per cycle). The self-test (30 cases, run by `make lint`) refuses one own wake-up, five irregular ones and a timer every 125 s in the final phase, accepts wake-ups the control shares but refuses a 60 s timer hidden behind the control's irregular ones, and refuses at most 3 % of 1 000 seeded draws of 4–6 random own wake-ups after launch and at most 5 % of draws in which the app shares 3–5 of the control's random samples (0–1.7 % as built). The literal "`top` idle wake-ups 0" on a quiet machine is the owner's run (HARDWARE-TEST §13). The **settling run**, WP14's first `MINUTES=17 make soak` (8 cycles, judged by the first gate): 0 idle wake-ups for both apps in the first 96 s and the final 349 s off; footprint 42.4 MB after cycle 1, 46.5 after cycle 3, 47.0 after cycle 8 and 46.0 at the end, a slope of 129 ± 142 KB per cycle (2 standard errors; the first version of the gate, without the error bound, failed this settling run); WP13's 30-minute run reads 50 ± 13.
- **Tests:** `EndToEndScenarioTests`, `LifecycleOrderTests`, `LaunchOrderTests`, `ReopenTests`, `QuitTests`, `DockMenuTests`, `DiagnosticsReportTests`; as built also `LaunchCheckSignalsTests` and `QAHUDTests`.
- **As built (WP14 review fixes, C-SHELL; §7.4, §8.5):** a launch check skipped off the console runs again right before the engine starts when the session came back to the console before Signals started, which posts nothing Signals hears (`CompositionRoot.launchCheckBeforeBoost`, `ServiceRunner.start(beforeBoost:)`; `aSessionBackOnTheConsoleBeforeSignalsStartsIsCheckedBeforeTheEngine`); a QA defaults suite keeps the control's channel silent on the real ports too (`CompositionRoot.controlOutlet(for:)`; `aQASuiteKeepsTheControlChannelSilent`); `--qa-state` shows a whole scripted state (its settings, Fill Light, the "Why?" row; `QAScriptedStateTests.everyReadoutMatchesItsThumb`); every QA surface and the snapshot wait for the launch work (`theSurfacesWaitForTheLaunchWork`, `applyShowsNothingBeforeTheLaunchWork`); `--qa-panel` stays open on clicks elsewhere and logs every close with its cause (`PanelController.CloseCause`); `--qa-snapshot` redraws each SwiftUI root in an opaque host in the window's appearance and `-OverbrightQAAppearance` pins the app's appearance (`QASnapshotTests`).
- **As built (WP13).** `CompositionRoot.livePorts` wires every real implementation (one `CoreGraphicsGamma`, also the directory's; `SystemTriggerFactory`; `RunningAppsConflictProbe` over `ConflictCatalog.entries`; `SignalsMonitor` with Displays' events relayed into it; `FillLightController` over EDR frame windows; `HotKeyCenter` whose presses `ShortcutActions` routes to the engine; `UpdateChecker`; `SMAppService` through `LoginItemController`; the control's real outlet), so no real port is paired with a fake any more. `simulatedPorts` keeps every display port a Core fake and adds Fill Light's SDR stand-ins, an in-memory login item and a silent control outlet; its fakes keep their newest 256 records. `ShellContext` carries what both wirings share; `ServiceStack` holds the one order and `ServiceRunner` runs it (the launch check's outcome reaches the engine right before it starts; a stop that hangs cannot hold the quit past 1 s); `Shell` keeps the engine, the rescue (its deferred outcome goes to the engine) and the `SignalHandlers`, which the launch work installs. `AppDelegate` is `LaunchSequence` plus `QuitFlow`; `ShellAppControl` drives the login item and the status item from their settings; `StatusIconPresence` wires the visibility check to the icon-not-visible window; the Dock menu is `applicationDockMenu(_:)`; `ControlStateService` is the Intents place in the lifecycle. Debug QA adds `--qa-script` / `--qa-status` (`ScenarioScript`, `ScenarioRunner`, `StatusSummary`), and `SIMULATE=1 make smoke` is the agents' smoke. Integration fixes outside the shared files, each with a test: the boost-switch ruling of §6.4 (Policy), `BoostEngine.forgetLearnedMethods()` and one re-reduction when a display settles into boosted (the chip kept the pre-arm reading's \"Safe limit\"), `IntentRouter.requestCount` (the launch Focus read is no request), the visibility check's first-check gate, trigger methods following the Advanced pane on reset, `OverbrightLinkButtonStyle` with a Design name probe, the fakes' `recordLimit`, `FakeOverlayHandle`'s request rule, and two non-trapping integer conversions. Review fix round 1: the delegate reads the first Apple event in `applicationDidFinishLaunching`, where it is current (§7.6; in `applicationWillFinishLaunching` it was nil, so only the fallbacks recognised a login); a quit Apple Event that arrives while a user quit stops terminates at once (§7.4); `ServiceRunner` stops a service whose `start()` returns after a stop; `--qa-hud` sets a level only over the simulated ports (§8.5); the scenario script's `panel open|close`; the soak's control app (below).
- **Acceptance as run by WP13** (agents launch the app only under `--qa-simulate`): `EndToEndScenarioTests` and `make qa-matrix` pass for all 12 fixtures (symbol, banner and chips in Design's English copy); `SIMULATE=1 make smoke` passes on the universal Release build (static and exit-64 checks) and on a Debug build (the report over the fakes, `gammaWrites` 0, `triggerWindows` 0); the soak, stated plainly: on this Mac, which is in use while agents work, the acceptance's literal "`top` idle wake-ups 0" while off holds in some runs and not in others, so the raw count cannot be the gate. WP13's 31-minute soak (22 cycles, 5 192 table writes into the fake) settled at a 44–45 MB footprint by the third cycle (40 MB after the first) and stayed flat, but counted 8 idle wake-ups in its final 6 minutes off; the review's `MINUTES=30 make soak` failed the then-strict check with 5 in the final 352 s (footprint 32 → 40 → 45 → 45 MB), at irregular gaps, with 0.0 % CPU and no log line of Overbright's own. Fix round 1 looked for the cause: in an 8-minute run beside two bare status-item apps (one with a panel like Overbright's), Overbright counted 4 idle wake-ups and the bare apps 0, and the system log shows Overbright doing only work the system hands it, a keyboard-layout reload at every input-source switch (the system sends it to every app that reads the layout through Text Input Sources; Overbright does, for its shortcut key caps, and follows it) and MenuBarAgent's status-item scene updates (every menu bar app gets them; the bare apps logged those, and never a layout reload). `make soak` therefore runs `scripts/soak-control.swift` beside the app, a menu bar app that reads and follows the keyboard layout and does nothing else; keeps the panel closed while off (a user launch opens it; the script closes it, and opens it once per cycle so the footprint check covers it); and judges the final off phase on Overbright's own wake-ups, those the control does not have in the same 10 s sample: neither periodic (4 or more at even gaps) nor more than one a minute (WP14 reworked both gates, and since its last round none is allowed there; see the Acceptance bullet). The footprint at the end must be within 5 MB of the one after the third cycle, once the caches the first cycles fill have settled (the first 30-minute run of fix round 1, judged from the first cycle, passed by a hair: 31 → 42 after cycle 1 → 47 → 47 MB, 0 idle wake-ups for both apps in the final 347 s off), and every cycle's footprint is reported. Fix round 1's `MINUTES=30 make soak` (20 cycles, the panel opened in each): passed, with **0 idle wake-ups for both apps in the final 352 s off** (and 0 in the first 96 s after launch), 4 720 table writes into the fake, no trigger window left, and the footprint 31 MB while off before the cycles, 42 → 46 → 47 MB after cycles 1–3, 47–48 MB from then on and 48 MB at the end (1 MB above cycle 3). So the soak shows no leak and no periodic work while off; a literal 0 on a Mac in use depends on its user (two of the four 30-minute runs had it in the final off phase), and the quiet-machine count stays with the owner (HARDWARE-TEST §13: off = 0 idle wake-ups), as does the real-port smoke (§14 step 8).

### 10.16 WP14 — Review (phase C, parallel with WP15)

- **Owns:** review notes and fix branches (`wp/14-fix-<area>-<n>`), each fix in its owner's paths.
- **Delivers:** a code review against §4.5 invariants, D24, D26, D27, clean-room rules and energy rules; a design review of every snapshot against DESIGN.md; an accessibility pass (VoiceOver-only and keyboard-only runs under `--qa-simulate`); a macOS 14/15 availability review; findings filed as `C-<TARGET>-<n>` and fixed.
- **Acceptance:** no open finding of severity "must"; DESIGN.md and this document synced with "As built" notes.
- **As built (2026-10-17).** The review ran in nine areas, each fixed on its own branch and merged into `main` as "Merge WP14 fixes: <area>": C-SIGNALS (WP6), C-DESIGN (WP9), C-PLATFORM (WP1–WP3, WP7), C-SHELL (WP0b, WP8, the shell), C-ONBOARD (WP12), C-SETTINGS (WP11), C-PANEL (WP10), C-RELEASE (build, CI, project, docs) and C-BOOST (WP4, WP5). What each built is in the behaviour sections it changed and in the "As built (WP14 …)" bullets of §10.2–§10.15; the Changelog has one entry per round. The contract lane added `EngineFeedback.fullBrightnessHeadroom`, `DisplayStatus.lastGrant`, the equal-ends rule of `ScheduleWindow` and the capped sleep tolerance (§3.4–§3.6) and `DisplayVerdict.panelFactsUnknown` (§3.2, §5.3; C-PLATFORM-3, in the WP14 leftovers), and Policy gained `GainCeiling.frameAverageSDRWhite` (§3.10).
- **Handed on, each with its home:** `DisplayStatus.lastGrant` reaches no verdict sentence yet, because Settings, Welcome and the panel pass `lastGrant: nil` to `VerdictText` (DESIGN.md §12.1); C-SETTINGS' two details that need the contract lane (§10.13); and for the owner's session the read-only hardware suites (HARDWARE-TEST 1.13) and "Displays have separate Spaces" off (7.10, 7.12, H-FS2). Extra brightness itself has not run on a real display yet: every boost so far ran against the simulated ports (WP16).
- **Test count** (`make test` on 2026-10-17, macOS 27.0.1, Xcode 27, after the last WP14 merge): 1 788 Swift Testing tests in 242 suites, all passing: AppShell 218, Boost 357, Channel 19, Core 111, Design 162, Displays 84, FillLight 93, HotKeys 16, Intents 43, Onboarding 89, PanelUI 90, Policy 100, SettingsUI 122, Signals 159, Triggers 104, Updates 21 (a parameterized test counts once; 11 skip themselves without their switch: `RealDisplayReadTests` and `MetalClearPassTests` without `OVERBRIGHT_HARDWARE=1`, the component gallery without `OVERBRIGHT_SNAPSHOT_DIR`, and a check that runs only before macOS 26). The count is the number of `@Test` declarations, so `grep -rho '@Test\b' Packages/OverbrightKit/Tests | wc -l` gives the current one without a build, and a run prints it per target ("Test run with N tests in M suites").

### 10.17 WP15 — Localization (phase C, parallel with WP14)

- **Owns:** every `.xcstrings` translation state, `docs/l10n/terms/*.md`.
- **Delivers:** 35 languages for every key (Russian first as the pivot), the glossary of §8.8 confirmed per language, Apple terms from `apple-terms.py`, brand suffix decisions (fi, hu, tr), fit-test fixes by rewording.
- **Acceptance:** `make strings-check` with no pending key; every fit test green in every language (the Russian and all-language fit tests of WP9–WP12 are WP15's acceptance); `validate.py --shipped --release` passes; the denylist is clean in every language including comments.

### 10.18 WP16 — Hardware session and tuning (phase D)

- **Owns:** `EngineTiming` values, `GainCeiling.safeBound` and the taper constants, the ladder defaults, `docs/HARDWARE-TEST.md` results section, open questions in §11.2.
- **Delivers:** the owner runs `docs/HARDWARE-TEST.md`; an agent reads the returned diagnostics, self-test logs and `--monitor` captures and decides: the read-back model (HARDWARE-TEST §2.0), the default rung on 26+/27 (T1 black?), whether T2 frees its working set, tag policy A or B, the transfer domain default per display class, the Safe bound (H-G1), the taper constants (H-B1), the drift tolerance (read-back noise), whether Compatibility mode multiplies (H-C1), whether the control ships ad-hoc (H-CC-1), the SDR-white source (H-N1/H-N2), player and browser assertions (H-P1), camera without TCC (H-F1), login-launch detection (H-L2).
- **Acceptance:** every [HW] item in this document resolved or explicitly deferred with a reason; a changelog entry lists every constant changed and the evidence.

### 10.19 WP17 — Release (phase E)

- **Delivers:** the icon rendered by `make icon` (DESIGN.md §14), README final, notices, privacy statement, `VERSION`, `make dist` (+ notarization if the owner signs), release notes, docs synced ("As built").
- **Acceptance:** a clean install on the owner's Mac passes the release checklist of `docs/HARDWARE-TEST.md` §15; `release.yml` dry run green.

### 10.20 Dependency summary

| WP | Title | Depends on | Group |
|---|---|---|---|
| WP0a | Foundation and contracts | — | A |
| WP0b | Ports and docs | WP0a | B |
| WP1 | Policy | WP0a | B |
| WP2 | Displays | WP0a | B |
| WP3 | Triggers | WP0a | B |
| WP4 | Boost engine | WP0a | B |
| WP5 | Boost safety and instruments | WP0a | B |
| WP6 | Signals and conflicts | WP0a | B |
| WP7 | Fill Light | WP0a | B |
| WP8 | Intents, Focus filter, channel, dormant Controls | WP0a | B |
| WP9 | Design system | WP0a | B |
| WP10 | Panel, status item, menu, HUD, Help | WP0a | B |
| WP11 | Settings UI, calibration and self-test views | WP0b | B (late start) |
| WP12 | Welcome | WP0b | B (late start) |
| WP13 | Integration | WP0b, WP1–WP12 | C1 |
| WP14 | Review | WP13 | C2 |
| WP15 | Localization | WP13 | C2 |
| WP16 | Hardware session and tuning | WP13 (+ WP14 fixes) | D |
| WP17 | Release | WP14, WP15, WP16 | E |

Phase-B packages never touch each other's paths (the contract lane's mechanical switch updates excepted); where one uses another's output (PanelUI → Design visuals, Onboarding → PanelUI's card, Boost → Policy bodies and WP5's safety types, Signals → the catalogue, the shell → `DisplayMonitor`, `URLRoute`, `ScriptedStatuses`), it codes against the WP0a seam and picks up the real body by rebasing.

---

## 11. Failure modes, open hardware questions, risks

### 11.1 Failure-mode table

| # | Failure | How we detect it | Response | Covered by |
|---|---|---|---|---|
| 1 | Headroom never arrives (preset without EDR, HDR off, trigger not composited, OS change) | rung timeouts; potential ≈ 1; ladder exhausted | Neutral, trigger removed, `failed(headroomNeverArrived)`, chip "No extra range" with the verdict's fix; retried on wake, unlock, reconfiguration or Retry; after two tries the chip offers Self-Test, Help and Compatibility mode | §4.3, §4.7; H-T*, H-E1 |
| 2 | Headroom already held by something else (HDR video, another app, our Fill Light or Welcome card) | `H0 ≥ max(1.3, G / 0.97)`, `OwnEDRSurfaces` | Pre-held path: cheapest rung, absolute gate, escalate only if H later falls short | D6, §4.3 |
| 3 | Headroom drops while boosted (lock shield, screensaver, thermal throttling, macOS cooldown, brightness keys) | 2 s drift check, screen-parameters notification, occlusion | One write down to `F(0.97·H)` once applied > 0.98·H, or the baseline; re-gate when the cause clears; monotonic tracking is not counted as flicker | invariant 1, 6, 8 |
| 4 | Table reset by the system (reconfiguration, wake, profile or preset change, accessibility options, **any other table writer's death**) | event; drift check; a check 50 ms after any app terminates | Recompute the expected base, adopt it (event-explained only), reapply with a ramp | §4.8 |
| 5 | Another app writes the table | drift classified foreign; catalogue; libproc attribution; adoption budget | S1: suspend all, no Continue on the table mechanism (Compatibility mode offered); S2: suspend, Continue Anyway; S3: suspend that display at the first drift; unknown: 3 repairs in 6 s or > 2 unexplained adoptions in 60 s → stop | §7.2, §4.8 |
| 6 | Another booster's scaled table would be taken as our baseline (and boosted again) | `TableClassifier` (`scaled`, uniform multiple) | Never adopted; arm refused with attribution; S1 never continued on the table mechanism | D26, §4.8 |
| 7 | Table writes succeed but change nothing (known Mac models on macOS ≥ 26.3) | not detectable in software; model list (`CompatibilityModels` + `MachineIdentity`); "Did it get brighter?" | Compatibility mode suggested or automatic | §7.5; H-C1 |
| 8 | Auto-brightness toggled while boosted leaves a bad picture on a built-in XDR | not detectable before it happens | Advisory; Help item "Display looks wrong?"; calibration returns to Standard before asking for the change | §7.4; H-A1 |
| 9 | Overexposed screen (scaled table without headroom) | prevented by the interlock (fresh reading of the same display, hang epoch); drift check headroom term | Baseline in the same turn | invariant 1 |
| 10 | Crash or `kill -9` while boosted | WindowServer restores; boost marker at next launch | Journal "recovered by macOS"; a `scaled` residue → dirty-then-restore with verification | §7.4; H-K1 |
| 11 | Overbright hangs while boosted | ping unanswered 3 s | Epoch bump + background baseline writes; queued scaled writes refused; re-gate on recovery | §4.6, §7.4; H-X1 |
| 12 | Display unplugged or lid closed while boosted | remove flag (immediate), window screen-change notifications | Order out the trigger and overlay at once, drop the controller; overlays to factor 1 at configuration begin; never call CoreGraphics with a stale ID; on reconnect start over | §4.3; H-W5 |
| 13 | External HDR headroom stuck at 1.0 after wake (a known macOS 26 bug) | potential > 1, H = 1 after the wake backoff | Stop retrying; chip "No extra range" with "Turn High Dynamic Range off and on for this display" | §4.3; H-E1 |
| 14 | HDR video clipped or washed out | full-screen video rule, paused-app rules | Pause that display with a ramp; resume 1 s after | §6.5 |
| 15 | Heat or battery pressure | thermal state, IOPS (read synchronously at boost start), Low Power | Cap at serious, stop at critical, battery and Low Power guards (boost only), HUD reason | §6.1, D19 |
| 16 | OLED wear | OLED class | Opt-in with notice on the first move into the boost half, Safe ×1.3, 5 min idle pause, black trigger, trigger shifting | §4.7, §5.3 |
| 17 | Trigger visible as a dot or captured in screenshots | user report; H-W2/H-W3 | Corner under the rounded edge, black first, soft-light on externals, `sharingType = .none` | §4.7 |
| 18 | Compatibility overlay flickers in Mission Control or a Space switch | `activeSpaceDidChange` | Accept and document; re-place after the switch | §7.5 |
| 19 | A main-actor closure or `@objc` method called off the main thread (it traps at runtime under MainActor default isolation) | off-main tests per entry point; review | Every system entry point explicitly nonisolated (§8.1 rule 2) | §7.1, §8.1 |
| 20 | Reference preset active | reference > 0 | Verdict "reference preset", no boost; no dimming either (the preset owns the curve) | D8 |
| 21 | macOS suppresses HDR for an inactive agent (possible for `.high` layers) | suppression messages | Reason "macOS is limiting HDR"; current rung kept, no escalation, no suspension; journaled for H-T1b | §4.3, §4.7 |
| 22 | Flicker from fighting another writer or a wobbling headroom | flicker guard, repair and adoption budgets, dead band | Stop that display, banner "stopped to prevent flicker", Try Again; no automatic restart on unlock or wake | §5.8 |
| 23 | Fast user switching, or Overbright started in a session that is not on the console | session resign; `kCGSessionOnConsoleKey` | Neutral on resign; no table write and no rescue until the session is active | D27, §7.1 |
| 24 | Foreign session-level table at launch | rescue re-read still `scaled` | Banner `foreignTableAtLaunch`, no boost on that display | §7.4 |
| 25 | The global restore writes an invalid (all-zero) table | post-restore verification | Write the profile base explicitly; journal | §7.4 |
| 26 | Two engines at once (installed copy plus a dev build, `open -n`) | bundle-ID check at launch | The second hands over (reopen) and exits | D27 |
| 27 | Stale "On" in a Control Center control after a crash (Controls builds) | liveness gate | Extension reports off when the app is not running; `reloadAllControls()` at launch | §7.7; H-CC-2 |
| 28 | Menu bar icon hidden (crowded bar, notch, user hid it, macOS "Allow in the Menu Bar" off) | visibility check 3 s after launch and on screen changes | A window once per version, a warning row in Settings ▸ General, every non-login launch shows UI, shortcut, optional Dock icon, Help | D13, §7.6; H-M1 |
| 29 | Calibration sets an unsafe transfer domain (late press, missed press, run to the end) | decision rule; linear confirmation frame; record validity | Only a confirmed linear result sets `.linear`; stale records fall back to `.encoded` | §5.2 |
| 30 | A very dark dim level hides the UI | level crosses below 10 % of Standard light | "Keep this level?" with a 10 s revert owned by the engine | §4.9 |
| 31 | A hardware-mirror member would be scaled with another panel's headroom | mirror detection; reading display ≠ target | Verdict `mirrored` (dim only); `TableWriter` refuses foreign readings | D8, invariant 1 |
| 32 | HLG still cannot be generated (no encoder on an old Intel Mac) | write or verify fails | ProRes fallback; else skip the rung | §4.7 |
| 33 | Localized display names | — | No name logic anywhere; Russian fixture tests | invariant 10 |
| 34 | A discrete GPU wakes for the trigger (dual-GPU Intel) | — | Per-display Metal device, `NSSupportsAutomaticGraphicsSwitching` | §8.6 |
| 35 | Calibration sweep interrupted (lock, occlusion, Esc, headroom drop) | events | Abort to neutral at once; record nothing (an earlier record stays); 60 s cap. Ruling (WP13): this row wins over DESIGN.md §9's "stopped early", which means a sweep that ended without a mark. As built (WP14, C-BOOST-19): after an abort `finish(brighter:)` returns nil, so nothing replaces an earlier record, unless the run had already measured something: step 1 answered No, the sweep ended with a mark, or the linear confirmation answered (WP5 returned `.inconclusive` there) | §10.7 |
| 36 | Clock or time-zone change during a schedule | `NSSystemClockDidChange`, `NSSystemTimeZoneDidChange`, day change | Recompute the boundary sleep | §10.8 |
| 37 | Settings corrupted or from a newer version | decode failure | Fall back to defaults per key (Cranny's store), journal | §8.2 |

### 11.2 Open questions for the owner's hardware session

Each item has a step in `docs/HARDWARE-TEST.md`.

| ID | Question | Decides |
|---|---|---|
| **H-R1** | **While boosted at Max, does `--monitor`'s table maximum exceed 1.0 (read-back keeps values above 1) or stay at 1.0 (clamps)?** Run first; every SCALED step depends on the answer | which read-back model the fakes default to; confirms that the classifier flags both |
| H-E1 | `potential / current / reference` for the built-in in P3-1600, P3-600 (and P3-500 if listed), HDR Video, one SDR reference preset; the MSI with HDR on, off, and after sleep/wake; is the built-in's name localized in a ru-RU app | eligibility thresholds and verdict copy |
| H-T1a–d | Does T1 engage and hold with black and with 1.6 on the built-in and the MSI; is it suppressed for an agent; does the tag cap the grant; (14/15 legacy path needs a real 14/15 Mac) | default rung, tag policy |
| H-T2a–c, H-T3 | Does one Metal frame hold; is the GPU working set freed; tagged `CAMetalLayer`; longest keep-alive that holds | rungs 3–5 |
| H-T4a–d | HLG still black vs peak, HEVC vs ProRes, 1 pt vs 5 pt, side effects (Now Playing, assertions), sample-buffer variant | rungs 6–7 |
| H-T6, H-W1–W4 | Notch coordinates; hold across Spaces, full screen, Mission Control, Stage Manager, lock, display sleep; corner pixel invisible on the built-in, visible on the MSI with or without soft light; capture exclusion; each rung on the MSI | placement, recipe |
| H-W5 | Close the lid (MSI attached) and unplug the MSI while boosted, without killing Overbright: does any trigger, overlay or boost appear on the remaining display | display-removal handling |
| H-L1 | Time from arm to first headroom movement | the 2.5 s rung timeout |
| H-G1 | Granted headroom on the built-in at full brightness with our trigger (logs earlier showed grants near 900–1000 nits) | how much Peak adds over Safe; `GainCeiling.safeBound` |
| H-B1 | With "Add extra brightness only near full brightness" on: light at 100 %, 75 % and 50 % system brightness feels continuous; brightness keys keep their range | taper constants (1.15, 2.0) |
| H-D1 | Step wedge: encoded or linear on the built-in (and on the MSI with HDR on); does the linear confirmation frame behave as predicted | default transfer domain |
| H-DM1 | Table-method dimming on the built-in and the MSI (HDR off): every named dim stop, Keep this level, Back to Standard | dim half shape |
| H-K1 | `kill -9` while boosted → neutral at once; a separate process that only restores → no change; dirty-then-restore → neutral; lid close + kill; logout | D7 confirmation |
| H-K2 | Another table-writing process quits while Overbright is boosted or dimmed: is every display reset, and does Overbright reapply within ≈ 0.3 s with a ramp | §4.8 app-termination check |
| H-X1 | Hang watchdog writes from a background queue work; nothing re-scales before the re-gate | D7 hang path |
| H-A1 | Auto-brightness toggle while boosted on the M4 Max: bad state or not, and what clears it | advisory text |
| H-NS1 | Night Shift and True Tone on while boosted and while dimmed: does either change the table (drift, adoption) or interact visibly | conflict copy (Night Shift is recommended), drift classification |
| H-C1–C3 | Compatibility overlay multiplies other apps, menu bar, full screen; pointer; Mission Control; domain; power vs table + trigger | Compatibility mode scope |
| H-N1, H-N2 | Does IORegistry `BrightnessMilliNits` track SDR white with EDR active; does the MSI's frame average follow the HDR-mode SDR slider | nits readout, Safe cap |
| H-P1 | Which power assertion QuickTime, TV, IINA, VLC, Infuse, Safari, Chrome hold while playing (in a window and full screen), released on pause | `whilePlaying` rules, the full-screen video rule (beta label) |
| H-F1 | Camera-in-use without a TCC prompt from the signed app | Fill Light auto rule |
| H-F2–F5 | (WP7) Does macOS grant Fill Light's 2.07 request or the potential; no tone-mapping while its headroom ramps; the auto-hidden menu bar band; no presents while idle | Fill Light's request and drawing |
| H-E2, H-E3 | (WP2) Sidecar and AirPlay facts (vendor, capacity, virtual); do an external panel's `DisplayAttributes` exist before the 0.5 s pass after a hot-plug | virtual-display rule, reconfiguration passes |
| H-X2 | (WP2) CoreGraphics transfer calls from the watchdog's and the signal queue's threads: no fault, no crash | D7 background writes |
| H-FS1 | Full-screen heuristic on the notched built-in, Split View, auto-hidden menu bar | full-screen rules |
| H-FS2 | (WP6, C-SIGNALS-5) "Displays have separate Spaces" off: only the main display has a menu bar, so elsewhere only a frontmost window is full screen (exact, or below the notch band on a notched built-in that is not the main display); does a full-screen video pause exactly its display; with the MSI as the main display, is a native full-screen app on the built-in detected, and where does a zoomed window there put its top edge (at the display's top edge or below the notch band it counts as full screen while frontmost) | full-screen rules |
| (WP11) | the paused-app suggestions' bundle IDs (Prime Video, Infuse, GeForce NOW, Moonlight) | the suggestion list |
| H-AI-1–3 | Intents and Focus filter appear and run; localized in German and Russian; Run Shortcut control | D18 |
| H-CC-1–2 | Ad-hoc control listed, rendered, survives a rebuild, follows the system language (English, then French); stale state after `kill -9` | D18 promotion |
| H-M1 | Does the visibility check notice that macOS hides our status item ("Allow in the Menu Bar" off) or that the notch covers it | the hidden-icon window |
| H-L2 | Does a login launch by `SMAppService.mainApp` carry `keyAELaunchedAsLogInItem`; does the fallback separate login from Finder launches | launch UI |
| H-S1 | Energy: T1 vs T2 vs Compatibility mode; tag policy A vs B; 30-minute battery drain at G 1.5 | energy budget |

### 11.3 Risks

1. **A macOS update changes the table or revert behaviour.** Mitigation: launch check, `--monitor`, the self-test, re-running H-R1, H-K1 and H-T* after each major release; the strategy cache is keyed by OS build.
2. **The read-back model is unknown** (values above 1.0 may or may not clamp). Mitigation: every neutrality and residue test compares with the profile base (D26), so both models work; H-R1 records which one is true.
3. **The tagged-layer trigger is suppressed for inactive agents.** Mitigation: the ladder falls through to Metal and HLG strategies; suppression keeps the current rung rather than stopping.
4. **The transfer domain is unknown.** Mitigation: the encoded default never clips for any truth exponent up to 2.4; calibration needs positive proof for linear.
5. **Safe may be nearly inert if macOS grants well below the panel peak.** Mitigation: H-G1 decides between the worst-case bound and the static top with honest copy (§5.4).
6. **More Macs ignore table writes** (the M5 family on 26.3+ already does). Mitigation: Compatibility mode, the "Did it get brighter?" question, an updatable model list.
7. **No Pro Display XDR or Studio Display XDR to test.** Mitigation: verdicts from formulas; ask testers for diagnostics and self-test logs.
8. **Ad-hoc Control Center control unusable.** Mitigation: Run Shortcut fallback; Developer ID builds.
9. **CI and Intel slices never exercised** (as in Cranny). Mitigation: confirm runner labels on the first push; a manual Intel smoke or an honest README note.
10. **35 machine-assisted translations.** Mitigation: Russian reviewed by the owner first; fit tests; the README states how translations were made.
11. **Name clearance.** "Overbright" passed a quick App Store, GitHub and web screen, not a legal search; run a USPTO/EUIPO class 9/42 search before the first public release.
12. **Brightness-key integration** is the most-requested interaction in this category and needs Accessibility. It is the first v1.x item, designed as an opt-in event tap with Cranny's revocation handling; the v1 taper already keeps the keys' normal range.

---

## Appendix A — Verification log (2026-10-16, macOS 27.0.1, Xcode 27.1, Swift 6.4, MacOSX27.0 SDK)

| What | How | Result |
|---|---|---|
| §3 Core contracts (v0.2) | `swiftc -typecheck -swift-version 6 -warnings-as-errors` + the four upcoming features, nonisolated **and** `-default-isolation MainActor`, targets `arm64-apple-macos14.0`, `x86_64-apple-macos14.0`, `arm64-apple-macos26.0`; the settings store is the real Cranny port | 0 errors, 0 warnings in all six combinations |
| §3.10 Policy API | the same flags, against the emitted Core module | 0 errors, 0 warnings |
| SDK name collisions | a probe importing AppIntents, AppKit, AVFoundation, Carbon, ColorSync, CoreGraphics, CoreMedia, CoreMediaIO, CoreVideo, Foundation, IOKit, Metal, QuartzCore, ServiceManagement, SwiftUI, UniformTypeIdentifiers, WidgetKit, Observation, os, OverbrightCore and OverbrightPolicy, aliasing all 131 top-level public names | no ambiguity |
| §2.2 Package.swift | a scratch package with the §3 files in Core and Policy and placeholders (with catalogs and tests) in the other 15 targets | `swift package describe` → 33 targets, products `OverbrightAppShell` and `OverbrightControlsKit` both static; `swift build -Xswiftc -warnings-as-errors` and `swift test` pass |
| MainActor-default entry points (§8.1) | `swiftc -swift-version 6 -default-isolation MainActor`, macOS 14 target, run: a `DispatchSourceTimer` handler on a utility queue, a main-actor `@objc` observer posted from a background thread, a `{ @Sendable in }` handler, an observer in a `nonisolated` class | the first two trap (SIGTRAP, exit 133); the last two run |
| `allowedExecutionTargets` | the macOS 27 SDK's AppIntents swiftinterface | declared `@available(anyAppleOS 27.0, *)`; absent from Xcode 26's SDK → minimum toolchain Xcode 27 |
| Default shortcuts | `defaults export com.apple.symbolichotkeys` on the owner's Mac | the only ⌃⌥⌘ system entries are 8, comma and period; ⌃⌥⌘B, =, -, 0, 9 are free |
| §5.2 safety property | a script over H in (1, 16] and truth exponents 1–2.4 plus the sRGB curve | worst case `F^k ÷ H = 0.981`; the v0.1 `encodeSRGB` default reached 1.019 at H 3.2 and 1.059 at H 16 |
| §5.3, §5.6 numbers | a script implementing §5.2–§5.4 | the tables as printed |
| §2.3 / colour contrast | WCAG 2.x formula over the DESIGN.md §2.1 token values | the audit table in DESIGN.md |

Facts verified by the feasibility studies and restated here (public-safe): App Intents in a static package module are extracted into the app's metadata without `AppIntentsPackage`; an `AppShortcutsProvider` in a package is dropped; an ad-hoc sandboxed widget extension builds, signs and registers with PlugInKit; Xcode refuses a `group.` App Group without a profile; `runningApplications` lists bundle-less `NSApplication` processes; the window list gives bounds, layer, PID and alpha without Screen Recording; the idle-time call needs no permission; power assertions are readable without permission; every trigger strategy and the overlay compile at the macOS 14 floor for both architectures; a clear-only Metal pass needs no library; our HLG still verifies in 24 of 24 configurations; `CGColor` headroom tags ≤ 1.0001 read back as 1.0; `NSColor(colorSpace:components:count:)` wraps values above 1.0; HLG and PQ colour spaces imply a headroom of 4.93; `CALayer` and `CAMetalLayer` default to `preferredDynamicRange = .standard`; macOS 27.0.1's display server reverts a process's table writes when its connection dies, resets every online display when any table-writing process dies, and ignores a ColorSync restore from a process that wrote no table (static inspection of system frameworks); `maximumPotential…` reads 16 on the built-in in the 1600-nit preset and 4.6549 on the MSI with HDR on.

---

## Appendix B — Review findings (v0.2)

Every finding of the v0.1 design review and where it is addressed. "Refined" means the fix differs from the proposal in a detail; the reason is in the §0 review notes.

| # | Area | Fix |
|---|---|---|
| 1 | Two read-back models | D26 `TableClassifier` against the profile base for rescue, post-restore, `--monitor`, baselines; no adoption of uniform multiples; S1 no Continue on the table (Compatibility mode only); HARDWARE-TEST §2.0 (H-R1) first |
| 2 | Pre-held headroom | D6 pre-held path, §4.3 first rows, `OwnEDRSurfaces`, `ScriptedHeadroom` at H 2.6, `PreHeldTests` |
| 3 | Hang epoch | §4.1 ledger + `NSLock` across writes, §4.6, invariants 1, 3, 7, §5.4, §7.4, `hangEpochBlocksQueuedWrites` |
| 4 | Calibration domain safety | D5, §5.2 (no `encodedPower`, linear confirmation, record validity), `CalibrationSession` API, DESIGN.md §9 |
| 5 | Re-base on events | §4.3 reconfiguration/profile rows, §4.8 event-driven re-base, `RebaseTests` |
| 6 | Foreign writers adopted as profiles | §4.8 adoption window and budget, ramped reapply, §5.8 |
| 7 | Auto-brightness jump fade | removed (§7.4); monotonic tracking excluded from the detector; 1 % dead band (§4.3, §5.8) |
| 8 | MainActor-default entry points trap | §8.1 rule 2 [VERIFIED], §7.1 entry-point column, CMIO on `.main`, nonisolated `HangWatchdog`, off-main tests, `edr-mechanism.md` §11.1 |
| 9 | Safe without an SDR estimate | §5.4 live bound `capNits·H/panelPeak`, `GainCeiling.safeBound` switch (refined, §0 notes), DESIGN.md §12.2 copy variants |
| 10 | Studio Display XDR Safe row | §5.6 "no Safe boost"; verdict quotes Peak (DESIGN.md §12.1) |
| 11 | Display removal and window re-homing | D9, §4.3 removal and screen-change rows, `onScreenChange`, §7.5, H-W5 |
| 12 | Two engines | D27, §7.4 launch order, `secondInstanceHandsOverAndExits` (refined: `--qa-simulate` exempt) |
| 13 | Quit and signals | D7, §7.4 ramped stop before terminating + `stopNow()`, signal queue, `ServiceLifecycle.stop() async` |
| 14 | Other writer dies | §4.8 50 ms check, ramped reapply, invariant 12, H-K2 |
| 15 | Drift sampling at small factors | §4.8 sample index, separation rule, evaluation order; tolerance 0.01 (§4.4) |
| 16 | HDR suppression during arming | §4.3 row: keep rung, stop escalating |
| 17 | Automatic trip clearing | §4.3 failed rows, `TripCause` doc, §5.8 |
| 18 | Stale battery percent | §7.1 synchronous reads, `refreshPowerNow()`, §4.9 |
| 19 | Synchronous shield delivery | §4.1, invariant 6, `shieldIsNeutralWhenEmitReturns` |
| 20 | Cache poisoned after wake | §4.7 cached-rung-only backoff, two-arm replacement, 60 s quarantine |
| 21 | `encodeSRGB` unsafe for k = 2.4 | D5, §5.2 `G^(1/2.4)` above white, property over k ≤ 2.4 |
| 22 | Very dark dim | D11, §4.9 Keep this level, DESIGN.md §6 |
| 23 | Mirror sets | `DisplayVerdict.mirrored`, `HeadroomReading.display`, invariant 1 |
| 24 | Missing hardware steps | HARDWARE-TEST §2 (2.0 read-back first, table dimming, Night Shift/True Tone, another writer exits, lid/unplug), the booster step moved to §8 after 2.0 with a warning, results rows |
| 25 | Restore verification | D7, §7.4 step 5, `RescueOutcome.repairedInvalidRestore` |
| 26 | Not on console | D27, §7.4 step 1, `SuspendCause.notOnConsole` |
| 27 | Stair-step user raises | §4.3 user-raise row, poll burst, §5.7 |
| 28 | Contract suite writes real tables | §9.1 Displays row, `noWritesInHardwareTests`, WP2 tests |
| 29 | Cold launch shows nothing; no Quit | D13, §7.6 launch UI, DESIGN.md §4.4, §7.3, §8 |
| 30 | Hidden icon not detected | §7.6 visibility check, `MenuBarIconVisibility`, DESIGN.md §4.4, §12.4 (refined buttons) |
| 31 | Verdict overpromises | D8, DESIGN.md §12.1 |
| 32 | Uncalibrated numbers | §5.5, `ReadoutValues.isEstimate`, DESIGN.md §5.6, §8 |
| 33 | Safe copy false | DESIGN.md §7.4, §12.2 class variants |
| 34 | Full-screen rule too broad | D10, §6.1 rows 14–15, `fullScreenVideoDisplays`, DESIGN.md §7.5, §8 |
| 35 | Calibration checklist unsafe | §4.9 Standard first, DESIGN.md §8, §9 |
| 36 | Dimming gated by the boost switch | D8, D11, `boostEnabled`, `LimitReason.boostNotEnabled`, DESIGN.md §5.4, §5.11 |
| 37 | Steps in travel | D11, §5.3 dim curve, steps in stops, `StepMath` (refined: named-stop jumps excluded from the ½-stop property) |
| 38 | Units across surfaces | DESIGN.md §1 principle 4, §5.5, §6, §12.8; intents §7.7; `lastDimLight` |
| 39 | Automations without explanation | D19, `LevelChange`, §4.9, DESIGN.md §6, §12.9 |
| 40 | Back to Standard semantics | §4.9, `BoostControl.returnToStandard`, DESIGN.md §4.3, §7.6 |
| 41 | Dim parity | §4.9 Dim All, default ⌃⌥⌘9 (D17), DESIGN.md §4.3, §7.6 |
| 42 | Keyboard reach | DESIGN.md §5.12 |
| 43 | Contrast and headroom bar | DESIGN.md §2.1, §5.5 marker (refined, §0 notes), D14 |
| 44 | Settings destination labels | DESIGN.md §16 rule, `noSettingsDestinationLabels` |
| 45 | Hard-coded key caps | `ShortcutCenter.displayString`, §8.8, DESIGN.md §16, `noLiteralKeyCapsInCatalogs` |
| 46 | Boost multiplies low brightness | D11 taper, §5.4, `boostOnlyNearFullBrightness`, DESIGN.md §8, §12.6, H-B1 |
| 47 | Translocated copies | D13, §7.4 launch order, DESIGN.md §12.4 |
| 48 | Missing strings | DESIGN.md §12.8, §12.9, §5.10, §5.4 |
| 49 | Duplicate global chips | `LimitReason.isGlobal`, §6.2–§6.3, banners `focusOff`, `outsideSchedule` |
| 50 | Footer chip labels | DESIGN.md §5.9, §16 fit list |
| 51 | Faded text, gesture rule | §4.9 (moving a slider ends a pause), DESIGN.md §5.5, §5.11 |
| 52 | No preparing state | `StatusSymbolState.preparing`, `LevelChange.preparing`, DESIGN.md §4.1, §6 |
| 53 | Chip in the title row | DESIGN.md §5.4, §5.7; §8.8 width rule |
| 54 | Presets below the gain threshold | §5.3 `PresetVisibility` (refined walk-down rule) |
| 55 | Verdict wording | DESIGN.md §12.1 |
| 56 | Fill Light in the panel | D12, DESIGN.md §5.3 |
| 57 | Dimmer / Dim homonyms | `ShortcutID.lessBright`, D17, DESIGN.md §7.6 |
| 58 | Repeated "No extra range" | DESIGN.md §12.2, `DisplayStatus.failedTries` |
| 59 | Menu status line, update item | DESIGN.md §4.3 |
| 60 | Welcome length and gaps | D16, DESIGN.md §8 |
| 61 | Undo only for 10 s | D15, `AppControl.undoResetAllSettings`, DESIGN.md §7.8, §15 |
| 62 | Timer, battery, per-display off | D10, §3.8 ranges, DESIGN.md §4.3, §5.4, §7.5 |
| 63 | Moon glyph | DESIGN.md §4.1, §5.4, §6, §13.1 |
| 64 | OLED notice, Self-Test, readout wording | DESIGN.md §12.4, §10, §5.6 |
| 65 | Core cannot carry reducer inputs | `PolicySettings.linkedLevel`, `DisplayPolicyInput.sdrWhite`, `CalibrationRecord.measuredSDRWhiteNits`, `MachineIdentity`, `CompatibilityModels`, `classify(…preferences:…machine:)`; recompiled |
| 66 | Additive-only rule impossible | §10.0 contract lane |
| 67 | Controls link the wrong product | `OverbrightChannel` target, static `OverbrightControlsKit`, 33 targets (refined count) |
| 68 | Missing cross-module ports | `SystemSignals.setFocusDirective`, `BoostStatus.lastChange/isReady`, `IntentRouter()` + `connect`, pause owned by BoostEngine |
| 69 | Seams for parallel work | §10.0 seeded stubs (Writer, Safety, SelfTest, Calibration, DisplayCardView, DisplayMonitor, URLRoute) |
| 70 | WP0-owned copy and fakes | option (b): copy in Design (WP9), `ScriptedStatuses` in PanelUI (WP10), WP4 test fakes |
| 71 | Shared String Catalogs | §8.8 per co-tenant tables, `Resources/*.xcstrings`, merge driver in §10.0 |
| 72 | Stand-in settings store | §3.8 real port typechecked, `SettingKey.id`/`Hashable`, `binding` in Design |
| 73 | `allowedExecutionTargets` on Xcode 26 | minimum toolchain Xcode 27; macos-26 CI job package-only |
| 74 | Reducer stub blocks WP4 | injected reducer, TestSupport reference reducer, fuzz ≥ 30 % boosted |
| 75 | WP0 too large | WP0a / WP0b split |
| 76 | Unmeetable acceptance | WP0a uses `--diagnostics`; smoke metadata and TSan step pre-written; Russian fit tests in WP15; `noNetworkingOutsideUpdates`; snapshot OS wording |
| 77 | `pgrep` matches the monitor | HARDWARE-TEST `obpid` function |
| 78 | Invariant 3 vs watchdog | `TableWriter.writeBaselines(fromLedger:)`, invariant 3, lint `onlyTableWriterAndRescueWrite` |
| 79 | Pending translations | §8.7 `make l10n-pending`, §9.3 step 1 |
| 80 | Non-persistent cwd and env | §2.4 and §9.3 absolute, self-contained commands |
| 81 | Ambiguous paths | §1.3, §10.0 full paths; WP8 owns intents files |
| 82 | Double or missing owners | `ReadoutValues` (WP1) vs builders (WP9); Dock menu WP10, wiring WP13; `AppControl.showHelp`, Help in WP10 |
| 83 | Untestable `perform()` | §7.7 testing, §9.1 Intents row |
| 84 | Denylist allowlist gaps | D3 allowlist, synthetic IDs |
| 85 | THIRD_PARTY_NOTICES contents | D2 rows |
| 86 | Disk budget | §10.0 disk budget, `make distclean`, §9.3 step 7 |

---

## Changelog

### 2026-10-17 — Energy pass: one 2 s grid for the steady timers (D29)

`TimeSource.nextGridPoint(every:)`, an extension method that changes no conformer, names the next multiple of a period since the time source's origin, strictly after now and at most one period away (§3.6). The hang watchdog sends every ping after the first at the next 2 s grid point of `writer.time`, and while a ping waits for its answer it wakes at the earlier of its timeout deadline and the next grid point, so a stall is still caught 3–5 s after it starts (§4.1, §4.4, §7.4). Signals' full-screen and playback watch and the OLED idle input poll wait for the same grid points; the watch stays Signals' own timer (D28) and the idle deadline before the poll stays exact (§7.1, §7.3). The drift loop's part is the engine lane's E4, merged into this branch so that no part ships without the others. D29 records the decision, the measurements, the two rejected variants and why the parts ship together; DESIGN.md §17's boosted row names the grid.

### 2026-10-17 — Energy pass: the engine (E1–E8)

Status publication, reductions, the drift tick, level persistence and settings reads (`energy/engine`, one commit per item). E1: a published reading changes only when a value moves by ≥ 0.0005, and a launch neither publishes nor reduces (§4.1). E5: the drift tick computes the profile base only when its verdict consults it (§4.8). E2: a screen-parameters notification's re-reduction is coalesced to ≤ 10 Hz while its headroom check stays synchronous (§4.4 `screenParametersReduceInterval`, §7.1). E4: the drift checks sleep to the shared 2 s grid (D29). E3: minor-only status changes publish at most every 250 ms, DESIGN.md §17's marker rule (§4.1, §4.4 `minorPublishInterval`). E8: Signals' boost-only sources follow boosting, not dimming (D30, §7.1). E7: settings boxes make their key path once (§3.8; the planned cast change was measured and dropped). E6: level persistence is coalesced during drags, and a level step costs one reduction (§3.8, §4.9, §4.4 `levelPersistDelay`). Measured on an optimized Debug build under `--qa-simulate builtin-xdr-lid-open` with the panel opened at launch and closed (U1 not applied), against `9ef2587`: a screen-parameters notification 1 983 → 30 µs of CPU off and 2 198 → 49 µs boosted; a burst of 120 notifications 231 → 2.9 ms off and 239 → 9.6 ms boosted; with a measurement-only T2 patch two boosted displays 0.96–1.01 → 0.51–0.54 interrupt wake-ups/s; real-port drift tick 71 → 36 µs; panel drag (screen mostly locked) settings getter samples 22–38 → 5–7. Tests: `StatusPublicationTests`, `DriftProfileBaseTests`, `ScreenParametersReduceTests`, `DriftGridTests`, `MinorPublishTests`, `BoostSourcesTests`, `LevelPersistenceTests`, `SettingsStoreTests`.

### 2026-10-17 — WP14 leftovers: engine edge cases and deterministic tests

A scaled write that throws no longer leaves a stale safety-ledger entry that kept the hang watchdog and the boost marker on while off: every landing writes the baseline of a marked display, and a write refused before WindowServer leaves the ledger as it was (§4.5 invariant 9; C-BOOST-1 regression, `StaleLedgerTests`). The low-level confirmation lives in `BoostEngine+LowLevel.swift`; `HangWatchdog`'s comments say the ledger's occupancy observer switches it, inside the ledger lock. Tests that depended on how a loaded machine schedules threads no longer do (§9.1): the signal stop's wait is injected, the hang watchdog's tick and answer are pure functions checked on explicit uptimes (the 3–5 s window, once per stall) and its real-timer tests wait for queues through blocks queued on them, the fuzz replays the seed that once failed under load, and short real-time polls in the shell and update tests became `eventually` or explicit synchronization. `CopyLanguage.named` opens a language's `.lproj` folder by path (an empty code gave German, a path another folder), and the fit tests require each language's tables instead of measuring English in their place (C-PANEL-33). Panel snapshots are taken at the panel's settled size, and the key-state check compares where the header and footer draw (C-PANEL-31).

### 2026-10-17 — WP14 docs as built (C-RELEASE-15, C-RELEASE-18) and the strict soak

Every WP14 area is on `main`, so both documents now say what was built. ARCHITECTURE: §4.8's re-base adopts a new profile base only when the profile moved since the baseline's capture (C-BOOST-17), and records C-BOOST-16 and -18; §11.1 #35 gives the abort rule as built (C-BOOST-19); §3.10 lists `GainCeiling.sdrMaxNits` and `frameAverageSDRWhite`; §10.0's seams name `StatusChip`'s `isPresented` initializer, `HelpView(anchor:shortcuts:)` and the `ScriptedStatuses` additions, and that Welcome draws its own rows; §8.5 says `--qa-state` surfaces are timed from a status that is ready at once; §8.7 names the width classifier's self-test; §7.7's English Get State example reads "25%"; as-built bullets for C-SHELL (§10.2, §10.10, §10.15), C-PANEL (§10.12), C-SETTINGS with its three hand-offs (§10.13) and C-ONBOARD (§10.14); §10.14 and DESIGN.md §8 give Welcome step 2 its compact stage band (C-RELEASE-15); §10.16 records the review as built, what it handed on and the test count. DESIGN: §7.4, §7.5 and §12.4 as built (every switch to Peak asks; an Add App menu), §9's colorimeter window and abort rule, §12.1's row not shown everywhere yet (`lastGrant` not passed by any surface). The soak's final off phase fails on any idle wake-up of Overbright's own, and §10.15 states the leak threshold and its baseline, the footprint after cycle 3 (`scripts/soak_judge.py`, its self-test, `scripts/soak.sh`). `render-icon.swift`'s bloom comment gives the real stops. README, CONTRIBUTING and TRANSLATING follow.

### 2026-10-17 — WP14 leftovers: Signals energy and platform remainders

Signals still posts every process's termination, background-only ones included, because any table writer's death resets every display; the engine bounds the cost (only a boosted or dimmed display runs the 50 ms drift check, and a termination re-reduces only when it ends a continuation), and only a regular app's termination re-checks full screen (§4.8, §7.1, DESIGN.md §17; C-SIGNALS-1). With "Displays have separate Spaces" off, a notched built-in that is not the main display counts its frontmost app's window below the notch band as full screen, as an exact cover counts there; the zoomed-window and Split View limits are stated and H-FS2 gains step 7.12 (§7.3, §11.2, HARDWARE-TEST; C-SIGNALS-5). The full-screen watch's own timer is decision D28, with its wake-up cost and the H-S1 case that decides a revisit (C-SIGNALS-6). Contract lane: `DisplayVerdict.panelFactsUnknown` ("Range unknown") replaces the unbacked `noGainAtFullBrightness(peakGain: 1)` of a boosting class without a known panel peak or SDR maximum: dim only, no gain claimed (D8, §3.2, §5.3, DESIGN.md §12.1; C-PLATFORM-3, translated in every shipped language). `TriggerModuleLintTests` scans each file as one text and treats a name as a summary only when every binding of it is one (§10.5; C-PLATFORM-10).

### 2026-10-17 — WP14 review fixes, the other areas (C-SIGNALS, C-DESIGN, C-PLATFORM, C-SHELL, C-ONBOARD, C-SETTINGS, C-PANEL)

Signals: launches and terminations of agent apps come from the running list's KVO too (macOS 27.0.1 posts no notification for them), once per process; boost-only sources stop behind a shield; with "Displays have separate Spaces" off only the main display has a menu bar; the 2 s full-screen and playback watch stays Signals' own timer by decision (§7.1, §7.3, DESIGN.md §17). Design: banners never cut their sentence, only an app name in the middle; every readout state is `labelColor`; the allowed-now marker is 2 × 24 pt over the thumb in a halo, the thumb travels the track inset by its radius and gets a ring under Increase Contrast; scrolling follows the hand; the Welcome divider takes ← / → (§10.11, DESIGN.md §2, §5, §8, §15). Platform: Apple XDR externals get their SDR maximum and peak from the product (`AppleXDRProducts`) and their frame average is never an SDR white; a panel peak falls back to potential × 100 and never to `BrightnessMilliNits`; a virtual display needs the IORegistry walk's evidence; a schedule from a minute to the same minute is the whole day; the Fill Light Metal path's present is a closure a test can see; Triggers' log lint checks `.public` interpolations against an allowlist (§3.4, §5.1, §5.3, §5.5, §10.4, §10.5, §10.9). Shell: a skipped launch check runs before the engine when the session came back early (§7.4); a QA suite silences the control channel; QA hooks show whole scripted states and wait for the launch work; Move to Applications brings an older copy back from the Trash and Esc is Not Now; Intents join sentences in the language's way, bound a pause's length and watch readiness only while waiting; the Display type has its plural (§7.7, §8.5, §10.2, §10.10, §10.15). Welcome: one split on every step, centred progress dots, step 5's summary, step 1 only with its own display's light, Skip registering the default login item (§10.14, DESIGN.md §8). Settings: search follows row state, deep links versus search hits, the colorimeter range inline, announced flips, VoiceOver names and no beep, one slider track, the calibration window deciding simulated from the services (§7.6, §10.13, DESIGN.md §7, §9). Panel: the displayed level, one card style and the 304-pt footer, keyboard menus, Compatibility mode for a booster's drift, the HUD's content and announcements, Help following the shortcut center (§4.9, §7.2, §8.8, §10.12, DESIGN.md §4–§6, §12, §15, §16).

### 2026-10-17 — WP14 review fixes, C-BOOST (engine, writer, calibration)

The hang watchdog and the boost marker follow the safety ledger, so a ramp from neutral, a dim and the reapply after a reset are guarded from their first scaled write (§4.6, §7.4; C-BOOST-1). Boost-only sources stop while every display is suspended at its baseline (§7.1; C-BOOST-6). A boost requested back while a rate-limited disarm has written nothing yet settles with its drift watch (C-BOOST-2). Calibration: the writer's calibration path is bounded by the session's `maxFactor`, the reading's calibration ceiling and the hang epoch instead of `0.97 × H`, which the sweep must pass (§5.2; C-BOOST-5, C-BOOST-8); the engine's stops, the self-test, Reset Display Colors and a fired hang watchdog end a running calibration first (C-BOOST-8); Compatibility mode calibrates the overlay itself, without a table write or a trigger (C-BOOST-3); a driven trigger reports occlusion and screen moves, ending the calibration or that display's self-test (§8.4; C-BOOST-9); an aborted sweep records nothing unless it had ended with a mark or the confirmation was answered (C-BOOST-19; §11.1 #35's status and DESIGN.md §9's wording are C-RELEASE-18's); the step wedge is `CalibrationController.pattern` (C-BOOST-21) and the controller's steps live in `CalibrationController+Steps.swift` (C-BOOST-24). Policy inputs: a colorimeter SDR white holds only within ±5 % of the headroom it was measured with, checked at every write (§5.5; C-BOOST-4); the taper's reference reaches the reducer in `EngineFeedback.fullBrightnessHeadroom` (§3.4, §5.4; C-BOOST-7); `DisplayStatus.lastGrant` carries the largest gain macOS's grants allowed, from the strategy cache's new `highestGrantedHeadroom` (§3.5, §8.2; C-BOOST-25; the UI call sites are C-SETTINGS', C-ONBOARD's and C-PANEL's). A boost request while on reads the power source first when no boost-only source keeps it fresh (C-BOOST-12). Deadlines sleep in chunks of at most 5 min against the wall clock and the schedule boundary is calendar arithmetic, right on daylight-saving days; sleeps have at most 1 s of tolerance (§4.9, §3.6, §8.1; C-BOOST-10, C-BOOST-11). The strategy cache keeps only the running build's records (§8.2; C-BOOST-15). Re-basing: a base that cannot be written off the console stays pending (C-BOOST-16); a re-base replaces the baseline only when the profile base moved since it was captured or adopted, so a foreign baseline survives a reconfiguration (C-BOOST-17; clarifying §4.8's wording is C-RELEASE-18's); a table that is not ours forgets our last write and the display's safety-ledger entry, so a failed landing that WindowServer's new base replaced leaves neither the hang watchdog nor the boost marker on (C-BOOST-18; `windowServersNewBaseOverAFailedLandingEmptiesTheLedger`). Test margins: `SignalStopTests` and `EngineFuzzTests` no longer depend on scheduling (C-BOOST-14).

### 2026-10-17 — WP14 review fixes (C-RELEASE: build, CI, project, docs)

Build and release: both targets' Debug configurations link once (`ENABLE_DEBUG_DYLIB = NO`, so the App Intents metadata is always extracted) and both targets treat warnings as errors (§8.6, `ProjectLintTests`); `build.sh` fails without the intents metadata, rebuilds the resource bundles when a String Catalog changed, and with `smoke.sh` runs `check-lproj.py` (every translated table compiled into its bundle, no stale `.lproj`); smoke reads `designString.ru`; the update check's repository is the build setting `OVERBRIGHT_GITHUB_REPOSITORY`, which `release.yml` sets (§8.6, §8.9); `dist.sh` uses `diskutil image create from` (§8.7). Gates: the clean-room scan reads every repository file (D3); the QA matrix opens Welcome and requires `gammaWrites` 0 (§10.14); the soak judge is `soak_judge.py` with recurrence, shared-sample and per-cycle growth rules (§10.15); the width classifier constrains only a chip's own label (§8.8); `make lint` runs the scripts' self-tests; CI's Thread Sanitizer step covers the off-main suites and the gamma write gate (§8.9). Icon: refined per DESIGN.md §14 (`AppIconLintTests`). Docs: Status rows, §1.3, §2.2, §8.8 and §8.9 as built, DESIGN.md synced (Status, §2.0, §2.3, §2.4, §8, §12.5, §14, Appendix B), WP12's Welcome deviations confirmed (§10.14: step 2's compact stage band of C-ONBOARD-1, the rows over `DisplayCardModel`, Done applying step 2's switches, two advisories in step 2), the hardware checklist's handed-off questions (§11.2, HARDWARE-TEST), README's status, CONTRIBUTING and TRANSLATING corrected.

### 2026-10-16 — WP13 as built (integration)

The composition root wires every real implementation and the ordered lifecycle (§10.15 "As built"); the launch order is `LaunchSequence`, the quit `QuitFlow` (the WP0a design: cancel once, ramped stop within 1 s, terminate; quit Apple Events at once; §7.4), the launch UI detects launches by a URL or an intent (§7.6). Listings synced with the code: `SystemEvent.scheduleBoundary` and Displays' relayed events (§3.3), `DisplayDecision.level` (§3.4), `CalibrationSession.state` (§3.6), `LaunchRescue`'s contract-lane initializer and the shell's controllers (§10.0), `OverbrightLinkButtonStyle` (§10.0, DESIGN.md Appendix A), the fakes' `recordLimit` (§3.9), the diagnostics keys (§8.4), the QA switches `--qa-script` / `--qa-status` and `--qa-hud` (§8.5), `SIMULATE=1 make smoke` (§8.7, §9.3), the shell test names (§9.1). Rulings recorded: a display whose boost switch is off is neither paused nor a banner's cause (§6.3, §6.4); two schedule-boundary owners on purpose (§7.1); a `foreign` table is never rescued (§7.4 step 3); an aborted calibration records nothing (§11.1 #35, open for WP14); trigger methods reset with the Advanced pane; small gain at a Max of at most ×1.3 (§5.3, DESIGN.md §5.5); "Acknowledgments…" (DESIGN.md §7.9); the event-driven full-screen re-check is allowed while off (§7.1, DESIGN.md §17). WP2's 2 s confirming pass, WP6's camera listener and WP7's Fill Light hold and tag are described as built (§7.1, §7.6, §10.9).

### 2026-10-16 — WP0a review fixes, round 2

A bare `--qa-simulate` (no fixture name, or another switch right after it) wired the real ports in a Debug build: the switch now decides the wiring and the name only the fixture (`LaunchArguments.qaSimulates`, `CompositionRoot.simulatedFixture(for:)`, §8.5), in every build configuration. The GammaPort write scan (§9.1) also finds calls with implicit `self`, method references (`write(_:to:)`, an uncalled `.write`), `to :`, a trailing comma and every mention of the global restore, skips comments and string literals, and counts only two-argument `write` calls, so `TableWriter.write(_:to:reading:epoch:)` is not taken for `GammaPort.write`. `noWritesInHardwareTests` also forbids `SystemHeadroomPort(`, `SystemDisplayDirectory(` and `livePorts(` outside hardware-gated suites, and no test builds the real ports. `noSecondDisplayStateWriter` scans `scripts/` (Swift, Python, shell). §7.4 and §10.15 give the launch order as `AppDelegate` runs it: the hub before the CLI modes, the launch check inside `LaunchGate` after the status item.

### 2026-10-16 — WP0a review fixes

A cold launch opened the panel below the screen: before MenuBarAgent places the status item, its in-process button window reports frames off every screen, and any frame with a height counted as placed. A frame now counts only when it overlaps a screen (`PanelPlacement`, a pure function, `PanelPlacementTests`); an unplaced button puts the panel at the top-right of the main screen, and the open panel follows the button's window (§7.6). The lint write scan reads whole statements through nested parentheses (§9.1, `gammaWriteScanFindsEveryShape`). The D27 exemption follows the ports actually wired (`ports.fixture != nil`), and a Release build refuses every Debug-only switch with exit 64 instead of ignoring it (D27, §7.4, §8.5, checked by `make smoke`). §10.0 now gives the seams as built: `DisplayMonitor.run` is `async`, `ApplicationsMover` is an instance with `init(settings:)`, `SingleInstance.handOverIfRunning(arguments:)`. `ShellPorts` and `Shell` have files of their own (§9.2). §10.2 says that WP0a already ported `LaunchGate`, `ShellDefaults` and `QAHooks+Defaults`, so WP0b refines them.

### 2026-10-16 — WP0a as built

The repo wins where a listing and a file differ; corrected here: the quit no longer uses `.terminateLater` (§7.4, D7; verified on macOS 27.0.1 that the wait serves no main-actor work); `BoostEngine` has a designated initializer over explicit dependencies next to the `services:` one of §10.0; the seams' open parameter types are fixed in the files (`TableWriter.Request`/`Outcome`, `SafetyLedger.State`, `DisplayControllerDriving.display`, `IntentRouter`'s one method per intent, `BoostChannel.State`, `URLRoute`); `--diagnostics` adds `maxDeviationFromBase` and `simulatedFixture`, and reports placeholder signals and conflicts as null.

### 2026-10-16 — v0.2 proposed

Revised after a design review of 86 findings (Appendix B). Engine safety: neutrality judged against the profile base (D26), pre-held headroom, hang epoch, event-driven re-base, adoption budget, synchronous shield delivery, immediate display removal, single engine and console-only writes (D27), restore verification, `.terminateLater` quit and a signal queue, the `G^(1/2.4)` boost curve, calibration that needs proof for linear, the live Safe bound, steps in stops, the taper, Keep this level. Removed: the auto-brightness jump fade, `TransferDomain.encodedPower`, the shell pause controller. Buildability: Core contracts extended and recompiled, the settings store as the real port, `OverbrightChannel`, the contract lane, seeded seams, WP0a/WP0b, per-co-tenant catalogs, Xcode 27 minimum toolchain, absolute commands, disk budget. UX: launch UI, icon visibility, canonical units, automation HUD, Dim All, class-specific Safe copy and verdicts (DESIGN.md v0.2).

### 2026-10-16 — v0.1 proposed

First version, written from the research reports and the four feasibility studies before any code. Decisions changed against the orchestrator's list: D4 (ladder details), D12 (Fill Light instead of Ring Light), D15 (Safe / Peak), D18 (intents in the app target, control deferred). New: D23–D25.
