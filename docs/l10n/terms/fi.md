# Overbright — Finnish (suomi, `fi`) terminology sheet

Carried from Cranny’s sheet for this language (ARCHITECTURE.md §10.2): the register, voice and
typography decisions are language facts and stay; Cranny’s notch, widget and ambient-light rows are
deleted, and examples and notes that named Cranny’s features (the notch, the Tray, widgets, Calendar, Notes,
Media, permissions) were replaced with Overbright’s or dropped. Overbright’s own names, its pane names among them,
were decided in WP15 (ARCHITECTURE.md §10.17, §8.8); the table shows them as the catalogs ship them.
`scripts/l10n/languages.json` has this language’s plural categories and quotation marks.

## Register and typography

Register: informal *sinä*, as macOS does. Buttons and menu items in the imperative singular
(Avaa, Lisää, Poista, Kätke, Peru, Kumoa), toggles also in the imperative (“Näytä kuvake valikkorivillä”),
labels and headers as nouns. Sentence case. Quotes ”…” (U+201D on both sides) and ’…’, used sparingly —
setting names inside sentences are quoted (”Vähennä läpinäkyvyyttä”), app names are not (Pikakomennot-appi).
Ellipsis … (U+2026). Ranges and spaced dashes use the en dash (– ). Placeholders are never inflected: use
“apissa %@”, “pikakomento %@”, “Avaa %@” or a colon (“Lisätty: %@”) instead of “%@:ssa”.
Footnotes that describe what a setting does are in the 3rd person without a subject (“Keskeyttää, kun akun varaus
on alle 20 %.”) — never an imperative addressed to the user. Progress “X of Y” is “%1$lld / %2$lld”
(Apple’s VoiceOver “Sivu %@ / %@”; “2/5” is read as a fraction). Clock times take “klo” in sentences
(“jatkuu klo 7.00”). “You can’t undo this.” = AppKit’s “Toimintoa ei voida perua.”

### The brand

“Overbright” is never translated. It ends in a consonant, so it inflects with a linking -i- (Overbrightin, Overbrightiin, Overbrightille); Cranny’s harmony question does not arise the same way. WP15 confirmed these forms (ARCHITECTURE.md §10.17): the shipped strings use Overbrightin, Overbrightia and Overbrightiin, and compounds take a hyphen (Overbright-ohje).

## Apple names (`apple-terms.py fi` on macOS 27.0.1 — never paraphrased)

| English | fi |
|---|---|
| System Settings | Järjestelmäasetukset |
| Finder | Finder |
| Shortcuts | Pikakomennot |
| Photos | Kuvat |
| TV | TV |
| QuickTime Player | QuickTime Player |
| Privacy & Security | Tietosuoja ja suojaus |
| Accessibility | Käyttöapu |
| General | Yleiset |
| Appearance | Ulkoasu |
| Menu Bar | Valikkorivi |
| Control Center | Ohjauskeskus |
| Focus | Keskity-tila |
| Displays | Näytöt |
| Keyboard | Näppäimistö |
| Keyboard Shortcuts… | Näppäinoikotiet… |
| Lock Screen | Lukittu näyttö |
| Battery | Akku |
| Energy | Energia |
| Screen Saver | Näytönsäästäjä |
| Login Items | Kirjautumiskohteet |
| Login Items & Extensions | Kirjautumiskohteet ja laajennukset |
| Brightness | Kirkkaus |
| Automatically adjust brightness | Säädä kirkkautta automaattisesti |
| True Tone | True Tone |
| High Dynamic Range | Korkea dynaaminen alue |
| Preset | Esiasetus |
| Night Shift… | Night Shift… |
| Color profile | Väriprofiili |
| Refresh rate | Virkistystaajuus |
| Allow in the Menu Bar | Salli valikkorivillä |
| Low Power Mode | Alhaisen virran tila |
| Do Not Disturb | Älä häiritse |
| Camera | Kamera |
| Open Anyway | Avaa kuitenkin |
| Applications | Apit |
| Reduce motion | Vähennä liikettä |
| Reduce transparency | Vähennä läpinäkyvyyttä |
| Increase contrast | Lisää kontrastia |
| Differentiate without color | Erottele ilman väriä |
| VoiceOver | VoiceOver |

## Overbright’s own names

| English | fi | Note |
|---|---|---|
| Overbright | Overbright | never translated or transliterated |
| Settings panes: General · Displays · Automations · Shortcuts · Fill Light · Advanced · About | Yleiset · Näytöt · Automaatiot · Oikotiet · Täytevalo · Lisävalinnat · Tietoja | the sidebar and window titles |
| Standard (the brightness macOS shows) | Vakio | never “100 %” or “normal mode” |
| extra brightness (the boost half) | “Käytä lisäkirkkautta” (Use extra brightness) | never “boost”, “HDR mode”, “EDR” |
| Dim below minimum (the setting) | “Himmennys alle minimin päälle tai pois” (Dim Below Minimum On or Off) | the incumbent’s name for it is never used |
| Dimmed (the state) · Dim All Displays / Stop Dimming (actions) | Himmennetty · Himmennä kaikki näytöt / Lopeta himmennys | not “night mode” |
| Brighter · Less Bright (one step) | Lisää kirkkautta · Vähennä kirkkautta | never “Dimmer”: it reads like Dim |
| Back to Standard (the instant off) | Takaisin vakiotasolle | not “panic”, not “reset brightness” |
| Indoor · Bright room · Sunlight · Max (presets) | Sisätila · Valoisa huone · Auringonvalo · Maksimi | “Max” is a preset only |
| Safe · Peak (ceilings) | Turvallinen · Huippu | Peak, never “Max”, for a ceiling; one short word each (segments) |
| color table (in sentences: “macOS ignores color table changes”) | väritaulukko | never “gamma”; no “fallback” or “overlay” in copy |
| Fill Light (the edge light for video calls) | Täytevalo | never “ring light” |
| extra range (headroom, in user copy) | Kirkkausvara | “headroom” only in Advanced and diagnostics |
| Calibrate… · Run Self-Test… · Reset Display Colors… | Kalibroi… · Suorita itsetesti… · Palauta näyttöjen värit… |  |
| Keep this level? · Go Back · Keep | Pidetäänkö tämä taso? · Palaa · Pidä | the very-dark-level prompt |
| Pause · Paused · Resume | “Tauota Overbright” (Pause Overbright) · Tauolla · Jatka | a temporary stop; never “disabled” |

## Carried from Cranny (generic interface words)

| English | fi | Note |
|---|---|---|
| Overbright | Overbright | also the name of the open panel (“Avaa Overbright”, “Sulje Overbright”) |
| Never (timeout 0) | Ei koskaan |  |
| Shortcuts (Apple’s app) / a shortcut | Pikakomennot / pikakomento | “Pikakomennot-appi” |
| keyboard shortcut | (näppäin)oikotie | Apple’s “Näppäinoikotiet…” |
| Allow… / Grant… | Salli… |  |
| Reset to Default | Palauta oletusarvo | Apple’s “Palauta oletuksiin” |
| Changed from the default | Muutettu oletusarvosta |  |
| Remove (from a list) / Delete | Poista / Poista | “Poista luettelosta” when it could read as uninstalling |
| Undo / Cancel | Peru / Kumoa | Apple’s Finnish |
| setup (welcome) | käyttöönotto |  |
| Launch / Open at login | Avaa sisäänkirjauduttaessa | as the Dock’s “Open at Login” |
| Login Items (System Settings) | Kirjautumiskohteet | apple-terms |
| Space (the space bar in key caps) | Väli | as AppKit writes it in menu key equivalents (FunctionKeyNames.loctable “Space”), so Settings and Welcome show the same key caps as the menu; AppKit’s name for the physical key is Välilyönti |
