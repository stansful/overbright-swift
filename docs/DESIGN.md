# Overbright Design System

> **Brighter when you need it, never broken, always explained.** One control per display with a Standard detent, one warm colour that only ever means "extra light", a reason for every limit, and a way back to Standard from anywhere.

| | |
|---|---|
| Status | **v0.2, proposed** (2026-10-16), written with `docs/ARCHITECTURE.md` before any code and revised with it after a design review (ARCHITECTURE.md Appendix B lists every finding and its fix). This file is the single source of truth for every pixel, colour, motion, word and sound in Overbright; ARCHITECTURE.md owns behaviour, contracts and the work plan. Where they disagree, raise it; neither silently wins. |
| Applies to | The menu bar extra and its menu, the panel, the HUD and the Keep-this-level prompt, the Help window, the Settings window, the Welcome window, the calibration window, the self-test sheet, Fill Light, the app icon, every string (including Shortcuts, Spotlight and Focus). |
| Platform | macOS 14.0 deployment target. Liquid Glass (26+) only behind `#available`, always with a designed 14/15 fallback. macOS 27's global glass-opacity slider and fixed window radius are respected by never hard-coding translucency or window corner radii. |
| Clean room | Original work for Overbright (MIT). Nothing from the incumbent commercial app (its code, assets, icon, UI text or feature names) or from any GPL project. Competitors were studied only through public product pages, store listings, reviews and issue-tracker titles (`docs/research/ux-landscape.md`). The incumbent is named only in ARCHITECTURE.md D3. |
| Sibling | Cranny's design system (`/Users/stansful/projects/my/nook-preview/Cranny/docs/DESIGN.md`) supplies the token system, the Settings and Welcome conventions, the copy rules and the accessibility bar. Overbright has no notch surface, so it lives entirely in Cranny's "system world": ordinary windows that follow Light and Dark. |

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
| 14 | Defaults | Boost at launch; Max level | **Launch, keep off; Bright room; Safe; extra brightness only near full brightness; pause for full-screen video.** Nothing gets brighter until the user asks, and the brightness keys keep their range. |
| 15 | Help | Remote FAQ; GitHub link; local | **Local Help window** with the answers that matter (§12.6), opened from anywhere, with anchors for chips and verdicts; a GitHub link only when the repository key is set. No network for help. |
| 16 | Headroom display | A bar under the slider; a marker on the track; text only | **A marker on the slider track where the thumb will stop now**, plus the allowed and the potential multiplier in its help tag and VoiceOver. A bar scaled to the slider top could not show potential and was simply full in Safe. |
| 17 | Launching and quitting | Silent agent; always open UI | **Every launch that is not a login launch shows UI**, and Quit is in the panel, the menu, Settings ▸ General and Welcome. An agent app that shows nothing when launched by hand, with its icon hidden, has no visible way out. |

---

## 1. Principles

Each principle has a test that a build passes or fails.

1. **Never leave a broken screen.** Overbright only brightens what macOS can actually show, un-scales before anything else on every exit path, and lets macOS restore the display if it dies.
   *Test:* the engine fuzz suite never writes more than 0.97 × headroom; in the hardware session, `kill -9`, lock, sleep and lid close leave every table at its profile base within 1 s (HARDWARE-TEST §2.0, §4 and §5).
2. **Honest numbers.** Every number shown can be backed by a measurement or a published spec; every limit names its cause; estimates look like estimates.
   *Test:* every non-Standard state of a card has a chip, a banner or a readout that explains it; "nits" appears only with a trusted SDR white and a valid calibration; an uncalibrated multiplier is prefixed "≈"; verdicts quote the default ceiling or a measured grant, never the raw potential; the panel's numbers equal Copy Diagnostics' numbers.
3. **Invisible machinery.** Triggers, tables, ladders and overlays are our problem. The user sees displays, levels and reasons.
   *Test:* no trigger pixel is visible on the built-in display (HARDWARE-TEST H-W2); the words "trigger", "gamma", "EDR" and "headroom" appear only in Settings ▸ Advanced, Self-Test and diagnostics.
4. **One control, one meaning, one value text.** The level of a display is one number with **canonical units everywhere**: extra brightness is a preset name and/or a multiplier ("Bright room · ×1.29"); dimming is "Dimmed · N %" of Standard light. The panel, the menu, the HUD, Settings, the Shortcuts app and VoiceOver use the same text.
   *Test:* a change from any surface updates every other surface within one frame, and the value text of a level is byte-identical in the readout, the HUD, the menu item, Get State's result and VoiceOver (apart from VoiceOver's spelled-out "times" and "percent").
5. **Always escapable.** Back to Standard is one shortcut away; Quit is in the panel, the menu, Settings ▸ General and the Welcome window; every launch that is not a login launch shows UI; Force Quit restores the display; very dark levels revert on their own unless confirmed.
   *Test:* with the menu bar icon hidden, launching Overbright from Finder (running or not) opens Settings ▸ General, whose Quit Overbright button quits; the Back to Standard shortcut works with every window closed and while a conflict banner is up; a level below 10 % of Standard returns after 10 s without input.
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

- **Where:** `Packages/OverbrightKit/Sources/OverbrightDesign/` (`Color.swift`, `Typography.swift`, `Layout.swift`, `Motion.swift`, `Theme.swift`, `Symbols.swift`, `RightToLeft.swift`, `Components/`, `Copy/` — the localized names and sentences of every Core and Policy enum and their builders, ARCHITECTURE.md §8.8).
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
| `allowedMarker` | `labelColor`, 2 × 10 pt | same | same | where the thumb will stop now (§5.5) |
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

The v0.1 tokens that failed are gone: `headroomAvailable` (`tertiaryLabelColor`, 1.88:1 on the light card) and the 1-px `quaternaryLabelColor` outline (1.25:1). System orange (#FF9500, 2.0:1 on light backgrounds) fails 3:1 in Light mode, which is why the boost zone has its own token. Text never uses `boostWarm`; chip and banner text uses `labelColor` on a 15 % tint of the semantic colour, so text contrast is the system's own, and the coloured glyph is redundant with the words. Text is never faded by lowering a view's opacity (secondary text at 60 % opacity falls to 2.1:1).

### 2.2 Typography

System text styles only; SF Pro Rounded with monospaced digits for live numbers so they never jitter. Nothing below 10 pt. macOS has no Dynamic Type for third-party apps; layouts grow in height for long translations instead of truncating meaning.

| Style | Font | Use |
|---|---|---|
| `panelTitle` | 13 semibold (`.headline`) | "Overbright" in the panel header |
| `cardTitle` | 13 semibold (`.headline`), up to two lines, tail truncation, full name in the help tag | display names |
| `readout` | 13 medium, SF Pro Rounded, monospaced digits | "Bright room · ×1.29 · ≈ 775 nits" |
| `chip` | 11 medium (`.caption` medium) | status chips, footer chips |
| `caption` | 11 regular, `secondaryLabelColor` | "Compatibility mode" under the readout |
| `banner` | 12 regular (`.callout`), up to 3 lines | "Paused because…" |
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

- **Strokes** (`StrokeWidth`): hairline = 1 device pixel; regular 1; focus ring 2; slider track 4 (6 while dragging); detent tick 1.5 × 8 pt; preset ticks 1 × 5 pt; allowed marker 2 × 10 pt.
- **Hit targets** (`HitTarget`): ≥ 28 × 24 pt for every panel control (the 20-pt slider thumb takes a 28-pt hit area inside the control; footer chips at least 28 pt wide); widening happens inside the button style, never with an outer frame (Cranny gotcha).
- **Elevation:** the system's window shadow for the panel and the HUD; cards have none (a hairline only).

### 2.4 Materials

| Surface | macOS 26+ | macOS 14/15 | Reduce Transparency |
|---|---|---|---|
| Panel container | Liquid Glass (`NSGlassEffectView`, `.standard` style), corner radius `Radius.panel` | `NSVisualEffectView(.popover, .behindWindow, .active)` masked to `Radius.panel` | opaque `windowBackgroundColor` |
| HUD, Keep-this-level prompt | Liquid Glass (`NSGlassEffectView`, `.standard`) | `NSVisualEffectView(.hudWindow)` | opaque |
| Cards, banners | `card` fill (no glass, content layer) | same | same |
| Slider thumb | white; takes glass only while dragged (system behaviour of transient controls) | white with system shadow | white |
| Settings, Welcome, Help | system (sidebar and toolbar glass from AppKit; we add none) | system | system |

Glass is never stacked on glass, and nothing translucent sits behind text without a card.

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

### 4.3 The menu (exact English, title case as AppKit chrome)

```
‹Status sentence›                                     (disabled; only while a banner applies: the banner's own sentence, §12.3)
‹Its action›                                          (the banner's primary action: Resume, Try Again, Continue Anyway,
                                                       Use Compatibility Mode, Change Power Rules…, Change Hours…, Open System Settings)
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
                                          Dimmed · 25 %
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

- Key equivalents (`‹live›`) show the **live** global shortcut in the current keyboard layout, or nothing when the shortcut is cleared or failed to register (Cranny's `MenuKeyEquivalent`).
- Preset items list only the presets shown on that display (§5.5); the dim item uses the last dim level (default "Dimmed · 25 %", light relative to Standard).
- **Don't Use on This Display** turns extra brightness off for that display and returns it to Standard (dims undone); the opposite item turns extra brightness on (an OLED shows its notice first, §12.4).
- With no display that can boost, the presets are replaced by a disabled "No Extra Brightness on This Display"; a display that can only dim keeps Standard and Dimmed.
- **Back to Standard is not in this menu**: Turn Off already sits in the first group and does the same, a little slower. Back to Standard stays on its shortcut, in the Dock menu and in the Shortcuts app.

### 4.4 Launching, reopening, hiding the icon, quitting, Dock icon

- **Launch UI.** A login launch shows nothing. Every other launch, and every reopen while running (Finder, Spotlight, `open`), shows: the Welcome window until it is finished or skipped; else the panel under the icon; else, when the icon is hidden or not visible, **Settings ▸ General**. Launches by a Shortcuts action or an `overbright://` URL show nothing. Nobody is locked out, and nothing runs invisibly after a manual launch.
- **Quit** is in the panel's "⋯" menu, the right-click menu, Settings ▸ General (a **Quit Overbright** push button; ⌘Q also works in the Settings window), the Welcome window (bottom-leading on every step, and in the "Skip setup?" alert), and the Dock menu when the Dock icon is on.
- **Hide the icon:** General ▸ "Show menu bar icon" off asks first:
  > **Hide the menu bar icon?**
  > You can still open Overbright from Finder or Spotlight, which shows Settings, or use ‹toggle shortcut› to turn it on or off. To quit, open Overbright again and click Quit Overbright in Settings.
  > [Hide Icon] [Cancel]

  When the toggle shortcut is cleared or not registered, the middle clause is left out ("You can still open Overbright from Finder or Spotlight, which shows Settings. To quit, …").
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
- Trailing: the **master switch** (`Toggle`, `.switch`, `.controlSize(.small)`; VoiceOver "Overbright, on"), then the overflow button "⋯" (`IconButtonStyle`) with a menu: **Dim All Displays** ("Stop Dimming" while dimmed) · **Fill Light** (✓ while on) · separator · **Settings… ⌘,** · **Run Self-Test…** · **Help** · separator · **Quit Overbright ⌘Q**.
- **Fill Light card.** While Fill Light is on, a compact card appears above the display cards: "Fill Light" with a **Display** pop-up, **Brightness** and **Warmth** sliders (the same ranges as Settings) and a **Turn Off** button. It is the place to adjust the light during a call without opening Settings.
- **One-time calibration tip.** After the first boost on a display that can be calibrated, a dismissible card appears once: "Check that it works" / "A one-minute check makes sure extra brightness is right for ‹Display›." [Calibrate…] [Not now].

### 5.4 Display card

- `card` fill, `cardStroke` hairline, `Radius.card`, padding 12, 8 pt between cards. Every display that can boost **or dim** gets a full card.
- **Title:** display name (`cardTitle`, up to two lines). With linked levels a `link` glyph precedes the name of every card ("Same level on all displays"). Two displays with the same name get " (1)", " (2)" in UUID order, as macOS does.
- **Slider row** (§5.5) with `sun.min` at the dim end and `sun.max.fill` at the boost end (14 pt, `secondaryLabelColor`), 6 pt gaps: a 240-pt track whose boost half is 120 pt.
- **Readout** (§5.6). In Compatibility mode a `caption` line "Compatibility mode" sits under it, with the method's footnote (§7.4) as its help tag.
- **Chip line** (§5.7): only when a per-display reason applies.
- **Context menu** (right-click, ⌃-click, or ⌃↩ while the card's slider has keyboard focus): the shown presets · Dimmed · 25 % · separator · Calibrate… · Settings for This Display… (Overbright's Settings ▸ Displays at this display) · Don't Use on This Display / Use Extra Brightness on This Display · Try Again (only when failed). Every item is also a **VoiceOver custom action** on the card, and the items that fix a limit (Try again, Continue anyway, Turn on, Choose Peak…) are also actions in the chip's popover, so nothing depends on right-click.
- **Extra brightness off for this display** (opt-in displays, or after "Don't Use on This Display"): the boost half draws with `inactiveHatch` and the chip "Extra brightness off" offers **Turn on**. Moving the thumb past the detent turns it on as well; an OLED display shows the OLED notice first (§12.4), and the thumb waits at Standard until the notice is answered. Dimming always works.

### 5.5 The level slider (`BoostSlider`)

| Aspect | Specification |
|---|---|
| Track | 240 pt, 4 pt high (6 pt while dragging), `track` colour, capsule ends |
| Detent | a 1.5 × 8 pt `detentMark` at the centre: **Standard** |
| Fills | drawn over the track. Left of the detent: `dimFill` from the detent to the thumb. Right of the detent: `boostWarm` from the detent to the thumb **while extra light is on screen**; while Overbright is off or paused, the same span is drawn with `inactiveHatch` (nothing is brighter, so nothing is warm) |
| Allowed now | while boosting with a reading: a 2 × 10 pt `allowedMarker` where macOS's current limit puts the thumb's stop, and `inactiveHatch` beyond it to the end of the boost half. Hidden when there is no reading (off, never armed) |
| Ticks | 1 × 5 pt `tick` marks at the **shown** presets (Indoor 25 %, Bright room 50 %, Sunlight 75 %, Max 100 % of the boost half; a preset below ×1.1 or within 0.1 stop of the next shown one is hidden, ARCHITECTURE.md §5.3); none on the dim half |
| Thumb | 20 pt white circle with the system shadow (glass while dragged on macOS 26+); 28 pt hit area |
| Snapping | within ±3 % of the detent or a shown tick, a slow drag settles there (`detentSnap`) with an `.alignment` haptic at the detent and `.levelChange` at a preset; a fast drag passes through |
| Value tag | while dragging or hovering the thumb: a capsule 6 pt above it (`valueTag`) with the canonical value text: "Bright room · ×1.29" at a preset, "Standard" at the detent, "×1.42" between presets, "Dimmed · 25 %" on the dim half; "≈" before the multiplier while not calibrated; "· small gain on this display" when Max is at most ×1.3; while a guard pauses the display, the reason ("Paused: Low Power Mode") |
| Disabled boost half | when boosting is not possible (verdict, or the Safe top below ×1.05): the right half draws with `inactiveHatch`, the thumb stops at the detent, and hovering the half shows the reason as a help tag |
| Disabled dim half | displays without a transfer table (virtual) or in a reference preset: the left half is disabled the same way |
| Keyboard (focused) | ← / → by **1/12 stop** of light (≈ 6 %) · ⌥← / ⌥→ to the previous/next named stop (Standard, the shown presets; on the dim half 50 %, 25 %, 10 %, 5 %, 2 % of Standard light) · Home = Standard · End = Max · scrolling adjusts by 1/12 stop per notch · ⌃↩ opens the card's context menu. A key step never crosses Standard: the next press continues past it |
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
| Off | "Off" (`tertiaryLabelColor`) |
| Standard | "Standard" |
| Boosting at a preset, calibrated, SDR white trusted | "Bright room · ×1.29 · ≈ 775 nits" |
| Boosting at a preset, calibrated | "Bright room · ×1.29" |
| Boosting, not calibrated | "Bright room · ≈ ×1.29" |
| Between presets | "×1.42" (+ " · ≈ 852 nits" when known; "≈ ×1.42" when not calibrated) |
| Limited below the requested level | "×1.21 · asked ×1.47" |
| Dimmed | "Dimmed · 25 %" (light relative to Standard) |
| Preparing | "Preparing…" |

The multiplier is a light gain, formatted with one or two decimals by `FormatStyle` (locale decimal separator); nits are rounded to the nearest 5 and always prefixed "≈". The readout's help tag adds: "For the most light, turn your display brightness all the way up first; Overbright adds to it." and, while not calibrated, "Not calibrated: this is an estimate." with **Calibrate…** in the card's context menu and as a VoiceOver action.

**Allowed-now marker** (part of `BoostSlider`, §5.5): shows where the thumb will stop now. Its help tag and VoiceOver custom content: "macOS allows ×1.55 now. This display can reach ×2.6 at most." (the second figure is the Peak ceiling at full brightness). It shows at a glance why the thumb cannot go further, and how much further the display could go.

### 5.7 Status chips

A chip appears **on its own line under the readout**, only when a **per-display** reason limits or prepares the display (reasons that apply to every display are the banner's, §5.8). Capsule, 20 pt high, padding 8, glyph (12 pt, semantic colour) + text (`chip`, `labelColor`) on a 15 % tint of the semantic colour; up to the card's inner width (280 pt), measured per language. App names inside a chip ("Paused: ‹App›") are middle-truncated to fit, with the full name in the help tag and VoiceOver. A chip is a **button**: click, Space or Return opens a small popover with one sentence of explanation and, where they exist, its actions (§12.2); Esc closes it and returns focus to the chip. The chip shows the first per-display reason in the policy order (ARCHITECTURE.md §6.1); "Preparing…" and "No extra range" come from the engine phase and win while they apply.

### 5.8 Banners

At most one banner, between the header and the first card, for **a reason that applies to all displays** (a user pause, a conflict, Focus, heat, Low Power, battery, the schedule) or an attention state (a stop to prevent flicker, colours changed by another app): `card` fill tinted 10 % with the semantic colour, a 14-pt glyph, the sentence (`banner`, up to 3 lines) and up to two text buttons (primary first). Banners reflect state, so they have no close button; they leave with `bannerOut` when the cause clears, and the next reason in precedence takes their place. The same sentence is the first line of the right-click menu (§4.3). Precedence and exact copy: §12.3.

### 5.9 Footer guard chips

Three menu chips (`GuardChip`, 24 pt high, 6 pt apart) in a 44-pt footer; each shows its **setting** (never a live value) and opens a short menu. They are shortcuts to the most-used Automations rows; Settings has the rest. Together they fit 292 pt in every language; when they would not, each drops to glyph + value.

| Chip | Label (state) | Menu |
|---|---|---|
| Battery (`battery.25percent`) | "Below 20 %" (pause below a level) / "Adapter only" / "Any charge" | ✓ Pause Below a Level · Pause on Battery · Keep Boosting · ─ · Battery Level ▸ 10 % · 20 % · 30 % · 50 % (the current value is inserted with a checkmark when it is not one of these; Settings offers 5–95 %) |
| Auto-pause (`play.rectangle.fill`) | "Auto-pause" (any rule on) / "Auto-pause · Off" | ✓ Pause for Full-Screen Video · Pause for Every Full-Screen App · ✓ Pause for Apps in the List · ─ · Edit Apps… |
| Timer (`timer`) | "No timer" / "Off in 23 min" (counting down) | Turn Off After ▸ Never · 15 Minutes · 30 Minutes · 1 Hour · 2 Hours (plus the current value when it is another one; Settings offers 5 minutes to 2 hours) |

"Pause for Apps in the List" is the list's master switch (`automations.pauseForListedApps`); turning it off keeps every rule. On Macs without a battery the Battery chip is not shown.

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
| Four or more displays | Three cards visible, the rest scroll |
| Locked or asleep | (the panel cannot be open) |

### 5.12 Keyboard

| Keys | Action |
|---|---|
| Tab / ⇧Tab | master switch → for each card: its slider, its chip, its Turn on → "Why?" (then its fix buttons and Learn more links when expanded) → banner buttons → footer chips → the Fill Light card's controls (when shown) → "⋯" |
| ↑ / ↓ | previous / next card's slider |
| ← / →, ⌥← / ⌥→, Home, End | slider (§5.5) |
| ⌃↩ | the focused card's context menu |
| Space | toggles the focused switch, or opens the focused chip's popover or footer chip's menu |
| Return | the focused button, chip or "Why?" |
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
| `no-extra-range`, `still-no-extra-range` | failed ladder, first and after two tries (Self-Test, Compatibility mode, Help link) |
| `dimmed` | built-in at "Dimmed · 25 %", dim fill |
| `extra-brightness-off` | an opt-in HDR external: hatched boost half, chip with Turn On |
| `linked` | two cards with link glyphs moving together |
| `banner-battery`, `banner-low-power`, `banner-heat`, `banner-paused`, `banner-focus`, `banner-schedule` | each global banner with its buttons, and no chips repeating it |
| `heat-cap` | chip "Limited by heat" |
| `conflict-booster`, `conflict-color-app` | banner with an app name (long name and right-to-left name variants) |
| `conflict-may-interfere` | the S3 info chip |
| `flicker-stop`, `foreign-table` | danger banners |
| `full-screen-video`, `full-screen`, `paused-app`, `oled-idle` | per-display pause chips while the other display boosts; `paused-app` with a long app name, middle-truncated |
| `compatibility` | a card in Compatibility mode with its caption line |
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

- **When:** (1) the level or on/off state changes through a **global shortcut, the Shortcuts app, a Focus filter or Back to Standard**; (2) a turn-on from the **icon, a shortcut or the Shortcuts app** is not ready within 0.5 s ("Preparing…"); (3) a requested change is blocked by a guard; (4) an **automation stops, caps or resumes** extra brightness on a visible display: the timer ends, the battery threshold or "on battery" applies, Low Power Mode, heat, the schedule boundary, and the return when the cause clears. **Never** for changes made in the panel, the menu or Settings (they show their own state), and never for full-screen, app or game pauses, which the user caused. General ▸ "Show level changes on screen" turns all of it off.
- **Where:** horizontally centred on the display whose level changed (the display under the pointer for "all"), 64 pt above the bottom of its visible frame (above the Dock), clear of the system's own brightness indicator and notification banners.
- **Geometry:** 280 × 56 pt, `Radius.hud`, material per §2.4.
- **Content:** leading glyph 20 pt (`sun.max.fill` boosting, `sun.min` dimmed, `sun.max` Standard or off, `hourglass` preparing, `pause.fill` blocked or paused, `thermometer.medium` heat); centre: the display name (`hudLabel`, only with two or more displays) above a 150-pt level bar drawn like the slider (detent mark, `dimFill` left, `boostWarm` right, no thumb); trailing value (`hudValue`) in canonical units: "Bright room · ×1.29", "×1.42", "Standard", "Dimmed · 25 %", "Off".
- **Reasons:** for (2)–(4) the bar is replaced by one line (`hudLabel`, exact copy §12.9): "Preparing…", "Paused: battery below 20 %", "Off: timer ended", "Limited: Mac is warm", "Extra brightness is back", …
- **Timing:** `hudIn`, stays 1.5 s after the last change (3 s for automation reasons), `hudOut`. A new change updates the visible HUD; there are never two.
- **Never** activates, takes clicks or appears in screenshots where macOS honours `sharingType = .none`.
- **VoiceOver:** the same text posted as an announcement ("Bright room, 1.29 times"; "Off: timer ended"), not rate-limited for the user's own changes, at most one per 10 s for automations.

**Keep this level?** When a level below 10 % of Standard light is set from the panel (on release), a shortcut, the Shortcuts app or the menu, a prompt takes the HUD's place on that display: "Keep this level?" / "Going back in 10 s" (counting down) with **[Go Back]** and **[Keep]**. It can become key (Return = Keep, Esc = Go Back) and is excluded from capture. Without an answer, the engine itself returns the previous level after 10 s, so the revert does not depend on being able to read the screen. VoiceOver announces "Keep this level? Going back in 10 seconds."

---

## 7. Settings window

### 7.1 Structure

- **Window:** an AppKit `NSWindow` hosting a SwiftUI `NavigationSplitView` (Cranny's architecture: we must open any pane from an agent app, a chip, a banner or an intent). Default 860 × 620, minimum 780 × 560; size and last pane restored. Sidebar 190–260 pt (default 210) with `.searchable(placement: .sidebar)`. Follows Light/Dark; on macOS 26+ the sidebar and toolbar get Liquid Glass from AppKit and we add none. ⌘Q quits Overbright, ⌘Z undoes Reset All while the window is open.
- **Sidebar rows:** a 20 × 20 rounded square (radius 5) with a white glyph on a system colour, as in System Settings.

| Pane | Icon | Contents |
|---|---|---|
| General | `gearshape.fill` / gray | startup, menu bar (with Quit), Dock, feedback, updates |
| Displays | `display` / blue | all displays (same level, near full brightness); one section per display: verdict, extra brightness, level, limit, method, calibration, type |
| Automations | `bolt.fill` / green | battery, Low Power, heat note, timer, apps and video, schedule, OLED idle, Focus |
| Shortcuts | `keyboard` / indigo | recorders, step size, Shortcuts app and Control Center |
| Fill Light | `person.crop.rectangle` / orange | preview, switch, display, width, warmth, brightness, camera rule |
| Advanced | `wrench.and.screwdriver.fill` / gray | diagnostics, self-test, other apps, trigger method, recovery, Reset All with Undo |
| About | `info.circle.fill` / gray | version, updates, licence, acknowledgements, privacy, Show Welcome |

### 7.2 Conventions (Cranny's, carried over)

- `Form { … }.formStyle(.grouped)`; `Toggle` with `.switch` and `.controlSize(.small)`; segmented pickers for ≤ 4 options, pop-ups otherwise; sliders always show their value with its unit and ticks at meaningful stops.
- Every non-obvious row has a one-line footnote in `.secondary`.
- A 6-pt accent dot before the label marks a changed value; every row with a value has **Reset to Default** in its context menu; every pane footer has **Reset ‹Pane›…** (confirmation §12.9); Reset All is in Advanced, destructive, confirmed, and undoable until the window closes.
- **Search** matches pane names, row labels and keywords ("HDR", "XDR", "nits", "brighter", "dim", "battery", "shortcut", "camera", "login", "OLED", "flicker", "colors", "quit"); a result opens the pane, scrolls to the row and highlights it with an accent wash fading over 1 s. Deep links `pane#row` serve chips, banners, the menu and Help.
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
| Add extra brightness only near full brightness | switch | **on** | "Extra brightness fades out as you lower the display brightness, so the brightness keys keep their normal range. Turn this off to multiply any brightness." |

**One section per connected display** (header: the display name and a verdict badge, §12.1):

| Row | Control | Default | Options / range | Footnote |
|---|---|---|---|---|
| (verdict) | sentence + fix button | — | — | §12.1 |
| Use extra brightness on this display | switch | built-in XDR and Apple XDR displays on; other HDR and OLED displays off | — | "Dimming below the minimum works either way." OLED: turning it on shows the OLED notice (§12.4). Hidden for displays that cannot boost. |
| Level | `BoostSlider` + readout | Bright room | −1 … 1 | — |
| Limit | segmented | **Safe** | Safe · Peak | The class-specific Safe sentence of §12.2 (`safeLimit`), then "Peak goes up to what macOS allows; it uses more power, and macOS may lower it when the display gets warm." First switch to Peak confirms (§12.4). |
| Method | pop-up | Automatic | Automatic · Color table · Compatibility mode | Automatic: "Overbright picks the method that works on this Mac." With the advisory: "Automatic uses Compatibility mode, because macOS ignores color table changes on this Mac." Compatibility: "Brightens through an overlay. The pointer isn't brightened, and screen recordings may show the overlay." |
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
| Pause for full-screen video (beta) | switch | **on** | — | "Pauses while an app plays video full screen on that display, including browsers." |
| Pause for every full-screen app | switch | off | — | "Includes documents and games, not just video." |
| Pause in games | switch | off | — | "Apps that macOS knows as games, while in front." |
| Pause for these apps | switch + list | on; 12 apps | add · remove · mode per app | "Only the display that shows the app pauses." |
| (each app row) | icon, Finder name, pop-up, remove button | QuickTime Player, TV, IINA, Infuse, VLC, Plex (×2): **While playing (beta)**; Photos, Final Cut Pro, DaVinci Resolve (×3): **While in front** | While in front · While playing (beta) | "While playing" pauses while the app keeps your Mac awake for video. An app no longer installed reads "App not installed" and can still be removed. |
| (add) | **+** menu | — | apps that are running · Choose… · Suggested ▸ (installed video apps, Prime Video, Infuse Enterprise, GeForce NOW, Moonlight) | — |
| **Schedule** | | | | |
| Only allow extra brightness at set times | switch | off | — | "Outside these hours Overbright stays at Standard. Dimming still works." |
| From / To | time pickers | 08:00 / 20:00 | any minute | — |
| **OLED displays** (only when one is known) | | | | |
| Pause extra brightness after no input for | pop-up | **5 minutes** | 1 · 2 · 5 · 10 · 15 · 30 minutes | "Video that keeps your Mac awake doesn't count as no input." |
| **Focus** | | | | |
| (info) | text + **Open System Settings** | — | — | "Choose what Overbright does in each Focus in Focus settings: leave it alone, turn it off, or turn it on at a level." |

### 7.6 Shortcuts

Key caps in this pane, in the menu and in all copy are rendered from the live binding in the current keyboard layout (§16); the defaults below are shown with US key caps.

| Row | Default | Footnote |
|---|---|---|
| Turn Overbright on or off | ⌃⌥⌘B | — |
| Brighter | ⌃⌥⌘= | — |
| Less Bright | ⌃⌥⌘- | "Stops at Standard first; press again to dim below it." |
| Max | none | — |
| Dim Below Minimum On or Off | ⌃⌥⌘9 | "Dims every display to your last dim level, or brings them back." Shown as "Dimmed" in the menu and the HUD. |
| Back to Standard | ⌃⌥⌘0 | "Turns Overbright off at once, from anywhere. Your levels are kept for next time." |
| Fill Light | none | — |
| Step size | segmented: **Regular** · Fine | "Each press of Brighter or Less Bright changes the light by about a fifth (Regular) or about 6 % (Fine)." |

- **Recorder** (the owner's own, from Cranny): click a row to record; Esc cancels; Delete clears; one recorder at a time; every hot key pauses while recording; conflict lines in place: "Another app already uses this shortcut.", "Already used for Brighter.", "macOS uses this for ‹name of the system shortcut›." Clearing **Back to Standard** asks first: "Without this shortcut, use Turn Off Overbright in the menu or the panel. It does the same, a little more slowly." [Clear Shortcut] [Cancel]
- **Shortcuts app and Control Center:** "Overbright's actions are in the Shortcuts app: turn it on or off, set extra brightness, dim, pause, and more." **Open Shortcuts**. In builds without the control: "To put Overbright in Control Center or the menu bar, make a shortcut with Turn Overbright On or Off, then add Control Center's Run Shortcut control."

### 7.7 Fill Light

A preview at the top: a 200 × 125 pt miniature of the chosen display with the frame drawn to scale in the chosen warmth (an SDR approximation).

| Row | Control | Default | Range | Footnote |
|---|---|---|---|---|
| Fill Light | switch | off | — | "Lights your face on video calls with a glowing frame around the screen." |
| Display | pop-up | Built-in Display (else the main display) | connected displays | — |
| Width | slider + value | **48 pt** | 16–120 pt | — |
| Warmth | slider (Cool ↔ Warm) + value | **5,100 K** | 6,500–3,000 K | — |
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
| Apps that change display colors or brightness | live list: icon, name, kind ("Brightness app", "Color app", "May change brightness") and, for color apps and "may change" apps, an **Always continue** switch | — | "None running." when empty. Under brightness apps: "Overbright can't run next to another brightness app on the color table. Use Compatibility mode on a display to run alongside it." |
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
- **Skip** (and closing the window) applies every default, including the login item ("Open Overbright, keep it off", registered with `SMAppService.mainApp`). **Done** applies the choices of step 3.
- Shown at the first launch that is not a login launch (after the launch check and the move-to-Applications offer) and from Settings ▸ About; never again once finished or skipped.

| Step | Headline | Body (exact English) | Stage and interaction |
|---|---|---|---|
| 1 Hello | Use your display's extra range | "Your display can show light brighter than ordinary white. Overbright lets everyday content use that range, so the screen stays readable in a bright room or in sunlight. For the most light, turn your display brightness all the way up first; Overbright adds to it. Drag the divider to compare." | **Before/after card:** a sample page (text on white) at Standard on the left and at Bright room on the right of a draggable divider, rendered as EDR content inside this window only (`EDRPreviewSurface`). Caption: "Only this card is brighter. It's a preview: the real result depends on your display." Without a capable display: a static illustration and "None of your displays has extra range right now. The next step shows why." The card pauses while the window is hidden. |
| 2 Displays | Your displays | "Overbright checks what each display can do." | One row per display: glyph, name, verdict (§12.1), fix button, **Use extra brightness** switch (OLED notice when turned on). The rows re-evaluate whenever the displays change (for example after HDR is turned on in System Settings) and cross-fade (`contentSwap`). |
| 3 Defaults | How Overbright behaves | "Extra light uses more power, so Overbright steps back on its own. Choose how it starts." | Switches: **Pause on battery below 20 %** (with the level pop-up), **Pause in Low Power Mode**, **Pause for full-screen video**; note: "It also backs off when your Mac gets warm." Then three option cards for login: **Open and turn on** · **Open, keep off** (selected, "Recommended") · **Don't open at login**. |
| 4 Find it | Where to find Overbright | "Overbright lives in the menu bar." | Rows: the menu bar symbol ("Click for the panel, right-click for the menu"); key caps of the live **Turn on or off**, **Back to Standard** and **Dim Below Minimum On or Off** shortcuts in the current keyboard layout (rows without a registered shortcut are left out); "Shortcuts app and Control Center" with the Run Shortcut recipe; "Open Overbright again from Finder or Spotlight to see Settings." |
| 5 Done | You're set | — | **Check for updates on GitHub** switch (off; only when configured); buttons **Turn On Overbright** (primary; hidden when no display can boost) and **Done**. |

The calibration check is not part of Welcome: it asks for changes that are unsafe while boosted and only makes sense once extra brightness is in use. It is offered once, as the calibration tip card, after the first boost (§5.3).

---

## 9. Calibration

A guided check per display, from Settings ▸ Displays, the card's context menu or the one-time tip. It answers two questions: does the screen really get brighter (or does macOS ignore table changes on this Mac), and does the table work on encoded values or on linear light. It also records an optional colorimeter reading.

- **Starting it returns every display to Standard first** (neutral tables, triggers removed) and holds Overbright off until it ends; the window then brightens only the display under test, step by step.
- **Window:** borderless, full screen on the display under test, our colour space set to the screen's so code values reach the framebuffer unchanged; a **black** surround; four **100 × 100 pt** patches; instructions in a dark card at the top (light text on near-black), so an over-bright moment lights only small areas. Esc always restores at once and closes.
- **Before starting** (a checklist with live state where we can read it): "Plug in your Mac" (power source) · "Set brightness to maximum" · "Overbright is at Standard now, so it's safe to change these: turn off Automatically adjust brightness, True Tone and Night Shift in Displays settings." (asked, cannot be read) · "No other color or brightness app is running" (live) · "Your Mac is cool" (thermal state, live). **Start** is enabled when the live items pass.
- **Step 1, Does it get brighter?** The display under test switches between Standard and ×1.3 three times, at most once per 1.5 s, with a label "Standard" / "Brighter". Question: "Did the screen get brighter when the label said Brighter?" **Yes** · **No** · **Show Again**. **No** → "macOS seems to ignore color table changes on this Mac. Use Compatibility mode on this display?" **Use Compatibility Mode** · **Keep Color Table** (Compatibility mode repeats step 1).
- **Step 2, Where does white stop?** The four patches at 85 %, 90 %, 95 % and 100 % grey. Overbright raises extra brightness in small steps every 0.4 s. "Watch the two squares on the right. Press Space the moment you can no longer tell them apart." At 1.15 × the point where they usually merge, the sweep pauses: "The two squares on the right usually merge before this point. Keep going?" **Keep Going** · **Stop**. The sweep ends at the latest at 1.15 × the linear prediction, and on Space, Esc, 60 s, any lock, occlusion or headroom drop; it always returns to Standard at once.
- **Step 3, One more check** (only when the merge was near the linear prediction): "For two seconds the squares are shown much brighter. Can you still tell the two squares on the right apart?" **Show** · then **Yes, They Look Different** · **No, They Look the Same** · **Show Again**. Only "Yes" can record the linear result; it is impossible to see a difference there if the table works on encoded values.
- **Decision** (ARCHITECTURE.md §5.2): a merge nearer the encoded prediction → "standard curve"; nearer the linear prediction **and** confirmed in step 3 → "linear"; anything else (unconfirmed, within 15 % of the midpoint, stopped early, Space never pressed, the sweep reached its end) → "inconclusive", and the safe default stays.
- **Results (exact English):**
  - "Standard curve confirmed. Overbright keeps its default for this display."
  - "This display responds in linear light. Overbright can now use more of its range."
  - "The result wasn't clear, so Overbright keeps its safe default. You can try again."
  - Always followed by: "If you use Automatically adjust brightness, True Tone or Night Shift, turn them back on now, before you turn on extra brightness."
- **Colorimeter (optional disclosure):** "I have a colorimeter" reveals a field "SDR white: [ ] nits" (measured at Standard). A value makes the nits readout and the Safe cap exact for this display.
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

Advisories (a second line under the verdict): `compatibilityModeAdvised` "On this Mac, macOS ignores color table changes, so Overbright uses Compatibility mode." · `oledCare` "OLED display: extra brightness stays lower and pauses after 5 minutes without input." · `autoBrightnessInteracts` (Settings only, §7.4) · `notCalibrated` "Not calibrated. Numbers are estimates, and Overbright uses a safe default."

"High Dynamic Range", "Displays", "Automatically adjust brightness", "True Tone", "Night Shift", "Preset", "Menu Bar", "Allow in the Menu Bar", "Battery", "Focus" and "Login Items" are macOS's own names and must match macOS in every language (German: "Hochkontrastbild" for High Dynamic Range).

### 12.2 Status chips (panel, §5.7; per-display reasons only)

| Reason or phase | Chip | Glyph | Colour | Popover sentence | Actions |
|---|---|---|---|---|---|
| arming, gating | Preparing… | (progress) | info | "Overbright is unlocking extra range on this display. The first time takes a few seconds." | — |
| failed, no headroom (first) | No extra range | `exclamationmark.triangle.fill` | danger | "macOS didn't make extra range available. This can happen right after waking up, or when HDR is off." | Try again · Learn more |
| failed, after two tries in this session | No extra range | `exclamationmark.triangle.fill` | danger | "macOS still didn't make extra range available." | Try again · Run self-test… · Use Compatibility mode (only where the compatibility advisory applies) · Learn more (Help: "The screen didn't get brighter") |
| `boostNotEnabled` | Extra brightness off | `sun.max` | neutral | "Extra brightness is off for this display. Dimming still works." | Turn on |
| verdict of a dim-only display | its badge (§12.1) | `display` | neutral | its sentence | its fix |
| `headroom` | Limited by macOS | `sun.min` | info | "macOS allows ×1.55 right now. It lowers the extra range when the surroundings are bright, the display is warm or the battery is low." | — |
| `hdrSuppressedByMacOS` | Limited by macOS | `sun.min` | info | "macOS is limiting HDR right now." | — |
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
| `tripped` (attributed drift) | Stopped: ‹App› | `exclamationmark.triangle.fill` | danger | "‹App› changed the colors of this display." | Continue anyway |
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
| conflict, booster (S1) | "Paused because ‹App› also changes display brightness. Quit it, or use Compatibility mode, which works alongside it." | Use Compatibility mode |
| conflict, color app (S2) | "Paused because ‹App› changes display colors. Night Shift gives warm light without a conflict." | Continue anyway |
| foreign table at launch | "Another app changed the display colors and they couldn't be reset. Change the color profile or preset in Displays settings and back, or log out." | Open System Settings |
| flicker stop | "Overbright stopped on ‹Display› to prevent flicker." | Try again |
| unattributed drift | "Another app keeps changing the colors of ‹Display›, so Overbright stopped there." | Try again |
| attributed drift | "‹App› changed the colors of ‹Display›, so Overbright stopped there." | Continue anyway |
| Focus | "Off because of the current Focus." | Open System Settings |
| heat | "Paused because your Mac is hot. Overbright continues when it cools down." | — |
| Low Power Mode | "Paused because Low Power Mode is on." | Change power rules… |
| battery | "Paused because the battery is below 20 %." | Change power rules… |
| on battery | "Paused while on battery." | Change power rules… |
| schedule | "Extra brightness is allowed from 08:00 to 20:00." | Change hours… |

The same sentence is the first, disabled line of the right-click menu, and its primary action the second line in title case ("Resume", "Use Compatibility Mode", "Continue Anyway", "Open System Settings", "Try Again", "Change Power Rules…", "Change Hours…").

### 12.4 Sheets and alerts (title-case buttons)

- **OLED notice** (turning on extra brightness for an OLED display, from the switch, Turn on, or the first move into the boost half) — "Use extra brightness on this OLED display?" / "Bright content that stays in one place for a long time, like the menu bar, can wear OLED panels unevenly. Overbright keeps extra brightness lower on OLED displays and pauses it after 5 minutes without input." [Turn On] [Cancel]
- **First use of Peak** — "Use Peak on ‹Display›?" / "Peak lets the whole screen go above the level the display can hold for long. It uses noticeably more power and makes the display warmer; macOS lowers it when needed." [Use Peak] [Cancel]
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
| Dim level | "Dimmed · " + percent of Standard light, `FormatStyle` | Dimmed · 25 % / Затемнено · 25 % |
| Temperature | `Measurement<UnitTemperature>` in kelvin | 5,100 K / 5 100 K |
| Durations | `Duration.UnitsFormatStyle` | 23 min / 23 мин |
| Time of day | locale 12/24 h | 2:20 PM / 14:20 |
| Key caps | the live binding through the current keyboard layout | ⌃⌥⌘B (US) / ⌃⌥⌘B (German) |

### 12.6 Help (a small window, from "⋯ ▸ Help", the menu, Settings, Welcome and every "Learn more")

Each answer has an anchor; "Learn more" links open the window scrolled to it.

1. **The screen didn't get brighter** (`no-extra-range`). "Turn the display brightness all the way up; Overbright adds to it. Check the display's verdict in Settings ▸ Displays. On a MacBook Pro, use the 1600-nit preset. On some Macs, macOS ignores color table changes: choose Calibrate… to check, or try Compatibility mode. Run Self-Test… shows what macOS reports."
2. **Colors look washed out, or HDR video looks flat** (`washed-out`). "While extra brightness is on, HDR highlights can't go above the brightened white. Overbright pauses for full-screen video and for video players; add other apps in Settings ▸ Automations."
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
- **Get State dialog:** "Overbright is on. Built-in Display: Bright room · ×1.29. MPG322UX OLED: Dimmed · 25 %." / "Overbright is off." (the result value is on/off).
- **Errors:** "Overbright is still starting. Try again in a moment." · "That display isn't connected." · "This display can't show extra brightness." · "This display can't be dimmed."
- **Focus filter:** title "Overbright"; parameter "Overbright" with the options "Leave Alone", "Off", "On", and "Level" (shown with On); display representation "Overbright: Leave Alone" · "Overbright: Off" · "Overbright: On at ‹Level›".
- **App Shortcuts:** "Turn \(.applicationName) on or off" (short title "Turn On or Off", image `sun.max`) and "\(.applicationName) back to Standard" (short title "Back to Standard", image `sun.min`).
- **Control Center** (dormant control): title "Overbright", subtitle "Extra brightness".

### 12.9 HUD lines, announcements and confirmations

- **HUD values:** "Bright room · ×1.29", "×1.42", "Standard", "Dimmed · 25 %", "Off".
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
| Chrome | `ellipsis` · `ellipsis.circle` · `chevron.down` · `chevron.right` · `gearshape.fill` (11) · `info.circle.fill` · `questionmark.circle` · `keyboard` · `wrench.and.screwdriver.fill` (11) · `stethoscope` (11) · `link` · `doc.on.doc` · `square.and.arrow.down` · `arrow.counterclockwise` · `arrow.clockwise` · `power` |
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

**Concept.** A white screen whose light does not stay inside its frame. On a graphite squircle sits a rounded, slightly tilted-up white rectangle (the screen at ordinary white); from its upper trailing corner a soft bloom of light spills **over the frame's edge** into the dark, brighter than the white rectangle itself. It reads as "brighter than white", which is what the app does, and stays legible at 16 px as a white tile with a glowing corner on a dark ground.

- **Colours:** body graphite (Light: P3 (0.17, 0.18, 0.21) → (0.07, 0.075, 0.09) top to bottom; Dark: (0.05, 0.05, 0.06) → (0.03, 0.03, 0.04)); screen white (P3 0.96); bloom: a white core fading through a pale warm tint (#FFE7C2 at 40 %) to transparent; a 3-pt keyline in `boostWarm` dark (#FFB020) along the stretch of the screen's edge that the bloom crosses (the product's one warm accent as the mark's signature).
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
| **Increase Contrast** | `highContrast` palette: opaque cards with a full-strength separator hairline, darker or lighter `boostWarm` (§2.1), `labelColor` detent, ticks, dim fill and hatch lines, the focus ring at full accent. |
| **Differentiate Without Color** | Colour never carries meaning alone: chips always have words; the boost half has preset ticks and the dim half none; "not allowed now" and "nothing is brighter" are a hatch, not a colour; the allowed-now marker is a shape; the HUD always shows its value as text; the status symbol's states differ in shape (outline, filled, dotted rays, small disc with dots, badges). |
| **VoiceOver** | §12.7; the panel is one container "Overbright"; each card a container named after its display, with its context-menu items as custom actions; the slider adjustable with named stops and canonical values; decorative layers (fills, Fill Light, the welcome card's light) hidden; level changes and automation stops announced. |
| **Keyboard and Full Keyboard Access** | §5.12 for the panel (every chip, "Why?", Turn on and the Fill Light card are reachable; ⌃↩ opens a card's context menu); Settings and Welcome follow Cranny's maps; every action has a key path; nothing is hover-only (the value tag and help tags repeat what VoiceOver and the readout say). |
| **Pointer and motor** | 28 × 24 pt hit targets; slider snapping only on slow drags; scroll-wheel adjustment in stops. |
| **Time limits** | The HUD is informational. The Undo of Reset All stays available as a button until the Settings window closes and through ⌘Z (the banner itself fades after 10 s). "Keep this level?" reverts after 10 s on purpose: going back is the safe direction, and any Overbright shortcut or Return keeps the level. |
| **Flashing (WCAG 2.3.1)** | §3.4. |
| **Photosensitivity** | Brightness changes ramp; the calibration flips are slow and announced; Back to Standard is always one shortcut away; very dark levels ask before staying. |

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
| Compatibility mode | the overlay method | "fallback", "overlay" |
| Fill Light | the edge light | "ring light" |
| Back to Standard | the instant off action | "panic", "reset brightness" |
| extra range | headroom, in user copy | "headroom" outside Advanced and diagnostics |
| display | a screen | "monitor" (except "external display"), "screen" for a device |
| Pause / Paused | temporary stop by a guard or the user | "disabled", "turns off" for a pause |

- **Denylist (ARCHITECTURE.md D3):** no competitor product or company name in any key, value or translator comment, in any language; other apps' names appear only at runtime. No reference to Launchpad (removed in macOS 26).
- **Numbers and units:** always `FormatStyle` / `Measurement` (§12.5); "≈ %lld nits" has plural forms in every language.
- **Length:** Russian runs 15–35 % longer; constrained strings are measured in every language by fit tests (English and a pseudo-long locale during development, all 35 in WP15), and a failure is fixed by wording first: chips ≤ 280 pt (their own line), the footer row ≤ 292 pt for all three chips (else glyph + value), readout ≤ 200 pt, value tag ≤ 240 pt (a "small gain" suffix may wrap), HUD text ≤ 200 pt, Safe/Peak segments.
- **Right to left** (Arabic, Hebrew): the panel, cards, slider, footer and Settings mirror; the status symbol does not; names inside sentences are bidi-isolated.
- **35 languages** from day one; Russian is the owner's review language and the pivot for the rest.

---

## 17. Energy budget (a release gate)

Displays use more power when brighter: that is the product, and the README says so. The budget below is about Overbright's **own** work, measured with Activity Monitor (5-minute average), `top -stats pid,cpu,idlew,power`, `footprint` and `powermetrics` before each release.

| State | Allowed work | Target |
|---|---|---|
| Off (nothing dimmed) | event notifications only, and the one-shot work an event asks for (the full-screen re-check 0.6 s after a Space, app or screen event, which ends a full-screen or app pause); no periodic timers or tasks, no windows, Metal devices or IOPS percent source | 0 wake-ups/s; Energy Impact 0.0; < 40 MB resident |
| Preparing (first arm) | 10 Hz headroom reads; ≤ 7 rungs × 2.5 s once per display and macOS build, then ≈ 1–3 s | — |
| Boosted, steady (T1/T2) | 2 s drift check (one table read, one headroom read, ≤ 2 ms window list when a full-screen rule is on) + the 2 s hang ping; a ≤ 3 s 10 Hz poll burst only after a raise that waits for range | ≤ 1.5 wake-ups/s; < 0.1 % CPU; no GPU work after the first frame |
| Boosted with T3 | + one tiny present every 5 s | measured and reported in the release notes |
| Ramping | ≈ 60 table writes/s for ≤ 0.4 s | — |
| Panel open | redraw on change only; the allowed-now marker ≤ 4 Hz | < 2 % CPU while dragging |
| Compatibility mode | a full-screen blend in WindowServer on every redraw | measured (H-S1) and stated in Settings |
| Fill Light | one static layer; no redraw unless settings change | — |

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
10. **Always escapable:** Back to Standard on a shortcut, every launch shows its UI, Quit everywhere, "Keep this level?" for very dark levels, `--off`, `--restore-gamma`, Force Quit restores.
11. **Compatibility mode** for Macs where macOS ignores color table changes, and next to another brightness app.
12. **One control** for dimming below the minimum and brightening above the maximum, with Dim All Displays on its own shortcut, extra brightness that respects the brightness keys, and a Fill Light that turns on with the camera.

---

## Appendix A — Components (`OverbrightDesign`)

| Component | Purpose | Key behaviour |
|---|---|---|
| `BoostSlider` | the level control (§5.5) | detent, shown ticks, fills over the track, the allowed-now marker and hatch, value tag in canonical units, snapping with haptics, keyboard steps in stops, adjustable VoiceOver element with named stops and custom content, RTL mirroring, disabled halves |
| `ReadoutText` | the readout line (§5.6) | rounded monospaced digits, estimate prefix, no numeric content transition |
| `StatusChip` | per-display limit and phase chips (§5.7, §12.2) | a button: glyph + text on a tint; popover with one sentence and its actions |
| `GuardChip` | footer chips (§5.9) | a menu button showing its setting |
| `PausedBanner` | the one banner (§5.8, §12.3) | glyph, sentence, up to two buttons |
| `EDRPreviewSurface` | the Welcome card (§8) | EDR content in our own view, draggable divider, SDR stand-in under `--qa-simulate`, paused when hidden |
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
- `NSGlassEffectView` (macOS 26) with `.standard` and `.clear` styles: present in the macOS 27 SDK headers.
- Numbers in copy (×1.67, ×1.40, ≈ 1,000 nits only with a trusted SDR white, ×1.55, 1.61 / 3.00, the preset gains) match ARCHITECTURE.md §5.3 and §5.6.
- Nothing here has been rendered yet; WP9/WP10 snapshots are the first visual verification.
