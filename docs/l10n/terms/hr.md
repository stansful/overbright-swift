# Overbright — Croatian (hrvatski, `hr`) terminology sheet

Carried from Cranny’s sheet for this language (ARCHITECTURE.md §10.2): the register, voice and
typography decisions are language facts and stay; Cranny’s notch, widget and ambient-light rows are
deleted, and examples and notes that named Cranny’s features (the notch, the Tray, widgets, Calendar, Notes,
Media, permissions) were replaced with Overbright’s or dropped. Overbright’s own names, its pane names among them,
were decided in WP15 (ARCHITECTURE.md §10.17, §8.8); the table shows them as the catalogs ship them.
`scripts/l10n/languages.json` has this language’s plural categories and quotation marks.

## Register and typography

Register and style, following macOS 27 in Croatian:

- Buttons, menu items, toggles and checkboxes: **imperative, 2nd person singular** (Apple: “Prikaži”, “Otvori”, “Obriši”, “Smanji pomicanje”, “Prikaži u traci s izbornicima”).
- Sentences, footnotes, instructions and onboarding: **formal Vi** (“Povucite”, “Kliknite”, “Vaši zasloni”).
- Confirmation titles as questions: **infinitive** (Apple: “Pristupiti kalendaru “%@”?”) → “Resetirati boje zaslona?”, “Resetirati sve postavke?”.
- Sentence case everywhere (no English title case in menus); quotes “…” as macOS writes them in Croatian; one-character ellipsis …; ▸ for paths.
- Placeholders are not declined: a noun in front carries the case (“u aplikaciji %@”, “na zaslonu “%@””).
- Apple’s names come from the apple-terms glossary (`apple-terms.py hr`): Postavke sustava, Privatnost i sigurnost, Pristupačnost, Stavke za prijavu, Traka s izbornicima, Mod slabog napajanja, Prečaci, Smanji pomicanje, Smanji prozirnost, Povećaj kontrast, Razgraniči bez boje.

Reviewed 2026-10-14 (independent review).

### The brand

“Overbright” is never translated. Cranny’s sheet inflected its name; those forms do not carry over (“Overbright” ends in a consonant), so the inflected forms are WP15’s decision (ARCHITECTURE.md §10.17). Until then every brand-bearing string is marked needs_review.

## Apple names (`apple-terms.py hr` on macOS 27.0.1 — never paraphrased)

| English | hr |
|---|---|
| System Settings | Postavke sustava |
| Finder | Finder |
| Shortcuts | Prečaci |
| Photos | Foto |
| TV | TV |
| QuickTime Player | QuickTime Player |
| Privacy & Security | Privatnost i sigurnost |
| Accessibility | Pristupačnost |
| General | Općenito |
| Appearance | Izgled |
| Menu Bar | Traka s izbornicima |
| Control Center | Kontrolni centar |
| Focus | Fokus |
| Displays | Zasloni |
| Keyboard | Tipkovnica |
| Keyboard Shortcuts… | Prečaci tipkovnice… |
| Lock Screen | Zaključani zaslon |
| Battery | Baterija |
| Energy | Energija |
| Screen Saver | Zaštita zaslona |
| Login Items | Stavke za prijavu |
| Login Items & Extensions | Stavke za prijavu i ekstenzije |
| Brightness | Svjetlina |
| Automatically adjust brightness | Automatski podesi svjetlinu |
| True Tone | True Tone |
| High Dynamic Range | Visok dinamički raspon |
| Preset | Podešenje |
| Night Shift… | Night Shift… |
| Color profile | Profil boje |
| Refresh rate | Stopa osvježavanja |
| Allow in the Menu Bar | Dozvoli u traci s izbornicima |
| Low Power Mode | Mod slabog napajanja |
| Do Not Disturb | Zabrana ometanja |
| Camera | Kamera |
| Open Anyway | Otvori svejedno |
| Applications | Aplikacije |
| Reduce motion | Smanji pomicanje |
| Reduce transparency | Smanji prozirnost |
| Increase contrast | Povećaj kontrast |
| Differentiate without color | Razgraniči bez boje |
| VoiceOver | VoiceOver |

## Overbright’s own names

| English | hr | Note |
|---|---|---|
| Overbright | Overbright | never translated or transliterated |
| Settings panes: General · Displays · Automations · Shortcuts · Fill Light · Advanced · About | Općenito · Zasloni · Automatizacija · Prečaci tipkovnice · Osvjetljenje lica · Napredno · Opis | the sidebar and window titles |
| Standard (the brightness macOS shows) | Standardno | never “100 %” or “normal mode” |
| extra brightness (the boost half) | “Koristi dodatnu svjetlinu” (Use extra brightness) | never “boost”, “HDR mode”, “EDR” |
| Dim below minimum (the setting) | “Uključi ili isključi zatamnjenje ispod minimuma” (Dim Below Minimum On or Off) | the incumbent’s name for it is never used |
| Dimmed (the state) · Dim All Displays / Stop Dimming (actions) | Zatamnjeno · Zatamni sve zaslone / Ukloni zatamnjenje | not “night mode” |
| Brighter · Less Bright (one step) | Svjetlije · Manje svijetlo | never “Dimmer”: it reads like Dim |
| Back to Standard (the instant off) | Vrati na standardno | not “panic”, not “reset brightness” |
| Indoor · Bright room · Sunlight · Max (presets) | U zatvorenom · Svijetla prostorija · Na suncu · Maksimum | “Max” is a preset only |
| Safe · Peak (ceilings) | Sigurno · Vršno | Peak, never “Max”, for a ceiling; one short word each (segments) |
| Compatibility mode · Color table (methods) | Način kompatibilnosti · Tablica boja | never “fallback” or “overlay” |
| Fill Light (the edge light for video calls) | Osvjetljenje lica | never “ring light” |
| extra range (headroom, in user copy) | Rezerva svjetline | “headroom” only in Advanced and diagnostics |
| Calibrate… · Run Self-Test… · Reset Display Colors… | Kalibriraj… · Pokreni samoprovjeru… · Resetiraj boje zaslona… |  |
| Keep this level? · Go Back · Keep | Zadržati ovu razinu? · Vrati · Zadrži | the very-dark-level prompt |
| Pause · Paused · Resume | “Pauziraj Overbright” (Pause Overbright) · Pauzirano · Nastavi | a temporary stop; never “disabled” |

## Carried from Cranny (generic interface words)

| English | hr | Note |
|---|---|---|
| Shortcuts (Apple’s app) · shortcut | Prečaci · prečac | “u Prečacima” / “u aplikaciji Prečaci” (both Apple); “Otvori aplikaciju Prečaci” (Apple “Otvori aplikaciju Glazba”); “Aplikacija Prečaci nije dostupna” |
| keyboard shortcut | prečac tipkovnice | short “prečac” inside Overbright's Shortcuts pane (the key bindings) |
| Reset to Default · Changed from the default | Resetiraj na standardno · Promijenjeno u odnosu na standardnu vrijednost | Apple’s exact menu item (Podcasts “Reset to Default”); “standardne vrijednosti” in sentences |
| click | klik / kliknuti |  |
| Open at login / Launch at login | Otvori kod prijave | Apple’s Login Items wording |
| Check for Updates | Potraži ažuriranja | Apple |
| About (pane) / About Overbright | Opis / Više o aplikaciji Overbright | Apple General ▸ Opis; AppKit app menu “About %@” = “Više o aplikaciji %@” |
| Acknowledgments | Priznanja | Apple |
| Remove · Delete · Clear · Undo · Cancel | Ukloni · Obriši · Očisti · Poništi · Odustani | Apple |
| Preview | Pretpregled | “Pregled” is Apple’s Preview app |
| Never (timeout 0) | Nikad | Apple “Nikad” |
| Off | Isključeno |  |
