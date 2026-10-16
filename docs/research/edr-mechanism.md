# How extra brightness works on a Mac, and every pitfall we know

*Public summary for contributors, 2026-10-16. Written from Apple's SDK headers and documentation, WWDC sessions, Apple Developer Forums, open-source projects (licences named; GPL projects consulted only through their READMEs, release notes and issue trackers), read-only measurements on the project owner's Mac (MacBook Pro Mac16,5 with M4 Max, macOS 27.0.1, an external MSI MPG322UX QD-OLED), compile-only probes, and static inspection of macOS's own system frameworks. No code from any project is reproduced. Nothing here changed a display's state while it was researched.*

Labels: **[DOC]** Apple header or documentation · **[WWDC]** · **[FORUM]** Apple Developer Forums · **[OSS]** open-source project · **[LOCAL]** read-only measurement on the owner's Mac · **[SYS]** behaviour read from macOS's system frameworks (static inspection, described in our own words) · **[PROBE]** compiled or run off screen · **[HW]** still needs the hardware session (`docs/HARDWARE-TEST.md`).

---

## 1. What EDR headroom is

- Extended Dynamic Range is linear, SDR-relative light: 0 is black, 1.0 is SDR (UI) white, values above 1.0 are highlights [WWDC21 10161].
- **Headroom** `H` = the brightest renderable value ÷ SDR white. It depends on the display, its preset and the brightness slider. Values above `H` clip to `H` [WWDC].
- Three `NSScreen` properties [DOC NSScreen.h]:

  | Property | Meaning |
  |---|---|
  | `maximumExtendedDynamicRangeColorComponentValue` | **current** headroom; 1.0 until something on screen requests EDR, then it rises; "when the value changes, `NSApplicationDidChangeScreenParametersNotification` will be posted" |
  | `maximumPotentialExtendedDynamicRangeColorComponentValue` | the most this display can offer in its current preset; 1.0 for displays or presets without EDR |
  | `maximumReferenceExtendedDynamicRangeColorComponentValue` | > 0 only while a reference mode is active |

- **Why the trick works on a backlit XDR panel** (consistent with WWDC's description and every tool's behaviour): when anything on screen requests EDR, the display pipeline raises the backlight towards the preset's peak and scales SDR pixel values down so SDR white stays where the user set it. A scaled display transfer table, which sits after compositing, pushes every SDR value up again, into the freed range.

## 2. The two-part technique (public APIs only)

1. **An EDR trigger:** a tiny on-screen layer that requests EDR, one per display (headroom is per display).
2. **A scaled transfer table:** `CGGetDisplayTransferByTable` reads the per-channel table; `CGSetDisplayTransferByTable` writes `baseline × F` [DOC CGDirectDisplay.h].
   - The header documents entries as 0…1. Entries above 1.0 are undocumented but take effect while headroom is available; without headroom they clamp, which overexposes everything (the classic "blown-out screen").
   - `CGSetDisplayTransferByFormula` cannot boost (its maximum must be in (0, 1]).
   - `CGDisplayRestoreColorSyncSettings` restores **every** display to its ColorSync profile, wiping other apps' tables (warm-light tools, calibration loaders) [DOC].
   - Reading back a table is **reported** to clamp entries above 1.0 at 1.0 (one field report on an M1 Max [OSS issue notes]); it is not yet measured on macOS 27 (HARDWARE-TEST §2.0). A residue or drift check must therefore not key on "maximum > 1.0": Overbright compares a read with the display's profile base at entries below 1.0 and looks for a clamped plateau, which works under either behaviour (ARCHITECTURE.md D26).
   - `CGDisplayIOServicePort` is unavailable in the macOS 27 SDK [PROBE].

Every tool in this category pairs these two parts [OSS xdr-light (MIT); README descriptions of the other tools].

## 3. Triggers

### 3.1 What the SDK says

- **`CAMetalLayer.wantsExtendedDynamicRangeContent`** (macOS 10.11+, not deprecated): "If any rendering context on the screen has this enabled, all content will be clamped to its NSScreen's maximumExtendedDynamicRangeColorComponentValue rather than 1.0." The grant follows the flag on an on-screen context; pixel values and frame rate are not mentioned [DOC CAMetalLayer.h]. A forum report on macOS 13.3 saw an EDR view showing an 8-bit image (values ≤ 1.0) unlock headroom for everyone [FORUM 727301].
- **`CALayer.wantsExtendedDynamicRangeContent`** is deprecated in macOS 26 in favour of **`preferredDynamicRange`**, which "requires that the layer contain a CGColor or contents with headroom tagging greater than 1.0 in order to activate EDR" [DOC CALayer.h]. The tag is separate from the colour's values (`CGColor(headroom:…)`, `NSColor.applyingContentHeadroom`), so a black colour can carry a tag.
- `.high` "should be reserved for situations where the user is expected to be focused on the media"; `.constrainedHigh` modulates brightness "for co-existence" [DOC]. macOS 26 also added an HDR-suppression policy (`applicationShouldSuppressHighDynamicRangeContent` and begin/end messages) that follows "established policy" [DOC]. An always-inactive menu bar agent might be suppressed [HW].
- `contentsHeadroom` "can help reduce the power impact when using a limited amount of dynamic range" [DOC]: a tag may cap the grant, and might therefore save backlight power [HW].
- AVFoundation renders HLG, HDR10 and Dolby Vision as EDR automatically [WWDC21 10161].

### 3.2 Off-screen facts (macOS 27.0.1, [PROBE])

- A clear-only Metal render pass (load action `.clear`, no draw call) needs no pipeline and no shader library: it cleared an `rgba16Float` texture to 0, 1.0, 1.6 (read back 1.5996) and 8.0 with no library in the process. **No strategy needs `.metal` files or the Metal Toolchain.**
- `CGColor(headroom:)` stores tags at about 1e-3 precision; tags ≤ 1.0001 read back as 1.0 and tags below 1 clamp to 1.0. A tagged-layer trigger must tag at ≥ 1.01.
- `NSColor(colorSpace:components:count:)` returns 8-bit components and **wraps** values above 1.0 (1.6 becomes ≈ 0.596). EDR colours must start from a `CGColor`.
- Colours in the BT.2100 HLG or PQ spaces created with headroom 0 read back a headroom of 4.926 (= 1000 / 203).
- `CALayer` and `CAMetalLayer` both default to `preferredDynamicRange = .standard` on macOS 27; a tagged `CAMetalLayer` therefore also needs `.high`.
- The HEVC encoder adds a Dolby Vision configuration box to HLG output by default; `kVTHDRMetadataInsertionMode_None` gives plain HLG.
- A one-frame, 16 × 16 px HLG still (HEVC Main10 or ProRes 422, BT.2020 / BT.2100 HLG / BT.2020) of about 1 KB can be generated at runtime with `AVAssetWriter` and verified by decoding frame 0; it verified in 24 of 24 codec × level × size combinations, also with the software encoder.
- The trigger window recipe (borderless non-activating panel, level `.screenSaver`, `[.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary, .canJoinAllApplications]`, `ignoresMouseEvents`, `sharingType = .none`) is accepted by AppKit.

### 3.3 Field practice and open questions

- Shipping open-source triggers render bright values (1.6 to 8.0) and present periodically (every 0.2 s to every 5 s) [OSS xdr-light (MIT), xdr-boost (MIT), others' READMEs]. Nobody has published a test of a **black** or a **static** trigger, pass or fail. Users of one GPL tool reported a visible white dot from its trigger; that project moved the pixel behind the notch.
- A 1 × 1 pt trigger in the extreme top-right corner of a 14″/16″ MacBook Pro sits under the panel's physically rounded corner (Apple's spec pages note the rounded top corners) and is therefore invisible whatever its value [HW to confirm]. On external displays no area is masked: black (if it works) or soft-light blending (a bright pixel nearly disappears over pure black and pure white, not over mid-grey) are the options.
- WindowServer's own log on the owner's Mac (read passively) shows headroom up-ramps with a median of 1.14 s (max 4.75 s), near-instant drops, and levels held for minutes without re-hinting [LOCAL]. It also shows macOS 27 idling at **H ≈ 1.2** without any request, so a fixed "H > 1.05" readiness gate passes too early; gate relative to the level measured before arming.
- A window with alpha 0, an ordered-out window or a zero-size window is not composited and therefore requests nothing [inference from the documented "on-screen" rule].
- Overbright turns these unknowns into a **ladder** (ARCHITECTURE.md §4.7): tagged layer (black, then bright), one Metal frame (black, then bright), a 5-second keep-alive, an in-memory HLG frame, an HLG still; escalation by measured headroom; the winner cached per display and macOS build.

## 4. The transfer domain: linear light or encoded values?

**Unresolved by measurement.** No public colorimeter or step-wedge result exists; published "nits" figures from tools are arithmetic (`F × SDR nits`) or marketing.

- For a pure power-law curve, scaling encoded values by `F` equals scaling light by `F^γ`, so **a plain multiply is correct under both models**; only the factor that delivers a wanted light gain, and where whites clip, differ.
- Evidence leaning **encoded** (about 65–70 % confidence): the API calls the table "the gamma function" over an index, and `CGDisplayRestoreColorSyncSettings` loads the ICC `vcgt`, which is defined on device code values [DOC]; the built-in panel's own profile uses the sRGB tone curve [LOCAL, read-only profile parse]; tools tuned by eye stop at factors around 1.6 on panels whose headroom is 2.67–3.2 (xdr-light's slider ends at 1.6, and its README reports another tool's maximum as about 1.66), close to `encode(H)` (1.53–1.66) and far below `H`, although several advertise 1600 nits [OSS READMEs].
- Evidence leaning **linear** (weak): one GPL tool ships a fixed 2× factor and reports no SDR clipping; the display pipeline of Apple-silicon built-ins has a linear stage, so a linear model is architecturally possible [LOCAL IORegistry].
- **Design consequence** (ARCHITECTURE.md D5): cap in light units, convert with a per-display domain defaulting to an encoded curve: the sRGB curve at and below white (dimming) and the pure 2.4 power above it (`F = G^(1/2.4)`). That default never clips for a linear truth or for any power-law truth with an exponent up to 2.4, the sRGB curve included; it costs at most a few percent of light. The plain sRGB encode above white would not be safe for a pure 2.4 power: at H 3.2 it writes 1.636, and `1.636^2.4 = 3.26 > 3.2`.
- **The decisive test** needs no instrument: in a step wedge at headroom 2.667, the 95 % patch merges with white at `F ≈ 1.61` if encoded and `≈ 3.00` if linear. A merge near the linear prediction can also come from a late or missed keypress, so linear is accepted only after a confirmation frame at the linear-domain Peak factor (`0.97 × H`), where the 0.95 and 1.0 patches stay distinguishable only if the table really is linear. With a colorimeter, a 10 % window at `F = 1.2` reads 1.20× if linear and ≈ 1.5× if encoded.

## 5. What resets a scaled table, and what to listen for

| Cause | Signal |
|---|---|
| Display connect/disconnect, mode, arrangement, lid, mirroring | `CGDisplayRegisterReconfigurationCallback` (after-phase only; do no display work inside it) + `didChangeScreenParametersNotification` |
| System sleep/wake, display sleep | `NSWorkspace` will-sleep/did-wake, screens-did-sleep/wake (the system resets the table [SYS]) |
| Lock, login window, screensaver | distributed `com.apple.screenIsLocked` / `…Unlocked`, `com.apple.screensaver.didstart` / `didstop`; the shield covers the trigger and headroom drops, so un-scale first |
| Fast user switching | `NSWorkspace` session resign/become active |
| ColorSync profile or preset change | distributed `com.apple.ColorSync.DisplayProfileNotification` |
| Accessibility display options | `NSWorkspace.accessibilityDisplayOptionsDidChangeNotification` |
| Other table writers (warm-light tools, brightness managers, calibration loaders, other boosters) | read-back watchdog + running-apps list |
| Headroom changes (slider, ambient light, heat) | screen-parameters notification + polling while gating |

## 6. What happens when the process dies

- **Behavioural finding (macOS 27.0.1, static inspection of system frameworks [SYS]):** WindowServer remembers that a process wrote a table through the public setter and **reverts the tables when that process's connection dies**: normal quit, crash, `SIGKILL`, jetsam, or the system terminating a menu bar extra app. The kernel tears down the connection, so `SIGKILL` cannot skip it. Two open-source projects report the same from experiment (displaytint, MIT; OpenDisplay's release notes). [HW: `kill -9` run pending.]
- The revert is **global**: it resets every online display to its base, not only the tables the dead process wrote [SYS]. So when any table-writing process quits or crashes (a warm-light tool, another booster, a command-line tool that wrote a table), every other app's tables are reset too and must be re-asserted; Overbright checks its displays 50 ms after any app terminates.
- `CGDisplayRestoreColorSyncSettings()` from a process that wrote **no** table does nothing on 27.0.1 [SYS]. A working rescue writes the read-back table unchanged first (which marks the process as a writer), then restores, then re-reads ("dirty, then restore"). A third-party FAQ reports the global restore sometimes writing all-zero tables (a black screen until reconnect or restart), so the re-read must check that every table is plausible (monotonic, from near 0 to near 1, or equal to the profile base) and write the profile base explicitly otherwise.
- Cases that still leave a scaled table: a **hung** but living process (its connection is alive), death **while a display is captured**, and tables written at **session level** through private API by other tools (they replace the base table, so even a restore re-applies them until a preset change, logout or reboot).
- Logout and reboot clear tables; sleep/wake and lid reconnects reset ours (the boost is lost rather than left behind).
- Consequence: no guardian process is needed; Overbright adds a launch check, a hang watchdog and a documented panic shortcut (ARCHITECTURE.md §7.4).

## 7. The overlay technique (Compatibility mode)

- One full-screen, click-through window per display holding an EDR layer filled with `(F, F, F)` and `compositingFilter = "multiplyBlendMode"` multiplies everything beneath it; the overlay is its own EDR request [OSS xdr-boost (MIT); DOC CALayer.h on compositing filters]. Additive filters lift blacks and wash out the picture.
- It works where table writes are ignored, needs no table, and does not conflict with table writers. Costs: the pointer is not brightened (separate hardware plane); Mission Control and Space switches can flicker; screen recordings may capture it; every recomposition pays a full-screen blend; full-screen video may lose direct-to-display scan-out.
- A factor below 1 dims without any EDR request.

## 8. Known OS behaviour to design around

- **Table writes silently ignored** on the M5 Pro/Max MacBook Pro (Mac17,6–17,9) and the MacBook Neo (Mac17,5) on macOS 26.3 and later: the call succeeds and reads back correctly but nothing changes on screen [FORUM 819331, feedback numbers there]. Software cannot detect it; Overbright uses Compatibility mode on those models and asks "Did the screen get brighter?" during calibration.
- **Auto-brightness interplay on built-in XDR** (macOS 26+): toggling "Automatically adjust brightness" while a table is applied can leave a persistent wrong picture that survives app termination and is cleared by a preset change [FORUM 819331]. Advise not to toggle it while boosted, and return to Standard before asking users to change it (calibration). A headroom jump is not a usable warning sign: the brightness keys and ambient light move headroom just as much, and the bad state is created at the moment of the toggle.
- **External HDR headroom stuck at 1.0 after wake** on macOS 26 until HDR is toggled [FORUM 810008].
- **Headroom throttling**: macOS lowers headroom with heat and over long HDR sessions; never fight it; say "Limited by macOS".
- **`NSScreen` objects are recreated on reconfiguration**: re-fetch after every screen-parameters change; `maximumPotential…` is fixed per object.
- **Transient potential of 0 or 1** around sleep/wake on virtual displays [LOCAL log]: treat as "unknown, check again".

## 9. HDR content, screenshots, colour

- With a scaled table, HDR content above SDR white collapses to the boosted white (the table's input ends at 1.0), so HDR video looks flat; pause for video players and full-screen apps.
- Table boosts do not appear in screenshots (they look like normal SDR) [OSS MonitorControl discussion #1189]; a trigger pixel can; overlays do unless excluded, and ScreenCaptureKit may ignore `sharingType = .none` [FORUM 808016].
- Multiplying the calibrated baseline preserves hue and white point in SDR; reference presets are excluded automatically (`reference > 0`).

## 10. What we do not use

Private frameworks would allow a headroom request without a window, a real nits readout, preset detection and the system brightness value (CoreDisplay, SkyLight, DisplayServices, MonitorPanel symbols exist on 27.0.1 [LOCAL `dyld_info -exports`]). They are undocumented, break between releases, are App Store-ineligible and would make our private-API register non-empty. Overbright uses none; IORegistry **property reads** through public IOKit calls are used, with every key optional.

## 11. Swift 6 pitfalls met while probing

1. Under `defaultIsolation(MainActor)`, a closure or `@objc` method without an isolation annotation is inferred `@MainActor`. It **compiles silently**, but the compiler inserts an executor check at its entry, so when the system calls it from another thread (a Dispatch timer on a utility queue, a CoreMediaIO listener queue, a notification posted on a background thread, a C callback) it **traps at runtime** before any hop inside it can run [PROBE: Swift 6.4, macOS 14 target, SIGTRAP]. Declare every such entry point nonisolated (`{ @Sendable … }` closures, `nonisolated static` C callbacks, observers in a `nonisolated` class), hop inside, and deliver on main where the API allows it (`queue: .main`, a main listener queue).
2. `@convention(c)` callbacks cannot capture; pass context with `Unmanaged`.
3. `NSScreen` and `CAMetalLayer` are not actor-annotated; keep them on main by convention.
4. Typed notification messages are availability-gated (HDR suppression 26+, screen parameters 27+); use string names at a macOS 14 floor.
5. Signal handlers must not call CoreGraphics or actors: `signal(SIG_IGN)` + `DispatchSource.makeSignalSource`.
6. `CGEventSourceSecondsSinceLastEventType` is obsoleted in Swift; use `CGEventSource.secondsSinceLastEventType(_:eventType:)`.
7. `CGDisplayCreateUUIDFromDisplayID` needs `import ColorSync` under `MemberImportVisibility`.

## 12. Sources and licences

| Source | Licence | Used for |
|---|---|---|
| Apple SDK headers (macOS 27.0): NSScreen.h, NSApplication.h, NSWindow.h, NSColor.h, CALayer.h, CAMetalLayer.h, CGDirectDisplay.h, CGColor.h, ColorSyncDevice.h | Apple SDK | API facts |
| WWDC21 10161 "Explore HDR rendering with EDR"; WWDC22 10113, 10114; WWDC23 10181 | — | definitions, examples |
| Apple Developer Forums 727301, 758402, 787257, 795074, 808016, 810008, 819331 | — | field reports |
| Apple support 108321 (presets), 121552 (M4 MacBook Pro), 126323 (Studio Display XDR) | — | specs |
| xdr-light (lichengzhe) | MIT | trigger + table approach, keep-alive, watchdog idea |
| xdr-boost (levelsio) | MIT | multiply overlay idea (credited for Compatibility mode) |
| displaytint (noahlincke) | MIT | reported process-death revert on macOS 26 |
| MonitorControl | MIT | screenshot behaviour of table vs shade dimming |
| brightboi (joaodavidsilva) | licence not stated | field reports only (read-back clamp, reset events); not credited in THIRD_PARTY_NOTICES |
| Gamma Dimmer FAQ (lowtechguys) | proprietary | report that the global restore can write all-zero tables |
| OpenDisplay, BrightIntosh, BrightXDR | GPL-3.0(-or-later) | **READMEs, release notes and issue titles only**; no code used or credited as a source |
| Lunar | MIT licence file, XDR parts encrypted | nothing reusable |
| BetterDisplay | proprietary | public wiki description of its methods |
