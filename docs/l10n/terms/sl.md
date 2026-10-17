# Overbright — Slovenian (slovenščina, `sl`) terminology sheet

Carried from Cranny’s sheet for this language (ARCHITECTURE.md §10.2): the register, voice and
typography decisions are language facts and stay; Cranny’s notch, widget and ambient-light rows are
deleted, and examples and notes that named Cranny’s features (the notch, the Tray, widgets, Calendar, Notes,
Media, permissions) were replaced with Overbright’s or dropped. Overbright’s own names, its pane names among them,
were decided in WP15 (ARCHITECTURE.md §10.17, §8.8); the table shows them as the catalogs ship them.
`scripts/l10n/languages.json` has this language’s plural categories and quotation marks.

## Register and typography

Register and style, following macOS 27 in Slovenian (checked in the system's own loctables):

- Buttons, menu items, commands and toggles: **imperative, 2nd person singular**, as Apple writes them
  (“Odpri”, “Prikaži odstotek”, “Premakni v koš”, “Zapri aplikacijo Koledar”).
- Sentences, footnotes and VoiceOver hints: **formal vi** (“Kliknite”, “Povlecite”,
  “Če zaprete zdaj, boste izgubili …”, “Vaši zasloni”).
- Confirmation titles: **“Želite …?”** (Apple: “Želite izbrisati zbirko?”) → “Želite ponastaviti barve zaslona?”,
  “Želite ponastaviti vse nastavitve?”.
- Sentence case everywhere; Slovenian has no title case (Apple: “O aplikaciji Koledar”, “Zapri okno”).
- Quotes: **»…«** (macOS 27), inner „…“. Names of apps/panes/settings in running text either quoted or after a
  generic noun (Apple: “aplikacija Vreme”, “razdelek »Zasloni«”, “mapa Aplikacije”).
- Ellipsis: **no-break space + …** exactly as macOS writes it (“Nastavitve …”, “Preverjanje …”, “Dovoli …”;
  confirmed in Battery.loctable: “Nastavitve baterije …”). A “(…)” standing for the ⋯ button keeps no space.
  ▸ for Overbright's own Settings paths.
- Units: a space before units (“90 s”, “12 min”); “h” for hours, “min”, “s”, “ms”, “pt”, “px”.
- Placeholders are not declined: a noun in front carries the case (“v aplikaciji %@”, “na zaslonu »%@«”).
- Plurals: one (1, 101), **two (dual: 2, 102)**, few (3–4), other (0, 5–20, 100): “1 element, 2 elementa,
  3 elementi, 5 elementov”; “1 zaslon, 2 zaslona, 3 zasloni, 5 zaslonov”; “1 dan, 2 dneva, 3 dnevi, 5 dni”.
- Apple's names from `apple-terms.py sl`: Nastavitve sistema (v Nastavitvah sistema), Zasebnost in varnost, Dostopnost,
  Elementi prijave, Menijska vrstica, Način nizke porabe, Bližnjice, Aplikacije, Zmanjšaj dinamičnost animacij,
  Zmanjšaj prosojnost, Razlikuj brez barv.

### The brand

“Overbright” is never translated. Cranny’s sheet inflected its name; those forms do not carry over (“Overbright” ends in a consonant), so the inflected forms are WP15’s decision (ARCHITECTURE.md §10.17). Until then every brand-bearing string is marked needs_review.

## Apple names (`apple-terms.py sl` on macOS 27.0.1 — never paraphrased)

| English | sl |
|---|---|
| System Settings | Nastavitve sistema |
| Finder | Finder |
| Shortcuts | Bližnjice |
| Photos | Fotografije |
| TV | TV |
| QuickTime Player | QuickTime Player |
| Privacy & Security | Zasebnost in varnost |
| Accessibility | Dostopnost |
| General | Splošno |
| Appearance | Videz |
| Menu Bar | Menijska vrstica |
| Control Center | Nadzorno središče |
| Focus | Fokus |
| Displays | Zasloni |
| Keyboard | Tipkovnica |
| Keyboard Shortcuts… | Bližnjice na tipkovnici … |
| Lock Screen | Zaklenjeni zaslon |
| Battery | Baterija |
| Energy | Energija |
| Screen Saver | Ohranjevalnik zaslona |
| Login Items | Elementi prijave |
| Login Items & Extensions | Elementi prijave in razširitve |
| Brightness | Svetlost |
| Automatically adjust brightness | Samodejno prilagodi svetlost |
| True Tone | True Tone |
| High Dynamic Range | Visok dinamični razpon |
| Preset | Prednastavitev |
| Night Shift… | Night Shift … |
| Color profile | Barvni profil |
| Refresh rate | Hitrost osveževanja |
| Allow in the Menu Bar | Dovoljeno v menijski vrstici |
| Low Power Mode | Način nizke porabe |
| Do Not Disturb | Ne moti |
| Camera | Kamera |
| Open Anyway | Vseeno odpri |
| Applications | Aplikacije |
| Reduce motion | Zmanjšaj dinamičnost animacij |
| Reduce transparency | Zmanjšaj prosojnost |
| Increase contrast | Povečaj kontrast |
| Differentiate without color | Razlikuj brez barv |
| VoiceOver | VoiceOver |

## Overbright’s own names

| English | sl | Note |
|---|---|---|
| Overbright | Overbright | never translated or transliterated |
| Settings panes: General · Displays · Automations · Shortcuts · Fill Light · Advanced · About | Splošno · Zasloni · Avtomatizacije · Bližnjice na tipkovnici · Osvetlitev obraza · Napredno · O aplikaciji | the sidebar and window titles |
| Standard (the brightness macOS shows) | Standardno | never “100 %” or “normal mode” |
| extra brightness (the boost half) | “Uporabi dodatno svetlost” (Use extra brightness) | never “boost”, “HDR mode”, “EDR” |
| Dim below minimum (the setting) | “Vklopi ali izklopi zatemnitev pod minimum” (Dim Below Minimum On or Off) | the incumbent’s name for it is never used |
| Dimmed (the state) · Dim All Displays / Stop Dimming (actions) | Zatemnjeno · Zatemni vse zaslone / Izklopi zatemnitev | not “night mode” |
| Brighter · Less Bright (one step) | Svetleje · Manj svetlo | never “Dimmer”: it reads like Dim |
| Back to Standard (the instant off) | Nazaj na standardno svetlost | not “panic”, not “reset brightness” |
| Indoor · Bright room · Sunlight · Max (presets) | V sobi · Svetla soba · Na soncu · Maksimum | “Max” is a preset only |
| Safe · Peak (ceilings) | Varno · Vrh | Peak, never “Max”, for a ceiling; one short word each (segments) |
| Compatibility mode · Color table (methods) | Način združljivosti · Barvna tabela | never “fallback” or “overlay” |
| Fill Light (the edge light for video calls) | Osvetlitev obraza | never “ring light” |
| extra range (headroom, in user copy) | Rezerva svetlosti | “headroom” only in Advanced and diagnostics |
| Calibrate… · Run Self-Test… · Reset Display Colors… | Umeri … · Zaženi samopreizkus … · Ponastavi barve zaslonov … |  |
| Keep this level? · Go Back · Keep | Želite ohraniti to raven? · Vrni · Ohrani | the very-dark-level prompt |
| Pause · Paused · Resume | “Začasno ustavi Overbright” (Pause Overbright) · Začasno ustavljeno · Nadaljuj | a temporary stop; never “disabled” |

Fit (WP15): the footer’s default row (Battery, Auto-pause, Timer) must fit its 304 pt in full in every language (`FooterFitTests`), so the Auto-pause chip reads “Premori” (off: “Brez premorov”).

## Carried from Cranny (generic interface words)

| English | sl | Note |
|---|---|---|
| Shortcuts (Apple's app) · a shortcut | Bližnjice · bližnjica | Apple's name |
| keyboard shortcut | bližnjica na tipkovnici / bližnjica | Apple: “Bližnjice na tipkovnici …”; in Overbright's Shortcuts pane (the key bindings) just “bližnjica” |
| Allow… / Grant… | Dovoli … |  |
| Welcome / setup | Dobrodošli / nastavitev | “Preskoči nastavitev” |
| Show … (every show-switch) | Prikaži … | Apple: “Prikaži odstotek” |
| Click | Klik / kliknite | Apple: “Kliknite …” |
| Remove (from a list) | Odstrani | “Odstrani s seznama” where it could read as uninstall |
| App not installed | Aplikacija ni nameščena |  |
| Reset to Default · Changed from the default | Ponastavi na privzeto · Spremenjeno glede na privzeto | Apple “Ponastavi na privzeto” |
| Never (a timeout) | Nikoli |  |
| Off / On / Automatic / None | Izklopljeno / Vklopljeno / Samodejno / Brez | Apple |
