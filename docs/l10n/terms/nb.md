# Overbright — Norwegian Bokmål (norsk bokmål, `nb`) terminology sheet

Carried from Cranny’s sheet for this language (ARCHITECTURE.md §10.2): the register, voice and
typography decisions are language facts and stay; Cranny’s notch, widget and ambient-light rows are
deleted. Overbright’s own names are decided in WP15 (ARCHITECTURE.md §10.17, §8.8); until then they
read “—”. `scripts/l10n/languages.json` has this language’s plural categories and quotation marks.

## Register and typography

Register: informal **du**, sentence case everywhere (also menu items and buttons, as Norwegian macOS writes them:
“Søk etter oppdateringer…”, “Avslutt Overbright”, “Om Overbright”). Buttons, menu items and switches in the
**imperative** (Åpne, Legg til, Fjern, Vis, Skjul), as Apple’s Norwegian System Settings does (“Vis prosent”,
“Skjul og vis Dock automatisk”). Quotes «…» (inner ‘…’), apostrophe ’, ellipsis … glued to the word
(“Innstillinger…”), spaced en dash “ – ” in running text. Conservative bokmål forms as Apple uses them
(“menylinjen”, “hyllen”, “Macen”). Errors in Apple’s style: “Kunne ikke …” / “Kan ikke …”. Units: min, t
(time), sek, pkt. (points), px. Genitive of the name: “Overbrights” (no apostrophe). Overbright is “den” (appen);
adjectives in common gender (“Overbright, lukket”). Compounds with a name take a hyphen (“Bluetooth-enheter”,
“Overbright-vinduet”, “zip-arkiv”).


### Style notes

- Permission reasons (Permissions pane, onboarding) are descriptive present tense: “Viser hendelsene dine i Overbright.”,
  “Styrer avspillingen …”, “Erstatter systemets …” — never a bare imperative that reads like an order to the user.
- No comma between two imperatives joined by “og/eller” (“Klikk her eller trykk”, “Fest den med festeknappen og trykk
  så Esc”); a comma after a subordinate clause in mid-sentence (“Apper som ikke er installert, blir værende her”).
- Questions in alerts start with “Vil du …?” (“Vil du slette «%@»?”, “Vil du nullstille alle innstillinger?”).
- Apple’s app names are not quoted (“Åpne i Kalender”, “Musikk og Spotify”); names of settings and Overbright rows are
  quoted when they sit in running text («Reduser bevegelse», «Bli med», «Legg på hyllen»).
- Widget names compound with a hyphen: “Speil-widgeten”, “%@-widgeten”, “Hylle-siden”.
- Keyboard navigation is «Gå mellom …» (“Gå mellom widgeter”); «Flytt …» is only for really moving something
  (“Flytt til venstre”, Apple’s “Flytt ett arbeidsområde til venstre”).
- Purpose takes «brukes til» (“Brukes til fremdrift, ringer og brytere”), questions to a service «spørre om»
  (“Spør GitHub om nye utgivelser”).
- After «første/siste/neste» the noun is definite with its article: “det første objektet”.
- A macOS shortcut name in a sentence is quoted like a Overbright one: “macOS bruker %1$@ for «%2$@».”

## Apple names (`apple-terms.py nb` on macOS 27.0.1 — never paraphrased)

| English | nb |
|---|---|
| System Settings | Systeminnstillinger |
| Finder | Finder |
| Shortcuts | Snarveier |
| Photos | Bilder |
| TV | TV |
| QuickTime Player | QuickTime Player |
| Privacy & Security | Personvern og sikkerhet |
| Accessibility | Tilgjengelighet |
| General | Generelt |
| Appearance | Utseende |
| Menu Bar | Menylinje |
| Control Center | Kontrollsenter |
| Focus | Fokus |
| Displays | Skjermer |
| Keyboard | Tastatur |
| Keyboard Shortcuts… | Tastatursnarveier… |
| Lock Screen | Låst skjerm |
| Battery | Batteri |
| Energy | Strøm |
| Screen Saver | Skjermsparer |
| Login Items | Påloggingsobjekter |
| Login Items & Extensions | Påloggingsobjekter og utvidelser |
| Brightness | Lysstyrke |
| Automatically adjust brightness | Juster lysstyrken automatisk |
| True Tone | True Tone |
| High Dynamic Range | Utvidet dynamisk område |
| Preset | Forhåndsinnstilling |
| Night Shift… | Night Shift… |
| Color profile | Fargeprofil |
| Refresh rate | Skjermfrekvens |
| Allow in the Menu Bar | Tillat i menylinjen |
| Low Power Mode | Spareblussmodus |
| Do Not Disturb | Ikke forstyrr |
| Camera | Kamera |
| Open Anyway | Åpne likevel |
| Applications | Apper |
| Reduce motion | Reduser bevegelse |
| Reduce transparency | Reduser gjennomsiktighet |
| Increase contrast | Øk kontrast |
| Differentiate without color | Differensier uten farger |
| VoiceOver | VoiceOver |

## Overbright’s own names

| English | nb | Note |
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

| English | nb | Note |
|---|---|---|
| Overbright | Overbright | never translated; genitive “Overbrights”; “Åpne Overbright” |
| Settings | Innstillinger | “Innstillinger ▸ Tastatur” |
| Welcome / setup (first-run window) | velkomst | “Hopp over velkomsten”, “Vis velkomst”; never “oppsett”, which is the layout |
| shortcut (Shortcuts app) | snarvei / snarveier | “Kjør «%@»”, “Legg til snarvei” |
| keyboard shortcut | tastatursnarvei | “Trykk tastatursnarveien” |
| Reset to Default · Changed from the default | Gjenopprett standard · Endret fra standard |  |
| click | klikk / klikke (på) | Apple: “Klikk på …” |
| Getting started · Acknowledgments | Kom i gang · Takk til |  |
