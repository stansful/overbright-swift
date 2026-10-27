# Hardware test session

> The owner's session that turns every [HW] question in `docs/ARCHITECTURE.md` §11.2 into a measured answer. It changes the display state on purpose, so it is the **only** time Overbright runs on real displays without `--qa-simulate`.

| | |
|---|---|
| When | After WP13 (integration) has merged, and again after every major macOS update. Sections can be run on different days, but **§2.0 always runs first** in a session. |
| Who | The project owner, on the owner's Mac: MacBook Pro Mac16,5 (M4 Max) and the external MSI MPG322UX QD-OLED. |
| Time | About 4 hours in total; each section states its own time. |
| Outcome | A folder of diagnostics, monitor captures, self-test logs and a filled results table, analysed by WP16 to set the engine's defaults. |

**Safety first.** Everything here is reversible.
- **Back to Standard** returns every display to Standard at any time, without a shortcut: the switch at the top of the panel, Turn Off Overbright in the menu, Back to Standard in the Dock menu (General ▸ Show in Dock) or the Shortcuts action. No shortcut ships bound (since 2026-10-20); this plan records ⌃⌥⌘0 for it during setup (step 0.7; free on macOS 27).
- **"Keep this level?"** follows every level change you make: without an answer the display goes back to Standard after 10 s, so a white or dark screen comes back by itself.
- If Overbright stops responding, **Force Quit** it (⌥⌘⎋): macOS restores your displays at once.
- `/Applications/Overbright.app/Contents/MacOS/Overbright --restore-gamma` resets every display's colours from Terminal.
- If a display still looks wrong: switch its preset in System Settings ▸ Displays and back; as a last resort, log out.
- Steps marked **(optional, risky)** can leave the built-in display in a wrong state that only a preset change clears. Skip them if you prefer.

---

## 0. Setup (15 min)

1. Build and install (each line on its own; the zsh profile can abort `&&` chains):
   ```zsh
   export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
   make -C <your clone of Overbright> build
   ```
   Then copy `build/Overbright.app` to `/Applications` (Shortcuts actions and opening at login work only from there) and open it once from Finder. Gatekeeper may ask; use System Settings ▸ Privacy & Security ▸ Open Anyway.
2. Make a results folder, an alias and a helper function (run each line on its own):
   ```zsh
   mkdir -p ~/Overbright-HW
   alias ob=/Applications/Overbright.app/Contents/MacOS/Overbright
   alias obdiag='ob --diagnostics'
   obpid() { pgrep -P 1 -x Overbright; }
   ```
   `obpid` prints the PID of **the app** only: the app is started by launchd (parent PID 1), while `ob --monitor` and `obdiag` run as children of your shell, so a plain `pgrep -x Overbright` would also match the monitor. Check it once: with the app running and a monitor in another window, `obpid` prints exactly one number. (Alternative: `lsappinfo info -only pid -app app.overbright.Overbright`.) Use `$(obpid)` wherever a step needs the app's PID.
3. Copy the **results table** at the end of this file into `~/Overbright-HW/results.md` and fill it as you go.
4. Conditions unless a step says otherwise: lid **open**, power adapter connected, built-in preset **Apple XDR Display (P3-1600 nits)**, brightness at **maximum** for boosting steps, **Automatically adjust brightness off**, True Tone and Night Shift off, no other brightness or colour app running, no HDR video playing.
5. In a second Terminal window, keep a live monitor running during the sections that say so:
   ```zsh
   ob --monitor > ~/Overbright-HW/monitor-<section>.jsonl
   ```
   It prints one line per display every 250 ms: the table's **class** against the display's colour profile (`matchesBase`, `scaled` with its ratio, `foreign`, `invalid`), the table maximum and mid entry, and current/potential/reference headroom. In this document **SCALED** means a class other than `matchesBase`. The monitor is read-only and exempt from the one-instance rule (since 2026-10-21: before that, opening the app while a monitor ran made the app hand over to the monitor and quit); `obdiag` is exempt too, and opening the app while `ob --restore-gamma` runs waits for it to finish. Stop it with Ctrl-C.
6. Optional live log in a third window:
   ```zsh
   log stream --level info --predicate 'subsystem == "app.overbright.Overbright"' > ~/Overbright-HW/log-<section>.txt
   ```
7. Shortcuts and automations ship off (since 2026-10-20). In Settings ▸ Shortcuts record **Back to Standard** (⌃⌥⌘0), **Less Bright** (⌃⌥⌘-) and **Brighter** (⌃⌥⌘=), the keys this plan names; §7 turns its own automations on. External displays leave the panel by default (since 2026-10-27): turn on Settings ▸ Displays ▸ **Show external displays in the panel**, since this plan uses the MSI's card, its chips and the "Why?" row.
8. Only one Overbright app may run (`ob --monitor` and `obdiag` do not count). A second launch (a Debug build from `scripts/run.sh`, `open -n`) hands over to the running one and quits; quit the installed copy before any step that uses a Debug build.

**What to send back:** zip `~/Overbright-HW` and hand it to WP16 together with `results.md`. Nothing in it contains personal files or window titles; display names and app names appear only where you typed them in `results.md`.

---

## 1. What macOS reports (read-only, 30 min) — H-E1–E3

Nothing here boosts: keep Overbright running but off (master switch off in the panel). `obdiag` and `ob --monitor` run as separate, read-only processes that open no window and add no menu bar icon.

| Step | Do | Capture | Expected |
|---|---|---|---|
| 1.1 | Built-in in **P3-1600** | `obdiag ~/Overbright-HW/1.1-p31600.json` | built-in potential **16**, reference **0**, verdict *supported*, gamma capacity > 0, table class `matchesBase`, `gammaWrites` 0 |
| 1.2 | Switch the built-in to **P3-600** (and repeat for **P3-500** if the list has it) | `obdiag …/1.2-p3600.json` (`1.2b-p3500.json`) | potential ≈ **6** (≈ 5), verdict *limited by preset* |
| 1.3 | Switch to **HDR Video (P3-ST 2084)** | `obdiag …/1.3-hdrvideo.json` | potential ≈ 10, reference **> 0**, verdict *reference mode* |
| 1.4 | Switch to **Internet & Web (sRGB)** | `obdiag …/1.4-srgb.json` | potential **1.0**, verdict *no HDR in this preset* |
| 1.5 | Back to P3-1600. MSI with **HDR off** | `obdiag …/1.5-msi-off.json` | MSI potential **1.0**, verdict *HDR is off*, supports PQ **true**; its card in the panel can still dim |
| 1.6 | Turn **HDR on** for the MSI (System Settings ▸ Displays) | `obdiag …/1.6-msi-on.json` | (verified by the owner on 2026-10-21: the MSI boosts with macOS HDR on; still capture the file for WP16's numbers) MSI potential **4.65**, panel peak ≈ 465, frame average ≈ 265, minimum ≈ 0.0003 nits, class *OLED external*, verdict *supported*; if Welcome is open on step 2, its row updates by itself |
| 1.7 | Put the displays to sleep (`pmset displaysleepnow`), wake them | `obdiag …/1.7-msi-after-wake.json` | MSI potential 4.65 again; if current headroom stays 1.0 later when boosting, note it (known macOS 26 bug) |
| 1.8 | Locale: your system runs Russian | look at `displays[].name` in 1.1 | the built-in's name may be Russian; verdicts in 1.1–1.7 must not depend on it |
| 1.9 | **H-N1** (needs §2.0 first, so Overbright can boost): boost the built-in at Bright room; set the system brightness to about 25 %, 50 % and 100 %; at each level capture both files | `obdiag …/1.9-<level>.json` and `/usr/bin/log show --last 1m --style compact --predicate 'subsystem == "com.apple.coreanimation" AND category == "Brightness"' > …/1.9-<level>-ws.txt` | WP16 compares `displays[].backlightMilliNits` with WindowServer's own `sdr:` value; if they track, Overbright can show nits on the built-in |
| 1.10 | **H-N2**: MSI with HDR on; move its SDR brightness slider in Displays settings (if macOS offers one) to two positions | the same two captures, `1.10-<position>` | whether the frame-average SDR white still matches WindowServer's `sdr:` |
| 1.11 | **H-E2** (WP2, virtual displays; if an iPad or an AirPlay receiver is at hand): connect it as a **Sidecar** display, then as an **AirPlay** display (extended, then mirrored) | `obdiag …/1.11-sidecar.json`, `…/1.11-airplay.json` and `system_profiler SPDisplaysDataType -json > …/1.11-<kind>-profiler.json` | the display reads `virtual` true, panel class `virtualDisplay`, no card in the panel (it sits under "Why?"); WP16 reads its vendor (WP2 expects macOS's placeholder `'unkn'`, `0x756e6b6e`) and gamma capacity from the files |
| 1.12 | **H-E3** (WP2, hot-plug): type `obdiag ~/Overbright-HW/1.12-early.json` without pressing Return; plug the MSI (HDR on) in and press Return at once; 3 s later run `obdiag …/1.12-late.json`; repeat once | the two files per try | whether the MSI's `panelPeakNits`, `panelFrameAverageNits` and `supportsPQ` (its `DisplayAttributes`) are already there in the early file; Overbright reads them 0.5 s after the last reconfiguration and again at 2 s, so a late arrival must show up by the 2 s pass (the panel's verdict and readout then match 1.6 without a replug) |
| 1.13 | (WP2, WP3; the hardware-gated test suites, read-only) both displays connected, the MSI with HDR on; in a Terminal at your clone, one command at a time: `OVERBRIGHT_HARDWARE=1 make -C <your clone of Overbright> test FILTER=RealDisplayReadTests`, then the same with `FILTER=MetalClearPassTests` | the two outputs, `> ~/Overbright-HW/1.13-<suite>.txt 2>&1` | both pass: on Apple silicon the IORegistry walk finds the framebuffer services, the built-in's panel while the built-in is online, and every online external paired with its `DisplayAttributes` and not virtual (WP14, C-PLATFORM-6); the off-screen Metal clear reads 1.6 back as ≈ 1.5996. Neither writes a table or opens a window |

---

## 2. First boost: read-back model, dimming, resets (35 min) — H-R1, H-DM1, H-NS1, H-K2, H-W5

Monitor running (`monitor-2.jsonl`). **Run 2.0a and 2.0 before every other step that boosts.**

Since 2026-10-20 (the owner's rule) **every** level change you make away from Standard (the panel, the menu, a shortcut, Shortcuts, Settings), and turning Overbright on with such a level stored, asks **"Keep this level?"** on the display you moved: answer **Keep** only when the screen looks right; with no answer that display goes back to **Standard** by itself 10 s after your last step. Answer Keep after each change the steps below rely on.

| Step | Do | Expected |
|---|---|---|
| **2.0a (H-WS1, white screen)** | Settings ▸ Advanced ▸ Trigger method: built-in **Automatic**; built-in brightness at maximum. (1) Drag its slider from Standard to **Bright room** and look for 10 s **without answering** the prompt. (2) Set Trigger method to **Tagged layer**, drag past Standard again and again do not answer. (3) Set it back to **Automatic**, drag past Standard and press **Keep**. `obdiag …/2.0a-N.json` after each try. | (1) The built-in gets **brighter, not white** (the diagnostics show `cachedRung` 5, “Metal layer, refreshed”), and returns to Standard after 10 s on its own. (2) Expected **white** (the 2026-10-20 report), back to Standard after 10 s; note whether it whitens. (3) Brighter, and it stays. If (1) or (3) turns white, **stop the session** and report it. |
| **2.0 (H-R1)** | Settings ▸ Displays ▸ Built-in: Limit **Peak**. Turn Overbright on, built-in at **Max**, brightness at maximum. Watch the monitor for 10 s. Then Back to Standard. | Record the monitor's **table max** while boosted: **> 1.0** (read-back keeps values above 1) or **exactly 1.0** (read-back clamps). Either way the class must read `scaled` while boosted and `matchesBase` after Back to Standard. If the class reads `matchesBase` while the screen is visibly brighter, **stop the session** and report it: every later SCALED check would be meaningless. |
| 2.1 (H-DM1) | Built-in at Bright room, then press Less Bright (the shortcut recorded in step 0.7) repeatedly | it stops at Standard once, then dims in steps; the panel shows "Dimmed · N %"; the class reads `scaled` with a ratio below 1 |
| 2.2 | With the panel's slider, step through the named dim stops with ⌥← (50 %, 25 %, 10 %, 5 %, 2 %) | the "Keep this level?" prompt appears at the first step and its countdown restarts at every step (it does not flash or move); without an answer the built-in goes back to **Standard** 10 s after the last step; with Keep it stays; Back to Standard always works |
| 2.3 | The MSI with **HDR off**: dim it to 25 % from the panel | it dims (no extra brightness needed); class `scaled`, ratio < 1 |
| 2.4 (H-NS1) | Boost the built-in at Bright room and dim the MSI to 50 %; turn **Night Shift** on (Displays ▸ Night Shift ▸ Turn On Until Tomorrow), wait 10 s, turn it off; then the same with **True Tone** | note whether the monitor's class changes (`foreign`?), whether a chip or banner appears, whether the picture looks right; no flicker; record which of the two touch the table |
| 2.5 (H-K2) | Boosted and dimmed as in 2.4; in a third Terminal run `ob --restore-gamma` (a separate process that writes and exits) | every display is reset by macOS when that process exits; within ≈ 0.3 s Overbright brings the boost and the dim back **with a ramp** (no hard flash back); the journal shows `drift.reapplied` |
| 2.6 (H-W5) | Boost both displays (MSI with HDR on). **Close the lid** (the MSI stays on) without killing Overbright; wait 10 s; open the lid. Then unplug the MSI while boosted, wait, plug it back | at no time does a bright dot or an extra boost appear on the remaining display; each display comes back neutral or re-armed |

---

## 3. Which trigger works (40 min) — H-T1a–c, H-T2a–c, H-T3, H-T4a–d, H-L1, H-G1

1. Settings ▸ Advanced ▸ **Run Self-Test…**, select only the **built-in display**, tick **Test every method**, Run. Keep the Mac awake, unlocked and untouched for about 3 minutes. **Save Log…** as `~/Overbright-HW/3.1-selftest-builtin.json`.
2. While it runs, open Activity Monitor and note Overbright's memory after the "Metal layer" methods finish (or run `footprint -p $(obpid) > ~/Overbright-HW/3.1-footprint.txt` when the sheet shows "Metal layer, black").
3. Repeat for the **MSI with HDR on**: `3.2-selftest-msi.json`.
4. Repeat steps 1 and 3 once in **Low Power Mode** (`3.3-selftest-lowpower.json`) and once while a full-screen HDR video plays on the other display (`3.4-selftest-hdrvideo.json`; a result "Already bright" is expected for the display that shows the video).
5. Open the log's summary in the sheet: note for each method **Held / Dropped / No response / Already bright**, response time, and whether "macOS is limiting HDR" appeared.
6. **H-G1:** boost the built-in at Max with Peak, brightness at maximum, and capture `obdiag …/3.6-grant.json` plus the WindowServer log of step 1.9; WP16 reads the granted peak (H × SDR white).

**Expected:** at least one method **Held** on each display. The decisions WP16 takes: the default first method on macOS 27 (ideally *Tagged layer, black*), whether the Metal one-frame method frees its memory after a few seconds, whether a lower headroom tag lowers the granted headroom (tag policy), the per-method timeout (time to first response, expected 0.1–2 s), and, from H-G1, whether Safe keeps its live worst-case bound.

---

## 4. Visibility and holding (30 min) — H-T6, H-W1–W4

Turn Overbright on with the built-in at **Bright room**; keep the monitor running (`monitor-4.jsonl`).

| Step | Do | Expected |
|---|---|---|
| 4.1 | Look at the extreme top-right corner of the built-in with a loupe or a phone's macro camera; photograph it | no visible dot (the rounded corner hides it) |
| 4.2 | Settings ▸ Advanced ▸ Trigger method for the built-in: pick *Tagged layer* and *Metal layer* in turn, repeat 4.1; then the same on the MSI (HDR on) with *Automatic* | MSI: a black trigger invisible; note any visible pixel |
| 4.3 | Switch Spaces; enter and leave full screen in Safari with a document (not video); open Mission Control; turn Stage Manager on and off | SCALED stays on throughout (a full-screen document no longer pauses by default); **no visible flash** |
| 4.4 | Lock the screen (⌃⌘Q), wait 10 s, unlock | the monitor shows `matchesBase` **within 1 s of locking**, then SCALED again ≤ 3 s after unlock |
| 4.5 | `pmset displaysleepnow`, wake | `matchesBase` while asleep; the boost resumes after wake (allow up to 30 s; note the time) |
| 4.6 | ⌘⇧3 screenshot and a ⌘⇧5 recording while boosted | the screenshot looks like normal SDR; no trigger pixel and no Fill Light in it (note what you see) |

Save the photos into the folder.

---

## 5. Process death, hangs and rescue (25 min) — H-K1, H-X1, H-X2

Monitor running (`monitor-5.jsonl`). Overbright on, built-in at **Max**. §2.0 must have passed.

| Step | Do | Expected |
|---|---|---|
| 5.1 | `kill -9 $(obpid)` | the monitor keeps running, and its next line shows the built-in `matchesBase` (macOS restored it) |
| 5.2 | Open Overbright again | starts off; `obdiag …/5.2.json` shows `boostMarker` present before and cleared after launch; journal "recovered by macOS" |
| 5.3 | Boost again, **close the lid** (the MSI stays on), `kill -9 $(obpid)`, open the lid | the built-in comes back `matchesBase` |
| 5.4 | Boost again, log out, log back in | `matchesBase` after login |
| 5.5 | Hang test (Debug build): quit the installed copy, then `<your clone>/scripts/run.sh -- --qa-defaults-suite app.overbright.Overbright.hw --qa-hang-main 20,8`, and within 20 s turn the boost on | about 3–5 s after the hang starts the monitor shows `matchesBase` (the watchdog restored); after the hang ends, the boost returns only after a fresh gate (no instant jump back) |
| 5.6 | (informational) Boost, then `kill -STOP $(obpid)` for 10 s, then `kill -CONT $(obpid)` | the monitor keeps printing; a fully stopped process cannot restore: the table stays SCALED while stopped (expected, documented); after CONT the engine continues |
| 5.7 | Quit Overbright from the panel, then `ob --restore-gamma` | prints "already neutral" |
| 5.8 | **H-X2** (WP2: CoreGraphics' transfer calls off the main thread). After 5.5 and after a `kill $(obpid)` (SIGTERM) while boosted, both of which write the baselines from a background queue: `/usr/bin/log show --last 15m --style compact --predicate 'process == "Overbright" AND messageType == fault' > ~/Overbright-HW/5.8-faults.txt`; look in `~/Library/Logs/DiagnosticReports` for an Overbright report | no fault and no crash report; each display came back `matchesBase` (the watchdog's and the signal queue's writes worked off the main thread) |

---

## 6. Calibration and the transfer domain (20 min) — H-D1

1. Conditions of §0.4, plus maximum brightness indoors. Note that starting a calibration first returns every display to Standard.
2. Settings ▸ Displays ▸ Built-in ▸ **Calibrate…**. Answer "Did it get brighter?" honestly; in step 2 press Space the moment the 95 % square merges with white. If the sweep pauses ("Keep going?"), choose Keep Going once and note the factor.
3. If step 3 ("One more check") appears, answer honestly whether the two right squares still look different.
4. Record the result line and the merge factor shown in the result (also in `obdiag …/6.1.json` under the display's calibration).
5. **Optional, colorimeter:** measure a 10 % white window at Standard and at Bright room; enter the Standard reading in "I have a colorimeter"; note both readings.
6. Repeat for the MSI with HDR on.

**Expected (built-in, headroom ≈ 2.67):** a merge near **1.6** means encoded (the default stays, no step 3); near **3.0** leads to step 3, and only a "they look different" there records linear. With a colorimeter at a table factor of 1.2: ≈ 1.2× means linear, ≈ 1.5× means encoded.

---

## 7. Guards, full screen, players, games and the taper (35 min) — H-FS1, H-FS2, H-P1, H-B1

Overbright on, both displays boosting; monitor running (`monitor-7.jsonl`). First turn on **Pause for full-screen video** and **Pause for these apps** in Settings ▸ Automations (both off by default since 2026-10-20).

| Step | Do | Expected |
|---|---|---|
| 7.1 | Play a video full screen in QuickTime on the MSI, keep typing on the built-in | the MSI pauses (chip "Paused: video"), the built-in keeps boosting |
| 7.2 | The same with Safari video full screen; then a full-screen Pages or TextEdit document; then Split View with two apps on one display | video: paused; document and Split View: **not** paused by default; with "Pause for every full-screen app" on: paused |
| 7.3 | On the notched built-in: an app full screen; hover the top edge (menu bar appears); a zoomed (not full-screen) window; menu bar set to auto-hide "Always" (with "Pause for every full-screen app" on) | full screen → paused even while hovering; a zoomed window → not paused unless the menu bar is hidden |
| 7.4 | IINA, VLC, TV, QuickTime, Safari, Chrome: play, then pause, in a window and full screen | "While playing" rules pause only while playing; capture `obdiag …/7.4-<app>-playing.json` and `-paused.json` (look at `signals.frontmost.isPlaying` and `fullScreenVideoDisplays`) |
| 7.5 | Unplug the adapter; let the battery cross 20 % if practical, or set the threshold just above the current level | the banner "Paused because the battery is below 20 %." and the HUD "Paused: battery below 20 %"; plug in → resumes with the HUD "Extra brightness is back" |
| 7.6 | Low Power Mode on/off | banner and HUD "Paused: Low Power Mode"; resumes with the HUD |
| 7.7 | Set Turn off after: 5 minutes, wait | turns off at the deadline; the HUD shows "Off: timer ended" (and VoiceOver announces it if running) |
| 7.8 | A game (or any app with the games category) full screen | paused only with "Pause for every full-screen app" or "Pause in games" on |
| 7.9 (H-B1) | Turn "Add extra brightness only near full brightness" **on** (off by default since 2026-10-20: its reference was measured while the grant still ramped, 1.31 on this Mac, and it cut every boost to ×1; the reference is now never below 1600 ÷ 600 ≈ 2.67). Built-in at Max (Safe); set system brightness to 100 %, about 75 %, 50 %, 25 %, using the brightness keys; then turn the option off and repeat | with the option on: full boost at 100 %, partly at 75 %, none at 50 % and below, and every brightness-key step looks like a normal step (no bigger jumps); with it off: the multiplier applies at every level. Note any step that looks uneven |
| 7.10 (H-FS2) | (WP6) System Settings ▸ Desktop & Dock: turn **Displays have separate Spaces** off (log out and back in), then repeat 7.1 and 7.3; afterwards turn it back on | as built (C-SIGNALS-5): only the main display (the one at the global origin, the built-in here) has a menu bar then, so on the MSI a window counts as full screen only while its app is frontmost and it covers the MSI exactly; a background window there is no evidence. Expected: a full-screen video on the MSI pauses the MSI only, while the player is frontmost (if macOS lets you type on the built-in meanwhile, the player becomes a background window and the MSI resumes); a zoomed (not full-screen) window that fills the MSI exactly (it does when nothing reserves space there: the MSI has no menu bar, and the Dock is on the built-in) counts as full screen while it is frontmost, the known limit of §7.3: with "Pause for every full-screen app" on (as in 7.3) the MSI pauses, with only the video rule it pauses only while that app holds a display-sleep assertion (plays video); a zoomed window that leaves a margin (the Dock) pauses nothing; the built-in behaves as in 7.1–7.3. Note any display that pauses (or not) otherwise |
| 7.11 | (WP11) Settings ▸ Automations ▸ Pause for these apps ▸ add from the suggestions: for each of Prime Video, Infuse, GeForce NOW and Moonlight that is installed, run `osascript -e 'id of app "<its name>"'` | the suggestion lists the installed ones by their Finder names; their IDs are `com.amazon.aiv.AIVApp`, `com.firecore.infuse.enterprise`, `com.nvidia.gfnpc.mall` and `com.moonlight-stream.Moonlight` (unverified publishers' IDs; note any that differ) |
| 7.12 (H-FS2) | (WP6, C-SIGNALS-5) **Displays have separate Spaces** off as in 7.10, "Pause for every full-screen app" on; make the MSI the main display (System Settings ▸ Displays ▸ Arrange: drag the menu bar onto the MSI). On the built-in: (a) an app full screen, frontmost; (b) the same, then click on the MSI if macOS lets you; (c) a zoomed (not full-screen) window, frontmost. Capture `obdiag ~/Overbright-HW/7.12-<case>.json` for each (look at `signals.fullScreenDisplays`). Afterwards put the menu bar back on the built-in, then turn the setting back on | as built: the built-in has no menu bar of its own then, so a frontmost window counts as full screen when it covers the display exactly or below the notch band. (a) the built-in pauses (chip "Paused: full screen"), the MSI does not; (b) note whether the built-in resumes (expected: a background window is no evidence there); (c) the zoomed window counts as full screen while it is frontmost and fills the built-in down to its bottom edge, whether its top edge sits at the display's top edge (an exact cover) or right below the notch band (a full-screen app's frame there): the built-in pauses either way, the known limit of §7.3, which this step measures. Note where the top edge sits; a zoomed window that leaves a margin (the Dock) is not paused |

---

## 8. Other apps (15 min) — conflicts

**Run only after §2.0 has passed.** Never choose Continue Anyway next to a brightness app with the color table method: two boosts would compound.

1. Start the commercial booster that is installed on this Mac (Vivid). <!-- denylist-ok -->
2. Open Overbright's panel: expected banner "Paused because ‹that app› also changes display brightness. Quit it to continue." with **no** button, and **no** launch rescue (the journal must not show `launch.rescued`). Overbright stays paused on every display until the other app quits.
3. Quit the other app: the banner clears; note whether every display read `matchesBase` right after it quit (`monitor-8.jsonl`) and whether Overbright reapplied with a ramp.
4. Optional: f.lux or MonitorControl if you have them (colour-app and conditional behaviour; Continue Anyway is offered for colour apps; note whether the boost pumps or stops within seconds).

---

## 9. Auto-brightness interplay (optional, risky; 10 min) — H-A1

1. Turn **Automatically adjust brightness on**, boost the built-in at Bright room.
2. Turn auto-brightness **off** while boosted.
3. Look at the picture after turning Overbright off and quitting it. If it looks wrong (too bright, washed out), note it, then switch the preset to P3-600 and back; if that does not help, log out.

**Expected:** record whether a wrong picture remained and what cleared it. Overbright does not try to catch the toggle (no heuristic can); the advisory and Help explain it.

---

## 10. (Removed) Compatibility mode — H-C1–C3

Nothing to run. On this MacBook Pro (M4 Max, macOS 27.0.1) the built-in turned **white** the moment the full-screen overlay boosted: WindowServer does not blend the overlay's `multiplyBlendMode` layer with the windows beneath it (ARCHITECTURE.md §7.5). The method was disabled on 2026-10-20, its panel, menu, Settings and calibration surfaces were removed on 2026-10-21, and its code the same day (the overlay engine, its triggers and the `OverlayHandle` port; the last commit with the code is `c76b47c`); the color table is the only method. The section number stays so the references below keep their numbers.

---

## 11. Fill Light and the camera (25 min) — H-F1–F5

1. Settings ▸ Fill Light: turn on "Turn on while a camera is in use" (Any camera).
2. Open Photo Booth or FaceTime: Fill Light turns on within ≈ 1 s; **no camera permission prompt may appear** (note if one does). The panel shows the Fill Light card; change Brightness and Warmth there. Close the app: off after ≈ 3 s.
3. Check width, warmth and brightness changes live; check that clicks pass through the frame and that a screenshot leaves it out.
4. With Fill Light on, turn the boost on for the built-in: it must still prepare and boost normally (Fill Light is counted as range already in use, not as idle).
5. **H-F2 (WP7, the headroom grant):** boost off, Fill Light on at Brightness 100 %; capture `obdiag …/11.5-filllight.json` and the WindowServer log of step 1.9 (`…/11.5-ws.txt`). Fill Light asks for 2.07 (2 ÷ 0.97, §4.7): does macOS grant about that (policy B) or the display's potential (policy A)? Either way the frame's light must settle at twice white.
6. **H-F3 (WP7, the ramp):** watch the frame while it fades in and out and while you drag Brightness from 20 % to 100 %: no flash, no step and no colour shift mid-ramp (macOS must not tone-map the frame while its headroom rises).
7. **H-F4 (WP7, the menu bar band):** System Settings ▸ Menu Bar ▸ Automatically hide and show the menu bar: **Always**. With Fill Light on, the frame keeps a band at the top clear; move the pointer to the top: the menu bar slides in over that band, not over the frame. Then a full-screen app on that display: the frame reaches the top. Set the menu bar back afterwards.
8. **H-F5 (WP7, presents):** Fill Light on and nothing changing for 60 s: `top -l 30 -s 2 -stats pid,cpu,idlew -pid $(obpid) > ~/Overbright-HW/11.8-top.txt`; Fill Light draws only when its size, warmth or brightness changes, so idle wake-ups stay near those of §13's on case and the CPU near 0 %.

---

## 12. Shortcuts, Focus, Control Center (25 min) — H-AI-1–3, H-CC-1–2

1. In the Shortcuts app, search "Overbright": every action is listed (Turn Overbright On or Off, Turn On Overbright, Turn Off Overbright, Set Extra Brightness, Dim Displays, Pause Overbright, Resume Overbright, Get Overbright State, Back to Standard). Run each; Get Overbright State's text must match the panel's readouts.
2. System Settings ▸ Focus ▸ (a Focus) ▸ Focus Filters ▸ Add Filter ▸ Overbright: set "On at Sunlight"; switch that Focus on with Overbright running, then with Overbright quit and launch it (the filter applies at launch).
3. Switch the system language to German, then Russian (log out/in): action titles and the Focus filter are translated; key caps in Welcome step 4 and Help follow the keyboard layout.
4. Make a shortcut with "Turn Overbright On or Off" and add Control Center's **Run Shortcut** control to Control Center and to the menu bar; use it with Overbright running and quit.
5. **Control Center control (H-CC-1):** `CONTROLS=1 make build`, install, launch once. Then: `pluginkit -m -v -i app.overbright.Overbright.Controls > ~/Overbright-HW/12.5-pluginkit.txt`; right-click the desktop ▸ Edit Widgets… (refreshes the gallery); Control Center ▸ Edit Controls: is "Overbright" listed? Add it; does it show the right state? Toggle it with the app running and quit. **Rebuild** (new signature), reinstall, and repeat. Record pass / works until an update / fail. **Language (WP8):** with the system language English, note the control's title and state labels in the Controls gallery and in Control Center; switch the system language to French (log out and in) and look again: they must be French (the extension's own `Controls/Localizable.xcstrings`); then switch back.
6. **H-CC-2:** boost, `kill -9 $(obpid)`: the control may show On until Overbright launches again, then Off.
7. **Launch by an action or a URL (WP13, H-AI-1):** quit Overbright, then run "Turn On Overbright" from the Shortcuts app: Overbright launches, turns on, and **no** window or panel opens. Quit again and run `open 'overbright://control?set=off'` in Terminal: nothing opens either. If a panel or Welcome opens, note how long after launch the action arrived (`log show --last 2m --info --predicate 'subsystem == "app.overbright.Overbright"' | grep -E 'launch UI|intent'`).
8. Afterwards: `make clean` unregisters the build products.

---

## 13. Energy (20 min) — H-S1

For each case run 60 s idle, then 60 s with a full-screen video on the other display (each command on its own):

```zsh
top -l 30 -s 2 -stats pid,command,cpu,idlew,power -pid $(obpid) > ~/Overbright-HW/13-<case>-top.txt
footprint -p $(obpid) > ~/Overbright-HW/13-<case>-footprint.txt
sudo powermetrics -i 1000 -n 30 --samplers cpu_power,gpu_power,tasks --show-process-energy > ~/Overbright-HW/13-<case>-power.txt
```

Cases (the Compatibility-mode case was removed with the overlay, §10; last commit with the code: `c76b47c`): Overbright **off**; on with the winning trigger at Bright room; on with *Metal layer* forced; Fill Light on; both displays at Bright room, once with "Pause for full-screen video" on (the default) and once with it and every other full-screen and "while playing" rule off (ARCHITECTURE.md D28: Signals' 2 s full-screen watch is its own timer). Optional: 30 minutes on battery at Bright room vs Standard (battery % before and after).

**Expected:** off = 0 idle wake-ups; on = ≤ 1.5 wake-ups/s and < 0.1 % CPU with no GPU work after the first frame (DESIGN.md §17). Both displays with the full-screen rule on: about 2.0 wake-ups/s by D28's count (two drift checks, the hang ping, the watch), about 1.5 with the rules off; note both, since they decide whether WP16 moves the watch onto one engine tick.

---

## 14. Menu bar visibility and launching (10 min) — H-M1, H-L2

1. System Settings ▸ Menu Bar: turn Overbright off under "Allow in the Menu Bar".
2. Within ≈ 3 s, Overbright should show the window "Overbright's icon isn't visible", and Settings ▸ General should show the warning row. Note what appears.
3. Open Overbright from Finder: Settings ▸ General must open; its **Quit Overbright** button must quit.
4. Open Overbright from Finder again while it is **not** running: Settings opens (the icon is still hidden). Turn the icon back on under Allow in the Menu Bar; quit; open from Finder: the panel opens under the icon.
5. Crowd the menu bar with other icons until Overbright's icon disappears behind the notch: the same window should appear (once per version).
6. **H-L2:** set "When you log in" to "Open Overbright, keep it off", log out and back in: nothing may open. Then capture `obdiag …/14.6-login.json` and `/usr/bin/log show --last 15m --info --predicate 'subsystem == "app.overbright.Overbright"' | grep 'launch opening' > …/14.6-login.txt`, and note in `results.md` what the line says: the opening (`login` or `user`), the event (`aevt/oapp` expected) and the login-item flag (`true`: `SMAppService` sets `keyAELaunchedAsLogInItem`; `false` with opening `login`: only the fallback recognised it). Advanced ▸ Copy Diagnostics shows the same as the journal event `launch.login` / `launch.user`. For comparison, quit and open Overbright from Finder: the line must say `user` with the flag `false`.
7. **Dock icon and quit (WP13):** General ▸ Show in Dock on: the Dock icon appears; its menu offers Turn On/Off Overbright, Dim All Displays/Stop Dimming, Back to Standard and Settings…; clicking the icon opens the panel (or Settings while the menu bar icon is hidden). Boost, then quit from the Dock menu's Quit and, separately, `osascript -e 'quit app "Overbright"'`: both quit at once without "User canceled", and `ob --monitor` (in another window) shows `matchesBase` right after. Boost again and `kill $(obpid)` (SIGTERM): the display returns to Standard and the process exits within ≈ 1 s.
8. **Real-port smoke (WP13 ran only `SIMULATE=1 make smoke`):** `make build`, then `make smoke` (the read-only `--diagnostics` report on the real ports): `gammaWrites` 0, `triggerWindows` 0, every display `matchesBase`.

---

## 15. Release checklist (every release, 15 min; WP17)

1. Clean install from the release DMG on the owner's Mac; launch: the move-to-Applications offer only when launched from the DMG; then Welcome on first run; the status symbol shows *off*. Welcome's "Where to find Overbright" step shows no key caps and the line "You can set keyboard shortcuts in Settings ▸ Shortcuts."; clicking it opens Settings ▸ Shortcuts at Back to Standard.
2. Boost the built-in to Bright room; Back to Standard without a shortcut: the panel's switch, then (boosted again) the Shortcuts action Back to Standard; once more and leave "Keep this level?" unanswered: Standard after 10 s.
3. Lock/unlock and sleep/wake once with the monitor: `matchesBase` while shielded.
4. `kill -9 $(obpid)` while boosted: `matchesBase` at once.
5. The MSI: verdict correct for its HDR setting.
6. A Shortcuts action runs.
7. `obdiag` → `gammaWrites` 0 while off; no `UsageDescription` prompts ever appeared.
8. Icons compared side by side with the incumbent's (DESIGN.md §14).

---

## Results table (copy into `~/Overbright-HW/results.md`)

| ID | Question | Result | Files |
|---|---|---|---|
| **H-WS1** | **built-in brighter, not white, with the automatic ladder (T3, 0.2 s)? Keep prompt reverts to Standard after 10 s? Tagged layer still white?** | | 2.0a |
| **H-R1** | **read-back while boosted: table max > 1.0, or exactly 1.0 (clamps)? class `scaled` either way?** | | 2.0 |
| H-E1 | potential / reference per preset; MSI on/off/after wake; name localized? | MSI with macOS HDR on boosts (owner, 2026-10-21); the rest open | 1.x |
| H-DM1 | table-method dimming on the built-in and the MSI; Keep this level | | 2.1–2.3 |
| H-NS1 | Night Shift / True Tone while boosted and dimmed: table touched? chip? picture? | | 2.4 |
| H-K2 | another table writer exits: reset, then ramped reapply within ≈ 0.3 s? | | 2.5 |
| H-W5 | lid close / unplug while boosted (no kill): anything on the remaining display? | | 2.6 |
| H-T1a–c | Tagged layer black / bright: held? suppressed? tag caps grant? | | 3.x |
| H-T2a–c, H-T3 | Metal one frame held? memory freed? keep-alive needed? | | 3.x |
| H-T4a–d | HLG still / frame: held? side effects (Now Playing, assertions)? | | 3.x |
| H-L1 | time to first headroom movement | | 3.x |
| H-G1 | granted headroom and granted peak on the built-in at full brightness | | 3.6, 1.9 |
| H-T6, H-W1–W4 | corner invisible? holds across Spaces, full screen, Mission Control, lock, sleep? capture? | | 4.x |
| H-K1 | kill -9, lid + kill, logout | | 5.x |
| H-X1 | hang watchdog restored after ≈ 3–5 s? no jump back before the re-gate? | | 5.5 |
| H-D1 | calibration: merge factor, step 3 answer, encoded or linear (built-in, MSI) | | 6.x |
| H-FS1 | full-screen heuristic cases; documents not paused by default | | 7.1–7.3 |
| H-P1 | players' and browsers' assertions while playing / paused, windowed and full screen | | 7.4 |
| H-B1 | taper: continuous light from 100 % to 50 % brightness; even key steps | | 7.9 |
| conflicts | booster banner without a button, no rescue, behaviour after quitting it | | 8 |
| H-A1 | auto-brightness toggle: wrong picture? cleared by? | | 9 |
| ~~H-C1–C3~~ | removed with Compatibility mode (§10; last commit with the code: `c76b47c`) | — | 10 |
| H-F1 | camera detection without a prompt; Fill Light card; boost still prepares with Fill Light on | | 11 |
| H-AI-1–3 | intents, Focus filter, translations, key caps by layout, Run Shortcut | | 12 |
| H-CC-1–2 | ad-hoc control: listed, rendered, after rebuild, after kill -9 | | 12.5–12.6 |
| H-S1 | energy per case | | 13 |
| H-M1 | hidden-icon window and Settings row; Finder launch opens Settings; Quit works | | 14.1–14.5 |
| H-L2 | login launch recognised and silent | | 14.6 |
| H-N1, H-N2 | (from the logs) does `BrightnessMilliNits` track SDR white with boost on; does the MSI's frame average follow its HDR SDR slider | | 1.x |
| H-E2 | Sidecar and AirPlay: virtual, no card, vendor and capacity | | 1.11 |
| H-E3 | hot-plug: the MSI's `DisplayAttributes` present at once, or only after the 0.5 s / 2 s passes? | | 1.12 |
| hardware suites | `RealDisplayReadTests` and `MetalClearPassTests` pass with `OVERBRIGHT_HARDWARE=1` | | 1.13 |
| H-X2 | baseline writes from the watchdog's and the signal queue's threads: no fault, no crash, `matchesBase` | | 5.8 |
| H-FS2 | "Displays have separate Spaces" off: which displays pause for full screen; the built-in as a secondary display: full-screen app detected? where does a zoomed window's top edge sit (at the top edge or below the notch band it counts as full screen while frontmost)? | | 7.10, 7.12 |
| suggestions | the paused-app suggestions' bundle IDs on this Mac | | 7.11 |
| H-F2–F5 | Fill Light: grant for the 2.07 request (policy A or B), no tone-mapping during the ramp, the auto-hidden menu bar band, no presents while idle | | 11.5–11.8 |
| H-CC-1 (language) | the control's title and labels in English, then French | | 12.5 |
