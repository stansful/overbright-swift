# UX landscape and why Overbright is designed the way it is

*Public summary for contributors, 2026-10-16. Sources are public: vendor sites and FAQs, Mac App Store listings and customer-review feeds (US, GB, DE, NL, CA, AU; about 60 reviews read), Setapp reviews (20), press, Product Hunt, AlternativeTo, GitHub READMEs, licences and issue titles, and Apple's Human Interface Guidelines. Reviews are paraphrased. No competitor's code, assets or UI text was used. This folder is exempt from the docs denylist rule (ARCHITECTURE.md D3); the rest of the repo never names competitors.*

---

## 1. The incumbent: Vivid by Lumen Digital (public facts)

- **What it is:** a menu bar app that raises everyday brightness above the SDR maximum on Apple's XDR displays, launched in 2022 and sold directly, through Setapp and on the Mac App Store (now a free download with a $4.99 in-app licence; earlier €10–€29.99). Its unlicensed mode boosts only half of the screen, with an upsell.
- **Supported, per its listing:** 14″/16″ MacBook Pro with M-series Pro/Max chips, Pro Display XDR, and since early 2026 Studio Display XDR. Not supported: MacBook Air, Intel Macs, 13″ MacBook Pro, the non-XDR Studio Display, third-party monitors.
- **Features visible to users:** an on/off toggle (menu bar, a global shortcut), a small on-screen indicator when the level changes, a choice of displays (all, built-in only, external only), syncing displays, a "fallback" switch for troubleshooting, a mode that dims below the macOS minimum, battery / Low Power / timer automations, three launch-at-login behaviours, Shortcuts actions, a short onboarding, warnings about incompatible apps, an optional Dock icon.
- **Its own FAQ** asks users of macOS 26 to switch off automatic brightness, says HDR video can look oversaturated while it is on, and blames presets, heat and ambient light when users do not reach the advertised brightness.

### 1.1 What users complain about (paraphrased)

| Theme | Reports |
|---|---|
| Breaks after macOS updates or on new hardware | stopped after 15.4; "doesn't work with Tahoe"; one update broke Sequoia; stopped on M5 unless auto-brightness is on; no difference on Studio Display XDR |
| Lid close, sleep/wake, lock | dim again after closing the lid with shortcuts not helping (force quit needed); re-enable after every logout; corrupted picture after wake; brightness at 0 after sleep with a second display |
| Colour | washed-out colours and over-strong whites now and then; oversaturated HDR video (its FAQ agrees) |
| Steps | the boost is applied in big, bouncing steps |
| Conflicts | f.lux flicker and reverting within a second; video-player stutter above 100 % |
| Trust and money | the half-screen trial called "scam" and "misleading"; no way to quit the trial popup in older versions; licence restore problems; price gaps between stores |
| Privacy | a reviewer's firewall flagged background traffic, while the store's privacy label says no data is collected |
| Menu bar | the coloured icon (users asked for a monochrome one); the icon hidden on crowded notched menu bars (its FAQ's first entry) |
| Heat and battery | the screen gets warm; battery drains faster (press and FAQ agree) |

### 1.2 What users praise

Readability outdoors and in bright rooms is behind every five-star review. Users like that it is system-wide, simple and one-purpose, that it can turn itself on at login, and that a click toggles it.

## 2. Competitors and open-source alternatives (October 2026)

| Product | Licence / price | Approach (as described publicly) | Notable | Weak spots (public reports) |
|---|---|---|---|---|
| BrightIntosh | GPL-3.0; App Store build with a small unlock | small HDR trigger + extended range | slider, shortcuts, battery and power automations, timer, CLI, incompatible-app warning, report generator | visible trigger dot; a flicker regression; overexposure after lid close on M5; full-screen video dropping the boost; high memory on some Macs; f.lux conflicts |
| Lunar | MIT licence file; Pro parts encrypted; Pro $23 | multi-purpose display tool; XDR brightness and a "full range" mode | sub-zero dimming, presets, sync | large, paywalled |
| BetterDisplay | proprietary; Pro ≈ $22 | four XDR/HDR methods ranked; colour-table upscaling clips HDR | combined slider with hardware markers, calibration patterns, third-party HDR displays | complexity; CPU spikes from frequent HDR notifications |
| DisplayBuddy | proprietary | an "UltraBright" mode | DDC, presets, schedules | — |
| LumiMax, LUMEL, Luxa, MaxBrightness, BrightLight, Brightness Plus, Solis, TotalXDR | proprietary, $0–$18 | EDR overlays, screen-capture redraw (Luxa needs Screen Recording), or undisclosed | battery and timer guards, compare modes behind paywalls, "no network" claims, thermal soft limits | thin documentation; several repeat the half-screen trial |
| BrightXDR | GPL-3.0, unmaintained | Metal overlay | — | loses HDR on Space switches; white Mission Control thumbnails |
| xdr-boost | MIT | multiply overlay, watchdog, always starts off, `--kill` switch | — | CLI-ish, no guards |
| Many small 2026 projects (xdr-light, glowgoblin, macbright, xdr-brightness, XDR-Booster, Lucent…) | mostly MIT | overlay or trigger + table | — | weekend projects: no lifecycle hardening |

## 3. What the landscape tells us

- **The core is a commodity.** Every product can raise EDR headroom. They differ in lifecycle robustness, honesty about limits, guards, preview UX and privacy.
- **No free, polished, native option exists.** The best-maintained open-source one is GPL and functional rather than refined.
- **Nobody ships** a Control Center control, a Focus filter, a real per-display headroom readout, a flicker-safety guarantee or careful handling of external OLED panels.
- **Each technique has a visible cost:** tables clip HDR and fight warm-light tools; overlays show in captures and flicker in Mission Control; screen-capture redraw needs a heavy permission. The UX must let users ignore which one is active while seeing what limits them.

## 4. Platform design notes (macOS 26 Tahoe, 27)

- **Liquid Glass** is for controls and navigation floating above content, used sparingly; not for the content layer; regular variant for panels with text; it adapts to Reduce Transparency and Increase Contrast. macOS 27 adds a global glass-opacity slider and a fixed window corner radius: never hard-code translucency or radii.
- **Menu bar extras** (HIG): a template symbol; a menu unless the feature is too complex; let people choose whether the extra shows; never rely on it being visible. macOS 26's "Allow in the Menu Bar" can hide any extra, and an app whose only UI is a SwiftUI `MenuBarExtra` is terminated when the user removes it.
- **Controls** (macOS 26+): third-party Control Center and menu bar controls are buttons or toggles only (no sliders).
- **App Intents** work on macOS (App Shortcuts phrases are limited there); Spotlight on 26+ runs app actions with parameters; `SetFocusFilterIntent` gives per-Focus behaviour.
- **Sliders** (HIG): live feedback, tick marks for meaningful points, labelled ends, a value tag.
- **Onboarding** (HIG): teach by doing, keep it short and skippable, never put licensing in it.

## 5. Improvements and where they landed

| # | Improvement | Why (source) | Where |
|---|---|---|---|
| 1 | Free with nothing to unlock | trial anger, licence failures | README; no licence code |
| 2 | Privacy by construction | background-traffic report; "no network" is a selling point | ARCHITECTURE D2 |
| 3 | A lifecycle state machine that always lands on a neutral screen | lid, sleep, lock, logout complaints; repeated fixes in changelogs | ARCHITECTURE §4, §7.4 |
| 4 | Always escapable; safe start | hidden icons, force-quit stories, trial popups without Quit | DESIGN §1 principle 5, §4.4 (every manual launch shows UI, Quit everywhere, hidden-icon detection); ARCHITECTURE D7, D13 |
| 5 | Per-display control with honest numbers | "didn't reach 1600 nits", invisible ambient and heat caps, wanting to see how far beyond Standard | DESIGN §5 |
| 6 | Smooth ramps and a flicker guarantee | a competitor's strobing regression; f.lux flicker | DESIGN §3.3–§3.4; ARCHITECTURE §5.7–§5.8 |
| 7 | An honest compatibility check with fixes | unsupported-hardware one-star reviews | DESIGN §12.1 |
| 8 | Conflict awareness | f.lux and brightness-manager conflicts | ARCHITECTURE §7.2 |
| 9 | Guards on by default with visible reasons | battery and heat worries | ARCHITECTURE §6 |
| 10 | Real-HDR and full-screen awareness | oversaturated HDR video; full-screen video dropping the boost; people who read full screen outdoors | ARCHITECTURE §6.5, §7.3 (pause for full-screen video, not for every full-screen window) |
| 11 | No visible artefacts | trigger dots, white Mission Control thumbnails | ARCHITECTURE §4.7 |
| 12 | A HIG-correct menu bar extra | coloured icon complaints | DESIGN §4 |
| 13 | Accessibility and 35 languages | the incumbent is English-only; nobody documents VoiceOver | DESIGN §15–§16 |
| 14 | Shortcuts actions and a Focus filter | parity plus a gap nobody fills | ARCHITECTURE §7.7 |
| 15 | Global shortcuts with a recorder | brightness keys are the best-loved interaction; shortcuts need no permission | DESIGN §7.6 |
| 16 | Interactive before/after onboarding without a nag | the half-screen idea is good, the paywall is not | DESIGN §8 |
| 17 | External HDR and OLED care | the owner's QD-OLED; competitors ignore third-party monitors | ARCHITECTURE D8 |
| 18 | Dim below minimum in the same control, plus Dim All on its own shortcut | well-liked across tools; the incumbent's one-step dim mode | DESIGN §4.3, §5.5 |
| 19 | Fill Light with camera automation | an edge light for calls exists in several tools | DESIGN §11 |
| 20 | Compatibility mode | Macs where table writes do nothing | ARCHITECTURE §7.5 (*as built: built, then removed 2026-10-21; the overlay turned the owner's built-in white*) |
| 21 | Brightness keys keep their range | "big, bouncing steps" complaints | ARCHITECTURE §5.4 (extra brightness only near full brightness; *as built: default off since 2026-10-20*), DESIGN §7.4 |
| 22 | Explained automatic stops | an unexplained dim reads as "it broke" | DESIGN §6 (HUD reasons for timer, battery, Low Power, heat, schedule) |
| — | **Later (v1.x):** brightness-key integration (needs Accessibility), a Control Center control in ad-hoc builds, sunrise/sunset schedules, "learn my preference", a battery-impact estimate, a CLI and a Homebrew cask | | ARCHITECTURE §1.2, §11.3 |
| — | **Won't:** trials, licences, accounts, analytics, remote config, Screen Recording or camera-based sensing, overriding macOS's heat and power limits | | |

## 6. The name

"Overbright" is a graphics term for rendering brighter than white, which is exactly what EDR does. A quick screen (Mac and iOS App Store search, GitHub, web) found no app or trademark collision; it is descriptive, which makes it a weak trademark, acceptable for open source. This is not legal clearance: a USPTO/EUIPO search in classes 9 and 42 is due before the first public release. Names rejected during the screen for collisions include Headroom, Lucent, Candescent, Daybright, Glint, Gleam, Sunlit, Floodlight, Solstice and Daylight.

## 7. The owner's machines (QA planning)

- **MacBook Pro 16″ M4 Max (Mac16,5):** SDR up to 1000 nits outdoors, XDR 1000 nits sustained full-screen and 1600 peak (below 25 °C). The gain is smaller than on M1–M3 and mostly indoors or with auto-brightness keeping SDR lower; the app should say so. The lid is usually closed, so lid-open and lid-close lifecycle testing is a must.
- **MSI MPG322UX QD-OLED:** with macOS HDR off, headroom is 1.0 and nothing can be boosted ("Turn on High Dynamic Range"). With HDR on, about 1.76× of headroom, but OLED full-field white is limited near 265 nits; burn-in care matters more than nits. A macOS 26 bug can report headroom 1.0 after wake until HDR is toggled.

## Sources

Vendor sites and FAQs (getvivid.app incl. its support JSON, brightintosh.de, lunar.fyi, betterdisplay.pro, displaybuddy.app, getlumel.app); Mac App Store listings and review feeds; Setapp reviews; Cult of Mac, 9to5Mac, HowToGeek, iMore, ifun.de; Product Hunt; AlternativeTo; Firecore forum; GitHub repositories (licences via the GitHub API; issue titles); Apple HIG (The menu bar, Materials, Controls, Onboarding, Sliders, App Shortcuts); Apple developer documentation for `MenuBarExtra`, `glassEffect`, `ControlWidgetToggle`, `SetFocusFilterIntent`; 9to5Mac and MacRumors coverage of macOS 26 and 27; MSI's MPG 322URX specifications. <!-- denylist-ok -->
