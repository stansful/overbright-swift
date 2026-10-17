# Overbright — Slovak (slovenčina, `sk`) terminology sheet

Carried from Cranny’s sheet for this language (ARCHITECTURE.md §10.2): the register, voice and
typography decisions are language facts and stay; Cranny’s notch, widget and ambient-light rows are
deleted, and examples and notes that named Cranny’s features (the notch, the Tray, widgets, Calendar, Notes,
Media, permissions) were replaced with Overbright’s or dropped. Overbright’s own names, its pane names among them,
were decided in WP15 (ARCHITECTURE.md §10.17, §8.8); the table shows them as the catalogs ship them.
`scripts/l10n/languages.json` has this language’s plural categories and quotation marks.

## Register and typography

Register and typography, as macOS 27 writes Slovak (checked in the system's own loctables):

- Formal *vy*, lower case mid-sentence ("vaše displeje"). Buttons and menu items in the **infinitive** ("Otvoriť", "Zrušiť", "Vyhľadať aktualizácie…"); instructions in the imperative ("Potiahnite…", "Kliknite…"). Switches that describe ongoing behaviour use the imperfective infinitive ("Zobrazovať…", "Skrývať…"), one-off commands the perfective ("Zobraziť…").
- Sentence case everywhere, also where English uses title case for menus ("Vyhľadať aktualizácie…", "Ukončiť Overbright").
- "app" is **apka** (apky, apiek, apkou), as System Settings writes it in macOS 27 ("Správa apiek", "Apka %@ žiada o prístup…"); the one exception is Apple's menu convention "O aplikácii Overbright" / pane "O aplikácii".
- Apple's names of settings, panes and apps are written **without quotes**, introduced by a classifier noun: "funkcia Obmedziť pohyb", "apka Fotky", "Súkromie a bezpečnosť ▸ Prístupnosť" (as macOS: "Keď je zapnutá funkcia Obmedziť priehľadnosť…"). User content (display names, search queries) goes in „…“ (‚…‘ inside), as Apple does ("Vymazať „%@“?").
- Placeholders are never declined: a noun in front carries the case ("apka %@", "na displeji %@", "skratka „%@“").
- Durations arrive in the nominative ("4 min", "2 minúty 11 sekúnd"): never after a preposition that needs another case. Abbreviated forms ("4 min", "1 h 30 min") may follow "o"/"na"; spelled-out ones use "ešte %@" or "Zostávajúci čas: %@".
- Plurals: one = 1, few = 2–4, other = 0 and 5+ (genitive plural: "5 displejov", "5 položiek"); many (fractions only) is filled with the same text as other.
- One-character ellipsis …; spaced en dash " – " where English has an em dash; no-break space (U+00A0) after the one-letter prepositions and conjunctions k, s, v, z, o, u, a, i (added by the build script).
- "Overbright" is never translated, transliterated or declined; "apka Overbright" when a case is needed. Where grammar needs a gender it is **neuter** like other indeclinable names ("Overbright je otvorené"), and that is avoided where possible. macOS is masculine ("macOS nepridal").

## Apple names (`apple-terms.py sk` on macOS 27.0.1 — never paraphrased)

| English | sk |
|---|---|
| System Settings | Systémové nastavenia |
| Finder | Finder |
| Shortcuts | Skratky |
| Photos | Fotky |
| TV | TV |
| QuickTime Player | QuickTime Player |
| Privacy & Security | Súkromie a bezpečnosť |
| Accessibility | Prístupnosť |
| General | Všeobecné |
| Appearance | Vzhľad |
| Menu Bar | Lišta |
| Control Center | Ovládacie centrum |
| Focus | Môj čas |
| Displays | Displeje |
| Keyboard | Klávesnica |
| Keyboard Shortcuts… | Klávesové skratky… |
| Lock Screen | Zamknutá obrazovka |
| Battery | Batéria |
| Energy | Energia |
| Screen Saver | Šetrič obrazovky |
| Login Items | Prihlásenie |
| Login Items & Extensions | Položky a rozšírenia spúšťané pri prihlásení |
| Brightness | Jas |
| Automatically adjust brightness | Automaticky upraviť jas |
| True Tone | True Tone |
| High Dynamic Range | Vysoký dynamický rozsah |
| Preset | Predvoľba |
| Night Shift… | Night Shift… |
| Color profile | Farebný profil |
| Refresh rate | Obnovovacia frekvencia |
| Allow in the Menu Bar | Povoliť položky v lište |
| Low Power Mode | Režim nízkej spotreby |
| Do Not Disturb | Nerušiť |
| Camera | Kamera |
| Open Anyway | Otvoriť aj tak |
| Applications | Aplikácie |
| Reduce motion | Obmedziť pohyb |
| Reduce transparency | Obmedziť priehľadnosť |
| Increase contrast | Zvýšiť kontrast |
| Differentiate without color | Rozlíšiť bez farby |
| VoiceOver | VoiceOver |

## Overbright’s own names

| English | sk | Note |
|---|---|---|
| Overbright | Overbright | never translated or transliterated |
| Settings panes: General · Displays · Automations · Shortcuts · Fill Light · Advanced · About | Všeobecné · Displeje · Automatizácie · Klávesové skratky · Osvetlenie tváre · Rozšírené · O aplikácii | the sidebar and window titles |
| Standard (the brightness macOS shows) | Štandardný | never “100 %” or “normal mode” |
| extra brightness (the boost half) | “Používať extra jas” (Use extra brightness) | never “boost”, “HDR mode”, “EDR” |
| Dim below minimum (the setting) | “Zapnúť alebo vypnúť stmavenie pod minimum” (Dim Below Minimum On or Off) | the incumbent’s name for it is never used |
| Dimmed (the state) · Dim All Displays / Stop Dimming (actions) | Stmavené · Stmaviť všetky displeje / Zrušiť stmavenie | not “night mode” |
| Brighter · Less Bright (one step) | Jasnejšie · Menej jasne | never “Dimmer”: it reads like Dim |
| Back to Standard (the instant off) | Späť na štandardný jas | not “panic”, not “reset brightness” |
| Indoor · Bright room · Sunlight · Max (presets) | V miestnosti · Svetlá miestnosť · Na slnku · Maximum | “Max” is a preset only |
| Safe · Peak (ceilings) | Bezpečný · Špičkový | Peak, never “Max”, for a ceiling; one short word each (segments) |
| Compatibility mode · Color table (methods) | Režim kompatibility · Tabuľka farieb | never “fallback” or “overlay” |
| Fill Light (the edge light for video calls) | Osvetlenie tváre | never “ring light” |
| extra range (headroom, in user copy) | Rezerva jasu | “headroom” only in Advanced and diagnostics |
| Calibrate… · Run Self-Test… · Reset Display Colors… | Kalibrovať… · Spustiť autotest… · Resetovať farby displejov… |  |
| Keep this level? · Go Back · Keep | Ponechať túto úroveň? · Vrátiť · Ponechať | the very-dark-level prompt |
| Pause · Paused · Resume | “Pozastaviť Overbright” (Pause Overbright) · Pozastavené · Pokračovať | a temporary stop; never “disabled” |

## Carried from Cranny (generic interface words)

| English | sk | Note |
|---|---|---|
| Overbright | Overbright | never declined; neuter agreement; "apka Overbright" |
| Shortcuts (Apple's app) · a shortcut in it | Skratky (apka Skratky) · skratka | Apple: "Spustiť skratku" |
| keyboard shortcut | klávesová skratka | "skratka" alone only where it is unambiguous |
| Settings (Overbright) · System Settings | Nastavenia · Systémové nastavenia | "v Systémových nastaveniach" |
| Welcome · setup | Vitajte v Overbright · úvodné nastavenie | "Preskočiť úvodné nastavenie" |
| Allow / Allow… / Grant… | Povoliť / Povoliť… | Apple's button |
| Reset to Default · Changed from the default | Obnoviť predvolenú hodnotu · Zmenené oproti predvolenej hodnote |  |
| Remove (from a list) · Delete | Odstrániť · Vymazať | as AppKit (Remove = Odstrániť, Delete = Vymazať) |
| Undo | Odvolať | as AppKit |
| Cancel · Done · OK | Zrušiť · Hotovo | as AppKit |
| App not installed | Apka nie je nainštalovaná |  |
| Never · Off | Nikdy · Vypnuté |  |
| Show … (every show switch) | Zobrazovať … | likewise "Zahŕňať predbežné verzie" |
| Preview | Náhľad | as Apple ("Zobrazovať náhľady") |
| Login Items | Položky a rozšírenia spúšťané pri prihlásení | Apple's pane name in General |
| launch at login | otvárať po prihlásení | Apple: "Otvoriť po prihlásení" |
| Check for updates · Last checked · Not checked yet | Vyhľadať aktualizácie · Posledná kontrola: %@ · Kontrola ešte neprebehla | "Posledná kontrola" is Apple's own status line |
| Space (the space bar in key caps) | Medzerník | as AppKit writes it in menu key equivalents (FunctionKeyNames.loctable “Space”), so Settings and Welcome show the same key caps as the menu; AppKit’s name for the physical key is Medzerník |
