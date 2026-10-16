# Overbright — Indonesian (Indonesia, `id`) terminology sheet

Carried from Cranny’s sheet for this language (ARCHITECTURE.md §10.2): the register, voice and
typography decisions are language facts and stay; Cranny’s notch, widget and ambient-light rows are
deleted. Overbright’s own names are decided in WP15 (ARCHITECTURE.md §10.17, §8.8); until then they
read “—”. `scripts/l10n/languages.json` has this language’s plural categories and quotation marks.

## Register and typography

Register: formal **Anda** (capital A), as macOS. Buttons and menu items use the bare imperative
("Buka", "Tampilkan", "Jeda"), as Apple's Indonesian does. Where English uses Title Case (menu items, buttons) the
Indonesian is Title Case too ("Periksa Pembaruan…", "Tutup Overbright", "Pindahkan ke Bawah"); function words stay
lower case (ke, di, dari, dan, untuk, yang, dengan). Settings rows, toggles and footnotes are sentence case.
Typography: quotes “…” (‘…’ inside), one-character ellipsis …, “ ▸ ” in Settings paths, no straight quotes.
Indonesian has no grammatical plural: every plural key has only `other` ("%lld item", "%lld hari", "Sisa %lld sel").
Apple's own names come from `apple-terms.py id` (read from macOS 27) and from macOS 27's own loctables
(AppKit menus, Finder, Calendar, keyboard-shortcut table).


Reviewed 2026-10-14 (independent review).

## Apple names (`apple-terms.py id` on macOS 27.0.1 — never paraphrased)

| English | id |
|---|---|
| System Settings | Pengaturan Sistem |
| Finder | Finder |
| Shortcuts | Pintasan |
| Photos | Foto |
| TV | TV |
| QuickTime Player | QuickTime Player |
| Privacy & Security | Privasi & Keamanan |
| Accessibility | Aksesibilitas |
| General | Umum |
| Appearance | Tampilan |
| Menu Bar | Bar Menu |
| Control Center | Pusat Kontrol |
| Focus | Fokus |
| Displays | Layar |
| Keyboard | Papan Ketik |
| Keyboard Shortcuts… | Pintasan Papan Ketik… |
| Lock Screen | Layar Terkunci |
| Battery | Baterai |
| Energy | Energi |
| Screen Saver | Penghemat Layar |
| Login Items | Item Masuk |
| Login Items & Extensions | Item Masuk & Ekstensi |
| Brightness | Kecerahan |
| Automatically adjust brightness | Sesuaikan kecerahan secara otomatis |
| True Tone | True Tone |
| High Dynamic Range | Rentang Dinamis Tinggi |
| Preset | Preset |
| Night Shift… | Night Shift… |
| Color profile | Profil warna |
| Refresh rate | Laju penyegaran |
| Allow in the Menu Bar | Izinkan di Bar Menu |
| Low Power Mode | Mode Daya Rendah |
| Do Not Disturb | Jangan Ganggu |
| Camera | Kamera |
| Open Anyway | Tetap Buka |
| Applications | Aplikasi |
| Reduce motion | Kurangi gerakan |
| Reduce transparency | Kurangi transparansi |
| Increase contrast | Tambah kontras |
| Differentiate without color | Bedakan tanpa warna |
| VoiceOver | VoiceOver |

## Overbright’s own names

| English | id | Note |
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

| English | id | Note |
|---|---|---|
| Overbright | Overbright | never translated; also the open panel ("Buka Overbright", "Biarkan Overbright terbuka") |
| Quit Overbright · Close Overbright (Esc, the panel) · When Overbright quits | Tutup Overbright · Tutup panel Overbright · Hingga app Overbright ditutup | macOS says "Tutup [App]" for Quit (TextEdit: "Tutup TextEdit"), so wherever closing the *panel* could be read as quitting, say "panel"; where the *app* quits, say "app Overbright" |
| Shortcuts (Apple's app) · a shortcut | Pintasan · pintasan | "app Pintasan" in sentences where it could mean keyboard shortcuts |
| keyboard shortcut | pintasan / pintasan papan ketik |  |
| About Overbright · Quit Overbright | Mengenai Overbright · Tutup Overbright | Apple's app-menu pattern ("Mengenai TextEdit", "Tutup TextEdit", verified in TextEdit's Edit.loctable) |
| setup (welcome flow) | penyiapan | "Lewati penyiapan" (not "pengaturan" = Settings) |
| Reset to Default · Reset | Atur Ulang ke Default · Atur Ulang | Apple: "Atur Ulang ke Default" |
| Changed from the default | Diubah dari default |  |
| Allow… · Grant… | Izinkan… |  |
| Preview | Pratinjau |  |
| click | klik |  |
| Never (timeout 0) · Off · On | Tidak pernah · Mati · menyala |  |
| Remove (app from a list) | Hapus … dari daftar | never a bare "Hapus app" |
| App not installed | App tidak terinstal |  |
| Symbol | Simbol |  |
