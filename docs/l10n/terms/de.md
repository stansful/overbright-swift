# Overbright — German (Deutsch, `de`) terminology sheet

Carried from Cranny’s sheet for this language (ARCHITECTURE.md §10.2): the register, voice and
typography decisions are language facts and stay; Cranny’s notch, widget and ambient-light rows are
deleted, and examples and notes that named Cranny’s features (the notch, the Tray, widgets, Calendar, Notes,
Media, permissions) were replaced with Overbright’s or dropped. Overbright’s own names, its pane names among them,
are decided in WP15 (ARCHITECTURE.md §10.17, §8.8); until then they read “—”.
`scripts/l10n/languages.json` has this language’s plural categories and quotation marks.

## Register and typography

Register: informal **du**, lowercase in running text ("dein", "deine Kamera"), as macOS since 2020.
Buttons, menu items, commands and toggles: **infinitive at the end** ("Overbright beenden", "Nach Updates suchen …",
"Symbol in der Menüleiste anzeigen"). Instructions and footnotes: **du-imperative** ("Klicke auf das Symbol in der Menüleiste").
Typography: „…“ (secondary ‚…‘), apostrophe ’, ellipsis … preceded by a **no-break space** in menu items, buttons and
progress text ("Einstellungen …", "Laden …") as AppKit/Finder write it; en dash with spaces " – " for a parenthetical
dash (English "—"); "&" only where Apple uses it (pane names). Nouns capitalized; compounds with names take a hyphen
("Overbright-Einstellungen", "HDR-Video", "OLED-Display").

## Apple names (`apple-terms.py de` on macOS 27.0.1 — never paraphrased)

| English | de |
|---|---|
| System Settings | Systemeinstellungen |
| Finder | Finder |
| Shortcuts | Kurzbefehle |
| Photos | Fotos |
| TV | TV |
| QuickTime Player | QuickTime Player |
| Privacy & Security | Datenschutz & Sicherheit |
| Accessibility | Bedienungshilfen |
| General | Allgemein |
| Appearance | Erscheinungsbild |
| Menu Bar | Menüleiste |
| Control Center | Kontrollzentrum |
| Focus | Fokus |
| Displays | Displays |
| Keyboard | Tastatur |
| Keyboard Shortcuts… | Tastaturkurzbefehle … |
| Lock Screen | Sperrbildschirm |
| Battery | Batterie |
| Energy | Energie |
| Screen Saver | Bildschirmschoner |
| Login Items | Anmeldeobjekte |
| Login Items & Extensions | Anmeldeobjekte & Erweiterungen |
| Brightness | Helligkeit |
| Automatically adjust brightness | Helligkeit automatisch anpassen |
| True Tone | True Tone |
| High Dynamic Range | Hochkontrastbild |
| Preset | Voreinstellung |
| Night Shift… | Night Shift … |
| Color profile | Farbprofil |
| Refresh rate | Wiederholrate |
| Allow in the Menu Bar | In Menüleiste erlauben |
| Low Power Mode | Stromsparmodus |
| Do Not Disturb | Nicht stören |
| Camera | Kamera |
| Open Anyway | Dennoch öffnen |
| Applications | Apps |
| Reduce motion | Bewegung reduzieren |
| Reduce transparency | Transparenz reduzieren |
| Increase contrast | Kontrast erhöhen |
| Differentiate without color | Ohne Farben differenzieren |
| VoiceOver | VoiceOver |

## Overbright’s own names

| English | de | Note |
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

| English | de | Note |
|---|---|---|
| Overbright | Overbright | never translated; neuter when a pronoun is unavoidable ("es"); also the open panel ("Overbright öffnen") |
| Shortcuts (Apple's app) · a shortcut in it | Kurzbefehle · Kurzbefehl | Apple's name |
| keyboard shortcut | Tastenkombination | never "Kurzbefehl" (= Shortcuts app) |
| Try again / Retry | Wiederholen | the standard German retry button: the chip, the banner and the card menu of a display that failed or stopped |
| Reset to Default | Auf Standard zurücksetzen |  |
| Changed from the default | Vom Standard abweichend |  |
| Allow… / Grant… | Erlauben … |  |
| Preview | Vorschau |  |
| click | klicken |  |
| Welcome / setup | Willkommen / Einrichtung |  |
| Never (timeout 0) · Off | Nie · Aus |  |
| Show … (toggles, buttons, actions) | … anzeigen | never bare „zeigen“ („Symbol in der Menüleiste anzeigen“, „Willkommen anzeigen …“) |
| Remove (from a list) · Delete | Entfernen · Löschen |  |
| App not installed | App nicht installiert |  |
| Symbol | Symbol |  |
