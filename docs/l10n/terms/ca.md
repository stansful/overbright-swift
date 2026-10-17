# Overbright — Catalan (català, `ca`) terminology sheet

Carried from Cranny’s sheet for this language (ARCHITECTURE.md §10.2): the register, voice and
typography decisions are language facts and stay; Cranny’s notch, widget and ambient-light rows are
deleted, and examples and notes that named Cranny’s features (the notch, the Tray, widgets, Calendar, Notes,
Media, permissions) were replaced with Overbright’s or dropped. Overbright’s own names, its pane names among them,
were decided in WP15 (ARCHITECTURE.md §10.17, §8.8); the table shows them as the catalogs ship them.
`scripts/l10n/languages.json` has this language’s plural categories and quotation marks.

## Register and typography

Register and style, checked against the Catalan strings of macOS 27 on this Mac (system loctables):

- Informal **tu** ("Vols…?", "Prem", "Fes clic"). Buttons, menu items and toggles are **imperative 2nd person
  singular**, as macOS writes them: "Obre", "Tanca", "Afegeix", "Mostra…", "Oculta…", "Cancel·la", "Continua",
  "Desa", "Omet", "Torna‑ho a provar", "Fet". VoiceOver hints are 3rd person ("Obre la configuració del sistema").
- Sentence case everywhere (also menus: "Cerca actualitzacions…", "Surt del Overbright").
- Apostrophe ’ (U+2019): l’app, d’Apple. Quotes “…” (secondary ‘…’). Ellipsis … (U+2026). Geminated l·l (U+00B7).
- Pronoun hyphen as macOS writes it: non-breaking hyphen U+2011 ("Torna‑ho", "Uneix‑t’hi", "Mou‑te").
- Product names take the article, as macOS does ("el Finder", "el Safari", "el macOS", "el Mac"):
  **el Overbright / del Overbright / al Overbright**. An app name in a placeholder: **l’app %@** (macOS: "l’app Música").
- System Settings in prose is lowercase, as macOS: "a la configuració del sistema"; the button is
  "Obre la configuració del sistema"; a path keeps the names: "Privacitat i seguretat ▸ Accessibilitat".
- "Couldn’t …" → "No s’ha pogut …"; "Delete “%@”?" → "Vols eliminar “%@”?"; "default" → "per omissió" (macOS).
- Plural categories one / many / other; *many* (millions) = same text as *other*. "one" is exactly 1, so
  "d’%lld" (d’1) is used in one-forms where the preposition elides.
- Pre-formatted durations (%@ = "1 min", "1 minut", "1 h 20 min") never follow a verb that must agree with them
  ("Queden %@" is wrong at one minute) or a preposition that must elide ("de %@" is wrong before "1 min"). Use the
  macOS patterns instead: "Restant: %@" (visible), "Temps restant: %@" (VoiceOver), "%@ després" (picker
  "After %@").
- A settings pane in running text is a "secció" (macOS: "a la secció Pantalles de la configuració del sistema").
- Key names in running text as macOS writes them: "la tecla d’opció", "la tecla d’ordre + fletxa amunt",
  "la barra espaiadora", "la tecla de retorn", "la tecla de supressió"; a shortcut hint is "Opció + 1".
_Reviewed 2026-10-14 (independent review): rows marked ★ changed or were added._

## Apple names (`apple-terms.py ca` on macOS 27.0.1 — never paraphrased)

| English | ca |
|---|---|
| System Settings | Configuració del Sistema |
| Finder | Finder |
| Shortcuts | Dreceres |
| Photos | Fotos |
| TV | TV |
| QuickTime Player | QuickTime Player |
| Privacy & Security | Privacitat i seguretat |
| Accessibility | Accessibilitat |
| General | General |
| Appearance | Aspecte |
| Menu Bar | Barra de menús |
| Control Center | Centre de control |
| Focus | Modes de concentració |
| Displays | Pantalles |
| Keyboard | Teclat |
| Keyboard Shortcuts… | Dreceres de teclat… |
| Lock Screen | Bloqueig de la pantalla |
| Battery | Bateria |
| Energy | Energia |
| Screen Saver | Estalvi de pantalla |
| Login Items | Ítems d’inici de sessió |
| Login Items & Extensions | Ítems d’inici de sessió i extensions |
| Brightness | Brillantor |
| Automatically adjust brightness | Ajusta automàticament la brillantor |
| True Tone | True Tone |
| High Dynamic Range | Rang dinàmic alt |
| Preset | Preconfiguració |
| Night Shift… | Night Shift… |
| Color profile | Perfil de color |
| Refresh rate | Freqüència d’actualització |
| Allow in the Menu Bar | Permet a la barra de menús |
| Low Power Mode | Mode de baix consum |
| Do Not Disturb | No molestar |
| Camera | Càmera |
| Open Anyway | Obre de tota manera |
| Applications | Apps |
| Reduce motion | Redueix el moviment |
| Reduce transparency | Redueix la transparència |
| Increase contrast | Augmenta el contrast |
| Differentiate without color | Diferencia sense color |
| VoiceOver | VoiceOver |

## Overbright’s own names

| English | ca | Note |
|---|---|---|
| Overbright | Overbright | never translated or transliterated |
| Settings panes: General · Displays · Automations · Shortcuts · Fill Light · Advanced · About | General · Pantalles · Automatitzacions · Dreceres de teclat · Llum de farciment · Avançat · Informació | the sidebar and window titles |
| Standard (the brightness macOS shows) | Estàndard | never “100 %” or “normal mode” |
| extra brightness (the boost half) | “Utilitza la brillantor extra” (Use extra brightness) | never “boost”, “HDR mode”, “EDR” |
| Dim below minimum (the setting) | “Activa o desactiva l’atenuació per sota del mínim” (Dim Below Minimum On or Off) | the incumbent’s name for it is never used |
| Dimmed (the state) · Dim All Displays / Stop Dimming (actions) | Atenuat · Atenua totes les pantalles / Deixa d’atenuar | not “night mode” |
| Brighter · Less Bright (one step) | Més brillant · Menys brillant | never “Dimmer”: it reads like Dim |
| Back to Standard (the instant off) | Torna a Estàndard | not “panic”, not “reset brightness” |
| Indoor · Bright room · Sunlight · Max (presets) | Interior · Sala lluminosa · Llum solar · Màxim | “Max” is a preset only |
| Safe · Peak (ceilings) | Segur · Pic | Peak, never “Max”, for a ceiling; one short word each (segments) |
| Compatibility mode · Color table (methods) | Mode de compatibilitat · Taula de colors | never “fallback” or “overlay” |
| Fill Light (the edge light for video calls) | Llum de farciment | never “ring light” |
| extra range (headroom, in user copy) | Marge extra | “headroom” only in Advanced and diagnostics |
| Calibrate… · Run Self-Test… · Reset Display Colors… | Calibra… · Executa l’autoprova… · Restableix els colors de les pantalles… |  |
| Keep this level? · Go Back · Keep | Vols mantenir aquest nivell? · Torna enrere · Mantén | the very-dark-level prompt |
| Pause · Paused · Resume | “Posa l’Overbright en pausa” (Pause Overbright) · En pausa · Reprèn | a temporary stop; never “disabled” |

Fit (WP15): the footer’s default row (Battery, Auto-pause, Timer) must fit its 304 pt in full in every language (`FooterFitTests`), so the Auto-pause chip reads “Autopausa” (off: “Sense autopausa”) and the Timer chip “Sense límit” for No timer.

## Carried from Cranny (generic interface words)

| English | ca | Note |
|---|---|---|
| Overbright | el Overbright | never translated; masculine with article: "Obre el Overbright", "Surt del Overbright" |
| Shortcuts (Apple app) · a shortcut | Dreceres (l’app Dreceres) · drecera | macOS name |
| keyboard shortcut | drecera de teclat / drecera | macOS: Teclat ▸ "Dreceres de teclat"; the bindings in Overbright's Shortcuts pane |
| Settings (Overbright) | Configuració | "Configuració ▸ General" |
| About (pane) · About Overbright (menu) | Informació · Sobre el Overbright | macOS: "Informació", "Sobre el Mail" |
| Reset to Default | Restableix el valor per omissió |  |
| Changed from the default | Canviat respecte del valor per omissió |  |
| Allow… / Grant… | Permet… |  |
| Preview | Previsualització |  |
| click | fer clic | "Fes clic a la icona de la barra de menús" |
| Never (timeout 0) | Mai |  |
| Symbol | Símbol |  |
| Login Items | Ítems d’inici de sessió | macOS |
| Acknowledgments ★ | Reconeixements | macOS (Books, Maps); search keeps "agraïments" |
| Option-1 (key hint) · Option key ★ | Opció + 1 · la tecla d’opció | macOS writes combinations with " + " |
