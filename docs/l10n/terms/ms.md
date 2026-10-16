# Overbright — Malay (Bahasa Melayu, `ms`) terminology sheet

Carried from Cranny’s sheet for this language (ARCHITECTURE.md §10.2): the register, voice and
typography decisions are language facts and stay; Cranny’s notch, widget and ambient-light rows are
deleted. Overbright’s own names are decided in WP15 (ARCHITECTURE.md §10.17, §8.8); until then they
read “—”. `scripts/l10n/languages.json` has this language’s plural categories and quotation marks.

## Register and typography

Register: **anda** in lower case, as macOS. Buttons, menu items and toggles use the bare imperative ("Buka",
"Tunjukkan", "Keluarkan", "Jeda"), as Apple's Malay does. Where English uses Title Case (menu items, buttons,
standard AppKit chrome) the Malay is Title Case too ("Semak Kemas Kini…", "Keluar daripada Overbright", "Alih ke
Bawah"); function words stay lower case (ke, di, dari, daripada, dalam, dan, untuk, pada, kepada, dengan).
Settings rows, toggles, footnotes and VoiceOver text are sentence case.
Typography: quotes “…” (‘…’ inside), the apostrophe ’, one-character ellipsis …, " ▸ " in Settings paths with
Apple's pane names unquoted (as Apple's Malay writes "Seting Sistem > Privasi & Keselamatan > Foto"); a setting or
button named inside a sentence is quoted (“Kurangkan pergerakan”, “Sertai”, “Simpan di Rak”); Apple's apps are not
("app Muzik", "app Pintasan"), user-made names are (“%@” for notes and shortcuts). No serial comma ("fon, tataletak
dan warna"), as Apple's Malay.
Malay has no grammatical plural: every plural key has only `other` ("%lld item", "%lld sel", "Tinggal %lld").
Numbers, dates and durations arrive formatted; units written by Overbright: jam / min / saat.
Apple's own names come from `apple-terms.py ms` (read from macOS 27) and macOS 27's own Malay loctables (AppKit
menus, Calendar, Music, Preview, System Settings, the keyboard-shortcut table).

## Apple names (`apple-terms.py ms` on macOS 27.0.1 — never paraphrased)

| English | ms |
|---|---|
| System Settings | Seting Sistem |
| Finder | Finder |
| Shortcuts | Pintasan |
| Photos | Foto |
| TV | TV |
| QuickTime Player | QuickTime Player |
| Privacy & Security | Privasi & Keselamatan |
| Accessibility | Kebolehcapaian |
| General | Umum |
| Appearance | Penampilan |
| Menu Bar | Bar Menu |
| Control Center | Pusat Kawalan |
| Focus | Fokus |
| Displays | Paparan |
| Keyboard | Papan Kekunci |
| Keyboard Shortcuts… | Pintasan Papan Kekunci… |
| Lock Screen | Skrin Kunci |
| Battery | Bateri |
| Energy | Tenaga |
| Screen Saver | Penyelamat Skrin |
| Login Items | Item Log Masuk |
| Login Items & Extensions | Item Log Masuk & Sambungan |
| Brightness | Kecerahan |
| Automatically adjust brightness | Laraskan kecerahan secara automatik |
| True Tone | True Tone |
| High Dynamic Range | Julat Dinamik Tinggi |
| Preset | Praset |
| Night Shift… | Night Shift… |
| Color profile | Profil warna |
| Refresh rate | Kadar segar |
| Allow in the Menu Bar | Benarkan dalam Bar Menu |
| Low Power Mode | Mod Kuasa Rendah |
| Do Not Disturb | Jangan Ganggu |
| Camera | Kamera |
| Open Anyway | Buka Juga |
| Applications | Aplikasi |
| Reduce motion | Kurangkan pergerakan |
| Reduce transparency | Kurangkan kelutsinaran |
| Increase contrast | Tingkatkan kontras |
| Differentiate without color | Membezakan tanpa warna |
| VoiceOver | VoiceOver |

## Overbright’s own names

| English | ms | Note |
|---|---|---|
| Overbright | Overbright | never translated or transliterated |
| Standard (the brightness macOS shows) | — | never “100 %” or “normal mode” |
| extra brightness (the boost half) | — | never “boost”, “HDR mode”, “EDR” |
| Dim below minimum (the setting) | — | the incumbent’s name for it is never used |
| Dimmed (the state) · Dim All Displays / Stop Dimming (actions) | — | not “night mode” |
| Brighter · Less Bright (one step) | — | never “Dimmer”: it reads like Dim |
| Back to Standard (the instant off) | — | not “panic”, not “reset brightness” |
| Indoor · Bright room · Sunlight · Max (presets) | — | “Max” is a preset only |
| Safe · Peak (ceilings) | — | Peak, never “Max”, for a ceiling; one short word each (segments) |
| Compatibility mode · Color table (methods) | — | never “fallback” or “overlay” |
| Fill Light (the edge light for video calls) | — | never “ring light” |
| extra range (headroom, in user copy) | — | “headroom” only in Advanced and diagnostics |
| Calibrate… · Run Self-Test… · Reset Display Colors… | — |  |
| Keep this level? · Go Back · Keep | — | the very-dark-level prompt |
| Pause · Paused · Resume | — | a temporary stop; never “disabled” |

## Carried from Cranny (generic interface words)

| English | ms | Note |
|---|---|---|
| Overbright | Overbright | never translated; also the open panel ("Buka Overbright", "Kekalkan Overbright terbuka") |
| Shortcuts (Apple's app) · a shortcut (Shortcuts.app) | Pintasan · pintasan | "app Pintasan" wherever bare "Pintasan" could read as "shortcuts": "Buka app Pintasan", "Muat semula daripada app Pintasan", "Tidak ditemui dalam app Pintasan"; the Settings pane name stays "Pintasan" |
| keyboard shortcut | pintasan papan kekunci / pintasan | Settings ▸ Keyboard section: "Pintasan papan kekunci" |
| launcher (search word) | pelancar |  |
| About Overbright · Quit Overbright | Perihal Overbright · Keluar daripada Overbright | Apple's app-menu pattern |
| setup (welcome flow) | persediaan | "Langkau persediaan" (not "seting" = Settings) |
| Reset to Default · Reset | Reset kepada Lalai · Reset | Apple ("Reset kepada Lalai", "mereset") |
| Changed from the default | Diubah daripada lalai |  |
| Allow… · Grant… | Benarkan… | Apple "Benarkan" / "Jangan Benarkan" |
| Preview | Pratonton | Apple |
| click | klik |  |
| Never (timeout 0) · Off · On | Tidak pernah · Mati · Hidup | segment pickers "Mati" |
| Turn on · Turn off (as a pair) | Hidupkan · Matikan | the pair as Apple's Home app: "Hidupkan mod demo" / "Matikan mod demo", "matikan penunjuk, kemudian hidupkannya semula"; on its own "mengaktifkan" stays fine for features and fallbacks, and a system setting quoted in a sentence is "… diaktifkan" |
| Delete | Padam | Apple |
| App not installed | App tidak dipasang |  |
| Symbol | Simbol |  |
| Undo | Buat asal | Apple |
| Check for Updates | Semak Kemas Kini | Apple |
| Login Items | Item Log Masuk | Apple |
| Launch at login / Open at login | Buka semasa log masuk |  |
