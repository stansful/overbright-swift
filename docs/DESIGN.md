# Overbright Design System

> **Brighter when you need it, never broken, always explained.** One control per display with a Standard detent, one warm colour that only ever means "extra light", a reason for every limit, and a way back to Standard from anywhere.

| | |
|---|---|
| Status | **As built through WP15, with WP14's review fixes** (2026-10-17). Written as v0.2 with `docs/ARCHITECTURE.md` before any code and revised with it after a design review (ARCHITECTURE.md Appendix B lists every finding and its fix); "As built" notes record where the code settled a detail this file left open or changed one with the owner's ruling. This file is the single source of truth for every pixel, colour, motion, word and sound in Overbright; ARCHITECTURE.md owns behaviour, contracts and the work plan. Where they disagree, raise it; neither silently wins. |
| Applies to | The menu bar extra and its menu, the panel, the HUD and the Keep-this-level prompt, the Help window, the Settings window, the Welcome window, the calibration window, the self-test sheet, Fill Light, the app icon, every string (including Shortcuts, Spotlight and Focus). |
| Platform | macOS 14.0 deployment target. Liquid Glass (26+) only behind `#available`, always with a designed 14/15 fallback. macOS 27's global glass-opacity slider and fixed window radius are respected by never hard-coding translucency or window corner radii. |
| Clean room | Original work for Overbright (MIT). Nothing from the incumbent commercial app (its code, assets, icon, UI text or feature names) or from any GPL project. Competitors were studied only through public product pages, store listings, reviews and issue-tracker titles (`docs/research/ux-landscape.md`). The incumbent is named only in ARCHITECTURE.md D3. |
| Sibling | The design system of Cranny (the same owner's MIT project), its `docs/DESIGN.md`, supplies the token system, the Settings and Welcome conventions, the copy rules and the accessibility bar. Overbright has no notch surface, so it lives entirely in Cranny's "system world": ordinary windows that follow Light and Dark. |

**Contents.** 0 Decision record · 1 Principles · 2 Tokens · 3 Motion, ramps, flicker safety · 4 Menu bar extra, launching, quitting · 5 Panel · 6 HUD and the Keep-this-level prompt · 7 Settings · 8 Welcome · 9 Calibration · 10 Self-test · 11 Fill Light · 12 Copy catalogue · 13 Symbols, haptics, sound · 14 App icon brief · 15 Accessibility · 16 Copy voice and localisation · 17 Energy budget · 18 What's better than the incumbent · Appendix A Components · Appendix B Verification.

---

## 0. Decision record

| # | Topic | Options considered | Decision (why) |
|---|---|---|---|
| 1 | Where the controls live | Menu only; popover only; both | **Both.** Left-click opens a panel (per-display sliders and status do not fit a menu); right-click or ⌃-click opens a plain `NSMenu` with the quick actions (HIG: menu bar extras show a menu). |
| 2 | Boost and dim | Two features with two switches; one control | **One slider per display** with a detent at Standard: left dims below the macOS minimum, right adds extra brightness. One mental model, one place to look. Dimming needs no per-display switch; the switch gates extra brightness only. |
| 3 | Slider scale and steps | Linear in gain; linear in nits; stops | **Stops, near the detent equally gentle on both sides.** The boost half is linear in stops of the display's top; the dim half is shaped so its first half covers −1 stop and the rest reaches 2 %. Keys and shortcuts step **in stops** (arrows 1/12 stop, Brighter / Less Bright ¼ stop), never in travel, and never cross Standard in one press. Equal travel across the detent was 7.6–15× more change on the dim side. |
| 4 | Preset labels | Labels under ticks; chips; menu only | **Ticks without labels** under the half-width boost zone (four names cannot fit 120 pt in every language). The preset name appears in the readout and in a value tag while dragging; presets are also in the card's context menu, the right-click menu and VoiceOver's named stops. Presets too close together, or below ×1.1, are hidden on that display. |
| 5 | Ceiling names | Safe / Max; Sustained / Peak; Safe / Peak | **Safe / Peak.** "Max" is already the top preset; one word never means two things. |
| 6 | Nits | Always estimate; never; only when known | **Only when known**: a trusted SDR white **and** a calibration for the display's method. Otherwise the multiplier alone, marked as an estimate until calibrated ("≈ ×1.29"). An honest "≈ ×1.29" beats a confident wrong "≈ 1,000 nits". |
| 7 | Colour | Brand accent everywhere; system accent; one warm token | **System accent for system controls, one warm token only for the boost zone** (slider fill right of the detent, the HUD bar, the icon's glow). Warm never carries text, and never shows while nothing is brighter (off or paused draws a neutral hatch). |
| 8 | Liquid Glass | Everywhere; nowhere; navigation layer only | **Panel container and HUD only** (the floating control layer, macOS 26+). Cards are content: no glass. Settings and Welcome get glass only from system controls. |
| 9 | Status chips | Always show state; only when limited | **Only when something per-display limits or prepares the display**, on its own line under the readout. A reason that applies to every display is said once, in the banner. A display that does what you asked shows no chip. |
| 10 | Feedback outside the panel | None; system-HUD look-alike; own HUD | **Own small HUD**, bottom centre of the display, away from the system's brightness indicator and notifications: for shortcut, Shortcuts-app and Focus changes, for "Preparing…" when a turn-on takes a moment, and whenever an automation stops, caps or resumes the boost. |
| 11 | Edge light name | Ring Light; Edge Light; Fill Light | **Fill Light**: the generic photography term for the same job; "Ring Light" is already used by other products in this category. |
| 12 | Onboarding preview | Boost the whole screen; split the screen; boost a card | **Boost only a card** inside our own window with a draggable divider. Nothing outside the Welcome window changes, and there is no nag. |
| 13 | Icons | Sun everywhere | **Sun motif only in the menu bar symbol** (the universal brightness sign, drawn as a template); the **app icon has no sun** and none of the incumbent's shapes or colours (§14). The moon is reserved for Focus. |
| 14 | Defaults | Boost at launch; Max level | **Launch, keep off; Bright room; Safe; no global shortcut bound; every Apps and video automation off** (the owner's rules, 2026-10-20, with "only near full brightness" off too). Nothing gets brighter until the user asks, no key combination is taken from other apps until the user records one, and only the power and heat guards step in on their own. |
| 15 | Help | Remote FAQ; GitHub link; local | **Local Help window** with the answers that matter (§12.6), opened from anywhere, with anchors for chips and verdicts; a GitHub link only when the repository key is set. No network for help. |
| 16 | Headroom display | A bar under the slider; a marker on the track; text only | **A marker on the slider track where the thumb will stop now**, plus the allowed and the potential multiplier in its help tag and VoiceOver. A bar scaled to the slider top could not show potential and was simply full in Safe. |
| 17 | Launching and quitting | Silent agent; always open UI | **Every launch that is not a login launch shows UI**, and Quit is in the panel, the menu, Settings ▸ General and Welcome. An agent app that shows nothing when launched by hand, with its icon hidden, has no visible way out. |
| 18 | Banner length (WP14) | Cut after three lines; grow with the sentence | **The whole sentence, always.** The banner grows and the card list below scrolls; only an app name is cut, in the middle, as a chip cuts it, with the full name in VoiceOver and the help tag. The second half of a banner sentence is what to do about it, and a three-line limit cut it in 29 languages, English included (§2.2, §5.8). |
| 19 | Welcome layout (WP14) | A layout per step; one split on every step | **One split on every step:** the stage, the headline at the stage boundary, then the step's controls; steps 2 and 3 take a compact band of glyphs instead of the half-height stage, so the headline never jumps between steps and always introduces what is under it. The progress dots stay centred in the window and visible on every step (§8). |

---

## 1. Principles

Each principle has a test that a build passes or fails.

1. **Never leave a broken screen.** Overbright only brightens what macOS can actually show, un-scales before anything else on every exit path, and lets macOS restore the display if it dies.
   *Test:* the engine fuzz suite never writes more than 0.97 × headroom; in the hardware session, `kill -9`, lock, sleep and lid close leave every table at its profile base within 1 s (HARDWARE-TEST §2.0, §4 and §5).
2. **Honest numbers.** Every number shown can be backed by a measurement or a published spec; every limit names its cause; estimates look like estimates.
   *Test:* every non-Standard state of a card has a chip, a banner or a readout that explains it; "nits" appears only with a trusted SDR white and a valid calibration; an uncalibrated multiplier is prefixed "≈"; verdicts quote the default ceiling or a measured grant, never the raw potential; the panel's numbers equal Copy Diagnostics' numbers.
3. **Invisible machinery.** Triggers, tables and ladders are our problem. The user sees displays, levels and reasons.
   *Test:* no trigger pixel is visible on the built-in display (HARDWARE-TEST H-W2); the words "trigger", "gamma", "EDR" and "headroom" appear only in Settings ▸ Advanced, Self-Test and diagnostics.
4. **One control, one meaning, one value text.** The level of a display is one number with **canonical units everywhere**: extra brightness is a preset name and/or a multiplier ("Bright room · ×1.29"); dimming is "Dimmed · N %" of Standard light. The panel, the menu, the HUD, Settings, the Shortcuts app and VoiceOver use the same text.
   *Test:* a change from any surface updates every other surface within one frame, and the value text of a level is byte-identical in the readout, the HUD, the menu item, Get State's result and VoiceOver (apart from VoiceOver's spelled-out "times" and "percent").
5. **Always escapable.** Turn Off Overbright is one click away in the menu and the panel, Back to Standard is in the Dock menu and the Shortcuts app and one shortcut away once the user records one (none ships bound, 2026-10-20); Quit is in the panel, the menu, Settings ▸ General and the Welcome window; every launch that is not a login launch shows UI; Force Quit restores the display; every level change away from Standard goes back on its own unless kept (§6).
   *Test:* with the menu bar icon hidden, launching Overbright from Finder (running or not) opens Settings ▸ General, whose Quit Overbright button quits; a recorded Back to Standard shortcut works with every window closed and while a conflict banner is up; a level change nobody keeps returns to Standard after 10 s.
6. **Flicker-safe.** Brightness changes ramp, never strobe: at most one pair of opposing changes per second on a display, and Overbright stops itself if something keeps it reversing.
   *Test:* `FlickerGuardTests`; WCAG 2.3.1 (three flashes) can never be reached by Overbright alone.
7. **Calm and frugal.** Off means zero work; on means as little as the display allows; a working display shows no chip; a reason is said once.
   *Test:* the energy gate of §17 (0 wake-ups while off); no reason appears both as a banner and as a chip.
8. **Native and accessible.** System controls, system colours and text styles, SF Symbols, VoiceOver, full keyboard operation, Reduce Motion, Reduce Transparency, Increase Contrast and Differentiate Without Color honoured live; macOS 14 looks intentional, not degraded.
   *Test:* a keyboard-only run and a VoiceOver-only run cover every feature (no feature depends on right-click or hover); snapshot suites run on macOS 27 locally and 26 in CI; macOS 14/15 are compile-checked and reviewed for availability (WP14).
9. **Private and free.** No account, no license, no analytics, no permissions, no network unless the user turns on the update check.
   *Test:* `make smoke` reports "privacy: none"; the lint test `noNetworkingOutsideUpdates` passes.

---

## 2. Tokens

### 2.0 Placement and rules

- **Where:** `Packages/OverbrightKit/Sources/OverbrightDesign/`. As built: `Tokens/` (one file per family: `OverbrightColor`, `SemanticColor`, `SRGBA`, `Typography`, `Space`, `Radius`, `StrokeWidth`, `HitTarget`, `GlyphSize`, `OverbrightShadow`, `SurfaceMaterial`, `OverbrightMotion`, `OverbrightSymbol`), `Theme/` (`OverbrightTheme`, its root modifier, `RightToLeft`, haptics), `Styles/` (button styles, the focus ring), `Components/`, `Settings/` (row conventions, `SettingsStore.binding(_:)`) and `Copy/` (the localized names and sentences of every Core and Policy enum and their builders, ARCHITECTURE.md §8.8).
- **Rules:**
  1. No module outside Design writes a literal colour, font size, spacing, radius or animation.
  2. Views read `@Environment(\.overbright)` (an `OverbrightTheme`), never raw accessibility flags.
  3. Every surface applies `.overbrightThemeRoot(theme)` exactly once at its root: panel, HUD, Keep-this-level prompt, Help, Settings, Welcome, calibration chrome, self-test sheet.
  4. Components take already-localized `String`s; names inside sentences are bidi-isolated (`String.overbrightIsolated`).
- **One world.** Every Overbright surface is an ordinary window that follows the system appearance (Light/Dark), the user's accent colour and the accessibility display options. There is no forced dark mode.

### 2.1 Colour

**System colours carry everything except the boost zone.** Text uses `labelColor`, `secondaryLabelColor`, `tertiaryLabelColor`; backgrounds use materials and `windowBackgroundColor`; controls use the user's accent. Overbright sets **no global accent colour** (`AccentColor` is not shipped). Fills and marks on the slider are drawn **on top of** the track (composited over it), never in its place.

| Token | Light | Dark | Increase Contrast | Use |
|---|---|---|---|---|
| `panelBackground` | system material (§2.4) | system material | opaque `windowBackgroundColor` | panel, HUD |
| `card` | `quaternarySystemFill` | `quaternarySystemFill` | opaque `controlBackgroundColor` + `separatorColor` 1 px | display cards, banners |
| `cardStroke` | `separatorColor` 50 % | `separatorColor` 50 % | `separatorColor` 100 % | card edge |
| `track` | `systemFill` | `systemFill` | `secondaryLabelColor` 35 % | slider track |
| `detentMark` | `secondaryLabelColor` | `secondaryLabelColor` | `labelColor` | the Standard tick |
| `tick` | `secondaryLabelColor` | `secondaryLabelColor` | `labelColor` | preset ticks |
| `dimFill` | `secondaryLabelColor` over the track | same | `labelColor` | slider fill left of the detent |
| **`boostWarm`** | **#B35F00** | **#FFB020** | **#8F4A00** (light) / **#FFC65C** (dark) | slider fill right of the detent while extra light is on screen, the HUD bar, focus of the boost zone. **Never text, never a background behind text, never a status, never while off or paused.** |
| `inactiveHatch` | 45° hatch, 1-pt `secondaryLabelColor` lines every 3 pt, over the track | same | `labelColor` lines | the boost-side fill while Overbright is off or paused (nothing is brighter), the part of the boost half macOS does not allow now, and a boost half that is turned off for the display |
| `allowedMarker` | `labelColor`, 2 × 24 pt, drawn over the thumb in a 1-pt `panelBackground` halo | same | same | where the thumb will stop now (§5.5) |
| `thumb` | white | white | white | the slider thumb and the Welcome card's divider handle (§2.4) |
| `thumbRing` | none (clear) | none (clear) | `labelColor`, 1 pt | the white thumb's edge on the opaque white card (§15) |
| `neutral` | `secondaryLabelColor` glyph on a 15 % `systemGray` tint | same | `labelColor` glyph | neutral chips and banners |
| `info` / `warning` / `danger` / `success` | `systemBlue` / `systemOrange` / `systemRed` / `systemGreen` | same | the system's accessible variants | chip and banner glyphs and tints; always paired with text |

**Contrast audit** (WCAG 2.x). Non-text elements need 3:1 against what is next to them (1.4.11). Measured against reference backgrounds (light panel #F2F2F2, light card #FFFFFF, light track #DCDCDC, dark panel #1E1E1E, dark card #2C2C2E, dark track #48484A), with `secondaryLabelColor` as black 50 % (light) / white 55 % (dark) and `labelColor` 85 %; the test harness re-measures the resolved system colours in each appearance:

| Token | Light: vs track · vs card | Dark: vs track · vs card |
|---|:-:|:-:|
| `boostWarm` #B35F00 / #FFB020 | 3.36 · 4.61 (4.12 on panel) | 4.99 · 7.62 (9.12 on panel) |
| `boostWarm` Increase Contrast #8F4A00 / #FFC65C | 4.87 · 6.67 | 5.86 · 8.95 |
| `dimFill`, `tick`, `inactiveHatch` lines, `detentMark` (secondary over the track) | 3.72 · 5.10 | 4.07 · 6.22 |
| `allowedMarker` (label over the track) | 11.74 · 16.10 | 7.18 · 10.96 |
| `neutral` glyph on its tint | 3.86 (glyph vs tint); text in `labelColor` 13.39 | 4.65; text 8.63 |

As built (WP14): the allowed-now marker is also drawn over the white thumb, where it reads in its own ink in Light and by its dark `panelBackground` halo in Dark (near-white ink on a white thumb); under Increase Contrast the thumb's `thumbRing` stands at least 3:1 off both the white thumb and the opaque card in Light, and the white thumb stands 3:1 off the dark card by itself. `BoostSliderDrawingTests` read both from rendered pixels. The readout is text on the card in `labelColor` in every state, "Off" included (§5.6), and `ContrastAuditTests` render the "Off" readout to check it reaches 4.5:1 in every palette and appearance.

The v0.1 tokens that failed are gone: `headroomAvailable` (`tertiaryLabelColor`, 1.88:1 on the light card) and the 1-px `quaternaryLabelColor` outline (1.25:1). System orange (#FF9500, 2.0:1 on light backgrounds) fails 3:1 in Light mode, which is why the boost zone has its own token. Text never uses `boostWarm`; chip and banner text uses `labelColor` on a 15 % tint of the semantic colour, so text contrast is the system's own, and the coloured glyph is redundant with the words. Text is never faded by lowering a view's opacity (secondary text at 60 % opacity falls to 2.1:1).

### 2.2 Typography

System text styles only; SF Pro Rounded with monospaced digits for live numbers so they never jitter. Nothing below 10 pt. macOS has no Dynamic Type for third-party apps; layouts grow in height for long translations instead of truncating meaning.

| Style | Font | Use |
|---|---|---|
| `panelTitle` | 13 semibold (`.headline`) | "Overbright" in the panel header |
| `cardTitle` | 13 semibold (`.headline`), up to two lines, tail truncation, full name in the help tag | display names |
| `readout` | 13 medium, SF Pro Rounded, monospaced digits | "Bright room · ×1.29 · ≈ 775 nits" |
| `chip` | 11 medium (`.caption` medium) | status chips, footer chips |
| `caption` | 11 regular, `secondaryLabelColor` | the Fill Light card's Cool and Warm |
| `banner` | 12 regular (`.callout`), as many lines as the sentence needs (never cut; an app name in it is middle-truncated) | "Paused because…" |
| `valueTag` | 11 semibold, rounded, monospaced digits | the tag above the slider thumb |
| `hudValue` | 15 semibold, rounded, monospaced digits | HUD value |
| `hudLabel` | 11 regular | HUD display name and reasons |
| Settings, Welcome, calibration, Help | system styles (`.title2`, `.headline`, `.body`, `.callout`, `.footnote`) | — |

The live readout never uses `.contentTransition(.numericText)` (it grows CoreGraphics' glyph cache; Cranny gotcha); digits change in place.

### 2.3 Spacing, radii, strokes, hit targets, elevation

- **Spacing** (`Space`, Cranny verbatim): xxs 2 · xs 4 · s 6 · m 8 · l 12 · xl 16 · xxl 20 · xxxl 24 · huge 32.
- **Radii** (`Radius`, always `.continuous`, concentric: inner = outer − inset):

  | Token | macOS 26+ | macOS 14/15 |
  |---|---|---|
  | `panel` | 20 | 16 |
  | `card` (inset 8) | 12 | 8 |
  | `control` | 6 | 6 |
  | `chip` | capsule | capsule |
  | `hud` | 20 | 16 |
  | `keycap` | 4 | 4 |
  | `focusRingOutset` | 3 | 3 |

- **Strokes** (`StrokeWidth`): hairline = 1 device pixel; regular 1; focus ring 2; slider track 4 (6 while dragging); detent tick 1.5 × 8 pt; preset ticks 1 × 5 pt; allowed marker 2 × 24 pt (`allowedMarker`: taller than the 20-pt thumb and drawn over it, so it shows where the thumb rests on it) in a 1-pt halo of the panel background (`allowedMarkerHalo`, `panelBackground`).
- **Hit targets** (`HitTarget`): ≥ 28 × 24 pt for every panel control (the 20-pt slider thumb takes a 28-pt hit area inside the control; footer chips at least 28 pt wide); widening happens inside the button style, never with an outer frame (Cranny gotcha).
- **Glyph sizes** (`GlyphSize`, as built in WP9; SF Symbols beside text, `.font(.system(size: GlyphSize.chip))`, never a literal): `chip` 12 (status and footer chips, and the spinner that stands in for a chip's glyph) · `banner` 14 · `sliderEnd` 14 (`sun.min` / `sun.max.fill` at the ends of a card's slider row, drawn by the card) · `hud` 20 (the HUD's leading glyph).
- **Elevation:** the system's window shadow for the panel and the HUD; cards have none (a hairline only). The few shadows Overbright draws itself are `OverbrightShadow` tokens (as built in WP9; `.overbrightShadow(_:)`, never a literal): `thumb`, the slider thumb and the Welcome card's divider handle (black 30 %, blur 1, 0.5 pt down, the system slider thumb's) · `valueTag`, the value tag's lift off the track (black 15 %, blur 2, 1 pt down).

### 2.4 Materials

| Surface | macOS 26+ | macOS 14/15 | Reduce Transparency |
|---|---|---|---|
| Panel container | Liquid Glass (`NSGlassEffectView`, `.regular` style), corner radius `Radius.panel` | `NSVisualEffectView(.popover, .behindWindow, .active)` masked to `Radius.panel` | opaque `windowBackgroundColor` |
| HUD, Keep-this-level prompt | Liquid Glass (`NSGlassEffectView`, `.regular`) | `NSVisualEffectView(.hudWindow)` | opaque |
| Cards, banners | `card` fill (no glass, content layer) | same | same |
| Slider thumb | white (the `thumb` colour token, white in every appearance); takes glass only while dragged (system behaviour of transient controls) | white with the `thumb` shadow | white |
| Settings, Welcome, Help | system (sidebar and toolbar glass from AppKit; we add none) | system | system |

Glass is never stacked on glass, and nothing translucent sits behind text without a card.

As built (WP9, `SurfaceMaterial`): the macOS 27 SDK's `NSGlassEffectView.Style` has `.regular` and `.clear` only, so the containers use `.regular`; Increase Contrast takes the opaque container too (the theme's `highContrast` palette, like Reduce Transparency's `opaque`), and the dragged thumb never takes glass under either.

### 2.5 Theme and environment

`OverbrightTheme` merges, once per surface root: `reduceMotion`, `reduceTransparency`, `increaseContrast`, `differentiateWithoutColor`, `voiceOverRunning`, the effective appearance and the layout direction. It exposes `animation(_ kind:)` (nil when motion must not play), `animatesSymbols`, `palette` (`standard` / `highContrast` / `opaque`) and `usesGlass`. Changes apply live.

---

## 3. Motion, brightness ramps and flicker safety

### 3.1 Interface motion (`OverbrightMotion.Kind`)

Every animation is interruptible, nothing queues, nothing overshoots when it shrinks, and nothing loops except the system progress indicator while a display is preparing.

| Kind | Curve | Duration | Use |
|---|---|---|---|
| `panelIn` | easeOut | 0.18 s | panel appears: opacity 0 → 1 and 4 pt downward settle |
| `panelOut` | easeIn | 0.12 s | fade |
| `contentSwap` | smooth | 0.25 s | card content changes (state, chip), Welcome verdict cross-fade |
| `expand` | spring, bounce 0 | 0.30 s | "Why?" row expanding, banner insertion |
| `hover` | easeOut | 0.12 s | hover highlights |
| `press` | spring, bounce 0.2 | 0.18 s | press scale 0.97 |
| `detentSnap` | spring, bounce 0 | 0.20 s | thumb settling into Standard or a preset |
| `colorShift` | easeInOut | 0.40 s | fill colour changes (dim ↔ boost, warm ↔ hatch) |
| `hudIn` / `hudOut` | easeOut / easeIn | 0.18 s / 0.25 s | HUD in (scale 0.96 → 1, fade) and out (fade) after 1.5 s (automation reasons: 3 s) |
| `bannerIn` / `bannerOut` | easeOut / easeIn | 0.22 s | 6-pt slide plus fade |

### 3.2 Reduce Motion

Cross-fades only (≤ 0.2 s), no slides, scales or symbol effects; the detent and preset snaps are immediate; brightness ramps shorten to 160 ms but never become a jump (§3.3). The HUD fades without scaling.

### 3.3 Brightness ramps (not SwiftUI; owned by the engine)

| Change | Duration | Shape |
|---|---|---|
| User or policy (slider release, preset, shortcut, guard, pause, resume, master on/off) | **300 ms** (band 250–400 ms) | smoothstep in stops, ≈ 60 steps per second, never fewer than 6 |
| Reapply after macOS or another app reset the display | ≤ 300 ms | same shape (never a jump back) |
| The same under Reduce Motion | 160 ms | same shape |
| Back to Standard | 120 ms | same shape |
| Safety drop (headroom fell, lock, sleep, occlusion) | **one step** | immediate: an over-bright screen is worse than a step |
| A raise you asked for (slider, preset, shortcut, Shortcuts) | at once, as far as macOS allows now; further as more range arrives (≤ 3 s) | 300 ms |
| Raising after headroom recovers by itself | waits for 1.5 s of stable headroom, then 300 ms | only if the new level is ≥ 5 % above the current one |
| Slider drag | follows the finger continuously | the rate limiter still applies to direction reversals |

The readout and the HUD show the target at once; the allowed-now marker moves with the ramp. Multiple displays ramp together, never one after another.

### 3.4 Flicker safety

WCAG 2.3.1 allows at most three general flashes per second. Overbright guarantees much less, per display:

- at least 500 ms between opposing brightness changes, so at most one flash per second, and only from the user's own repeated input;
- an oscillation detector that stops a display after four non-user reversals in 10 s ("Overbright stopped on ‹Display› to prevent flicker", §12.3); following a steady brightness change (brightness keys, ambient light) does not count;
- a repair budget (3 in 6 s) that stops fighting another app over the display colours, even after "Continue anyway"; these stops end only when you choose Try Again or the other app quits;
- the calibration comparison flips at most once per 1.5 s; the Welcome card's divider changes only our own window.

---

## 4. Menu bar extra, launching and quitting

### 4.1 The status symbol

An original template image drawn in code (`NSImage(size:flipped:drawingHandler:)`, `isTemplate = true`, no asset): an 18 × 18 pt canvas holding a sun of a 3.5-pt-radius disc and eight round-capped rays 1.5 pt wide. Badges are 5 × 5 pt in the lower trailing corner, cut free from the sun with 1 pt of clearance (the rays under the badge are clipped), as Cranny's demo badge.

| State (`StatusSymbolState`) | Drawing | Accessibility label |
|---|---|---|
| `off` | disc **outlined** (1.5 pt), rays short (radius 5.5 → 7.0) | "Overbright, off" |
| `on` | disc **filled**, rays long (5.5 → 8.0) | "Overbright, on" |
| `preparing` | disc filled, each ray drawn as **two dots** (1.5 pt at radius 6.0 and 7.5) | "Overbright, preparing" |
| `dimming` | a **smaller** filled disc (2.5 pt radius) with eight single dots at radius 6.5 (the `sun.min` idiom) | "Overbright, dimmed" |
| `paused` | the `off` drawing + a pause badge (two 1.25-pt bars) | "Overbright, paused" |
| `attention` | the `off` drawing + an exclamation badge (a 1.5-pt bar and dot) | "Overbright, needs attention" |

The symbol changes without animation (AppKit template images do not animate in the menu bar). In right-to-left languages it is not mirrored (a sun has no direction). No crescent anywhere: the moon reads as macOS's own Focus and Sleep symbols. Fallback symbol if drawing fails: `sun.max`.

### 4.2 Click behaviour

| Setting (General ▸ "Clicking the icon") | Click | Right-click or ⌃-click | ⌥-click |
|---|---|---|---|
| **Opens the panel** (default) | opens or closes the panel | the menu | turns Overbright on or off |
| Turns Overbright on or off | turns Overbright on or off | the menu, which then starts with **Show Panel** | opens the panel |

Turning on or off from the icon announces "Overbright on" / "Overbright off" to VoiceOver; the symbol itself is the feedback. If a turn-on is not ready within 0.5 s, the HUD shows "Preparing…" (§6) and the symbol shows `preparing`, so nobody clicks again and turns it off.

**A second click closes the panel** (as built, the owner's report of 2026-10-20). A click on the icon can reach the panel's outside-click monitor before the icon's own action (the icon's window on another display's menu bar is not the window the panel is anchored to): the monitor closed the panel and the action, finding it closed, opened it again. A press on the icon within **0.4 s** of an outside-click close now counts as that closing click and leaves the panel closed, once; a later press opens it (`PanelController.press()`, `toggleAfterOutsideCloseWindow`). A close by any other cause (Esc, ⌘W, the icon itself, a control) never swallows the next press.

### 4.3 The menu (exact English, title case as AppKit chrome)

```
‹Status sentence›                                     (disabled; only while a banner applies: the banner's own sentence, §12.3)
‹Its action›                                          (the banner's primary action: Resume, Try Again, Continue Anyway,
                                                       Change Power Rules…, Change Hours…, Open System Settings)
───────────
Turn Off Overbright                       ‹live›      ("Turn On Overbright" while off)
Dim All Displays                          ‹live›      ("Stop Dimming" while dimmed)
───────────
Built-in Display                        ▸ Standard
                                          Indoor
                                        ✓ Bright Room
                                          Sunlight
                                          Max
                                          ─────
                                          Dimmed · 25%
                                          ─────
                                          Don't Use on This Display      ("Use Extra Brightness on This Display" when off)
MPG322UX OLED                           ▸ …           (one submenu per display that can boost or dim; "All Displays ▸" when levels are linked)
───────────
Pause for 1 Hour                                      (while paused: "Paused Until 14:20" (disabled) and "Resume")
Fill Light                                            (✓ while on)
───────────
Update Available: Overbright 0.2.0…                   (only when updates are configured and one is available)
Settings…                                 ⌘,
Help
Quit Overbright                           ⌘Q
```

- Key equivalents (`‹live›`) show the **live** global shortcut in the current keyboard layout, or nothing when the shortcut is not recorded (the default: none ships bound, §7.6), cleared or failed to register (Cranny's `MenuKeyEquivalent`). As built (WP14): named keys (Space, Return, Tab, Delete, Esc, the arrows, F1–F12) come from the combo's key code, never from their localized caps ("Пробел", "Leertaste"); a character key comes from the caps of the current layout.
- The status sentence names an app in full (`BannerModel.accessibilityLabel`): the panel middle-truncates a long app name (§5.8) and keeps it whole for its help tag and VoiceOver, but a menu row has no help tag, and the menu sizes itself to its longest row (WP14).
- Preset items list only the presets shown on that display (§5.5); the dim item uses the last dim level (default "Dimmed · 25%", light relative to Standard).
- **Don't Use on This Display** turns extra brightness off for that display and returns it to Standard (dims undone); the opposite item turns extra brightness on (an OLED shows its notice first, §12.4).
- With no display that can boost, the presets are replaced by a disabled "No Extra Brightness on This Display"; a display that can only dim keeps Standard and Dimmed.
- **Back to Standard is not in this menu**: Turn Off already sits in the first group and does the same, a little slower. Back to Standard stays on its shortcut (once recorded), in the Dock menu and in the Shortcuts app.

### 4.4 Launching, reopening, hiding the icon, quitting, Dock icon

- **Launch UI.** A login launch shows nothing. Every other launch, and every reopen while running (Finder, Spotlight, `open`), shows: the Welcome window until it is finished or skipped; else the panel under the icon; else, when the icon is hidden or not visible, **Settings ▸ General**. Launches by a Shortcuts action or an `overbright://` URL show nothing. Nobody is locked out, and nothing runs invisibly after a manual launch.
- **Quit** is in the panel's "⋯" menu, the right-click menu, Settings ▸ General (a **Quit Overbright** push button; ⌘Q also works in the Settings window), the Welcome window (bottom-leading on every step, and in the "Skip setup?" alert), and the Dock menu when the Dock icon is on.
- **Hide the icon:** General ▸ "Show menu bar icon" off asks first:
  > **Hide the menu bar icon?**
  > You can still open Overbright from Finder or Spotlight, which shows Settings, or use ‹toggle shortcut› to turn it on or off. To quit, open Overbright again and click Quit Overbright in Settings.
  > [Hide Icon] [Cancel]

  When the toggle shortcut is not recorded (the default), cleared or not registered, the middle clause is left out ("You can still open Overbright from Finder or Spotlight, which shows Settings. To quit, …").
- **Icon not visible.** 3 s after launch and after every screen change, Overbright checks that its icon is really on screen (its window exists, is visible and not occluded, and is not behind the notch). If it is not, and the user did not hide it: a small window, at most once per app version, and a warning row at the top of Settings ▸ General for as long as the condition holds:
  > **Overbright's icon isn't visible**
  > macOS may be hiding it, or the menu bar is too full to show it. You can still use ‹toggle shortcut›, or open Overbright from Finder or Spotlight. To show it, turn on Overbright under Allow in the Menu Bar in Menu Bar settings.
  > [Open System Settings] [OK]

  The last sentence appears on macOS 26 and later; without a registered toggle shortcut the first sentence ends "…, or open Overbright from Finder or Spotlight."
- **Move to Applications.** Launched from outside `/Applications` (Downloads, a disk image, a translocated path), Overbright asks before Welcome (§12.4). Shortcuts actions and opening at login work only from Applications.
- **Dock icon** (General, off by default): shows Overbright in the Dock; clicking it follows the launch UI rule; its menu offers "Turn On Overbright" / "Turn Off Overbright", "Dim All Displays" / "Stop Dimming", "Back to Standard" and "Settings…" (plus the system's Quit).

---

## 5. The panel

### 5.1 Window

- 320 pt wide; height fits the content up to 70 % of the screen's visible height, beyond which the card list scrolls (the header, banner and footer stay put).
- Anchored under the status item, centred on it and clamped 8 pt from the screen edges, positioned from the status button's window frame (the menu bar is 30 pt on macOS 27 while `NSStatusBar.system.thickness` still says 22).
- A non-activating panel: it takes keyboard focus only when opened by keyboard or VoiceOver, or when the user clicks into it; it closes on a click outside, Esc, ⌘W or a second click on the icon. `panelIn` / `panelOut`.

### 5.2 Anatomy (built-in M4 Max boosted, MSI with HDR off)

```
┌────────────────────────────────────────────────┐  320
│  ☀  Overbright                      [●══]  ⋯    │  header 44
├────────────────────────────────────────────────┤
│ ┌────────────────────────────────────────────┐ │
│ │ Paused because Low Power Mode is on.       │ │  banner (only for reasons that apply to all displays)
│ │                       Change power rules…  │ │
│ └────────────────────────────────────────────┘ │
│ ┌────────────────────────────────────────────┐ │  card 304 × ≈ 110, padding 12
│ │ Built-in Display                           │ │  title (up to two lines)
│ │ ☼ ━━━━━━━━━━━━━━━━━━┃━━━━━●──┊──▌╱╱┊╱╱ ☀    │ │  slider: dim half │ detent │ boost half, allowed-now marker ▌, hatch beyond
│ │ Bright room · ≈ ×1.29                      │ │  readout
│ │ (ⓘ Limited by macOS)                       │ │  chip, own line, only when a per-display reason applies
│ └────────────────────────────────────────────┘ │
│ ┌────────────────────────────────────────────┐ │
│ │ MPG322UX OLED                              │ │  dim-only display: full card, boost half disabled
│ │ ☼ ━━━━━━━━━━━━━━━━━━┃╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱╱ ☀    │ │
│ │ Standard                                   │ │
│ └────────────────────────────────────────────┘ │
├────────────────────────────────────────────────┤
│ (🔋 Below 20 %) (▶ Auto-pause) (⏱ No timer)      │  footer chips 44
└────────────────────────────────────────────────┘
```

### 5.3 Header

- Leading: the status symbol in its current state (16 pt), then "Overbright" (`panelTitle`).
- Trailing: the **master switch** (`Toggle`, small; VoiceOver "Overbright, on"; as built (WP14) drawn by `PanelSwitchStyle`, accent while on in any window state, because the panel is not key when clicked open and a system switch would draw its inactive grey for both states), then the overflow button "⋯" (`IconButtonStyle`) with a menu: **Dim All Displays** ("Stop Dimming" while dimmed) · **Fill Light** (✓ while on) · separator · **Settings… ⌘,** · **Run Self-Test…** · **Help** · separator · **Quit Overbright ⌘Q**.
- **Fill Light card.** While Fill Light is on, a compact card appears above the display cards: "Fill Light" with a **Display** pop-up, **Brightness** and **Warmth** sliders (the same ranges as Settings) and a **Turn Off** button. It is the place to adjust the light during a call without opening Settings. As built (WP14): one grid of a `.callout` label column, the controls and a value column as wide as the widest value, so both sliders start and end at the same x; the controls (the Display pop-up, no wider than the sliders, and the sliders) take the rest of the 280-pt inner width, so the value column ends at the card's inner edge; "Cool" and "Warm" (Settings' words) under the Warmth slider. As built (energy U5): the two sliders are PanelUI's own (`PanelSlider`), drawn like the level slider's track at the small control size (the `track` capsule, the accent colour up to the thumb in any window state, the white `thumb` with its ring under Increase Contrast), one VoiceOver element that adjusts by the keyboard step; the system slider's Liquid Glass knob rendered with in-process Metal on every showing (≈ 270 MB for ≈ 1 s per panel opening while Fill Light is on, §17).
- **One-time calibration tip.** After the first boost on a display that can be calibrated, a dismissible card appears once: "Check that it works" / "A one-minute check makes sure extra brightness is right for ‹Display›." [Calibrate…] [Not now].

### 5.4 Display card

- `card` fill, `cardStroke` hairline, `Radius.card`, padding 12, 8 pt between cards. Every display that can boost **or dim** gets a full card. As built (WP14): one card style (`panelCard`) for the display cards, the calibration tip, the Fill Light card and the expanded "Why?" rows, each exactly 304 pt wide, so their edges line up with each other and the banner, all opaque with a full-strength hairline under Increase Contrast.
- **Title:** display name (`cardTitle`, up to two lines). With linked levels a `link` glyph precedes the name of every card ("Same level on all displays"). Two displays with the same name get " (1)", " (2)" in UUID order, as macOS does.
- **Slider row** (§5.5) with `sun.min` at the dim end and `sun.max.fill` at the boost end (14 pt, `secondaryLabelColor`), 6 pt gaps: a 240-pt track whose boost half is 120 pt (the thumb's centre travels 220 pt of it, §5.5). The glyphs draw 16 and 17 pt wide, so each sits in a 14 × 14 frame and the row is exactly the 280-pt inner width.
- **Readout** (§5.6). Nothing sits under it: the color table is the only method, so no caption names one (the Compatibility-mode caption went with the method, removed 2026-10-21: ARCHITECTURE.md §7.5).
- **Chip line** (§5.7): only when a per-display reason applies. The chip and an inline **Turn on** share the line when both fit its 280 pt; otherwise Turn on drops under the chip. A **Safe limit** or **OLED limit** chip has a gear button beside it (`gearshape.fill`, `IconButtonStyle`, `Space.xs` gap; help tag and VoiceOver label "Choose Peak…") that opens Settings ▸ Displays at this display's Limit row, so Safe becomes Peak in one click (the owner's request, 2026-10-20; `DisplayCardView.offersLimitSetting`); the chip's popover keeps its own "Choose Peak…". Chip, gap and gear fit 280 pt in every language (`ChipFitTests`).
- **Context menu** (right-click, ⌃-click, or ⌃↩ while the card's slider has keyboard focus): the shown presets · Dimmed · 25% · separator · Calibrate… · Settings for This Display… (Overbright's Settings ▸ Displays at this display) · Don't Use on This Display / Use Extra Brightness on This Display · Try Again (only when failed). Every item is also a **VoiceOver custom action** on the card and on its slider (where VoiceOver lands), and the items that fix a limit (Try again, Continue anyway, Turn on, Choose Peak…) are also actions in the chip's popover, so nothing depends on right-click.
- **Extra brightness off for this display** (opt-in displays, or after "Don't Use on This Display"): the boost half draws with `inactiveHatch` and the chip "Extra brightness off" offers **Turn on**. Moving the thumb past the detent turns it on as well; an OLED display shows the OLED notice first (§12.4), and the thumb waits at Standard until the notice is answered (asked when the move ends, for the level it ended at; a move back to Standard or below asks nothing). Dimming always works. The thumb, the value tag, VoiceOver's value, the HUD bar and the menus' checkmark show the level the display has: Standard while the boost half is off or unavailable, whatever level is stored for the next turn-on (as built, WP14).

### 5.5 The level slider (`BoostSlider`)

| Aspect | Specification |
|---|---|
| Track | 240 pt, 4 pt high (6 pt while dragging), `track` colour, capsule ends. The thumb's centre travels the track inset by its radius at both ends, as a system slider's does: 220 pt, from 10 pt in at the dim end through Standard at the centre to 10 pt in at Max, so the thumb never overhangs the track into the 6-pt gap before the end glyphs. Ticks, fills, the detent, the marker, the value tag and drags follow the same travel |
| Detent | a 1.5 × 8 pt `detentMark` at the centre: **Standard** |
| Fills | drawn over the track. Left of the detent: `dimFill` from the detent to the thumb. Right of the detent: `boostWarm` from the detent to the thumb **while extra light is on screen**; while Overbright is off or paused, the same span is drawn with `inactiveHatch` (nothing is brighter, so nothing is warm) |
| Allowed now | while boosting with a reading: a 2 × 24 pt `allowedMarker` where the thumb stops now — macOS's current limit, or the decision's own cap when one binds (heat, Safe, near full brightness: the figure the readout's "asked ×…" states) — drawn over the thumb in a 1-pt `panelBackground` halo (the thumb often rests just past it while a limit binds, so a marker under the thumb would be hidden), and `inactiveHatch` beyond it to the end of the boost half; it moves in steps of ×0.01, the figure its help tag states, not with every headroom poll. Hidden when there is no reading (off, never armed) |
| Ticks | 1 × 5 pt `tick` marks at the **shown** presets (Indoor 25 %, Bright room 50 %, Sunlight 75 %, Max 100 % of the boost half; a preset below ×1.1 or within 0.1 stop of the next shown one is hidden, ARCHITECTURE.md §5.3); none on the dim half |
| Thumb | 20 pt white circle (`thumb`) with the system shadow (glass while dragged on macOS 26+), a 1-pt `thumbRing` under Increase Contrast; 28 pt hit area; its centre on the inset travel of the Track row |
| Snapping | within ±3 % of the detent or a shown tick, a slow drag settles there (`detentSnap`) with an `.alignment` haptic at the detent and `.levelChange` at a preset; a fast drag passes through |
| Value tag | while dragging or hovering the thumb: a capsule 6 pt above it (`valueTag`) with the canonical value text: "Bright room · ×1.29" at a preset, "Standard" at the detent, "×1.42" between presets, "Dimmed · 25%" on the dim half; "≈" before the multiplier while not calibrated; "· small gain on this display" when Max is at most ×1.3; while a guard pauses the display, the reason ("Paused: Low Power Mode") |
| Disabled boost half | when boosting is not possible (verdict, or the Safe top below ×1.05): the right half draws with `inactiveHatch`, the thumb stops at the detent, and hovering the half shows the reason as a help tag |
| Disabled dim half | displays without a transfer table (virtual) or in a reference preset: the left half is disabled the same way |
| Keyboard (focused) | ← / → by **1/12 stop** of light (≈ 6 %) · ⌥← / ⌥→ to the previous/next named stop (Standard, the shown presets; on the dim half 50 %, 25 %, 10 %, 5 %, 2 % of Standard light) · Home = Standard · End = Max · scrolling adjusts by 1/12 stop per notch, following the hand (§15) · ⌃↩ opens the card's context menu. A key step never crosses Standard: the next press continues past it |
| VoiceOver | one adjustable element: label "Level, ‹display name›"; value in canonical units: "Bright room, 1.29 times" / "Standard" / "Dimmed, 25 percent" / "1.42 times"; uncalibrated: "Bright room, about 1.29 times, not calibrated"; increment and decrement move between named stops; custom actions "Standard", "Max", "Dimmed", and the card's context-menu items; custom content "Extra range": "macOS allows 1.55 times now. This display can reach 2.6 times at most." |
| Right to left | the whole control mirrors like a system slider (dim on the right, boost on the left, glyphs swap) |
| Master off | moving the slider turns Overbright on (direct manipulation is intent); the readout then updates |
| Paused | moving the slider also ends a pause you set (the same rule as Master off). A guard (battery, Low Power, heat, schedule, Focus) is not lifted: the level is stored and the value tag names the guard |
| Linked levels | every card's slider moves together; each display stops at its own ceiling |

Per-step light changes are the same on every display, because steps are in stops; only the number of presses differs (ARCHITECTURE.md §5.3: three Brighter presses take the M4 Max from Standard to Safe's Max, twenty-three Less Bright presses take any display from Standard to the 2 % floor).

### 5.6 Readout and the allowed-now marker

**Readout** (`readout`, one line, ≤ 200 pt; parts separated by " · "):

| State | Readout |
|---|---|
| Off | "Off" (`labelColor`, as every state: the word says the state, and text is never faded; `tertiaryLabelColor` read 2.5:1 on the dark card) |
| Standard | "Standard" |
| Boosting at a preset, calibrated, SDR white trusted | "Bright room · ×1.29 · ≈ 775 nits" |
| Boosting at a preset, calibrated | "Bright room · ×1.29" |
| Boosting, not calibrated | "Bright room · ≈ ×1.29" |
| Between presets | "×1.42" (+ " · ≈ 852 nits" when known; "≈ ×1.42" when not calibrated) |
| Limited below the requested level | "×1.21 · asked ×1.47" |
| Dimmed | "Dimmed · 25%" (light relative to Standard) |
| Preparing | "Preparing…" |

The multiplier is a light gain, formatted with one or two decimals by `FormatStyle` (locale decimal separator); nits are rounded to the nearest 5 and always prefixed "≈". The readout's help tag adds: "For the most light, turn your display brightness all the way up first; Overbright adds to it." and, while not calibrated, "Not calibrated: this is an estimate." with **Calibrate…** in the card's context menu and as a VoiceOver action.

**Allowed-now marker** (part of `BoostSlider`, §5.5): shows where the thumb will stop now, drawn over the thumb so it shows even where the thumb rests on it. Its help tag and VoiceOver custom content: "macOS allows ×1.55 now. This display can reach ×2.6 at most." (the second figure is the Peak ceiling at full brightness). It shows at a glance why the thumb cannot go further, and how much further the display could go.

### 5.7 Status chips

A chip appears **on its own line under the readout**, only when a **per-display** reason limits or prepares the display (reasons that apply to every display are the banner's, §5.8). Capsule, 20 pt high, padding 8, glyph (12 pt, semantic colour) + text (`chip`, `labelColor`) on a 15 % tint of the semantic colour; up to the card's inner width (280 pt), measured per language. App names inside a chip ("Paused: ‹App›") are middle-truncated to fit, with the full name in the help tag and VoiceOver. A chip is a **button**: click, Space or Return opens a small popover with one sentence of explanation and, where they exist, its actions (§12.2); Esc closes it and returns focus to the chip. The chip shows the first per-display reason in the policy order (ARCHITECTURE.md §6.1); "Preparing…" and "No extra range" come from the engine phase and win while they apply. The HDR-suppression chip (`hdrSuppressedByMacOS`, "Limited by macOS") is no longer shown (2026-10-20): macOS 27 asks the app to suppress HDR from launch while the boost works, so it hid the real limit; a boost that Safe caps says **Safe limit**, with the gear of §5.4 beside it, and a grant that really falls shows as the headroom chip.

### 5.8 Banners

At most one banner, between the header and the first card, for **a reason that applies to all displays** (a user pause, a conflict, Focus, heat, Low Power, battery, the schedule) or an attention state (a stop to prevent flicker, colours changed by another app): `card` fill tinted 10 % with the semantic colour, a 14-pt glyph, the sentence (`banner`) and at most one text button (§12.3: one action per banner). The sentence is never cut: the banner grows in height for a long translation while the card list below scrolls, and only an app name in it is middle-truncated (to 200 pt, as a chip does), with the full sentence in the help tag and VoiceOver. Banners reflect state, so they have no close button; they leave with `bannerOut` when the cause clears, and the next reason in precedence takes their place. The same sentence is the first line of the right-click menu (§4.3), there with the app name in full. Precedence and exact copy: §12.3.

### 5.9 Footer guard chips

Three menu chips (`GuardChip`, 24 pt high, 6 pt apart, 6 pt of padding each side) in a 44-pt footer inset like the cards; each shows its **setting** (never a live value) and opens a short menu (also on Space or Return). They are shortcuts to the most-used Automations rows; Settings has the rest. Together they fit 304 pt, the cards' width, in every language, measured with their glyphs as they draw (`battery.25percent` is 21 pt wide); when they would not (a long translation, a running timer, the widest settings, the default row with "Auto-pause · Off" in English, below), they drop to glyph + value one at a time, the timer first, then Auto-pause, the battery last, since its "20 %" alone reads as a battery level (WP14: a Russian countdown dropped all three at once), and as a last resort to their glyphs. VoiceOver reads each chip's name as its label and its setting as its value, once ("Battery limit, Below 20 %"). As built (WP14): the earlier 292-pt budget was checked with 12-pt glyphs and 10-pt text, so the drawn English default row (296 pt) dropped to glyph + value, where "20 %" read as a battery level; measured as drawn, the row takes the cards' 304 pt with 6-pt chip padding, and the longest translations were reworded to fit.

| Chip | Label (state) | Menu |
|---|---|---|
| Battery (`battery.25percent`) | "Below 20 %" (pause below a level) / "Adapter only" / "Any charge" | ✓ Pause Below a Level · Pause on Battery · Keep Boosting · ─ · Battery Level ▸ 10 % · 20 % · 30 % · 50 % (the current value is inserted with a checkmark when it is not one of these; Settings offers 5–95 %) |
| Auto-pause (`play.rectangle.fill`) | "Auto-pause" (any rule on) / "Auto-pause · Off" (the default since 2026-10-20: every rule ships off, §7.5) | Pause for Full-Screen Video · Pause for Every Full-Screen App · Pause for Apps in the List (a checkmark on each rule that is on; none by default) · ─ · Edit Apps… |
| Timer (`timer`) | "No timer" / "Off in 23 min" (counting down) | Turn Off After ▸ Never · 15 Minutes · 30 Minutes · 1 Hour · 2 Hours (plus the current value when it is another one; Settings offers 5 minutes to 2 hours) |

"Pause for Apps in the List" is the list's master switch (`automations.pauseForListedApps`); turning it off keeps every rule. On Macs without a battery the Battery chip is not shown.

As built (2026-10-20): with every Auto-pause rule off by default the default row reads "Below 20 %" · "Auto-pause · Off" · "No timer", 311 pt in English, wider than the cards' 304, so the rule above drops the timer to its glyph first (262 pt) and the battery and Auto-pause keep their words; in every shipped language the default row keeps the battery's words at least, and the row with Auto-pause on ("Below 20 %" · "Auto-pause" · "No timer", the old default) still shows all its words (`FooterFitTests`). VoiceOver reads the default chip as "Auto-pause, Off".

### 5.10 Displays that cannot be boosted or dimmed

Displays with neither a boostable nor a dimmable verdict (virtual displays, reference presets) collapse into one line under the cards: "1 display can't be adjusted · Why?" (pluralised). "Why?" expands it in place (`expand`) into one row per display: name, the verdict sentence (§12.1) and its fix (an **Open System Settings** button when the fix is in System Settings, **Settings for this display…** when it is in Overbright) and a **Learn more** link that opens the Help window at the matching answer. Displays that can dim but not boost (an SDR external, HDR off, a MacBook Air) show a full card with the boost half disabled, the verdict sentence as the boost half's help tag, and the verdict badge as a `neutral` chip ("HDR is off") whose popover holds the sentence and its fix.

### 5.11 Empty and edge states

| Situation | Panel shows |
|---|---|
| No display can boost | The banner-less panel with each display's card (dim-only cards where dimming works), the "Why?" line expanded for the rest, and the sentence "None of your displays can show extra brightness right now." above the cards |
| Overbright off | Cards with their sliders (moving one turns Overbright on), readouts "Off", boost fills drawn with `inactiveHatch`, no chips, no marker |
| Paused (by you, or by a global guard) | The banner; cards at full opacity (text is never faded); boost fills with `inactiveHatch`; moving a slider ends a pause you set, while a guard pause stores the level |
| First arm of a display | Chip "Preparing…" with a small progress indicator; slider usable; readout "Preparing…"; the symbol `preparing` |
| Fill Light on | The Fill Light card above the display cards (§5.3) |
| Four or more displays | Three whole cards (their measured heights) and a 24-pt faded peek of the next, the rest scroll; when the panel's height cap binds, the list gives way first so the footer always shows |
| Locked or asleep | (the panel cannot be open) |

### 5.12 Keyboard

| Keys | Action |
|---|---|
| Tab / ⇧Tab | master switch → for each card: its slider, its chip, its Turn on → "Why?" (then its fix buttons and Learn more links when expanded) → banner buttons → footer chips → the Fill Light card's controls (when shown) → "⋯" |
| ↑ / ↓ | previous / next card's slider |
| ← / →, ⌥← / ⌥→, Home, End | slider (§5.5); ← / → also step the Fill Light card's sliders |
| ⌃↩ | the focused card's context menu |
| Space | toggles the focused switch, or opens the focused chip's popover, footer chip's menu, the "⋯" menu or the Fill Light card's display pop-up (the same rows as an AppKit menu at the control) |
| Return | the focused button, chip or "Why?" (no panel button is a default button: Return never runs one that has no focus) |
| Esc | closes an open popover or menu (focus returns to its chip), else the panel |
| ⌘, | Settings |
| ⌘Q | Quit Overbright |
| ⌘W | close the panel |

A 2-pt accent focus ring, concentric (radius + 3, outset 3), shows only after keyboard interaction; the system focus effect is disabled on the same elements so rings never double. A test walks this Tab order with every element present.

### 5.13 States gallery (snapshot names)

Every state below is a named status in PanelUI's `ScriptedStatuses` (`--qa-state <name>`, ARCHITECTURE.md §8.5; in the app the state's levels, switches, links, calibration records, Fill Light and "Why?" row come with it, so its thumbs and HUD bars agree with its readouts) and has a snapshot in Light, Dark and Increase Contrast: in English and a pseudo-long locale while the UI is built (WP10), in Russian once WP15 has translated it, and in all 35 languages for the fit tests. Fixtures from ARCHITECTURE.md §3.9.

| Name | Shows |
|---|---|
| `off` | two cards, readouts "Off", hatched boost fills, no chips |
| `standard` | on, both at Standard |
| `boosting` | built-in at Bright room, calibrated, no nits (SDR white unknown) |
| `boosting-uncalibrated` | the same before calibration: "Bright room · ≈ ×1.29" |
| `boosting-nits` | MSI at Sunlight with a trusted SDR white and a calibration ("≈ 400 nits") |
| `limited-by-macos` | outdoors: requested ×1.67, applied ×1.55, chip "Limited by macOS", marker short of the thumb's target |
| `safe-limit`, `safe-limit-hdr-external`, `safe-limit-oled` | at Max in Safe, the class-specific popovers |
| `small-gain` | OLED in Safe: only Bright room and Max shown, value tag "· small gain on this display" |
| `below-full-brightness` | the taper binds: chip "Below full brightness" |
| `preparing` | first arm, chip "Preparing…", symbol `preparing` |
| `no-extra-range`, `still-no-extra-range` | failed ladder, first and after two tries (Self-Test, Help link) |
| `dimmed` | built-in at "Dimmed · 25%", dim fill |
| `extra-brightness-off` | an opt-in HDR external: hatched boost half, chip with Turn On |
| `linked` | two cards with link glyphs moving together |
| `banner-battery`, `banner-low-power`, `banner-heat`, `banner-paused`, `banner-focus`, `banner-schedule` | each global banner with its buttons, and no chips repeating it |
| `heat-cap` | chip "Limited by heat" |
| `conflict-booster`, `conflict-color-app` | banner with an app name (long name and right-to-left name variants) |
| `conflict-may-interfere` | the S3 info chip |
| `flicker-stop`, `foreign-table` | danger banners |
| `full-screen-video`, `full-screen`, `paused-app`, `oled-idle` | per-display pause chips while the other display boosts; `paused-app` with a long app name, middle-truncated |
| `why-expanded` | a virtual display in the expanded "Why?" rows |
| `nothing-capable` | the empty state with the dim-only cards |
| `two-identical-externals`, `long-russian-name` | name handling in the title |
| `fill-light-card` | the Fill Light card with its sliders |
| `calibration-tip` | the one-time tip card |
| `four-displays` | scrolling card list |
| Menu bar and windows: `menubar-hidden` (the icon-not-visible window and the Settings warning row), `move-to-applications` | §4.4 |
| HUD: `hud-boost`, `hud-dim`, `hud-standard`, `hud-off`, `hud-preparing`, `hud-blocked`, `hud-two-displays`, `hud-automation-timer`, `hud-automation-battery`, `hud-automation-low-power`, `hud-automation-heat`, `hud-automation-schedule`, `hud-automation-back`, `keep-level` | §6 |

---

## 6. HUD and the Keep-this-level prompt

- **When:** (1) the level or on/off state changes through a **global shortcut, the Shortcuts app, a Focus filter or Back to Standard**; (2) a turn-on from the **icon, a shortcut or the Shortcuts app** is not ready within 0.5 s ("Preparing…"); (3) a requested change is blocked by a guard; (4) an **automation stops, caps or resumes** extra brightness on a visible display: the timer ends, the battery threshold or "on battery" applies, Low Power Mode, heat, the schedule boundary, and the return when the cause clears. **Never** for changes made in the panel, the menu or Settings (they show their own state), and never for full-screen, app or game pauses, which the user caused. General ▸ "Show level changes on screen" turns the HUD's window off; VoiceOver still hears every change it would show (§15: a global shortcut has no other non-visual feedback), also while the Keep-this-level prompt holds the HUD's place. Back to Standard shows from every source, the Dock menu's included.
- **Where:** horizontally centred on the display whose level changed (the display under the pointer for "all"), 64 pt above the bottom of its visible frame (above the Dock), clear of the system's own brightness indicator and notification banners.
- **Geometry:** 280 × 56 pt, `Radius.hud`, material per §2.4.
- **Content:** leading glyph 20 pt (`sun.max.fill` boosting, `sun.min` dimmed, `sun.max` Standard or off, `hourglass` preparing, `pause.fill` blocked or paused, `thermometer.medium` heat); centre: the display name (`hudLabel`, only with two or more displays) above a 150-pt level bar drawn like the slider (detent mark, `dimFill` left, `boostWarm` right, no thumb, the theme's palette); trailing value (`hudValue`) in canonical units: "Bright room · ×1.29", "×1.42", "Standard", "Dimmed · 25%", "Off". As built (WP14): the name has its own line above the value and the bar (the full 200 pt, middle-truncated only beyond it); value and bar show the level the display is set to — the panel's thumb — at once, never the lagging on-screen state; a turn-on's "Preparing…" line stays until the display is ready (at most 3 s), then the level reached shows for 1.5 s.
- **Reasons:** for (2)–(4) the bar is replaced by one line (`hudLabel`, exact copy §12.9): "Preparing…", "Paused: battery below 20 %", "Off: timer ended", "Limited: Mac is warm", "Extra brightness is back", …
- **Timing:** `hudIn`, stays 1.5 s after the last change (3 s for automation reasons), `hudOut`. A new change updates the visible HUD; there are never two.
- **Never** activates, takes clicks or appears in screenshots where macOS honours `sharingType = .none`.
- **VoiceOver:** the same text posted as an announcement ("Bright room, 1.29 times"; "Off: timer ended"), not rate-limited for the user's own changes, at most one per 10 s for automations.

**Keep this level?** (the owner's rule, 2026-10-20; ARCHITECTURE.md §4.9.) **Every level change a person makes away from Standard** (the panel, the menu, a shortcut, the Shortcuts app or Settings; boosting and dimming alike) puts a prompt in the HUD's place **on the display whose control moved**: "Keep this level?" / "Going back in 10 s" (counting down) with **[Go Back]** and **[Keep]**. Turning Overbright on with a level away from Standard stored asks too (from the panel, the menu, a shortcut, the Shortcuts app, Settings, Welcome, a Focus filter, the status item or a login launch). It can become key (Return = Keep, Esc = Go Back) and is excluded from capture. Go Back, or no answer within 10 s, returns the display to **Standard** (not to the level before the change): how a boosted table looks depends on each panel and macOS release, so a screen that turns white or dark comes back by itself even when the prompt cannot be read. While the slider keeps moving the 10 s start again from the last step, and the prompt restarts its countdown in place (it is not presented or announced again, so the slider keeps the pointer). Moving back to Standard ends the question. Automations, Focus and the launch behaviour never ask when they only move a level. VoiceOver announces "Keep this level? Going back in 10 seconds." This replaces the very-dark rule (below 10 % of Standard light) and the first boost per macOS build.

**Kept levels are not asked again** (2026-10-21; ARCHITECTURE.md §4.9). Each display remembers the range a person already kept on it: up to the brightest boost and down to the darkest dim kept, together with the macOS build and the trigger method in use at the time. A change within that range, or turning on with a level inside it, asks nothing; only going brighter than the kept boost or darker than the kept dim asks, and Keep then widens the range. After a macOS update, or when Overbright settles on a different trigger method for that display, the range is forgotten and the next change asks again, because either can change how a level looks.

---

## 7. Settings window

### 7.1 Structure

- **Window:** an AppKit `NSWindow` hosting a SwiftUI `NavigationSplitView` (Cranny's architecture: we must open any pane from an agent app, a chip, a banner or an intent). Default 860 × 620, minimum 780 × 560; size and last pane restored. Sidebar 190–260 pt (default 210) with `.searchable(placement: .sidebar)`. Follows Light/Dark; on macOS 26+ the sidebar and toolbar get Liquid Glass from AppKit and we add none. ⌘Q quits Overbright, ⌘Z undoes Reset All while the window is open.
- **Sidebar rows:** a 20 × 20 rounded square (radius 5) with a white glyph on a system colour, as in System Settings.

| Pane | Icon | Contents |
|---|---|---|
| General | `gearshape.fill` / gray | startup, menu bar (with Quit), Dock, feedback, updates |
| Displays | `display` / blue | all displays (same level, near full brightness); one section per display: verdict, extra brightness, level, limit, calibration, type |
| Automations | `bolt.fill` / green | battery, Low Power, heat note, timer, apps and video, schedule, OLED idle, Focus |
| Shortcuts | `keyboard` / indigo | recorders, step size, Shortcuts app and Control Center |
| Fill Light | `person.crop.rectangle` / orange | preview, switch, display, width, warmth, brightness, camera rule |
| Advanced | `wrench.and.screwdriver.fill` / gray | diagnostics, self-test, other apps, trigger method, recovery, Reset All with Undo |
| About | `info.circle.fill` / gray | version, updates, licence, acknowledgements, privacy, Show Welcome |

### 7.2 Conventions (Cranny's, carried over)

- `Form { … }.formStyle(.grouped)`; `Toggle` with `.switch` and `.controlSize(.small)`; segmented pickers for ≤ 4 options, pop-ups otherwise; sliders always show their value with its unit and ticks at meaningful stops. As built (WP14): Settings' sliders (Fill Light's Width, Warmth and Brightness) have no stop worth a tick, so they draw none (a tick per step put 27 dots under Width); the value settles on whole steps, every track has the same width, and words for the ends sit under the track (Cool · Warm).
- Every non-obvious row has a one-line footnote in `.secondary`.
- A 6-pt accent dot before the label marks a changed value; every row with a value has **Reset to Default** in its context menu; every pane footer has **Reset ‹Pane›…** (confirmation §12.9); Reset All is in Advanced, destructive, confirmed, and undoable until the window closes.
- **Search** matches pane names, row labels and keywords ("HDR", "XDR", "nits", "brighter", "dim", "battery", "shortcut", "camera", "login", "OLED", "flicker", "colors", "quit"); a result opens the pane, scrolls to the row and highlights it with an accent wash fading over 1 s. Deep links `pane#row` serve chips, banners, the menu and Help. As built (WP14): the index is rebuilt as soon as a row appears or goes with a setting or app state (From / To, Battery level, OLED idle, the icon warning), and a row that acts when linked to (Run Self-Test… opens its sheet) acts only for a deep link, never for a search hit.
- Push buttons and sheet/alert buttons are title case (AppKit chrome); row labels and footnotes are sentence case. Buttons follow the destination rule of §16.

### 7.3 General

| Row | Control | Default | Options / range | Footnote |
|---|---|---|---|---|
| (warning, only while the icon is not visible) | `warning` row: "Overbright's icon isn't visible." + **Open System Settings** | — | — | the sentence of §4.4 |
| **Startup** | | | | |
| When you log in | radio group | **Open Overbright, keep it off** | Open Overbright and turn it on · Open Overbright, keep it off · Don't open Overbright | "After a restart, nothing gets brighter until you turn Overbright on, unless you choose the first option." While approval is pending: "macOS needs your approval in Login Items settings." + **Open System Settings** |
| **Menu bar** | | | | |
| Show menu bar icon | switch | on | — | "When it's hidden, open Overbright from Finder or Spotlight to see Settings." Turning it off asks first (§4.4). |
| Clicking the icon | segmented | **Opens the panel** | Opens the panel · Turns Overbright on or off | "Right-click or Control-click the icon for the menu." |
| Show in Dock | switch | off | — | "Adds a Dock icon with a menu." |
| Quit Overbright | push button **Quit Overbright** | — | — | "Your displays return to Standard. Open Overbright again from Finder or Spotlight." |
| **Feedback** | | | | |
| Show level changes on screen | switch | on | — | "When you use a shortcut, the Shortcuts app or a Focus, and when Overbright pauses or resumes on its own." |
| Haptic feedback | switch | on | — | "On a Force Touch trackpad, at Standard and at each preset." |
| **Updates** (only when a repository is configured) | | | | |
| Check for updates automatically | switch | off (or the Welcome choice) | — | "Overbright asks GitHub once a day. Nothing else is sent." |
| Include pre-releases | switch | off | — | — |
| Check Now | button + inline result | — | — | "Overbright is up to date." / "Overbright 0.2.0 is available." + **Download…** / the error line |

### 7.4 Displays

**All displays**

| Row | Control | Default | Footnote |
|---|---|---|---|
| Same level on all displays | switch | off | "Moving one slider moves the others. Each display still stops at its own limit." |
| Add extra brightness only near full brightness | switch | **off** (on before 2026-10-20) | "Extra brightness fades out as you lower the display brightness, so the brightness keys keep their normal range. Turn this off to multiply any brightness." Off by default since the taper cut the owner's boost to ×1 (a reference measured while the grant still ramped; ARCHITECTURE.md §5.4); its reference is now never below the panel's own full-brightness headroom. |

**One section per connected display** (header: the display name and a verdict badge, §12.1):

| Row | Control | Default | Options / range | Footnote |
|---|---|---|---|---|
| (verdict) | sentence + fix button | — | — | §12.1 |
| Use extra brightness on this display | switch | built-in XDR and Apple XDR displays on; other HDR and OLED displays off | — | "Dimming below the minimum works either way." OLED: turning it on shows the OLED notice (§12.4). Hidden for displays that cannot boost. |
| Level | `BoostSlider` + readout | Bright room | −1 … 1 | — |
| Limit | segmented | **Safe** | Safe · Peak | The class-specific Safe sentence of §12.2 (`safeLimit`), then "Peak goes up to what macOS allows; it uses more power, and macOS may lower it when the display gets warm." A switch to Peak confirms (§12.4). As built (WP14): every switch from Safe to Peak asks, because ARCHITECTURE.md §3.8 keeps no record of an earlier answer; asking only the first time waits for a settings key through the contract lane (ARCHITECTURE.md §10.13). |
| Calibration | value + **Calibrate…** | Not calibrated | Not calibrated · Standard curve (macOS 27.0.1) · Linear (macOS 27.0.1) · Check again: macOS, the preset or the method changed | "A one-minute check that makes the numbers exact and lets Overbright use the right amount of range on this display." |
| Display type (externals) | pop-up | Automatic | Automatic (OLED) / Automatic (not OLED) · OLED · Not OLED | "OLED displays get a lower Safe limit and pause extra brightness when idle." |
| (advisory, built-in XDR on macOS 26+) | info row | — | — | "Keep Automatically adjust brightness as it is while extra brightness is on. Changing it then can leave the picture wrong until you change the display preset." |

**Not connected:** remembered displays with their last name and **Forget**.

### 7.5 Automations

| Row | Control | Default | Options / range | Footnote |
|---|---|---|---|---|
| **Power** | | | | "These limits stop extra brightness only. Dimming below the minimum always works, because it saves power." |
| On battery | pop-up | **Pause below a battery level** | Pause below a battery level · Pause on battery · Keep boosting | — |
| Battery level | pop-up (shown with the first option) | **20 %** | 5–95 % in steps of 5 | — |
| Pause in Low Power Mode | switch | on | — | — |
| Now | read-only | — | "Battery 64 %, on battery" / "On power adapter" | live |
| Heat | read-only note | — | — | "Overbright limits extra brightness when your Mac gets warm and turns it off when it gets hot. This can't be turned off." |
| **Timer** | | | | |
| Turn off after | pop-up | **Never** | Never · 5, 10, 15, 20, 30, 45 minutes · 1 hour · 1.5 hours · 2 hours | "Counts from when you turn Overbright on." |
| **Apps and video** | | | | |
| Pause for full-screen video (beta) | switch | **off** (on before 2026-10-20) | — | "Pauses while an app plays video full screen on that display, including browsers." |
| Pause for every full-screen app | switch | off | — | "Includes documents and games, not just video." |
| Pause in games | switch | off | — | "Apps that macOS knows as games, while in front." |
| Pause for these apps | switch + list | **off** (on before 2026-10-20); 12 apps | add · remove · mode per app | "Only the display that shows the app pauses." |
| (each app row) | icon, Finder name, pop-up, remove button | QuickTime Player, TV, IINA, Infuse, VLC, Plex (×2): **While playing (beta)**; Photos, Final Cut Pro, DaVinci Resolve (×3): **While in front** | While in front · While playing (beta) | "While playing" pauses while the app keeps your Mac awake for video. An app no longer installed reads "App not installed" and can still be removed. |
| (add) | **+** menu (VoiceOver and help tag: "Add App") | — | apps that are running · Choose… · Suggested ▸ (installed video apps, Prime Video, Infuse Enterprise, GeForce NOW, Moonlight) | — |
| **Schedule** | | | | |
| Only allow extra brightness at set times | switch | off | — | "Outside these hours Overbright stays at Standard. Dimming still works." |
| From / To | time pickers | 08:00 / 20:00 | any minute (the same minute in both is the whole day, never no hours) | — |
| **OLED displays** (only when one is known) | | | | |
| Pause extra brightness after no input for | pop-up | **5 minutes** | 1 · 2 · 5 · 10 · 15 · 30 minutes | "Video that keeps your Mac awake doesn't count as no input." |
| **Focus** | | | | |
| (info) | text + **Open System Settings** | — | — | "Choose what Overbright does in each Focus in Focus settings: leave it alone, turn it off, or turn it on at a level." |

**Apps and video starts off** (the owner's rule, 2026-10-20): every row of the section ships off, so nothing pauses extra brightness on its own except the Power and Heat guards (and the OLED idle pause on an OLED) until the user turns a rule on, here or in the panel's Auto-pause chip (§5.9). The list keeps its 12 suggested apps and their modes for when its switch is turned on; Welcome step 3 shows Pause for full-screen video off too (§8).

### 7.6 Shortcuts

Key caps in this pane, in the menu and in all copy are rendered from the live binding in the current keyboard layout (§16). **No shortcut is bound by default** (the owner's rule, 2026-10-20; ARCHITECTURE.md D17): every recorder reads "Record Shortcut" and nothing is registered with macOS until the user records a combination; Reset to Default clears a row again. The menu shows no key equivalents (§4.3), Welcome step 4 no key caps (§8), Help answer 3 its no-shortcut sentence (§12.6) and the hidden-icon alerts leave out their shortcut clause (§4.4) until then. Before 2026-10-20 five shipped bound (⌃⌥⌘B, ⌃⌥⌘=, ⌃⌥⌘-, ⌃⌥⌘0, ⌃⌥⌘9, US key caps); they are still free of macOS shortcuts and are what the tests bind (`SampleShortcuts`).

| Row | Default | Footnote |
|---|---|---|
| Turn Overbright on or off | none | — |
| Brighter | none | — |
| Less Bright | none | "Stops at Standard first; press again to dim below it." |
| Max | none | — |
| Dim Below Minimum On or Off | none | "Dims every display to your last dim level, or brings them back." Shown as "Dimmed" in the menu and the HUD. |
| Back to Standard | none | "Turns Overbright off at once, from anywhere. Your levels are kept for next time." |
| Fill Light | none | — |
| Step size | segmented: **Regular** · Fine | "Each press of Brighter or Less Bright changes the light by about a fifth (Regular) or about 6 % (Fine)." |

- **Recorder** (the owner's own, from Cranny): click a row to record; Esc cancels; Delete clears; one recorder at a time; every hot key pauses while recording; while it listens VoiceOver's value is what the button shows ("Type Shortcut"), and a key without Command, Control or Option shows "Add Command, Control or Option" and announces it, with no sound (§13.3; as built, WP14); conflict lines in place: "Another app already uses this shortcut.", "Already used for Brighter.", "macOS uses this for ‹name of the system shortcut›." Clearing **Back to Standard** asks first: "Without this shortcut, use Turn Off Overbright in the menu or the panel. It does the same, a little more slowly." [Clear Shortcut] [Cancel]
- **Shortcuts app and Control Center:** "Overbright's actions are in the Shortcuts app: turn it on or off, set extra brightness, dim, pause, and more." **Open Shortcuts**. In builds without the control: "To put Overbright in Control Center or the menu bar, make a shortcut with Turn Overbright On or Off, then add Control Center's Run Shortcut control."

### 7.7 Fill Light

A preview at the top: a 200 × 125 pt miniature of the chosen display with the frame drawn to scale in the chosen warmth (an SDR approximation).

| Row | Control | Default | Range | Footnote |
|---|---|---|---|---|
| Fill Light | switch | off | — | "Lights your face on video calls with a glowing frame around the screen." |
| Display | pop-up | Built-in Display (else the main display) | connected displays | — |
| Width | slider + value | **48 pt** | 16–120 pt | — |
| Warmth | slider + value, "Cool" and "Warm" under the track's ends | **5,100 K** | 6,500–3,000 K | — |
| Brightness | slider + value | **80 %** | 20–100 % | "Uses the display's extra range when it has one, so the light can be brighter than white." |
| Turn on while a camera is in use | switch | off | — | "Turns off a few seconds after the camera stops." |
| Cameras | pop-up | Any camera | Any camera · Built-in and USB cameras only | "Virtual cameras and iPhone cameras count as Any camera." |
| (note) | — | — | — | "Fill Light is left out of screenshots where macOS allows. Some screen-sharing apps may still show it." |

### 7.8 Advanced

| Row | Control | Default | Footnote |
|---|---|---|---|
| **Diagnostics** | | | |
| Copy Diagnostics | button | — | "Copies a technical report to the clipboard. Nothing is sent anywhere." |
| Run Self-Test… | button | — | "Checks how each display responds. About a minute per display." |
| Detailed logging | switch | off | "Adds headroom samples to the system log for troubleshooting." |
| **Other apps** | | | |
| Apps that change display colors or brightness | live list: icon, name, kind ("Brightness app", "Color app", "May change brightness") and, for color apps and "may change" apps, an **Always continue** switch | — | "None running." when empty. |
| **Trigger method** | | | |
| (one pop-up per display) | Automatic · Tagged layer · Metal layer · Metal layer, refreshed · HDR frame · HDR video still | Automatic | "Automatic finds the lightest way to unlock extra range on each display and remembers it." Unavailable methods are disabled with the reason. |
| Forget Learned Methods | button | — | — |
| **Recovery** | | | |
| Reset Display Colors… | button | — | "Use this if colors look wrong after another app quit." Confirms first (§12.4). |
| (note) | — | — | "If Overbright ever stops responding, Force Quit it. macOS restores your displays at once." |
| **Reset** | | | |
| Reset All Settings… | destructive button | — | Confirms first; afterwards an **Undo Reset** button stays here until the Settings window closes, ⌘Z works too, and a banner "All settings were reset." [Undo] shows for 10 s |

### 7.9 About

The compiled icon, "Overbright", version and build; **Check for Updates** with the result inline (only when configured); "Free and open source under the MIT License."; **Acknowledgments…** (THIRD_PARTY_NOTICES; American spelling, as built and as §16's voice); the privacy statement: "Overbright collects nothing and needs no permissions. It connects to the internet only to check GitHub for updates, and only if you turn that on."; **Show Welcome…**; **Help**; a GitHub link (only when configured).

---

## 8. Welcome

- **Window:** 640 × 480, hidden title bar, not resizable, centred on the main display. The top half is a stage (the before/after card or an illustration), the bottom half holds copy and controls on the system background. Progress dots plus "Step 2 of 5" for VoiceOver; ↩ continues, ⌘[ goes back, Esc asks "Skip setup?" (the close button counts as Skip). A **Quit Overbright** text button sits bottom-leading on every step.
- **Layout (as built, WP14):** one split on every step: the stage on top, a divider, the headline and body, then the step's controls. Steps 1, 4 and 5 have the full stage (the card or illustration, the menu bar and key caps, the app icon); steps 2 and 3, whose controls need the room, a compact stage: a band of glyphs (one per display; the battery, Low Power Mode, full-screen video and heat), so the headline always sits at the stage boundary and introduces the controls under it. The progress dots show on every step, in the centre of the window whatever the widths of the button groups: in the footer row while the buttons leave the centre free, else centred on their own line just above the row (the last step with Turn On Overbright in most languages, whose page is that line shorter).
- **Skip** (and closing the window) applies every default, including the login item ("Open Overbright, keep it off", registered with `SMAppService.mainApp`). **Done** applies the choices of step 3. As built (WP14): Skip drops every choice made in Welcome and registers the default login item also on a later Welcome opened from Settings ▸ About; the other settings Welcome shows are at their defaults on a first run, and a later Skip leaves them as Settings holds them (resetting them is Reset All's job, §7.8).
- Shown at the first launch that is not a login launch (after the launch check and the move-to-Applications offer) and from Settings ▸ About; never again once finished or skipped.

| Step | Headline | Body (exact English) | Stage and interaction |
|---|---|---|---|
| 1 Hello | Use your display's extra range | "Your display can show light brighter than ordinary white. Overbright lets everyday content use that range, so the screen stays readable in a bright room or in sunlight. For the most light, turn your display brightness all the way up first; Overbright adds to it. Drag the divider to compare." | **Before/after card:** a sample page (text on white) at Standard on the left and at Bright room on the right of a draggable divider (the card is a Tab stop: ← / → move the divider 10 %, mirrored right to left), rendered as EDR content inside this window only (`EDRPreviewSurface`). Caption: "Only this card is brighter. It's a preview: the real result depends on your display." Without a capable display: a static illustration and "None of your displays has extra range right now. The next step shows why." The card shows only the light of the display the window is on: when that display cannot show extra brightness while another can, the illustration and "This display has no extra range right now. Move this window to another display to compare." (as built, WP14). The card pauses while the window is hidden. |
| 2 Displays | Your displays | "Overbright checks what each display can do." | One row per display: glyph, name, verdict (§12.1), fix button, **Use extra brightness** switch (OLED notice when turned on); when the name and the switch do not fit one line, the switch goes on its own line under the name. The rows re-evaluate whenever the displays change (for example after HDR is turned on in System Settings) and cross-fade (`contentSwap`). |
| 3 Defaults | How Overbright behaves | "Extra light uses more power, so Overbright steps back on its own. Choose how it starts." | Under the copy, switches: **Pause on battery below 20 %** (with the level pop-up), **Pause in Low Power Mode** (both on), **Pause for full-screen video** (off since 2026-10-20, §7.5); note: "It also backs off when your Mac gets warm." Then three option cards for login: **Open and turn on** · **Open, keep off** (selected, "Recommended") · **Don't open at login**. |
| 4 Find it | Where to find Overbright | "Overbright lives in the menu bar." | Rows: the menu bar symbol ("Click for the panel, right-click for the menu"); key caps of the live **Turn on or off**, **Back to Standard** and **Dim Below Minimum On or Off** shortcuts in the current keyboard layout (rows without a registered shortcut are left out, so a first run, where none is bound (§7.6), shows the menu bar and its caption alone, and a later Welcome from Settings ▸ About shows the ones the user recorded); "Shortcuts app and Control Center" with the Run Shortcut recipe; "Open Overbright again from Finder or Spotlight to see Settings." |
| 5 Done | You're set | — | A summary of step 3's choices that Done applies, in step 3's words and glyphs: the pause rules that are on, then "When you log in" and the chosen card. **Check for updates on GitHub** switch (off; only when configured); buttons **Turn On Overbright** (primary; hidden when no display can boost) and **Done**. |

The calibration check is not part of Welcome: it asks for changes that are unsafe while boosted and only makes sense once extra brightness is in use. It is offered once, as the calibration tip card, after the first boost (§5.3).

**As built (WP12, confirmed by the contract owner in WP14).** Four details settled differently from the window's half-height stage and the table above, each kept:
- **Step 2 has a compact stage.** A band of display glyphs, one per display, instead of the half-height stage; the headline sits at the band's lower edge, as on every step, and the rows follow it down to the footer, so two or three displays show at once (more scroll visibly in `DisplayRowList`). A half-height stage would leave room for barely one row. (WP12 built the step without a band, its rows as its stage; C-ONBOARD-1 gave it the compact band so every step has the same split, see Layout above.)
- **The rows are Welcome's own views over `DisplayCardModel`**, not PanelUI's `DisplayCardView`: step 2 shows a glyph, name, verdict, fix and switch, never a slider, and the model gives it the panel's own limit, switch default and top, so the two never disagree.
- **Done applies the choices of steps 2 and 3.** The "Use extra brightness" switches wait with step 3's choices; Skip and the close button drop them, so Skip still applies every default and nothing else.
- **Step 2 shows only one advisory,** OLED care (§12.1). "Not calibrated" would repeat on every row of a first run while calibration is not part of Welcome, and the auto-brightness advisory is Settings only (§7.4).

---

## 9. Calibration

A guided check per display, from Settings ▸ Displays, the card's context menu or the one-time tip. It answers two questions: does the screen really get brighter (or does macOS ignore table changes on this Mac), and does the table work on encoded values or on linear light. It also records an optional colorimeter reading.

- **Starting it returns every display to Standard first** (neutral tables, triggers removed) and holds Overbright off until it ends; the window then brightens only the display under test, step by step.
- **Window:** borderless, full screen on the display under test, our colour space set to the screen's so code values reach the framebuffer unchanged; a **black** surround; four **100 × 100 pt** patches; instructions in a dark card at the top (light text on near-black), so an over-bright moment lights only small areas. Esc always restores at once and closes. A display without a screen of its own (a mirror member) cannot be calibrated: the window opens as an ordinary titled window with "This display can't be calibrated right now…" and nothing brightens (as built, WP14); simulated displays (`--qa-simulate`) always use that titled window, with their scripted session.
- **Before starting** (a checklist with live state where we can read it): "Plug in your Mac" (power source) · "Set brightness to maximum" · "Overbright is at Standard now, so it's safe to change these: turn off Automatically adjust brightness, True Tone and Night Shift in Displays settings." (asked, cannot be read) · "No other color or brightness app is running" (live) · "Your Mac is cool" (thermal state, live). **Start** is enabled when the live items pass.
- **Step 1, Does it get brighter?** The display under test switches between Standard and ×1.3 three times, at most once per 1.5 s, with a label "Standard" / "Brighter"; VoiceOver hears each label as it changes (§15). Question: "Did the screen get brighter when the label said Brighter?" **Yes** · **No** · **Show Again**. **No** goes straight to the results: the record says the screen did not get brighter, and the color table stays (no other method to offer since 2026-10-20; ARCHITECTURE.md §7.5).
- **Step 2, Where does white stop?** The four patches at 85 %, 90 %, 95 % and 100 % grey. Overbright raises extra brightness in small steps every 0.4 s. "Watch the two squares on the right. Press Space the moment you can no longer tell them apart." At 1.15 × the point where they usually merge, the sweep pauses: "The two squares on the right usually merge before this point. Keep going?" **Keep Going** · **Stop**. The sweep ends at the latest at 1.15 × the linear prediction, and on Space, Esc, 60 s, any lock, occlusion or headroom drop; it always returns to Standard at once.
- **Step 3, One more check** (only when the merge was near the linear prediction): "For two seconds the squares are shown much brighter. Can you still tell the two squares on the right apart?" **Show** · then **Yes, They Look Different** · **No, They Look the Same** · **Show Again**. Only "Yes" can record the linear result; it is impossible to see a difference there if the table works on encoded values.
- **Decision** (ARCHITECTURE.md §5.2): a merge nearer the encoded prediction → "standard curve"; nearer the linear prediction **and** confirmed in step 3 → "linear"; anything else (unconfirmed, within 15 % of the midpoint, a sweep that ended without a mark: Space never pressed, the sweep reached its end) → "inconclusive", and the safe default stays. A run interrupted by a lock, occlusion, Esc, a headroom drop or the 60 s cap records nothing and an earlier result stays, unless it had already measured something: a No in step 1, a mark, or an answered confirmation (as built, WP14; ARCHITECTURE.md §11.1 #35).
- **Results (exact English):**
  - "Standard curve confirmed. Overbright keeps its default for this display."
  - "This display responds in linear light. Overbright can now use more of its range."
  - "The result wasn't clear, so Overbright keeps its safe default. You can try again."
  - After **No** in step 1: "The screen didn't get brighter, so Overbright keeps its safe default. Run Self-Test… in Settings ▸ Advanced shows what macOS reports."
  - Always followed by: "If you use Automatically adjust brightness, True Tone or Night Shift, turn them back on now, before you turn on extra brightness."
- **Colorimeter (optional disclosure):** "I have a colorimeter" reveals a field "SDR white: [ ] nits" (measured at Standard). A value makes the nits readout and the Safe cap exact for this display while the display shows the white it was measured at: as built (WP14), only while macOS's headroom stays within 5 % of the headroom at the measurement (macOS moves white with the brightness setting and the ambient light, and the headroom with it); otherwise, outdoors for example, the value is set aside and the readout and Safe behave as they do without one (ARCHITECTURE.md §5.5, §5.6's outdoor row). A value outside 20–4,000 nits (which the engine ignores) shows "Use a value from 20 to 4,000." under the field and holds **Start** (as built, WP14).
- **Validity:** stored per display with the macOS build, the method and the display's potential. When any of them changes, the result is no longer used (numbers become estimates again, "≈"), and the Displays pane shows "Check again: macOS, the preset or the method changed."

---

## 10. Self-test

A sheet from Settings ▸ Advanced or the panel's "⋯" menu.

- **Before:** "For about a minute per display, Overbright unlocks extra range and records how macOS responds. Your brightness doesn't change, but a tiny dot may appear in a corner of the display being tested. Keep your Mac awake and unlocked." Options: a checkbox per display; **Test every method** ("about 3 minutes per display"). **Run Self-Test** · **Cancel**.
- **While running:** "Built-in Display · Tagged layer, black · 12 s" with a determinate progress bar per display; **Stop** returns everything to normal at once. Overbright is held off for the duration.
- **Results:** a table per display: Method · Result (**Held** / **Dropped** / **No response** / **Already bright** / **Skipped**) · Response time · Steady time. "Already bright" means something else held extra range when the test began, so the method could not be judged. Summary line: "Built-in Display: Tagged layer works. It will be used from now on." (the cache is updated only from a clean pass).
- **Sharing:** **Save Log…** (JSON via a Save panel) · **Copy** · **Done**. "The log contains display models, the macOS version and measurements. It never contains your files, window titles or app names."

---

## 11. Fill Light

- **Look:** a frame around the chosen display, outer edge = the display's frame, inner edge a rounded rectangle inset by the width (inner corner radius `min(24, width)`); the top edge starts below the menu bar so menus stay usable (in a full-screen Space, where the menu bar hides, it reaches the top). Colour from the warmth (a black-body approximation, 6,500–3,000 K, in linear sRGB); brightness up to 2× white where the display has extra range (macOS 26+: a headroom-tagged layer colour; 14/15: a Metal clear), otherwise up to white.
- **Behaviour:** click-through; on every Space and over full-screen apps; excluded from screenshots where macOS honours it; ignored by the full-screen guard; it updates live while Settings or the panel card changes. On a boosted display it is boosted with everything else; it never makes Overbright misjudge the display's extra range (the engine counts it as range already in use).
- **Camera rule:** on 1 s after any matching camera starts, off 3 s after the last one stops; turning it off by hand while the camera runs keeps it off until the camera stops.
- **Entry points:** Settings ▸ Fill Light, the right-click menu, the panel's "⋯" menu, the Fill Light card in the panel while it is on, an optional shortcut.
- **VoiceOver:** not an element (decorative); state changes announce "Fill Light on" / "Fill Light off".

---

## 12. Copy catalogue (exact English)

Placeholders: ‹App› is `NSRunningApplication.localizedName` or Finder's name, bidi-isolated; ‹Display› is the display's name; ‹shortcut› is the live key caps of a shortcut in the current keyboard layout (§16); numbers come from `FormatStyle`. **Panel buttons (banners, chip popovers, cards) are sentence case; menus, Settings push buttons, sheets and alerts are title case.** Every string lives in a catalog with a `"<Surface>: <purpose>"` comment (ARCHITECTURE.md §8.8); the names and sentences of engine states live in Design's catalog.

### 12.1 Display verdicts (Settings ▸ Displays, Welcome step 2, the panel's "Why?" rows and dim-only chips)

The supported sentence quotes the display's current limit (Safe by default) and, once Overbright has seen one, the largest grant macOS gave; the potential-derived figure appears only in Advanced and diagnostics.

| Verdict | Badge | Sentence | Fix |
|---|---|---|---|
| `supported`, no grant seen yet | Supported | "With Safe, up to about 1.7× brighter at full brightness. Peak can go further when macOS allows it." (with Peak chosen: "With Peak, up to about 2.6× brighter at full brightness, when macOS allows it.") | — |
| `supported`, a grant seen | Supported | "With Safe, up to about 1.7× brighter at full brightness. macOS allowed up to ×1.55 on this display last time." | — |
| `supported`, Safe adds nothing (Studio Display XDR) | Supported | "Safe adds no extra brightness on this display, because its normal maximum already reaches the level it can hold across the whole screen. With Peak, up to about 1.9× brighter at full brightness, when macOS allows it." | Choose Peak… |
| `noGainAtFullBrightness` | Little gain | "At full brightness this display gains less than 10 %. Raising the display brightness gives the same result." | — |
| `panelFactsUnknown` (a boosting class whose panel peak or normal maximum no source gives; WP14) | Range unknown | "Overbright can't tell how much brighter this display can get, so it adds no extra brightness. You can still dim it below the minimum." | — |
| `presetLimits` | Limited by preset | "The current preset stops at about 600 nits. Choose a preset with a higher peak, such as 1600 nits, in Displays settings." | Open System Settings |
| `turnOnHDR` | HDR is off | "Turn on High Dynamic Range for this display in Displays settings to use extra brightness. This changes how everyday content looks on some displays. You can turn it off again at any time. You can still dim it below the minimum." | Open System Settings |
| `switchPreset` | No HDR in this preset | "This preset doesn't allow extra brightness. Choose a preset with a higher peak in Displays settings. You can still dim it below the minimum." | Open System Settings |
| `referencePreset` | Reference mode | "A reference preset is active. Overbright leaves reference modes as they are." | Open System Settings |
| `lcdClass` | Not supported | "This display has no extra brightness range. You can still dim it below the minimum." | — |
| `notHDR` | Not supported | "This display doesn't support HDR, so it has no extra range. You can still dim it below the minimum." | — |
| `mirrored` | Mirrored | "This display mirrors another one, so Overbright can only dim it." | — |
| `virtualDisplay` | Not supported | "Sidecar and AirPlay displays can't be adjusted." | — |
| `noGammaTable` | Not supported | "macOS doesn't let apps adjust this display." | — |
| `checking` | Checking… | "Overbright is reading this display." | — |

Advisories (a second line under the verdict): `oledCare` "OLED display: extra brightness stays lower and pauses after 5 minutes without input." · `autoBrightnessInteracts` (Settings only, §7.4) · `notCalibrated` (not in Welcome step 2, §8) "Not calibrated. Numbers are estimates, and Overbright uses a safe default."

As built (WP14), one row above is not what every display gets yet (a boosting class whose panel peak or SDR maximum no source gives reads `panelFactsUnknown`, "Range unknown", and no longer an unbacked "Little gain"; ARCHITECTURE.md §5.3, C-PLATFORM-3):
- **"macOS allowed up to … last time"** needs the largest grant macOS gave, which the engine keeps (`DisplayStatus.lastGrant`, WP14); Settings, Welcome and the panel do not pass it to the verdict yet, so every supported display reads the "no grant seen yet" sentence.

"High Dynamic Range", "Displays", "Automatically adjust brightness", "True Tone", "Night Shift", "Preset", "Menu Bar", "Allow in the Menu Bar", "Battery", "Focus" and "Login Items" are macOS's own names and must match macOS in every language (German: "Hochkontrastbild" for High Dynamic Range).

### 12.2 Status chips (panel, §5.7; per-display reasons only)

| Reason or phase | Chip | Glyph | Colour | Popover sentence | Actions |
|---|---|---|---|---|---|
| arming, gating | Preparing… | (progress) | info | "Overbright is unlocking extra range on this display. The first time takes a few seconds." | — |
| failed, no headroom (first) | No extra range | `exclamationmark.triangle.fill` | danger | "macOS didn't make extra range available. This can happen right after waking up, or when HDR is off." | Try again · Learn more |
| failed, after two tries in this session | No extra range | `exclamationmark.triangle.fill` | danger | "macOS still didn't make extra range available." | Try again · Run self-test… · Learn more (Help: "The screen didn't get brighter") |
| `boostNotEnabled` | Extra brightness off | `sun.max` | neutral | "Extra brightness is off for this display. Dimming still works." | Turn on |
| verdict of a dim-only display | its badge (§12.1) | `display` | neutral | its sentence | its fix |
| `headroom` | Limited by macOS | `sun.min` | info | "macOS allows ×1.55 right now. It lowers the extra range when the surroundings are bright, the display is warm or the battery is low." | — |
| `hdrSuppressedByMacOS` | Limited by macOS | `sun.min` | info | "macOS is limiting HDR right now." | — (never reported since 2026-10-20: ARCHITECTURE.md §6.1 row 19) |
| `nearFullBrightnessOnly` | Below full brightness | `sun.min` | info | "Extra brightness fades out as you lower the display brightness. Turn the brightness up for more." | Change setting… |
| `safeLimit` | Safe limit | `lock.fill` | info | the class sentence below, then "Choose Peak for more." | Choose Peak… |
| `oledLimit` | OLED limit | `lock.fill` | info | "Extra brightness stays at 1.3 times on OLED displays to protect the panel. Choose Peak for more." | Choose Peak… |
| `thermalSerious` | Limited by heat | `thermometer.medium` | warning | "Your Mac is warm, so extra brightness stays at 1.2 times until it cools down." | — |
| `fullScreenVideo` | Paused: video | `play.rectangle.fill` | neutral | "Extra brightness pauses while an app plays video full screen on this display." | Change rules… |
| `fullScreenApp` | Paused: full screen | `play.rectangle.fill` | neutral | "Extra brightness pauses while an app is full screen on this display." | Change rules… |
| `pausedApp` | Paused: ‹App› (middle-truncated) | `pause.fill` | neutral | "Extra brightness pauses while ‹App› is in front on this display." | Edit apps… |
| `game` | Paused: game | `gamecontroller.fill` | neutral | "Extra brightness pauses while a game is in front on this display." | Change rules… |
| `oledIdle` | Paused: idle | `zzz` | neutral | "Extra brightness pauses after 5 minutes without input on OLED displays. Move the pointer or press a key to continue." | — |
| `conflict` (S3, not blocking) | ‹App› may interfere | `exclamationmark.circle.fill` | info | "‹App› can change display colors in some modes. If it does, Overbright stops on this display." | — |
| `tripped` (flicker, repairs) | Stopped | `exclamationmark.triangle.fill` | danger | "Overbright stopped on this display to prevent flicker." | Try again |
| `tripped` (attributed drift) | Stopped: ‹App› | `exclamationmark.triangle.fill` | danger | "‹App› changed the colors of this display." | Continue anyway; none when ‹App› is a booster (S1: never Continue anyway, so two tables never compound, ARCHITECTURE.md §7.2) |
| `tripped` (foreign table) | Colors changed | `exclamationmark.triangle.fill` | danger | "Another app changed this display's colors in a way Overbright can't reset." | Open System Settings |

Reasons that apply to every display (a user pause, S1/S2 conflicts, Focus, heat that stops, Low Power, battery, the schedule) are never chips: the banner says them once (§12.3). A card also shows no chip for the reason the banner currently shows (a trip on that display).

**Safe sentences by class** (also the Limit footnote in Settings ▸ Displays); nits only with a trusted SDR white:

- Apple XDR panel, no SDR estimate (default): "Safe stays at the level this display can hold across the whole screen, ×1.67 here."
- Apple XDR panel with a trusted SDR white: "Safe stays at the level this display can hold across the whole screen, ×1.67 here, about 1,000 nits."
- Apple XDR panel in bright surroundings (the live bound is below the slider's top): "Safe stays at the level this display can hold across the whole screen. In bright surroundings macOS already shows white that bright, so Safe adds nothing now."
- Other HDR external: "Safe stays at ×1.40 here, about what this display can hold across the whole screen."
- OLED external: "Safe stops at 1.3 times on OLED displays."
- Studio Display XDR: "Safe adds no extra brightness on this display, because its normal maximum already reaches the level it can hold across the whole screen."
- If the hardware session switches Safe to its static top (ARCHITECTURE.md §5.4, `.sliderTopOnly`): "Safe stays at ×1.67 here."

Action destinations: "Choose Peak…" opens Settings ▸ Displays at the display's Limit row; "Change rules…" opens Automations ▸ Apps and video; "Edit apps…" opens the app list; "Change setting…" opens Displays ▸ Add extra brightness only near full brightness; "Learn more" opens the Help window at the answer.

### 12.3 Banners (panel, §5.8), highest precedence first

| Banner | Sentence | Buttons |
|---|---|---|
| user pause | "Overbright is paused until 14:20." | Resume |
| conflict, booster (S1) | "Paused because ‹App› also changes display brightness. Quit it to continue." | — (no action: never Continue anyway, ARCHITECTURE.md §7.2) |
| conflict, color app (S2) | "Paused because ‹App› changes display colors. Night Shift gives warm light without a conflict." | Continue anyway |
| foreign table at launch | "Another app changed the display colors and they couldn't be reset. Change the color profile or preset in Displays settings and back, or log out." | Open System Settings |
| flicker stop | "Overbright stopped on ‹Display› to prevent flicker." | Try again |
| unattributed drift | "Another app keeps changing the colors of ‹Display›, so Overbright stopped there." | Try again |
| attributed drift | "‹App› changed the colors of ‹Display›, so Overbright stopped there." | Continue anyway; none when ‹App› is a booster (S1: two tables never compound, ARCHITECTURE.md §7.2) |
| Focus | "Off because of the current Focus." | Open System Settings |
| heat | "Paused because your Mac is hot. Overbright continues when it cools down." | — |
| Low Power Mode | "Paused because Low Power Mode is on." | Change power rules… |
| battery | "Paused because the battery is below 20 %." | Change power rules… |
| on battery | "Paused while on battery." | Change power rules… |
| schedule | "Extra brightness is allowed from 08:00 to 20:00." | Change hours… |

The same sentence, with the app name in full, is the first, disabled line of the right-click menu, and its primary action the second line in title case ("Resume", "Continue Anyway", "Open System Settings", "Try Again", "Change Power Rules…", "Change Hours…").

### 12.4 Sheets and alerts (title-case buttons)

- **OLED notice** (turning on extra brightness for an OLED display, from the switch, Turn on, or the first move into the boost half) — "Use extra brightness on this OLED display?" / "Bright content that stays in one place for a long time, like the menu bar, can wear OLED panels unevenly. Overbright keeps extra brightness lower on OLED displays and pauses it after ‹OLED idle time› without input." [Turn On] [Cancel] (the configured Automations ▸ OLED displays time, 5 minutes by default, worded as Settings words it; the same in the panel, the menu, Welcome and Settings)
- **Switching to Peak** (every switch from Safe to Peak, as built in WP14: no setting records an earlier answer, §7.4) — "Use Peak on ‹Display›?" / "Peak lets the whole screen go above the level the display can hold for long. It uses noticeably more power and makes the display warmer; macOS lowers it when needed." [Use Peak] [Cancel]
- **Hide the menu bar icon** and **Overbright's icon isn't visible** — §4.4.
- **Move to Applications** (before Welcome, when launched from outside `/Applications`; asked again after an update if declined) — "Move Overbright to the Applications folder?" / "Shortcuts actions and opening at login work only from Applications." [Move to Applications] [Not Now] (Return moves, Esc is Not Now). Moving relaunches Overbright from its new place; an older copy there goes to the Trash. Failure: "Overbright couldn't be moved. Drag it to the Applications folder in Finder." [OK] (a failed move puts the older copy back from the Trash; a failed relaunch puts the bundle back, and the older copy too). If the moved copy can neither start nor go back: "Overbright is now in the Applications folder, but it couldn't be opened from there. Open it from the Applications folder in Finder." [OK], then this copy quits.
- **Reset display colors** — "Reset display colors?" / "Every display goes back to its color profile. This also clears changes made by other color apps." [Reset Colors] [Cancel]. Results inline: "Display colors reset." · "Display colors were already normal." · "Display colors reset. Some displays were set back to their color profile directly." · "Another brightness or color app is running. Quit it first." · "Some colors couldn't be reset. Change the color profile in Displays settings and back, or log out."
- **Reset all settings** — "Reset all settings?" / "Every Overbright setting returns to its default, including display calibration." [Reset All] [Cancel]; then the banner "All settings were reset." [Undo] for 10 s, and the **Undo Reset** button in Advanced until the Settings window closes.
- **Skip setup** — "Skip setup?" / "Overbright uses its defaults. You can see this again in Settings ▸ About." [Skip] [Continue Setup] [Quit Overbright]
- **Run self-test** — §10. **Clear Back to Standard** — §7.6. **Keep this level?** — §6. **Reset ‹Pane›** — §12.9.

### 12.5 Formats

| Thing | Format | Example (en / ru) |
|---|---|---|
| Multiplier | "×" + 2 significant decimals, locale separator | ×1.29 / ×1,29 |
| Multiplier, not calibrated | "≈ ×" … | ≈ ×1.29 / ≈ ×1,29 |
| Nits | "≈ " + number rounded to 5 + plural "nits" | ≈ 775 nits / ≈ 775 нит |
| Dim level | "Dimmed · " + percent of Standard light, `FormatStyle` | Dimmed · 25% / Затемнено · 25 % |
| Percent | the locale's percent format (`CopyFormat.percent`: `FormatStyle` percent, no decimals), never a literal "%" after a number | 25% in English; 25 % in Russian, German and French (as built in WP9: dim levels and battery levels in copy) |
| Temperature | `Measurement<UnitTemperature>` in kelvin | 5,100 K / 5 100 K |
| Durations | `Duration.UnitsFormatStyle` | 23 min / 23 мин |
| Time of day | locale 12/24 h | 2:20 PM / 14:20 |
| Key caps | the live binding through the current keyboard layout | ⌃⌥⌘B (US) / ⌃⌥⌘B (German) |

### 12.6 Help (a small window, from "⋯ ▸ Help", the menu, Settings, Welcome and every "Learn more")

Each answer has an anchor; "Learn more" links open the window scrolled to it.

1. **The screen didn't get brighter** (`no-extra-range`). "Turn the display brightness all the way up; Overbright adds to it. Check the display's verdict in Settings ▸ Displays. On a MacBook Pro, use the 1600-nit preset. On some Macs, macOS ignores color table changes: choose Calibrate… to check. Run Self-Test… shows what macOS reports."
2. **Colors look washed out, or HDR video looks flat** (`washed-out`). "While extra brightness is on, HDR highlights can't go above the brightened white. In Settings ▸ Automations, Overbright can pause for full-screen video and for the apps you choose." (Reworded 2026-10-20: both rules ship off, so "Overbright pauses for full-screen video and for video players" was no longer true.)
3. **How do I get back to normal right away?** (`back-to-standard`). "Press ‹Back to Standard shortcut›, or choose Turn Off Overbright. If Overbright stops responding, Force Quit it: macOS restores your displays at once." Without a registered shortcut: "Choose Turn Off Overbright in the menu or the panel. If Overbright stops responding, …"
4. **The display looks wrong even after quitting** (`looks-wrong`). "Change the display preset in Displays settings and back, or log out. If another color app was running, quit it. Settings ▸ Advanced ▸ Reset Display Colors can also help."
5. **Why is extra brightness limited?** (`limited`). "macOS decides how much extra range a display gets. It gives less when the surroundings are already bright, the display is warm or the battery is low. The chip on each display says what limits it."
6. **Why does extra brightness fade when I lower the brightness?** (`brightness-keys`). "With Add extra brightness only near full brightness on, Overbright adds light only when the display is near full brightness, so the brightness keys keep their normal range. Turn it off in Settings ▸ Displays to multiply any brightness."
7. **Does it use more battery?** (`battery`). "Yes. More light takes more power, roughly in proportion. By default Overbright pauses below 20 % battery and in Low Power Mode."
8. **Where is the menu bar icon?** (`menu-bar-icon`). "If the menu bar is full or macOS hides the icon, open Overbright from Finder or Spotlight to see Settings. In Menu Bar settings, check that Overbright is turned on under Allow in the Menu Bar."
9. **Add Overbright to Control Center** (`control-center`). The Run Shortcut recipe (§7.6).

### 12.7 VoiceOver

| Element | Label | Value / hint |
|---|---|---|
| Status item | "Overbright" | "On" / "Off" / "Preparing" / "Dimmed" / "Paused" / "Needs attention" |
| Master switch | "Overbright" | "On" / "Off" |
| Slider | "Level, ‹Display›" | canonical value (§5.5); custom content "Extra range"; custom actions |
| Card | "‹Display›" | container; custom actions = its context menu |
| Chip | its text | hint: "Shows why"; a button |
| Banner | its sentence | buttons as their titles |
| Footer chips | "Battery limit", "Auto-pause", "Timer" | their state ("Below 20 percent", "No timer") |
| HUD, Keep-this-level prompt | — | announcements (§6) |

Announcements go through the app-wide `Announcer` (Cranny): results and alerts at most one per 10 s; direct feedback to the user's own action is never limited.

### 12.8 Shortcuts, Spotlight and Focus (`App/Localizable.xcstrings`, `App/AppShortcuts.xcstrings`)

| Intent | Title | Description | Parameter summary |
|---|---|---|---|
| `ToggleOverbrightIntent` | Turn Overbright On or Off | "Turns extra brightness on or off." | — |
| `TurnOnOverbrightIntent` | Turn On Overbright | "Turns Overbright on. Each display uses its own level." | — |
| `TurnOffOverbrightIntent` | Turn Off Overbright | "Turns Overbright off. Your displays return to Standard." | — |
| `SetExtraBrightnessIntent` | Set Extra Brightness | "Sets the extra brightness of a display, or of every display. Each display stops at its own limit." | "Set extra brightness of ‹Display› to ‹Level›" |
| `DimDisplaysIntent` | Dim Displays | "Dims a display, or every display, below the macOS minimum." | "Dim ‹Display› to ‹Percent›" |
| `PauseOverbrightIntent` | Pause Overbright | "Pauses extra brightness for a while." | "Pause Overbright for ‹Duration›" |
| `ResumeOverbrightIntent` | Resume Overbright | "Ends a pause." | — |
| `GetOverbrightStateIntent` | Get Overbright State | "Tells whether Overbright is on, and the level of each display." | — |
| `ReturnToStandardIntent` | Back to Standard | "Turns Overbright off at once. Your levels are kept for next time." | — |

- **Parameters:** Display ("Display"; type name "Display", plural "Displays"; empty = "All Displays"); Level ("Level": the presets Indoor, Bright Room, Sunlight, Max, or "Multiplier", a number such as 1.3); Percent ("Brightness", 2–99 % of Standard light); Duration ("Duration").
- **Get State dialog:** "Overbright is on. Built-in Display: Bright room · ×1.29. MPG322UX OLED: Dimmed · 25%." / "Overbright is off." (the result value is on/off).
- **Errors:** "Overbright is still starting. Try again in a moment." · "That display isn't connected." · "This display can't show extra brightness." · "This display can't be dimmed."
- **Focus filter:** title "Overbright"; parameter "Overbright" with the options "Leave Alone", "Off", "On", and "Level" (shown with On); display representation "Overbright: Leave Alone" · "Overbright: Off" · "Overbright: On at ‹Level›".
- **App Shortcuts:** "Turn \(.applicationName) on or off" (short title "Turn On or Off", image `sun.max`) and "\(.applicationName) back to Standard" (short title "Back to Standard", image `sun.min`).
- **Control Center** (dormant control): title "Overbright", subtitle "Extra brightness".

### 12.9 HUD lines, announcements and confirmations

- **HUD values:** "Bright room · ×1.29", "×1.42", "Standard", "Dimmed · 25%", "Off".
- **HUD reasons:** "Preparing…" · "Paused until 14:20" · "Off for this Focus" · "Paused: battery below 20 %" · "Paused: on battery" · "Paused: Low Power Mode" · "Paused: Mac is hot" · "Limited: Mac is warm" · "Paused: outside set hours" · "Off: timer ended" · "Extra brightness is back".
- **Keep this level?** — "Keep this level?" / "Going back in 10 s" [Go Back] [Keep]; VoiceOver: "Keep this level? Going back in 10 seconds."
- **Announcements:** "Overbright on" · "Overbright off" · "Overbright turned off: the timer ended." · "Fill Light on" · "Fill Light off".
- **Reset ‹Pane›…** — "Reset ‹Pane› settings?" / "Every setting in ‹Pane› returns to its default." (Displays: "…, including display calibration.") [Reset] [Cancel].

---

## 13. Symbols, haptics, sound

### 13.1 SF Symbols (`OverbrightSymbol`)

Every symbol below exists on macOS 14 (most on 10.15–13) and none is restricted, checked against the system's `name_availability.plist` and `symbol_restrictions.strings` on macOS 27.0.1. `SymbolTests` re-checks the list against this table.

| Role | Symbols (minimum macOS) |
|---|---|
| Levels | `sun.max` (10.15) · `sun.max.fill` · `sun.min` · `sun.min.fill` |
| Focus only | `moon.fill` (never for dimming) |
| Displays | `display` (11) · `display.2` (11) · `laptopcomputer` (11) |
| Guards | `battery.25percent` (14) · `battery.100percent.bolt` (14) · `powerplug.fill` (12) · `bolt.fill` · `thermometer.medium` (13) · `thermometer.high` (13) · `timer` · `clock.fill` · `play.rectangle.fill` · `gamecontroller.fill` · `zzz` · `lock.fill` |
| States | `pause.fill` · `pause.circle.fill` · `exclamationmark.triangle.fill` · `exclamationmark.circle.fill` · `checkmark` · `checkmark.circle.fill` · `xmark` · `hourglass` |
| Chrome | `ellipsis` · `ellipsis.circle` · `chevron.down` · `chevron.right` · `gearshape.fill` (11) · `info.circle.fill` · `questionmark.circle` · `keyboard` · `wrench.and.screwdriver.fill` (11) · `stethoscope` (11) · `link` · `doc.on.doc` · `square.and.arrow.down` · `arrow.counterclockwise` · `arrow.clockwise` · `power` · `plus` (the paused apps' **+** menu, §7.5) |
| Fill Light | `person.crop.rectangle` · `camera.fill` |

Never use `video*` symbols (FaceTime only) or any restricted product glyph. Symbols animate only on a state change, never in loops, and not under Reduce Motion.

### 13.2 Haptics

`NSHapticFeedbackManager.defaultPerformer.perform(_:performanceTime: .now)`; reach the user only while a finger is on a Force Touch trackpad, so each has a visual counterpart; General ▸ Haptic feedback turns them off.

| Event | Pattern |
|---|---|
| The slider thumb settles into Standard | `.alignment` |
| The thumb crosses or settles on a shown preset | `.levelChange` |
| Anything else | none |

### 13.3 Sound

None. Overbright ships no audio and plays no system sound.

---

## 14. App icon brief: "Past white"

**Concept.** A white screen whose light does not stay inside its frame. On a graphite squircle sits a rounded, slightly tilted-up (leaning back) white rectangle (the screen at ordinary white); from its upper trailing corner a soft bloom of light spills **over the frame's edge** into the dark, brighter than the white rectangle itself. It reads as "brighter than white", which is what the app does, and stays legible at 16 px as a white tile with a glowing corner on a dark ground.

- **Colours:** body graphite (Light: P3 (0.17, 0.18, 0.21) → (0.07, 0.075, 0.09) top to bottom; Dark: (0.05, 0.05, 0.06) → (0.03, 0.03, 0.04)); screen white below white (P3 0.90 at the top → 0.84 at the bottom), so the bloom's core reads brighter than the screen; bloom: a white-hot core on the screen's upper trailing corner, straddling the frame, then a warm white falling off to nothing within about a quarter of the body (no half-transparent tint over a wide area: plus-lighter turns it into a grey-brown haze over the graphite); a 9-pt keyline in `boostWarm` dark (#FFB020) along the stretch of the screen's edge that the bloom crosses (the product's one warm accent as the mark's signature, wide enough to show at 128 px).
- **Shape:** the screen is 0.66 × 0.44 of the body with a 0.05 corner radius, centred slightly below the middle; "tilted up" is a perspective lean (the top edge 5 % narrower than the bottom), never a rotation in the image plane, which reads as crooked.
- **As built (WP14):** the WP0a version (a 0.40-body bloom with a 40 % warm middle stop, a P3 0.96 screen, a 4° in-plane tilt, a 3-pt keyline) read as a blank card with a smudge at 16, 32 and 128 px; `scripts/render-icon.swift` now draws the values above, with the keyline inside the screen's edge (stroked at twice its width and clipped to the screen, so the silhouette stays the rounded screen; centred on the edge it stood half outside and stepped up where it began, like a folder tab), and `AppIconLintTests` (Core) checks the rendered layers: no wide half-transparent haze, a white core brighter than the screen on its upper trailing corner, level top and bottom edges with a narrower top, a keyline at least 7 px wide at 1024. The 16/32/128/512 renders of the compiled icon were reviewed light and dark; the side-by-side comparison with the incumbent's icon stays with WP17 (HARDWARE-TEST §15).
- **Icon Composer** (`App/AppIcon.icon`, two groups, Cranny's structure): group "Screen" (`screen.png`, glass on for the system's specular edge, neutral shadow) and group "Bloom" (`bloom.png`, blend `plus-lighter`, glass off, no shadow); `fill-specializations` with the dark fill; `supported-platforms.squares = ["macOS"]`. Layers are rendered by `scripts/render-icon.swift` (`make icon`); never edit the PNGs. Tinted and Clear appearances let the system tint the bloom while the screen silhouette carries the mark.
- **Must not resemble the incumbent's icon:** no sun disc, no rays, no yellow-to-orange gradient field, no heavy rounded lettering. Before release a reviewer compares both icons side by side at 16, 32, 128 and 512 px and records the result in the WP17 pull request.
- **In-app use:** About and Welcome show the compiled icon (`NSApp.applicationIconImage`); actool generates the macOS 14/15 fallback.
- The menu bar symbol (§4.1) is a template sun because the menu bar needs the universal brightness sign; the app icon carries the brand.

---

## 15. Accessibility

| Need | Behaviour |
|---|---|
| **Reduce Motion** | §3.2: cross-fades only; no slides, scales or symbol effects; snaps are immediate; brightness ramps shorten to 160 ms but never jump. |
| **Reduce Transparency** | Opaque panel, HUD and prompt (`windowBackgroundColor`); no glass; cards unchanged. |
| **Increase Contrast** | `highContrast` palette: opaque cards with a full-strength separator hairline, darker or lighter `boostWarm` (§2.1), `labelColor` detent, ticks, dim fill and hatch lines, a 1-pt `labelColor` ring around the white slider thumb (token `thumbRing`), the focus ring at full accent. |
| **Differentiate Without Color** | Colour never carries meaning alone: chips always have words; the boost half has preset ticks and the dim half none; "not allowed now" and "nothing is brighter" are a hatch, not a colour; the allowed-now marker is a shape; the HUD always shows its value as text; the status symbol's states differ in shape (outline, filled, dotted rays, small disc with dots, badges). |
| **VoiceOver** | §12.7; the panel is one container "Overbright"; each card a container named after its display, with its context-menu items as custom actions; the slider adjustable with named stops and canonical values; decorative layers (fills, Fill Light, the welcome card's light) hidden; level changes and automation stops announced, also with the HUD's window turned off. |
| **Keyboard and Full Keyboard Access** | §5.12 for the panel (every chip, "Why?", Turn on and the Fill Light card are reachable; ⌃↩ opens a card's context menu); Settings and Welcome follow Cranny's maps; every action has a key path; nothing is hover-only (the value tag and help tags repeat what VoiceOver and the readout say). |
| **Pointer and motor** | 28 × 24 pt hit targets; slider snapping only on slow drags; scroll-wheel adjustment in stops, following the hand whether natural scrolling is on or off (wheel away or fingers up: brighter). |
| **Time limits** | The HUD is informational. The Undo of Reset All stays available as a button until the Settings window closes and through ⌘Z (the banner itself fades after 10 s). "Keep this level?" reverts after 10 s on purpose: going back is the safe direction, and any Overbright shortcut or Return keeps the level. |
| **Flashing (WCAG 2.3.1)** | §3.4. |
| **Photosensitivity** | Brightness changes ramp; the calibration flips are slow and announced; Turn Off Overbright is always one click away in the menu, and Back to Standard one shortcut away once recorded; every level change away from Standard asks before staying. |

---

## 16. Copy voice and localisation

- **Voice:** calm, plain, American English; sentence case except AppKit chrome (menus, Settings push buttons, sheets, alerts) which is title case; panel buttons (banners, chip popovers, cards) are sentence case; typographic ’ “ ” and a one-character … ; no exclamation marks, no "Oops", no marketing words inside the product ("amazing", "stunning", "double").
- **Name System Settings by pane**, never by a ▸ path ("in Displays settings"); our own Settings may use paths ("Settings ▸ Automations").
- **Destinations are unambiguous.** A button that opens **System Settings** is always **Open System Settings**, and the sentence names the pane ("Turn on High Dynamic Range for this display in Displays settings."). A button that goes somewhere in **Overbright** names the action, never a settings place: "Choose Peak…", "Change power rules…", "Change hours…", "Edit apps…", "Change rules…", "Settings for This Display…" (context menu). The banner and the chip for the same reason share one action. A lint (`noSettingsDestinationLabels`) flags button strings shaped "‹X› Settings…" or "‹X› settings…"; §7.8's "Reset All Settings…" names an action on every setting, not a place, and is its one exemption.
- **Key caps are never typed into copy.** A sentence that mentions a shortcut has a placeholder filled from the live binding, rendered through the current keyboard layout by the same code that draws the menu's key equivalents (on a German layout ⌃⌥⌘= shows the key that sits there, ´); when the shortcut is cleared or failed to register, the sentence variant without it is used. A lint (`noLiteralKeyCapsInCatalogs`) rejects ⌃⌥⌘ followed by a key outside a placeholder. Welcome step 4, Help and the hide-icon alert are snapshotted with US, German and French layouts.
- **Vocabulary:**

| Use | Means | Never |
|---|---|---|
| Overbright | the app (never translated or transliterated) | — |
| Standard | the brightness macOS itself shows | "100 %", "normal mode" |
| extra brightness | the boost half | "boost" in copy, "HDR mode", "XDR mode", "EDR", "gamma" |
| Dim below minimum (setting) · Dimmed (state) · Dim All Displays (action) | the dim half | the incumbent's name for it, "night mode" |
| Brighter · Less Bright | one step up or down | "Dimmer" (it reads like Dim) |
| Indoor · Bright room · Sunlight · Max | presets | — |
| Safe · Peak | ceilings | "Max" for a ceiling |
| Fill Light | the edge light | "ring light" |
| Back to Standard | the instant off action | "panic", "reset brightness" |
| extra range | headroom, in user copy | "headroom" outside Advanced and diagnostics |
| color table | what Overbright scales, in sentences only ("macOS ignores color table changes") | "gamma", "fallback", "overlay" |
| display | a screen | "monitor" (except "external display"), "screen" for a device |
| Pause / Paused | temporary stop by a guard or the user | "disabled", "turns off" for a pause |

- **Denylist (ARCHITECTURE.md D3):** no competitor product or company name in any key, value or translator comment, in any language; other apps' names appear only at runtime. No reference to Launchpad (removed in macOS 26).
- **Numbers and units:** always `FormatStyle` / `Measurement` (§12.5); "≈ %lld nits" has plural forms in every language.
- **Length:** Russian runs 15–35 % longer; constrained strings are measured in every language by fit tests (English and a pseudo-long locale during development, all 35 in WP15), and a failure is fixed by wording first: chips ≤ 280 pt (their own line), the footer row ≤ 304 pt for all three chips, glyphs included (else glyph + value), readout ≤ 200 pt, value tag ≤ 240 pt (a "small gain" suffix may wrap), HUD text ≤ 200 pt, Safe/Peak segments.
- **Right to left** (Arabic, Hebrew): the panel, cards, slider, footer and Settings mirror; the status symbol does not; names inside sentences are bidi-isolated.
- **35 languages** from day one; Russian is the owner's review language and the pivot for the rest.

---

## 17. Energy budget (a release gate)

Displays use more power when brighter: that is the product, and the README says so. The budget below is about Overbright's **own** work, measured with Activity Monitor (5-minute average), `top -stats pid,cpu,idlew,power`, `footprint` and `powermetrics` before each release.

| State | Allowed work | Target |
|---|---|---|
| Off (nothing dimmed) | event notifications only (with the KVO of the running-app list, which catches agent apps' launches), and the one-shot work an event asks for (the full-screen re-check 0.6 s after a Space, screen, app activation or regular app's exit, which ends a full-screen or app pause; a background-only process's exit asks for nothing while nothing is scaled or dimmed); no periodic timers or tasks, no windows, Metal devices or IOPS percent source | 0 wake-ups/s; Energy Impact 0.0; < 40 MB resident |
| Preparing (first arm) | 10 Hz headroom reads; ≤ 5 rungs × 2.5 s once per display and macOS build (7 before 2026-10-20), then ≈ 1–3 s | — |
| Boosted, steady (T2, or T1 by Advanced ▸ Trigger method) | 2 s drift check (one table read, one headroom read) + the 2 s hang ping + Signals' 2 s full-screen and playback watch (≤ 2 ms window list) while a full-screen or "while playing" rule is on: its own timer by decision, not a ride on the drift check (ARCHITECTURE.md D28); the drift checks, the hang ping and the watch all wait for one shared 2 s grid of the app's clock (D29), so they cost one wake-up every 2 s together (≈ 0.5 wake-ups/s for any number of displays, where D28's independent phases cost up to 1.5 with one display and 2.0 with two); Signals' boost-only work stops while the screen is shielded; a ≤ 3 s 10 Hz poll burst only after a raise that waits for range | ≤ 1.5 wake-ups/s; < 0.1 % CPU; no GPU work after the first frame |
| Boosted with T3 (the automatic ladder's first rung since 2026-10-20, ARCHITECTURE.md D4) | + one tiny clear-only present every 0.2 s: **5 presents/s** (about 5 more wake-ups/s), and the GPU working set the driver would free between slower presents stays allocated while boosting; the price of the cadence proven on the owner's built-in XDR (5 s before) | measured (H-S1) and reported in the release notes; the ≤ 1.5 wake-ups/s of the steady row holds only for T1/T2; the simulated `make perf` runs use fake triggers and do not include these presents |
| Ramping | ≈ 60 table writes/s for ≤ 0.4 s | — |
| Panel open | redraw on change only; the allowed-now marker ≤ 4 Hz | < 2 % CPU while dragging |
| Fill Light | one static layer; no redraw unless settings change | — |

**Measured after the energy pass** (2026-10-19, main 6d3552f vs 9ef2587, `make perf` on the optimized measurement build under `--qa-simulate`, runs interleaved A/B on a loaded M4 Max; own = app minus the control app; full tables in the pass's comparison report). Real-display numbers come from the owner's hardware session (H-S1).

| State | Before → after | Verdict |
|---|---|---|
| Off, simulated Signals | ≈ 0.00 ms/s CPU; 0.01–0.02 own wake-ups/s; 27.3–28.0 MB footprint | pass |
| Off, real Signals (`--qa-live-signals`) | 1.6 → 0.14 ms/s CPU (−91 %); 0.06 → 0.02 wake-ups/s; 27.5 MB | pass |
| Boosted steady, one display | 0.51–0.77 → 0.47–0.49 wake-ups/s; 0.013 % CPU; 31 → 27–28 MB | pass |
| Boosted steady, two displays | 0.49–0.60 → 0.50–0.53 wake-ups/s; 0.018 % CPU; 34.5 → 28.5–28.9 MB | pass |
| Ramp storm, panel closed | 5.5 % → 0.49 % CPU (−91 %); 40 → 29 MB | — |
| Panel open (boosted / off) | ≤ 0.1 % CPU / 0.27 → 0.011 ms/s; 33–40 → 29–30 MB | pass |
| Panel drag at 10 Hz | 14.7 % → 7.0 % CPU (−52 %); 43 → 52 wake-ups/s | **miss** (< 2 %) |
| HUD, a press every 2 s / every 0.25 s | 6.2 % → 3.8 % / 16.2 % → 1.9 % CPU | — |
| Fill Light card | peak 301 → 34 MB (no Metal on the default path) | pass |
| Back to off | ≤ 0.01 wake-ups/s; 40 → 29 MB | pass (was a miss) |
| After Settings, Help and Welcome have closed | 51–56 → 48–52 MB; a wake-up every 3.0 s remains (0.32/s) | **miss** (< 40 MB, ≤ 0.05/s) |
| Screen-parameters event | 5.6 → 0.25 ms CPU each (−95 %) | — |
| 17-minute soak | passed: 0 own wake-ups in the 373 s final off phase; 30 MB at the end | pass |

Open misses: the panel drag (SwiftUI/AttributeGraph re-rendering; an unreviewed attempt waits on branch `energy/panel-drag`), and the memory plus a 3 s periodic wake-up left behind after the Settings, Help or Welcome windows close.

---

## 18. What's better than the incumbent

1. **Free, with nothing to unlock:** no trial, no split-screen nag, no license, no account.
2. **Private by construction:** no analytics or crash SDKs, no background network; an opt-in GitHub update check is the only connection.
3. **Never leaves a broken screen:** a state machine for every lifecycle event, an interlock that never scales past measured headroom, a launch check that judges tables against the display's own profile, a hang watchdog, and macOS itself as the guardian after a crash.
4. **Honest:** a verdict with a fix for every display that quotes what macOS actually allows, a marker showing where the slider stops now, a reason for every limit said once, estimates marked as estimates, nits only when known.
5. **Correct math:** caps in light units with an encoded default that never blows out whites, and a one-minute calibration that needs proof before it asks for more.
6. **Works by measurement, not by name:** any HDR display, in any language; external OLEDs handled with care.
7. **Guards that matter:** battery, Low Power, heat, OLED idle, full-screen video, per-app, schedule, Focus, other apps, each explained on screen when it acts.
8. **Flicker-safe by guarantee**, not by luck.
9. **Native:** a template menu bar symbol, a panel and a menu, Shortcuts actions, a Focus filter, 35 languages, VoiceOver and the keyboard throughout.
10. **Always escapable:** Back to Standard on a shortcut you choose, every launch shows its UI, Quit everywhere, "Keep this level?" for very dark levels, `--off`, `--restore-gamma`, Force Quit restores.
11. **One control** for dimming below the minimum and brightening above the maximum, with Dim All Displays on a shortcut you choose, extra brightness that respects the brightness keys, and a Fill Light that turns on with the camera.

---

## Appendix A — Components (`OverbrightDesign`)

| Component | Purpose | Key behaviour |
|---|---|---|
| `BoostSlider` | the level control (§5.5) | detent, shown ticks, fills over the track, the allowed-now marker and hatch, value tag in canonical units, snapping with haptics, keyboard steps in stops, adjustable VoiceOver element with named stops and custom content, RTL mirroring, disabled halves |
| `ReadoutText` | the readout line (§5.6) | rounded monospaced digits, estimate prefix, no numeric content transition |
| `StatusChip` | per-display limit and phase chips (§5.7, §12.2) | a button: glyph + text on a tint; popover with one sentence and its actions |
| `GuardChip` | footer chips (§5.9) | a menu button showing its setting |
| `PausedBanner` | the one banner (§5.8, §12.3) | glyph, sentence, at most one button |
| `EDRPreviewSurface` | the Welcome card (§8) | EDR content in our own view, divider moved by dragging, ← / → (10 %, mirrored right to left) or VoiceOver, SDR stand-in under `--qa-simulate`, paused when hidden |
| `StepWedgeView` | the calibration squares (§9) | drawn in the screen's colour space on black |
| `KeyCap` | shortcut key caps | renders the text it is given (from `ShortcutCenter.displayString`) in system colours |
| `ChipButtonStyle`, `IconButtonStyle`, `OverbrightLinkButtonStyle` | buttons | hit-target widening inside the style |
| `.overbrightFocusRing` | keyboard focus | concentric, only after keyboard use |
| `SettingRowConventions`, `SettingsStore.binding(_:)` | changed dot, Reset to Default, SwiftUI bindings | Cranny's |
| Copy builders (`ChipModel`, `VerdictText`, `BannerModel`, `ValueText`, `HUDText`) | every sentence of §12.1–§12.3 and §12.9 | the only producers of engine-state copy |

PanelUI adds `DisplayCardView`, `FillLightCard`, `HelpView` and `ScriptedStatuses`; the shell adds the HUD, the Keep-this-level prompt and the icon-not-visible window.

## Appendix B — Verification (2026-10-16, macOS 27.0.1)

- Contrast values of §2.1: computed with the WCAG 2.x formula over the stated reference colours, with fills composited over the track.
- Symbols of §13.1: each found in `name_availability.plist` with the minimum macOS shown (incl. `zzz` and `hourglass`, 10.15); none in `symbol_restrictions.strings` (663 entries).
- `NSGlassEffectView` (macOS 26) with the `.regular` and `.clear` styles (`NSGlassEffectView.h`: Regular and Clear only): present in the macOS 27 SDK headers.
- Numbers in copy (×1.67, ×1.40, ≈ 1,000 nits only with a trusted SDR white, ×1.55, 1.61 / 3.00, the preset gains) match ARCHITECTURE.md §5.3 and §5.6.
- Rendered since: the snapshot suites (`OVERBRIGHT_SNAPSHOT_DIR`, Light, Dark and Increase Contrast, local only) of WP9 (tokens and components), WP10 (panel, menu, HUD, Help), WP11 (Settings, calibration, self-test), WP12 (every Welcome step, US, German and French key caps) and WP13 (`make qa-matrix` panel captures per fixture) are where this file's pixels were reviewed; WP15's fit tests measured every width rule in all 35 languages.
