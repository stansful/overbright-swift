# Overbright — Romanian (română, `ro`) terminology sheet

Carried from Cranny’s sheet for this language (ARCHITECTURE.md §10.2): the register, voice and
typography decisions are language facts and stay; Cranny’s notch, widget and ambient-light rows are
deleted, and examples and notes that named Cranny’s features (the notch, the Tray, widgets, Calendar, Notes,
Media, permissions) were replaced with Overbright’s or dropped. Overbright’s own names, its pane names among them,
are decided in WP15 (ARCHITECTURE.md §10.17, §8.8); until then they read “—”.
`scripts/l10n/languages.json` has this language’s plural categories and quotation marks.

## Register and typography

Register and typography: formal **dumneavoastră** ("dvs."), as macOS. Following Apple's Romanian macOS:
**buttons, menu items and VoiceOver actions use the formal imperative** ("Deschideți", "Afișați",
"Adăugați", "Anulați"); **setting labels and switches use the verbal noun** ("Afișare ceas…" style: "Afișare
pictogramă în bara de meniu"); section headers and states are nouns or adjectives.
Instructions to the user use the imperative ("Trageți Overbright în dosarul Aplicații", "Faceți clic pe…").
Sentence case everywhere (English Title Case menu items become "Căutați actualizări…"). Quotes „…” (secondary
«…»), apostrophe ’, one-character ellipsis …, comma-below ș ț. Clitic hyphens are Apple's non-breaking hyphen
U+2011 ("activați‑l", "într‑un"), never in search keywords. Numbers, dates and durations come pre-formatted
(Romanian ICU narrow: "4 m", "1 h 30 m"; "50 %"). Plural: one (1), few (0, 2–19, 101–119…), other (20+, with
"de" before a noun: "20 de articole").

**Overbright** is never translated, transliterated or inflected (no "Overbright‑ul"); it takes neuter/masculine agreement
("Overbright este deschis", "Mențineți Overbright deschis"). Where Romanian would need a genitive, rephrase or use
"aplicația Overbright" ("Închideți aplicația Overbright").

## Apple names (`apple-terms.py ro` on macOS 27.0.1 — never paraphrased)

| English | ro |
|---|---|
| System Settings | Configurări sistem |
| Finder | Finder |
| Shortcuts | Scurtături |
| Photos | Poze |
| TV | TV |
| QuickTime Player | QuickTime Player |
| Privacy & Security | Intimitate și securitate |
| Accessibility | Accesibilitate |
| General | General |
| Appearance | Aspect |
| Menu Bar | Bară de meniu |
| Control Center | Centru de control |
| Focus | Concentrare |
| Displays | Afișaje |
| Keyboard | Tastatură |
| Keyboard Shortcuts… | Scurtături din tastatură… |
| Lock Screen | Ecran de blocare |
| Battery | Baterie |
| Energy | Energie |
| Screen Saver | Screensaver |
| Login Items | Lansare la login |
| Login Items & Extensions | Lansare la login și extensii |
| Brightness | Luminozitate |
| Automatically adjust brightness | Ajustare automată luminozitate |
| True Tone | True Tone |
| High Dynamic Range | Gamă dinamică înaltă |
| Preset | Preconfigurare |
| Night Shift… | Night Shift… |
| Color profile | Profil de culoare |
| Refresh rate | Rată de actualizare |
| Allow in the Menu Bar | Permiteți în bara de meniu |
| Low Power Mode | Mod Consum redus |
| Do Not Disturb | Nu deranjați |
| Camera | Cameră |
| Open Anyway | Deschideți oricum |
| Applications | Aplicații |
| Reduce motion | Reducere mișcare |
| Reduce transparency | Reducere transparență |
| Increase contrast | Sporire contrast |
| Differentiate without color | Diferențiere fără culoare |
| VoiceOver | VoiceOver |

## Overbright’s own names

| English | ro | Note |
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

| English | ro | Note |
|---|---|---|
| Overbright | Overbright | brand, uninflected; also the name of the open panel ("Deschideți Overbright", "Închideți Overbright" = close the panel) |
| Quit Overbright | Închideți aplicația Overbright | Apple's "Închideți aplicația %@"; keeps Quit apart from Close |
| Preview | Previzualizare |  |
| click | clic / faceți clic | Apple "Faceți clic pe…" |
| Shortcuts (Apple app) | Scurtături | Apple's name; one shortcut of the app = "scurtătură" |
| keyboard shortcut | scurtătură din tastatură | Apple's wording; plain "scurtătură" where context is the keyboard |
| Settings | Configurări | Apple macOS 13+ ("Configurări…", "Configurări ▸ General") |
| Reset to Default | Resetați la valoarea implicită |  |
| Changed from the default | Modificat față de valoarea implicită |  |
| Allow… / Grant… | Permiteți… | Apple "Permiteți" |
| Delete | Ștergeți | only for real deletion |
| App not installed | Aplicație neinstalată |  |
| Welcome | Bun venit | "Bun venit în Overbright" |
| Never (timeout 0) | Niciodată |  |
| Show … (switches) | Afișare … |  |
| Symbol | Simbol |  |
| Login Items | Lansare la login | Apple's pane name ("Deschideți „Lansare la login”…") |
| Launch / Open at login | Deschidere la login | Apple "Deschideți la login" |
| Esc / Return / Space / Delete / Command / Option | Esc / Retur / Spațiu / Delete / Comandă / Opțiune | Apple key names; key caps stay symbols |
| Undo | Infirmați (button) · anula (running text) | Apple's Edit-menu word ("Infirmați %@") on the Reset All banner; sentences say "Puteți anula acțiunea…", as Apple ro ("pentru a anula modificările") |
| This action cannot be undone. | Această acțiune este ireversibilă. | Apple ro |
