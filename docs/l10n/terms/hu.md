# Overbright — Hungarian (magyar, `hu`) terminology sheet

Carried from Cranny’s sheet for this language (ARCHITECTURE.md §10.2): the register, voice and
typography decisions are language facts and stay; Cranny’s notch, widget and ambient-light rows are
deleted, and examples and notes that named Cranny’s features (the notch, the Tray, widgets, Calendar, Notes,
Media, permissions) were replaced with Overbright’s or dropped. Overbright’s own names, its pane names among them,
were decided in WP15 (ARCHITECTURE.md §10.17, §8.8); the table shows them as the catalogs ship them.
`scripts/lib/l10n/languages.json` has this language’s plural categories and quotation marks.

## Register and typography

Register: formal (Ön), as macOS — the pronoun is left out ("Kattintson…", "Nyissa meg…").
Buttons, menu items, commands and VoiceOver actions: nominalised verbs as macOS writes them
("Megnyitás", "Törlés", "Frissítések keresése", "A(z) %@ megnyitása"); toggles and row labels: noun phrases
("Mozgás csökkentése", "Menüsor ikonjának megjelenítése"); instructions in sentences: formal imperative.
Sentence case. Quotes „…” (inner »…«), ellipsis …, apostrophe ’. Article before a placeholder: a(z) %@.
Apple's app names are not quoted and take suffixes the way macOS writes them ("a Parancsokban", "a Fotók app").
Nouns after a number stay singular ("3 elem", "5 kijelző"), so the one/other plural forms are usually identical.


### Orthography

- Abbreviation + noun compounds take a hyphen: "MIT-licenc", "HDR-videó", "OLED-kijelző".
- Compounds are one word: "fókuszmód", "kijelzőmodell".
- Settings panes in running text: "a Kijelzők panelen", "a(z) %@ panel", as macOS ("az Általános panelen").

### The brand

“Overbright” is never translated. Its suffixes follow the pronunciation (“óverbrájt”, back vowels): Overbrightot, Overbrighttal, Overbrighthoz — confirmed in WP15 (ARCHITECTURE.md §10.17): the shipped strings use Overbrightot and Overbrightból, and compounds take a hyphen (Overbright-önteszt).

## Apple names (`apple-terms.py hu` on macOS 27.0.1 — never paraphrased)

| English | hu |
|---|---|
| System Settings | Rendszerbeállítások |
| Finder | Finder |
| Shortcuts | Parancsok |
| Photos | Fotók |
| TV | TV |
| QuickTime Player | QuickTime Player |
| Privacy & Security | Adatvédelem és biztonság |
| Accessibility | Kisegítő lehetőségek |
| General | Általános |
| Appearance | Megjelenés |
| Menu Bar | Menüsor |
| Control Center | Vezérlőközpont |
| Focus | Fókusz |
| Displays | Kijelzők |
| Keyboard | Billentyűzet |
| Keyboard Shortcuts… | Billentyűparancsok… |
| Lock Screen | Képernyő zárolása |
| Battery | Akkumulátor |
| Energy | Energia |
| Screen Saver | Képernyővédő |
| Login Items | Indítóelemek |
| Login Items & Extensions | Indítóelemek és bővítmények |
| Brightness | Fényerő |
| Automatically adjust brightness | Fényerő automatikus beállítása |
| True Tone | True Tone |
| High Dynamic Range | Nagy dinamikatartomány |
| Preset | Előbeállítás |
| Night Shift… | Night Shift… |
| Color profile | Színprofil |
| Refresh rate | Frissítési gyakoriság |
| Allow in the Menu Bar | Engedélyezés a menüsoron |
| Low Power Mode | Alacsony fogyasztású mód |
| Do Not Disturb | Ne zavarjanak |
| Camera | Kamera |
| Open Anyway | Megnyitás mindenképp |
| Applications | Alkalmazások |
| Reduce motion | Mozgás csökkentése |
| Reduce transparency | Átlátszóság csökkentése |
| Increase contrast | Kontraszt növelése |
| Differentiate without color | Differenciálás színek nélkül |
| VoiceOver | VoiceOver |

## Overbright’s own names

| English | hu | Note |
|---|---|---|
| Overbright | Overbright | never translated or transliterated |
| Settings panes: General · Displays · Automations · Shortcuts · Fill Light · Advanced · About | Általános · Kijelzők · Automatizálás · Billentyűparancsok · Arcmegvilágítás · Speciális · Névjegy | the sidebar and window titles |
| Standard (the brightness macOS shows) | Alapszint | never “100 %” or “normal mode” |
| extra brightness (the boost half) | “Extra fényerő használata” (Use extra brightness) | never “boost”, “HDR mode”, “EDR” |
| Dim below minimum (the setting) | “Minimum alatti sötétítés be- vagy kikapcsolása” (Dim Below Minimum On or Off) | the incumbent’s name for it is never used |
| Dimmed (the state) · Dim All Displays / Stop Dimming (actions) | Sötétítve · Összes kijelző sötétítése / Sötétítés megszüntetése | not “night mode” |
| Brighter · Less Bright (one step) | Világosabb · Kevésbé világos | never “Dimmer”: it reads like Dim |
| Back to Standard (the instant off) | Vissza az alapszintre | not “panic”, not “reset brightness” |
| Indoor · Bright room · Sunlight · Max (presets) | Beltéri · Világos szoba · Napfény · Maximum | “Max” is a preset only |
| Safe · Peak (ceilings) | Biztonságos · Csúcs | Peak, never “Max”, for a ceiling; one short word each (segments) |
| color table (in sentences: “macOS ignores color table changes”) | színtábla | never “gamma”; no “fallback” or “overlay” in copy |
| Fill Light (the edge light for video calls) | Arcmegvilágítás | never “ring light” |
| extra range (headroom, in user copy) | Fényerőtartalék | “headroom” only in Advanced and diagnostics |
| Calibrate… · Run Self-Test… · Reset Display Colors… | Kalibrálás… · Önteszt futtatása… · Kijelzőszínek visszaállítása… |  |
| Keep this level? · Go Back · Keep | Megtartja ezt a szintet? · Vissza · Megtartás | the very-dark-level prompt |
| Pause · Paused · Resume | “Az Overbright szüneteltetése” (Pause Overbright) · Szüneteltetve · Folytatás | a temporary stop; never “disabled” |

Fit (WP15): the footer’s default row (Battery, Auto-pause, Timer) must fit its 304 pt in full in every language (`FooterFitTests`), so the Auto-pause chip reads “Autoszünet” (off: “Autoszünet ki”).

## Carried from Cranny (generic interface words)

| English | hu | Note |
|---|---|---|
| Settings | Beállítások |  |
| Welcome (window) | üdvözlés / üdvözlőablak | "Üdvözli a Overbright" |
| setup | beállítás (folyamata) | "Beállítás kihagyása" |
| Reset to Default | Alapértelmezett érték visszaállítása |  |
| Changed from the default | Eltér az alapértelmezettől |  |
| Allow… / Grant… | Engedélyezés… |  |
| Remove (from a list) / Delete | Eltávolítás / Törlés | as macOS |
| App not installed | Az app nincs telepítve |  |
| Never | Soha |  |
| Off / On | Ki / Be |  |
| Show … (toggle) | … megjelenítése |  |
| click | kattintás / kattintson |  |
| Preview | Előnézet |  |
| Update(s) / Check for Updates | frissítés(ek) / Frissítések keresése |  |
| Try again / Retry (buttons, chips) | Próbálja újra | Apple's "Try Again"; one wording everywhere (the chip, the banner and the card menu of a display that failed or stopped) |
| Space (the space bar in key caps) | Szóköz | as AppKit writes it in menu key equivalents (FunctionKeyNames.loctable “Space”), so Settings and Welcome show the same key caps as the menu; AppKit’s name for the physical key is Szóközbillentyű |
