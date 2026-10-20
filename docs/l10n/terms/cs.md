# Overbright — Czech (čeština, `cs`) terminology sheet

Carried from Cranny’s sheet for this language (ARCHITECTURE.md §10.2): the register, voice and
typography decisions are language facts and stay; Cranny’s notch, widget and ambient-light rows are
deleted, and examples and notes that named Cranny’s features (the notch, the Tray, widgets, Calendar, Notes,
Media, permissions) were replaced with Overbright’s or dropped. Overbright’s own names, its pane names among them,
were decided in WP15 (ARCHITECTURE.md §10.17, §8.8); the table shows them as the catalogs ship them.
`scripts/l10n/languages.json` has this language’s plural categories and quotation marks.

## Register and typography

Register and typography (as macOS 27 in Czech):

- Formal *vy*, lower case mid-sentence ("vaše nastavení"). Buttons and menu items in the **infinitive** ("Otevřít", "Přeskočit", "Vyhledat aktualizace…"); instructions in the imperative ("Přetáhněte…", "Klikněte…"). Settings switches and timeout rows that describe ongoing behaviour use the imperfective infinitive ("Zobrazovat…", "Skrývat…", "Zahrnovat předběžné verze"), or an adjective or participle for a state ("Pozastaveno"); one-off commands the perfective ("Zobrazit…"). A label or header never ends in a preposition.
- Settings panes in running text as macOS writes them: "v nastavení Obecné", "v nastavení Soukromí a zabezpečení ▸ Zpřístupnění" (never "v sekci" / "v části"); "sekce" only as the plain noun ("v této sekci"). Overbright's own paths keep "v Nastavení ▸ Obecné". System setting names after "volba" without quotes, as macOS: "Při zapnuté volbě Snížit průhlednost".
- "Chcete‑li" with a no-break hyphen (U+2011), as macOS writes it.
- Sentence case everywhere, also where English uses title case for menus ("Vyhledat aktualizace…", "Připnout Overbright").
- Quotes „…“ (and ‚…‘); names of panes, buttons, settings and user content in „…“ only where Apple would quote them in running text. Ellipsis … (U+2026). Spaced en dash " – " for the English em dash. No-break space after one-letter prepositions and conjunctions (k, s, v, z, o, u, a, i) — added automatically by the build script.
- Placeholders are never declined: put a noun in front ("aplikace %@", "zkratka „%@“", "na monitoru „%@“").
- Durations come formatted in the nominative ("1 minuta", "4 min"); never put them after a preposition that needs another case ("po 1 minutě" ✗). Use "Za %@" only with short forms ("za 4 min"), otherwise colon forms ("Zbývající čas: %@") or "ještě %@".
- Plurals: one = 1, few = 2–4, other = 0 and 5+ (genitive plural: "5 displejů", "5 položek"); many (decimals only) is filled with the same text as other.
- "Overbright" is never translated, transliterated or declined; where grammar needs a gender it is masculine ("Overbright je otevřený", "aby se Overbright otevíral") — kept in review: Czech treats program names as masculine (Apple: "macOS spuštěný", "Finder nemůže"), and "Overbright" is also the name of the open panel (masculine "panel"). Every agreement in the file is masculine; neuter would read like an unknown foreign word ("taxi"), and "aplikace Overbright" everywhere would be wordy and wrong for the panel ("aplikace je otevřená").

## Apple names (`apple-terms.py cs` on macOS 27.0.1 — never paraphrased)

| English | cs |
|---|---|
| System Settings | Nastavení systému |
| Finder | Finder |
| Shortcuts | Zkratky |
| Photos | Fotky |
| TV | TV |
| QuickTime Player | QuickTime Player |
| Privacy & Security | Soukromí a zabezpečení |
| Accessibility | Zpřístupnění |
| General | Obecné |
| Appearance | Vzhled |
| Menu Bar | Řádek nabídek |
| Control Center | Ovládací centrum |
| Focus | Soustředění |
| Displays | Monitory |
| Keyboard | Klávesnice |
| Keyboard Shortcuts… | Klávesové zkratky… |
| Lock Screen | Zamknutá obrazovka |
| Battery | Baterie |
| Energy | Energie |
| Screen Saver | Spořič obrazovky |
| Login Items | Přihlášení |
| Login Items & Extensions | Aktivace položek a rozšíření při přihlášení |
| Brightness | Jas |
| Automatically adjust brightness | Automaticky upravit jas |
| True Tone | True Tone |
| High Dynamic Range | Velký dynamický rozsah |
| Preset | Předvolba |
| Night Shift… | Night Shift… |
| Color profile | Barevný profil |
| Refresh rate | Obnovovací frekvence |
| Allow in the Menu Bar | Povolit v řádku nabídek |
| Low Power Mode | Režim nízké spotřeby |
| Do Not Disturb | Nerušit |
| Camera | Kamera |
| Open Anyway | Přesto otevřít |
| Applications | Aplikace |
| Reduce motion | Omezit pohyb |
| Reduce transparency | Snížit průhlednost |
| Increase contrast | Zvýšit kontrast |
| Differentiate without color | Odlišit bez barvy |
| VoiceOver | VoiceOver |

## Overbright’s own names

| English | cs | Note |
|---|---|---|
| Overbright | Overbright | never translated or transliterated |
| Settings panes: General · Displays · Automations · Shortcuts · Fill Light · Advanced · About | Obecné · Monitory · Automatizace · Klávesové zkratky · Osvětlení obličeje · Pokročilé · O aplikaci | the sidebar and window titles |
| Standard (the brightness macOS shows) | Standardní | never “100 %” or “normal mode” |
| extra brightness (the boost half) | “Používat extra jas” (Use extra brightness) | never “boost”, “HDR mode”, “EDR” |
| Dim below minimum (the setting) | “Zapnout nebo vypnout ztmavení pod minimum” (Dim Below Minimum On or Off) | the incumbent’s name for it is never used |
| Dimmed (the state) · Dim All Displays / Stop Dimming (actions) | Ztmaveno · Ztmavit všechny monitory / Zrušit ztmavení | not “night mode” |
| Brighter · Less Bright (one step) | Jasněji · Méně jasně | never “Dimmer”: it reads like Dim |
| Back to Standard (the instant off) | Zpět na standardní jas | not “panic”, not “reset brightness” |
| Indoor · Bright room · Sunlight · Max (presets) | V místnosti · Světlá místnost · Na slunci · Maximum | “Max” is a preset only |
| Safe · Peak (ceilings) | Bezpečný · Špičkový | Peak, never “Max”, for a ceiling; one short word each (segments) |
| color table (in sentences: “macOS ignores color table changes”) | tabulka barev | never “gamma”; no “fallback” or “overlay” in copy |
| Fill Light (the edge light for video calls) | Osvětlení obličeje | never “ring light” |
| extra range (headroom, in user copy) | Rezerva jasu | “headroom” only in Advanced and diagnostics |
| Calibrate… · Run Self-Test… · Reset Display Colors… | Kalibrovat… · Spustit autotest… · Resetovat barvy monitorů… |  |
| Keep this level? · Go Back · Keep | Ponechat tuto úroveň? · Vrátit · Ponechat | the very-dark-level prompt |
| Pause · Paused · Resume | “Pozastavit Overbright” (Pause Overbright) · Pozastaveno · Pokračovat | a temporary stop; never “disabled” |

## Carried from Cranny (generic interface words)

| English | cs | Note |
|---|---|---|
| Overbright | Overbright | never declined; "v aplikaci Overbright" when a case is needed |
| Shortcuts (Apple's app) · a shortcut in it | Zkratky (aplikace Zkratky) · zkratka | glossary; "Spustit zkratku" |
| keyboard shortcut | klávesová zkratka | plain „zkratka" only inside Overbright's Shortcuts pane (the key bindings), where it is unambiguous |
| Settings (Overbright) · System Settings | Nastavení · Nastavení systému | "v Nastavení systému" |
| Welcome (window) / setup | Vítá vás Overbright · uvítání / průvodce | "Přeskočit průvodce", "Pokračovat v průvodci" (avoids a clash with Nastavení = Settings) |
| Allow / Allow… / Grant… | Povolit / Povolit… |  |
| Login Items | položky přihlášení | Apple's own wording („Obecné → Položky přihlášení“ in its Shortcuts actions); the macOS 27 pane is „Aktivace položek a rozšíření při přihlášení“, but the name differs between macOS versions and English names it loosely too, so the copy keeps the generic words |
| click (verb / noun) | kliknout / kliknutí | Apple Czech says „klikněte" |
| Preview | Náhled |  |
| Reset to Default | Obnovit výchozí hodnotu |  |
| Changed from the default | Změněno oproti výchozí hodnotě |  |
| Cancel · Done · Undo | Zrušit · Hotovo · Odvolat | Apple |
| Never (timeout 0) | Nikdy |  |
| Off / On | Vypnuto / Zapnuto |  |
| Space (the space bar in key caps) | mezerník | as AppKit writes it in menu key equivalents (FunctionKeyNames.loctable “Space”), so Settings and Welcome show the same key caps as the menu; AppKit’s name for the physical key is Mezerník |
