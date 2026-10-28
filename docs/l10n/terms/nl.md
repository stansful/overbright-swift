# Overbright — Dutch (Nederlands, `nl`) terminology sheet

Carried from Cranny’s sheet for this language (ARCHITECTURE.md §10.2): the register, voice and
typography decisions are language facts and stay; Cranny’s notch, widget and ambient-light rows are
deleted, and examples and notes that named Cranny’s features (the notch, the Tray, widgets, Calendar, Notes,
Media, permissions) were replaced with Overbright’s or dropped. Overbright’s own names, its pane names among them,
were decided in WP15 (ARCHITECTURE.md §10.17, §8.8); the table shows them as the catalogs ship them.
`scripts/lib/l10n/languages.json` has this language’s plural categories and quotation marks.

## Register and typography

Register: informal **je/jij** ("je", "jouw", lowercase), as macOS. Buttons, menu items, commands and settings
switches: **imperative first**, as Apple's Dutch macOS ("Open Overbright", "Stop Overbright", "Zoek naar updates…",
"Toon symbool in menubalk", "Verminder beweging"). Dialog titles that ask: **infinitive at the end**
("Alle instellingen herstellen?", "‘%@’ verwijderen?"). Section headers, picker labels and statuses: nouns,
adjectives or participles ("Duur", "Toegestaan", "Gepauzeerd"). Instructions and footnotes: imperative
("Klik op het symbool in de menubalk", "Sleep Overbright naar de map Apps").
Typography: quotes ‘…’ (secondary “…”); macOS itself writes straight '…' in Dutch, Overbright uses the typographic
ones. Apostrophe ’ ("foto’s", "video’s", "menu’s"), one-character ellipsis …, sentence case. Compounds are
written together; a hyphen after names, abbreviations, digits and vowel clashes ("Overbright-paneel",
"HDR-video", "OLED-beeldscherm", "Foto’s-app"). "&" in Apple pane names becomes "en"
as Apple writes it.

## Apple names (`apple-terms.py nl` on macOS 27.0.1 — never paraphrased)

| English | nl |
|---|---|
| System Settings | Systeeminstellingen |
| Finder | Finder |
| Shortcuts | Opdrachten |
| Photos | Foto's |
| TV | TV |
| QuickTime Player | QuickTime Player |
| Privacy & Security | Privacy en beveiliging |
| Accessibility | Toegankelijkheid |
| General | Algemeen |
| Appearance | Weergave |
| Menu Bar | Menubalk |
| Control Center | Bedieningspaneel |
| Focus | Focus |
| Displays | Beeldschermen |
| Keyboard | Toetsenbord |
| Keyboard Shortcuts… | Toetscombinaties… |
| Lock Screen | Toegangsscherm |
| Battery | Batterij |
| Energy | Energie |
| Screen Saver | Schermbeveiliging |
| Login Items | Inloggen |
| Login Items & Extensions | Inlogonderdelen en extensies |
| Brightness | Helderheid |
| Automatically adjust brightness | Pas helderheid automatisch aan |
| True Tone | True Tone |
| High Dynamic Range | Hoog dynamisch bereik |
| Preset | Voorinstelling |
| Night Shift… | Night Shift… |
| Color profile | Kleurenprofiel |
| Refresh rate | Verversing |
| Allow in the Menu Bar | Sta toe in de menubalk |
| Low Power Mode | Energiebesparingsmodus |
| Do Not Disturb | Niet storen |
| Camera | Camera |
| Open Anyway | Open toch |
| Applications | Apps |
| Reduce motion | Verminder beweging |
| Reduce transparency | Verminder doorzichtigheid |
| Increase contrast | Verhoog contrast |
| Differentiate without color | Differentieer zonder kleur |
| VoiceOver | VoiceOver |

## Overbright’s own names

| English | nl | Note |
|---|---|---|
| Overbright | Overbright | never translated or transliterated |
| Settings panes: General · Displays · Automations · Shortcuts · Fill Light · Advanced · About | Algemeen · Beeldschermen · Automatisering · Toetscombinaties · Invullicht · Geavanceerd · Over | the sidebar and window titles |
| Standard (the brightness macOS shows) | Standaard | never “100 %” or “normal mode” |
| extra brightness (the boost half) | “Gebruik extra helderheid” (Use extra brightness) | never “boost”, “HDR mode”, “EDR” |
| Dim below minimum (the setting) | “Schakel dimmen onder minimum in of uit” (Dim Below Minimum On or Off) | the incumbent’s name for it is never used |
| Dimmed (the state) · Dim All Displays / Stop Dimming (actions) | Gedimd · Dim alle beeldschermen / Stop dimmen | not “night mode” |
| Brighter · Less Bright (one step) | Helderder · Minder helder | never “Dimmer”: it reads like Dim |
| Back to Standard (the instant off) | Terug naar Standaard | not “panic”, not “reset brightness” |
| Indoor · Bright room · Sunlight · Max (presets) | Binnen · Lichte ruimte · Zonlicht · Maximum | “Max” is a preset only |
| Safe · Peak (ceilings) | Veilig · Piek | Peak, never “Max”, for a ceiling; one short word each (segments) |
| color table (in sentences: “macOS ignores color table changes”) | kleurentabel | never “gamma”; no “fallback” or “overlay” in copy |
| Fill Light (the edge light for video calls) | Invullicht | never “ring light” |
| extra range (headroom, in user copy) | Extra bereik | “headroom” only in Advanced and diagnostics |
| Calibrate… · Run Self-Test… · Reset Display Colors… | Kalibreer… · Voer zelftest uit… · Stel beeldschermkleuren opnieuw in… |  |
| Keep this level? · Go Back · Keep | Dit niveau behouden? · Ga terug · Behoud | the very-dark-level prompt |
| Pause · Paused · Resume | “Pauzeer Overbright” (Pause Overbright) · Gepauzeerd · Hervat | a temporary stop; never “disabled” |

## Carried from Cranny (generic interface words)

| English | nl | Note |
|---|---|---|
| Overbright | Overbright | never translated; also the open panel ("Open Overbright", "Houd Overbright open") |
| Shortcuts (Apple's app) · a shortcut in it | Opdrachten · opdracht | Apple's name |
| keyboard shortcut | toetscombinatie | never "opdracht" (= Shortcuts app) |
| Reset to Default | Herstel standaardwaarde | a restore, close to Apple’s ‘Herstel standaardinstelling’; every other Reset is ‘Stel opnieuw in’ |
| Changed from the default | Afwijkend van standaardwaarde |  |
| Allow… / Grant… | Sta toe… |  |
| Preview | Voorvertoning |  |
| click | klikken |  |
| Welcome / setup | Welkom / configuratie | "Sla configuratie over" |
| Never (timeout 0) · Off | Nooit · Uit |  |
| Show … (switches) | Toon … |  |
| Remove (from a list) · Delete | Verwijder uit … · Verwijder | "Verwijder %@ uit lijst" |
| App not installed | App niet geïnstalleerd |  |
| Symbol | Symbool |  |
| Space (the space bar in key caps) | Spatie | as AppKit writes it in menu key equivalents (FunctionKeyNames.loctable “Space”), so Settings and Welcome show the same key caps as the menu; AppKit’s name for the physical key is Spatiebalk |
