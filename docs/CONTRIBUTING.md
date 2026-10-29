# Contributing to Overbright

Thank you for helping. Overbright is MIT-licensed, clean-room and dependency-free, and it changes what a real display
shows, so a few of its rules exist to protect your own screen while you work. This page is the short version;
[ARCHITECTURE.md](ARCHITECTURE.md) (§9 rules, §10 process) and [DESIGN.md](DESIGN.md) are normative.

## Ground rules

- **Clean room (ARCHITECTURE.md D3).** Overbright is an independent alternative to a commercial app. Never copy its
  code, assets, icon, UI text, feature names or translations, and never look at its translations when you translate.
  For the record, the app is Vivid by Lumen Digital, named only on lines that carry the lint's marker. <!-- denylist-ok -->
  `scripts/lib/lint-copy.py` and the Core test `noDenylistedNamesOutsideAllowlist` reject its name, its maker's and
  those of other display tools in every catalog (keys, values and translator comments, every language) and in every text
  file of the repository: what git tracks plus untracked files `.gitignore` does not exclude, so the root's README,
  notices, Makefile and `.gitattributes`, the workflows, the Xcode project and `Package.swift` as much as the sources,
  tests, scripts and docs (without git, a walk of the root minus build outputs and caches). The allowlist is short: the
  conflict catalogue's bundle-ID literals (`Sources/OverbrightPolicy/Conflicts/ConflictCatalog.swift`), the denylist
  definitions in the two scripts (lines marked `denylist-ok`), Markdown lines carrying `<!-- denylist-ok -->`, and
  `docs/research/`. Other apps' names reach the UI only at runtime, through `NSRunningApplication.localizedName`.
  Tests use synthetic bundle IDs (`com.example.booster`) or catalogue entry ids.
- **No GPL code**, and no code from projects without a stated license. Ideas from MIT projects are credited in
  `THIRD_PARTY_NOTICES.md` (and Settings ▸ About), code from them is not taken. Code ported from Cranny (the owner's
  MIT app) keeps a "Ported from Cranny's …" line in its file header.
- **Zero dependencies.** No Swift packages, vendored code, fonts, sounds, images, videos or animations made by others;
  no analytics or crash SDKs; no network except the opt-in update check in `OverbrightUpdates`.
- **No private API.** IORegistry reads are public IOKit calls; every input from them is optional with a fallback.
- **Never change your display's state while developing (D24).** Run the app only with simulated displays
  (`--qa-simulate`, which `make run` passes), and run tests only against the Core fakes. Exactly one file may call
  the CoreGraphics table setters or the global ColorSync restore (`Sources/OverbrightDisplays/Gamma/CoreGraphicsGamma.swift`,
  test `noSecondDisplayStateWriter`), and tests never construct a real display port except in suites gated by
  `OVERBRIGHT_HARDWARE=1`, which only read (`noWritesInHardwareTests`). A test process that writes a table resets
  every display when it exits.

## Ownership and the contract lane

Work is split into work packages (ARCHITECTURE.md §10), each in its own git worktree and branch (`wp/04-boost-engine`),
merged into `main` with `--no-ff`. **Ownership is by path:** a package edits only the folders §10 lists for it. The
shared files — `Packages/OverbrightKit/Package.swift`, `Sources/OverbrightCore/**` (except `Additions/`),
`Sources/OverbrightBoost/Shared/**`, `Sources/OverbrightTestSupport/**`, `App/**` (except the intents' files),
`Overbright.xcodeproj/**`, `scripts/**`, `.github/**`, `docs/ARCHITECTURE.md`, `docs/DESIGN.md`,
`docs/HARDWARE-TEST.md`, `THIRD_PARTY_NOTICES.md`, `LICENSE`, `VERSION` and the shell's composition files — belong
to the contract owner.

**Contract changes go through one serialized lane** (§10.0), because Swift cannot add an enum case, a protocol
requirement or a stored property through an extension, and a new case breaks every exhaustive `switch` elsewhere:

1. Open a short pull request titled `contract: …` (or ask the contract owner). It edits the Core file in place; a new
   enum case comes with a mechanical fallback in **every** exhaustive `switch` over it in the repo (the one sanctioned
   cross-folder edit); a new protocol requirement comes with a default implementation in the same file; a new stored
   property gets a default in every initializer.
2. After it merges, every worktree rebases the same day.
3. Until then, `Sources/OverbrightCore/Additions/<WPnn>-<Topic>.swift` may hold **new types and extension methods
   only**; the integration package folds them into their final files.
4. Adding a public top-level Core or Policy type? Run `make probe` and commit the regenerated name-collision probe.

`main` is always green: CI runs the copy rules, `check-modules`, the tests, the Thread Sanitizer suite,
`strings-check`, the name probe, a universal build (and the dormant Controls extension with `CONTROLS=1`), the smoke
test and packaging.

## Toolchain

- **Xcode 27** for the app (the App Intents use `allowedExecutionTargets`, which only Xcode 27's SDK has); the package
  alone builds and tests with Xcode 26.6 / Swift 6.3, given `--build-system swiftbuild` (Xcode 26's default native
  backend leaves the String Catalogs uncompiled, as CI's macos-26 job notes). **No Metal Toolchain** (there are no
  `.metal` files, and `make lint` keeps it that way).
- If `xcode-select -p` points at the Command Line Tools, start every manual command with
  `export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`; the scripts find Xcode themselves.
- **Run commands one at a time and check each exit status.** On some shells (the owner's zsh profile prints
  `GVM_ROOT not set`) `a && b` chains abort silently and report nothing. Prefer absolute paths and `make -C <repo>` /
  `git -C <repo>`: agent shells reset the working directory between commands.
- Scripts run on macOS's `/bin/bash` 3.2: no associative arrays, no `mapfile`.

## Everyday commands

```zsh
<repo>/scripts/lib/check-modules.sh OverbrightBoost   # one target alone, zero warnings (logs in build/logs/)
make -C <repo> test FILTER=OverbrightBoostTests    # swift test --filter, scratch path .build-test
make -C <repo> check                               # every target alone (JOBS=4; TEST=1 adds swift test)
make -C <repo> tsan FILTER='HangWatchdog|OffMain|GammaWriteGate|StatusSymbolTests'   # Thread Sanitizer (CI's filter)
make -C <repo> lint                                # copy rules, competitor denylist, no shader files, script self-tests
make -C <repo> strings                             # add new English keys to the String Catalogs
make -C <repo> l10n-pending                        # mark them pending in every language (docs/TRANSLATING.md)
make -C <repo> strings-check                       # catalogs in sync + copy rules + every shipped language valid
make -C <repo> probe-check                         # SDK name-collision probes are current
make -C <repo> build                               # universal Release → build/Overbright.app; CONTROLS=1 keeps the appex
make -C <repo> smoke                               # --diagnostics only: gammaWrites == 0, triggerWindows == 0, …
SIMULATE=1 make -C <repo> smoke                    # agents: never launches on the real ports (Debug: --qa-simulate)
make -C <repo> qa-matrix                           # after `make debug`: every fixture's scenario, Welcome writes nothing
make -C <repo> soak                                # after `make debug`: 30 minutes under --qa-simulate (MINUTES ≥ 17); no own periodic wake-up while off
make -C <repo> perf RUNS=ui                        # after `make debug`: energy phases under --qa-simulate → build/logs/perf/<variant>/perf.md
make -C <repo> perf-compare A=<dir> B=<dir>        # two perf folders side by side: own CPU, own wake-ups, footprint, §17 verdicts
make -C <repo> run                                 # Debug build, simulated displays, a dev settings suite
make -C <repo> dist                                # zip + dmg + sha256 (+ notarization when signing)
make -C <repo> release                             # the next version into VERSION, committed (see Releasing)
make -C <repo> release-build                       # the release files as release.yml builds them → dist/
make -C <repo> distclean                           # also every .build-* scratch dir
```

During development build only your own target (`check-modules.sh <Target>`) and run only your suites: the full
`make check` builds seventeen targets, each in its own scratch directory.

**Disk hygiene.** A worktree holds up to seventeen per-target scratch directories (`.build-<target>`, 50–700 MB each),
`.build-test`, `.build-strings` and an Xcode DerivedData under `build/`: 4–6 GB per worktree. Run
`make -C <worktree> distclean` before handing a worktree back and `git -C <repo> worktree remove <worktree>` after
its merge. `make clean` also unregisters the build products from LaunchServices and PlugInKit, so a dev copy never
lingers in the Control Center gallery or the Open With menu.

### Gotchas carried over from Cranny

- Universal builds need `-destination 'generic/platform=macOS'` (the scripts pass it).
- Debug and Release differ in hardening: verify signing and entitlements on a Release build (`make smoke`).
- Never link a `.dynamic` product into the app: a hardened ad-hoc Release dies with "different Team IDs".
- Launch the built app with `open` (LaunchServices) or `scripts/lib/run.sh`, not by running the binary, except for the
  command-line modes (`--diagnostics`, `--monitor`, `--restore-gamma`).
- `xcodebuild` never adds catalog keys: run `make strings`. **Building in the Xcode app rewrites String Catalogs**
  (its own key order, stale marks): if `git status` shows catalogs you did not mean to change, run `make strings` or
  check them out again before committing; `make strings-check` fails on IDE-sorted catalogs.
- A changed default needs a settings upgrade step (`Sources/OverbrightCore/Settings/SettingsUpgrades.swift`): a value
  equal to its default is never stored, so a new default silently changes every user who kept the old one.
- The CI runner labels were never confirmed by a real run.

## Running the app safely

`make run` builds Debug and launches it with `--off --qa-simulate builtin-xdr-lid-open --qa-defaults-suite
app.overbright.Overbright.dev`: every display port is a Core fake (no table is written, no EDR window is ordered in),
and every setting the run writes stays in that suite instead of your preferences. **`--qa-simulate` is mandatory for
agents and for every scripted run**; only the owner's hardware session (docs/HARDWARE-TEST.md) runs without it. A
Release build refuses every Debug-only switch (`--qa-…`, `-OverbrightQA…`) and exits with status 64, so a QA command
can never fall back to the real displays. A run with `--qa-simulate` is exempt from the single-instance check, so it
can run next to your installed copy.

```zsh
QA=(--off --qa-simulate builtin-xdr-lid-open --qa-defaults-suite app.overbright.Overbright.qa)
<repo>/scripts/lib/run.sh -- "${QA[@]}" --qa-settings about --qa-snapshot /tmp/qa --qa-exit-after 8
<repo>/scripts/lib/run.sh -- "${QA[@]}" --qa-welcome defaults --qa-snapshot /tmp/qa --qa-exit-after 8
defaults delete app.overbright.Overbright.qa       # the next session starts from the defaults
```

Seed a setting for a run through the `UserDefaults` argument domain (part of the suite's search list, never written):
the key is `-overbright.<namespace>.<name>` and the value the setting's JSON as plist data, for example
`-overbright.onboarding.completedVersion '<22302e312e3022>'` ("0.1.0") skips Welcome.

### Visual QA hooks (Debug builds only)

No hook posts input or asks for a permission. Launch arguments (`LaunchArguments`,
`Packages/OverbrightKit/Sources/OverbrightAppShell/App/QAHooks.swift`):

| Argument | Effect |
|---|---|
| `--qa-simulate [fixture]` | Core fakes for every display port over a fixture of ARCHITECTURE.md §3.9 (`builtin-xdr-lid-open`, `mpg322ux-hdr-on`, `lcd-only`, `hardware-mirror`, …); a missing or unknown name falls back to `builtin-xdr-lid-open`, never to the real ports. |
| `--qa-defaults-suite <name>` | Keeps every setting the run writes in that suite (`Launch/QAHooks+Defaults.swift`); the app's own domain or a global one is refused and the run keeps its settings in memory. The Settings window's frame is not autosaved then. |
| `--qa-state <name>` | Drives the panel with a named status of PanelUI's `ScriptedStatuses` (every chip, banner, phase and HUD of DESIGN.md §5.13); the state's settings go into the run's suite (in memory without one), and its Fill Light and "Why?" row show too. A scripted status is ready at once, so its surfaces wait only for the services to start (Help shows once the shortcuts are registered). |
| `--qa-live-signals` | With `--qa-simulate` only: the real, read-only Signals (running apps, window list, power, session) over the simulated displays, for `make perf RUNS=signals`; every display port and Fill Light stay fakes, and the script's signal steps (lock, sleep, events, conflicts) are skipped. |
| `--qa-panel`, `--qa-menu`, `--qa-hud <level>` | Opens the panel (it stays open on clicks elsewhere, and every close is logged with its cause), the status menu (its rows go to `qa-trace.txt`; it closes by itself after 3 s), the HUD (under `--qa-simulate` at that level; on the real displays only its generic change, never a level). Like every surface hook, they wait for the launch work (every service started and the status ready, at most 10 s). |
| `--qa-settings <pane[#row]>` | Opens Settings at a pane (`general`, `displays`, `automations`, `shortcuts`, `fillLight`, `advanced`, `about`), scrolled to and highlighting a row. |
| `--qa-welcome <step>` | Opens Welcome at `hello`, `displays`, `defaults`, `findIt` or `done`; takes no focus and records nothing. |
| `--qa-calibration <display>`, `--qa-help <anchor>` | Opens the calibration window (a simulated display always gets the titled window) or Help at an anchor, after the launch work, so there is an engine to ask and a registered shortcut to show. |
| `--qa-snapshot <dir>` [`--qa-snapshot-at <s>`] | Renders every visible window in-process into `<dir>` (works while the display sleeps; menus cannot be rendered): each window's SwiftUI root, opaque, in the window's appearance; timed from the end of the launch work (3 s; 2 s with `--qa-hud`, 1 s for a HUD state). Settings' sidebar and toolbar are not faithful there in either appearance (the selected row a black bar without its label, no search field, no pane title): judge them in `SettingsChromeSnapshotTests` or on screen. |
| `--qa-exit-after <s>`, `--qa-update-check` | Quits after that many seconds; runs the update check at once. |
| `--qa-hang-main <delay>,<duration>` | Blocks the main thread (hang-watchdog test H-X1, the owner's session only). |

`-OverbrightQAAppearance light|dark` pins the whole app's appearance. Settings-window defaults: `-OverbrightQASnapshot <file.png>`
[`-OverbrightQASnapshotDelay <s>`], `-OverbrightQASearch "<text>"`, `-OverbrightQACloseAfter <s>` (closes Settings as
its close button would), `-OverbrightQASettingsMenuItem <s>` (performs the app menu's ⌘, item after that many
seconds, as the key would; no input is synthesized), and `-OverbrightQAKeyboardLayout <id>` (key caps
in another layout, for example `com.apple.keylayout.German`; read wherever key caps are drawn). Debug builds also
take `-OverbrightGitHubRepository owner/repo` to try the update check against a scratch repository. A build's own
repository is the build setting `OVERBRIGHT_GITHUB_REPOSITORY` (empty in the project: no update check):
`OVERBRIGHT_GITHUB_REPOSITORY=owner/repo make build` sets it, and `release.yml` builds with the repository it publishes
from; smoke checks the value.

**Right to left:** pass `-AppleLanguages "(ar)" -AppleTextDirection YES` (AppKit mirrors only with both).

### Command-line modes (also Release)

`--diagnostics <file|->` writes the read-only report and quits before any service starts; `--monitor [seconds]`
prints one JSON line per display every 250 ms (read-only); `--restore-gamma` runs the launch check's restore on every
display and quits. `--off` starts with the master off.

### Opt-in tests

Skipped unless their variable is set; never run in CI:

| Variable | What |
|---|---|
| `OVERBRIGHT_SNAPSHOT_DIR=<dir>` | Snapshot suites write PNGs for review into `<dir>/<Target>/`. |
| `OVERBRIGHT_INTEGRATION=1` | Tests that show windows on screen (never with EDR content). |
| `OVERBRIGHT_HARDWARE=1` | The owner's hardware session only (docs/HARDWARE-TEST.md 1.13): read-only real display ports (`RealDisplayReadTests`: capacity, read, profile base, the IORegistry walk) and the off-screen Metal clear (`MetalClearPassTests`). |

## Measuring energy

`scripts/lib/perf.sh` (`make perf`, ARCHITECTURE.md §8.7) measures a Debug build under `--qa-simulate` against
DESIGN.md §17, phase by phase. Each run launches the app once with a scripted scenario and a unique
`--qa-defaults-suite`, which it deletes afterwards; beside it runs the soak's control app
(`scripts/lib/soak-control.swift`), a menu bar app that subscribes to what Overbright subscribes to at rest. Every
number is the app's minus the control's:

- **CPU** is CPU time (`proc_pid_rusage` user + system) over a clean window, as % of one core. The Mac may be busy
  with other work: never judge by `top`'s instantaneous %.
- **Wake-ups** are interrupt wake-ups (`ri_interrupt_wkups`) per second. `top`'s IDLEW counts only platform idle
  exits and reads 0 for every process on a loaded Mac, so it judges nothing.
- **Memory** is the `footprint` total (what Activity Monitor's Memory column shows), never RSS. Any in-process Metal
  work makes the GPU driver charge ≈ 237 MB of graphics footprint until 1–3 s after the last frame.
- `sample` (hot stacks and a busy-sample split by subsystem), `footprint` and `vmmap --summary` run after each window.
- **Counted phases** (`events`, `panelcycle`) do a known number of things and report the own CPU per thing. The app
  runs the next step right after a `dump`, and perf.sh notices a dump 0–0.25 s later (it polls the status file), so
  each reading's dump is followed by a 1 s rest: the reading at the start and the one after the counted work both fall
  where the app is idle, and the tail that `sample` watches starts only after that rest. A 5 s rest before each
  counted phase lets perf.sh finish reading the previous one's footprint first. perf.md prints how late each reading
  came (marks.tsv keeps it) and flags one 0.75 s or more after its dump.
- **The lock state** is read with every reading and every 5 s between them (lock.tsv), with the load average. A
  window in which the Mac was locked or unlocked partway is reported as "lock changed (locked→unlocked)", is not
  judged, and `perf-compare` marks it not comparable: an unlock redraws the screen inside the window. Run it again.
- **Apps launched, quit and activated** on the Mac are counted per window (apps.tsv, counts only: no app is named).
- **Off's verdict** uses the soak's wake-up rule (at most 0.05 own interrupt wake-ups/s; whether they beat
  periodically is judged by `make soak` and the `timeline` run, not in one 60 s window) and a footprint under 40 MB
  (DESIGN.md §17's literal wake-up figure is 0/s).

| Run | What it measures |
|---|---|
| `launch` | launch to ready, with a `sample` of the first 10 s |
| `base` | off, boosted, the panel open (steady and while the level moves at 10 Hz), a ramp storm and the HUD with the panel closed, dimmed, back to off (≈ 21 min) |
| `ruleoff`, `two` | boosted with the full-screen-video rule off; two boosting displays (`russian-names`) |
| `ui` | off, one panel open and close, the ramp storm and the HUD, back to off (≈ 7 min) |
| `events` | 1,500 screen-parameters events 10 ms apart while off and while boosted, then bursts of 120 at 8 ms every 5 s with the panel closed and open: CPU per event |
| `panelcycle` | the panel opened and closed 10 times while off: CPU per open and the footprint after |
| `timeline` | interrupt wake-ups every second for 300 s while two displays are boosted: seconds with two wake-ups, gaps |
| `signals` | off, boosted and dimmed (60 s windows) with `--qa-live-signals`: the real Signals' cost on this Mac. Its numbers depend on the apps running, launching and quitting (the apps column) and on the lock state: a running conflict-catalogue app or a locked screen keeps the engine from boosting (the engine line names the reason, and a boosted phase is then not judged). The app's own dump names a running app by its catalogue entry only (`StatusSummary.byEntry`), so no file of the run carries an app's name or bundle ID |

```zsh
make -C <repo> debug
cp -R <repo>/build/Overbright.app <repo>/build/Overbright-base.app   # or build the base in its own worktree
make -C <repo> perf RUNS="ui events" APP=build/Overbright-base.app VARIANT=base
make -C <repo> perf RUNS="ui events"                                  # your build → build/logs/perf/Overbright/
make -C <repo> perf-compare A=build/logs/perf/base B=build/logs/perf/Overbright
<repo>/scripts/lib/perf.sh summarize <repo>/build/logs/perf/Overbright    # the tables again (perf.md, perf.csv)
```

**Protocol.** Measure the base and your branch alternately in one session (base, branch, base, branch), every steady
phase at least twice, and report the repeat pair, never a single window; `signals` above all, whose cost follows what
the rest of the Mac does: compare its windows only with the base run next to them, and with similar app counts.
Discard a window whose lock state changed, and one in which the system log shows a click on the status item or the
panel (`/usr/bin/log show --last 30m --predicate 'subsystem == "app.overbright.Overbright"'`: "panel closes:
outsideClick", AppKit `trackMouse`), and run it again. `PHASE`, `MEASURE`, `SETTLE` and `SAMPLE` change the windows
(`SAMPLE=0` skips `sample`). A run that stops partway (an error, Ctrl-C) asks the app to quit with SIGTERM (its quit
flow), stops its readers and deletes its suite.

**The app's own domain.** perf.sh and the soak export `app.overbright.Overbright` before and after (read-only)
and fail when a QA run changed it (ARCHITECTURE.md §8.5); they never delete a key there.

**Safety.** perf.sh refuses a Release build, runs only the simulated ports (D24), never posts input and never attaches
a debugger: `sample`, `footprint` and `vmmap` read the process. Do not attach `lldb -p` or `xctrace --attach` to a QA
run either: lldb asks for a password on screen and makes `footprint` and `sample` hang.

## Releasing

Releases go out from `main` on GitHub (`.github/workflows/release.yml`, ARCHITECTURE.md §8.9): a push whose `VERSION`
has no release yet runs the whole CI, builds the release on the xcode-27 runner with `scripts/build-release.sh` and
publishes `Overbright-<version>.zip`, `.dmg` and `.sha256` as the release "Overbright <version>", tagged `v<version>`,
with the commit subjects since the previous release as its notes. A push that keeps the version is only tested.

```zsh
make -C <repo> release                  # shows the version and the last release tag, asks for the next one (Enter:
                                        # the next patch version), writes it into VERSION and the project's
                                        # MARKETING_VERSION and commits both as "feat: release - version X.Y.Z";
                                        # never pushes
make -C <repo> release V=patch          # or V=minor, V=major, V=1.4.0: no question asked
git -C <repo> push origin main          # starts the release
make -C <repo> release-build            # the same files locally, built the way release.yml builds them → dist/
SIMULATE=1 make -C <repo> release-build ARGS=--allow-pending   # agents: no real display ports; pending strings allowed
make -C <repo> release-test             # the release scripts' tests (CI runs them too)
```

The new version must be higher than `VERSION` and every release tag (`vX.Y.Z`, local or on GitHub). With the
repository secrets `DEVELOPER_ID_P12_BASE64`, `NOTARY_KEY_P8_BASE64`, `NOTARY_KEY_ID` and `NOTARY_ISSUER_ID` (and
`DEVELOPER_ID_P12_PASSWORD` when the .p12 has a password) the release is signed with Developer ID and notarized; with
none of them it is ad-hoc signed. Once a release is signed with Developer ID, a build that is ad-hoc or of another team
is refused. A release refuses strings
pending translation. When a release job fails, re-run it or push a fix: the version stays unreleased until its release
is published. Run the workflow by hand with **dry_run** to build any branch without publishing anything.

## Engineering rules (summary of ARCHITECTURE.md §8–§9)

**Concurrency.** Core, Policy and Channel are nonisolated; every other target is `MainActor` by default. Every entry
point the system may call off the main thread is explicitly nonisolated (a `nonisolated static` C callback, a
`{ @Sendable … }` closure, `queue: .main` observers) and has an off-main test; un-annotated closures handed to such
APIs trap at runtime. Leave the main actor with `@concurrent` functions. No repeating timers (a stored `Task` with
`TimeSource.sleep`), no `DispatchQueue.main.sync`, no semaphores on main, no Combine.

**Energy.** Zero work while off (the soak fails on a periodic wake-up of Overbright's own while off, and on more
than 0.05 own interrupt wake-ups/s in its last off phase);
boost-only sources run only while a display is scaled or dimmed, and all but the schedule boundary also stop while
the screen is locked, asleep or off the console.

**Errors and logging.** `Log.logger(<category>)`; codes and numbers `.public`, display names, app names and paths
`.private`; no `print`. No `fatalError`, `try!`, `as!` or force unwraps in `Sources/`.

**Style.** Swift API Design Guidelines; small files, one primary type per file, a header naming the doc sections the
file implements, doc comments on every public declaration, explicit imports (`Foundation` for `String(localized:)`,
`os` for `Logger`, `Observation` for `@Observable`). Views use Design's tokens (`@Environment(\.overbright)`, `Space`,
`Radius`, `theme.animation(…)`, `Image(symbol:)` with `OverbrightSymbol`), never literal colors, sizes or animations;
every view file ends with `#Preview`s over `OverbrightServices.preview(fixture:)`. Never give a public type a name an
Apple framework exports.

**Strings.** Catalogs per target (`Sources/<Target>/Resources/*.xcstrings`); always `bundle: .module`; keys are the
English text with one comment `"<Surface>: <purpose>"` (a key used twice shares one comment). Key caps are never
typed into copy: a sentence that mentions a shortcut takes `ShortcutCenter.displayString(_:)` as a placeholder.
**New English text: translate it or mark it pending in every shipped language** (`make strings` →
`make l10n-pending` → `make strings-check`; docs/TRANSLATING.md ▸ New strings). Counts get plural variations;
numbers, percentages and durations go through `FormatStyle`.

**Copy** (DESIGN.md §16): American English; sentence case, title case only in AppKit chrome (menus, Settings push
buttons, sheets, alerts); ’ “ ” and one-character …; System Settings named by its pane, never by a ▸ path; a button
into System Settings is "Open System Settings", a button into Overbright names the action. Vocabulary: Standard,
extra brightness, Dim below minimum / Dimmed, Brighter / Less Bright, Safe / Peak, Fill Light, Back to Standard,
extra range — never "boost", "EDR", "gamma" or "headroom" outside Advanced and diagnostics, and never "fallback" or
"overlay".

**Settings in tests and previews.** `OverbrightServices.preview()` keeps its settings in memory; anything else that
needs a `UserDefaults` takes `InMemoryDefaults()`. Never create a `UserDefaults(suiteName:)` in a test or preview
(`noCodeCreatesAPreferencesSuite`).

**Testing.** Swift Testing only, in `Tests/<Target>Tests`. Test against the Core fakes and `ManualTimeSource`; never
bound main-actor scheduling with a short real-time wait (TestSupport's `eventually` waits 30 s and, on a main actor
busy with other tests, until it checked the condition as often as an idle one would in that time).

## Definition of done (ARCHITECTURE.md §9.3)

`scripts/lib/check-modules.sh <Target>` with zero warnings; `make test FILTER=<Target>Tests` passes; new strings synced,
translated or pending, and `make strings-check` green; `make build` and `make smoke` pass with `gammaWrites == 0` and
`triggerWindows == 0`; previews, accessibility labels and values, Reduce Motion / Transparency / Increase Contrast
behaviour for every view; no edits outside your paths; the acceptance criteria demonstrated in the pull request;
**no display state changed while developing**; `make distclean` before handing the worktree back.
