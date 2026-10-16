# Overbright — Hungarian (magyar, `hu`) terminology sheet

Carried from Cranny’s sheet for this language (ARCHITECTURE.md §10.2): the register, voice and
typography decisions are language facts and stay; Cranny’s notch, widget and ambient-light rows are
deleted. Overbright’s own names are decided in WP15 (ARCHITECTURE.md §10.17, §8.8); until then they
read “—”. `scripts/l10n/languages.json` has this language’s plural categories and quotation marks.

## Register and typography

Register: formal (Ön), as macOS — the pronoun is left out ("Kattintson…", "Nyissa meg…").
Buttons, menu items, commands and VoiceOver actions: nominalised verbs as macOS writes them
("Megnyitás", "Törlés", "Kuka ürítése", "A(z) %@ megnyitása"); toggles and row labels: noun phrases
("Mozgás csökkentése", "Menüsor ikonjának megjelenítése"); instructions in sentences: formal imperative.
Sentence case. Quotes „…” (inner »…«), ellipsis …, apostrophe ’. Article before a placeholder: a(z) %@.
Apple's app names are not quoted and take suffixes the way macOS writes them ("a Parancsokban", "a Zene app").
Nouns after a number stay singular ("3 elem", "5 cella"), so the one/other plural forms are usually identical.


### Orthography

- Abbreviation + noun compounds take a hyphen: "MIT-licenc", "ZIP-archívumok", "AirDrop-zóna", "PDF-ek".
- Compounds are one word: "fókuszmód", "kódmód", "kijelzőmodell".
- Settings panes in running text: "az Élő tevékenységek panelen", "a(z) %@ panel", as macOS ("az Általános panelen").

### The brand

“Overbright” is never translated. Its suffixes follow the pronunciation (“óverbrájt”, back vowels): Overbrightot, Overbrighttal, Overbrighthoz — to be confirmed in WP15 (ARCHITECTURE.md §10.17); until then every brand-bearing string is marked needs_review.

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
| Try again / Retry (buttons, chips) | Próbálja újra | Apple's "Try Again"; one wording everywhere; "Újrapróbálkozás" (90 pt) overflows the Mirror chip in a 2-cell card |
| subject (of a photo, Remove background) | téma | Apple: "…megtartva a témát"; not "alany" |
| guided tour (search keyword) | körbevezetés | not "túra" (= hike) |
