# Display and headroom facts

*Public reference for contributors, 2026-10-16. "Measured" values were read on the project owner's Mac (MacBook Pro Mac16,5, M4 Max, macOS 27.0.1; external MSI MPG322UX QD-OLED) with read-only tools: `NSScreen` properties, `CGGetDisplayTransferByTable`, `ioreg`, and WindowServer's own log lines (`log show`, subsystem `com.apple.coreanimation`, category `Brightness`). Nothing changed a display's state. "Spec" values are Apple's or the vendor's published specifications. "Inferred" values follow from the formula below and need the hardware session.*

---

## 1. The rule behind `maximumPotential…`

`maximumPotentialExtendedDynamicRangeColorComponentValue ≈ (preset or panel peak in nits) ÷ 100`, with built-in XDR panels capped at **16**.

- Built-in M4 Max in the 1600-nit preset: **16** on every log line; the device tree's `EDRPotentialHeadroom` reads 16.0 (16.16 fixed point) [measured].
- MSI MPG322UX with macOS HDR on: **4.6549** = its EDID/DisplayID maximum luminance 465.49 nits ÷ 100 [measured].
- So the value is **not a model signature**: any 1600-nit display reads 16, a DisplayHDR 1000 monitor reads 10, a 500-nit preset reads 5. Exact-value whitelists and display-name checks are wrong; names are also localized by macOS (the built-in's name is translated in a Russian UI).

`maximumExtendedDynamicRangeColorComponentValue` (current) is the **granted** headroom: granted peak ÷ current SDR white. It is 1.0 or about 1.2 when nothing requests EDR on macOS 27, and rises only while something on screen requests it [measured].

## 2. The matrix (macOS 27)

| Display and preset | potential | current: idle → with an EDR request | reference | Basis |
|---|---|---|---|---|
| Built-in M4 Max, Apple XDR Display (P3-1600 nits) | **16.0** | 1.0 (often ≈ 1.2) → up to min(16, peak ÷ SDR): 2.67 at 600 nits SDR, 1.6 at the 1000-nit outdoor SDR maximum; 9.09 seen at 97.8 nits SDR | 0.0 (measured on an M1 Max by another project; to read on M4) | measured |
| Built-in, Apple Display (P3-600 nits) | ≈ 6.0 | 1.0 → 600 ÷ SDR; **1.0 at full brightness** | 0 | inferred |
| Built-in, Apple Display (P3-500 nits) | 5.0 | 1.0 → 500 ÷ SDR; 1.0 at full brightness | 0 | inferred |
| Built-in, HDR Video (P3-ST 2084) reference | ≈ 10 | fixed ≈ 10 | > 0, ≈ 10 | inferred |
| Built-in, SDR reference presets (sRGB, BT.709, …) | 1.0 | 1.0 | 0 or 1 | inferred from Apple docs |
| Pro Display XDR (P3-1600) | 16 expected | → 3.2 at 500 nits SDR (WWDC) | 0 | spec + inferred |
| Studio Display XDR (P3-2000) | 16 (capped) or 20 | → 2.0 at 1000 nits SDR | 0 | spec + inferred |
| MSI MPG322UX OLED, HDR **on** | **4.6549** | 1.0 (sometimes 1.2) → **1.756** (465.49 ÷ 265.05) | not read (0 expected) | measured |
| MSI MPG322UX OLED, HDR **off** | **1.0** | 1.0 | **0.0** | measured |
| LCD built-ins (MacBook Air, 13″ MacBook Pro) | 2.0 | ≈ 1.25 at full brightness, up to 2.0 when dimmed | 0 | forum report + inferred |
| Sidecar, Reference Mode off / on | 1.0 / ≈ 10 | 1.0 / fixed ≈ 10 | 0 / unverified | WWDC22 10113 + inferred |
| Other HDR monitors | max nits ÷ 100 | 1.0 → max ÷ SDR white | 0 | inferred |
| Transient virtual display around sleep/wake | 1, once 0 | — | — | measured (log) |

## 3. SDR white, peaks and grants

| Display | SDR white (max user-selectable) | HDR peak | Full-screen sustained | Notes |
|---|---|---|---|---|
| MacBook Pro M1/M2 Pro/Max | 500 nits | 1600 | 1000 | spec |
| MacBook Pro M3 family | 600 | 1600 | 1000 | spec |
| MacBook Pro M4/M5 family (owner's Mac16,5) | 600 indoors, **1000 outdoors** (ambient-driven) | 1600 (below 25 °C) | 1000 | spec; IORegistry `user-accessible-max-nits` = 600, `aurora-maximum-nits` = 1000, backlight `BrightnessMilliNits` max ≈ 1600 [measured] |
| Pro Display XDR | 500 | 1600 (below 25 °C) | 1000 | spec |
| Studio Display XDR (2026) | 1000 | 2000 (below 25 °C) | not published | spec; needs macOS 26.3.1+ |
| MSI MPG322UX OLED (HDR mode) | **265.05** (= DisplayAttributes MaxFrameAverage; matched WindowServer's own SDR value) | 465.49 (EDID max) | full-field ≈ 250–265 (ABL) | measured; minimum luminance 0.0003 nits (self-emissive); `SupportsPQEOTF` yes, HLG no |

- **Grants are not the panel peak.** In a six-hour window of WindowServer logs on the owner's Mac, the granted peak (`sdr × headroom`) sat near **889 nits** and reached **986 nits** at most while the logged brightness limit read 1600 [measured]. So `panel peak ÷ H` overestimates SDR white; Overbright never estimates SDR white that way (ARCHITECTURE.md §5.5).
- **Headroom ramps:** 174 ramps in that window; up-ramps median **1.14 s** (max 4.75 s); down-ramps median 9 ms; levels held 186–214 s without a new hint [measured].
- **Power:** the built-in backlight's LED current scales roughly linearly with nits (≈ 8.4–8.6 µA per nit between 382 and 1600 nits, from undocumented IORegistry keys) [measured, indicative]. Doubling luminance roughly doubles backlight power. The Studio Display XDR's EU energy label lists about 32.7 W SDR vs 47.7 W HDR (retailer listing).

## 4. Transfer tables seen

- MSI (HDR off): capacity **1024** entries, identity ramp (entry 512 = 0.5005); `CGGetDisplayTransferByFormula` returns 1001 (`kCGErrorFailure`) [measured].
- Built-in: its ColorSync profile uses the sRGB tone curve (an `aarg` parametric curve type 3 with γ 2.4, a 1024-entry TRC whose midpoint is 0.2145 at 0.5005) and an identity `vcgt`; a neutral table is therefore an identity ramp [measured, read-only profile parse; live read needs the lid open].
- Read-back of entries above 1.0 is **reported** to clamp at 1.0 (one field report, M1 Max on macOS 26); not yet measured on macOS 27 (HARDWARE-TEST §2.0). Overbright relies on neither behaviour: it judges a table against the display's profile base (ARCHITECTURE.md D26).
- The expected base of a display is its ColorSync profile's `vcgt`, or identity when the profile has none (the built-in's profile has an identity `vcgt`; the MSI's live table reads as identity).

## 5. IORegistry keys Overbright reads (public IOKit property reads; keys undocumented, all optional)

| Where | Key | Format | Use |
|---|---|---|---|
| built-in `backlight` node | `EDRPotentialHeadroom` | 16.16 fixed | panel peak = value × 100 |
| built-in `backlight` node | `user-accessible-max-nits` | 16.16 fixed | SDR maximum |
| `AppleARMBacklight` → `IODisplayParameters` | `BrightnessMilliNits` {min, value, max} | integers | SDR white **only if** H-N1 confirms it tracks SDR white |
| external `IOMobileFramebufferShim` → `DisplayAttributes` | `Luminance` {Max, MaxFrameAverage, Min} | 16.16 fixed | peak, HDR-mode SDR white, OLED detection |
| same | `SupportsPQEOTF`, `SupportsHLGEOTF` | bool | "Turn on HDR" verdict |
| same | `ProductAttributes` vendor/product IDs | integers | Apple external detection, diagnostics |
| placeholder vendor | `0x756e6b6e` ("unkn") | — | virtual-display detection |

## 6. Presets (Apple support 108321)

General-use: "Apple XDR Display (P3-1600 nits)" (MacBook Pro), "Pro Display XDR (P3-1600 nits)", "Apple XDR Display (P3-2000 nits)" and "(P3 + Adobe RGB-2000 nits)" (Studio Display XDR), "Apple Display (P3-500 nits)" and "(P3-600 nits)". Reference modes include HDR Video (P3-ST 2084), HDTV (BT.709-BT.1886), NTSC, PAL/SECAM, Digital Cinema (P3-DCI, P3-D65), Design and Print (P3-D50), Photography (P3-D65), Internet and Web (sRGB). In reference modes brightness, auto-brightness, True Tone and Night Shift may be unavailable. Preset names are localized by macOS; Overbright's copy never quotes them.

## 7. Worked factors

See ARCHITECTURE.md §5.6 for the light gains and table factors Overbright writes on each display above (M4 Max indoors Safe: ×1.667 light → table factor 1.237; Peak ×2.587 → 1.486; Pro Display XDR Safe ×2.0 → 1.335; MSI OLED Safe ×1.3 → 1.116). Above white the default writes `G^(1/2.4)`, which stays safe for any power-law truth up to exponent 2.4.

## 8. Still to measure (`docs/HARDWARE-TEST.md`)

1. The built-in with the lid open in P3-1600, P3-600 (and P3-500 if listed), HDR Video and one SDR reference preset: all three values, and `localizedName` under a Russian UI.
2. The MSI with HDR on, off, and after sleep/wake (the macOS 26 "stuck at 1.0" bug).
3. Granted headroom on the built-in at full brightness with Overbright's trigger.
4. Whether `BrightnessMilliNits` tracks SDR white while EDR is active, and whether the MSI's frame-average value follows the HDR-mode SDR slider.
5. Whether read-back of table entries above 1.0 clamps (HARDWARE-TEST §2.0), and whether Night Shift or True Tone touch the table while it is scaled (§2.4).
6. Pro Display XDR and Studio Display XDR values (testers).
