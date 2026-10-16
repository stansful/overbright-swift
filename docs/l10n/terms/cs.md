# Overbright — Czech (čeština, `cs`) terminology sheet

Carried from Cranny’s sheet for this language (ARCHITECTURE.md §10.2): the register, voice and
typography decisions are language facts and stay; Cranny’s notch, widget and ambient-light rows are
deleted. Overbright’s own names are decided in WP15 (ARCHITECTURE.md §10.17, §8.8); until then they
read “—”. `scripts/l10n/languages.json` has this language’s plural categories and quotation marks.

## Register and typography

Register and typography (as macOS 27 in Czech):

- Formal *vy*, lower case mid-sentence ("vaše události"). Buttons and menu items in the **infinitive** ("Otevřít", "Přeskočit", "Vyhledat aktualizace…"); instructions in the imperative ("Přetáhněte…", "Klikněte…"). Settings switches and timeout rows that describe ongoing behaviour use the imperfective infinitive ("Zobrazovat…", "Skrývat…", "Nahrazovat systémový indikátor", "Zavírat po nečinnosti", "Sbalovat po nečinnosti", "Zahrnovat předběžné verze", "Skrývat přejetím nahoru"), or an adjective for a state ("Obrácený směr"); one-off commands the perfective ("Zobrazit…"). Permission reasons use the same imperfective ("Zobrazovat…", "Nahrazovat…", "Ovládat…"). A label or header never ends in a preposition.
- Settings panes in running text as macOS writes them: "v nastavení Obecné", "v nastavení Soukromí a zabezpečení ▸ Zpřístupnění" (never "v sekci" / "v části"); "sekce" only as the plain noun ("v této sekci"). Overbright's own paths keep "v Nastavení ▸ Klávesnice". System setting names after "volba" without quotes, as macOS: "Při zapnuté volbě Snížit průhlednost".
- "Chcete‑li" with a no-break hyphen (U+2011), as macOS writes it.
- Sentence case everywhere, also where English uses title case for menus ("Vyhledat aktualizace…", "Připnout Overbright").
- Quotes „…“ (and ‚…‘); names of panes, buttons, settings and user content in „…“ only where Apple would quote them in running text. Ellipsis … (U+2026). Spaced en dash " – " for the English em dash. No-break space after one-letter prepositions and conjunctions (k, s, v, z, o, u, a, i) — added automatically by the build script.
- Placeholders are never declined: put a noun in front ("aplikace %@", "zkratka „%@“", "na monitoru „%@“").
- Durations come formatted in the nominative ("1 minuta", "4 min"); never put them after a preposition that needs another case ("po 1 minutě" ✗). Use "Za %@" only with short forms ("za 4 min"), otherwise colon forms ("Zbývající čas: %@", "Uplynulý čas: %@") or "ještě %@" / "%@ po pozastavení".
- Plurals: one = 1, few = 2–4, other = 0 and 5+ (genitive plural: "5 buněk", "5 položek"); many (decimals only) is filled with the same text as other.
- "Overbright" is never translated, transliterated or declined; where grammar needs a gender it is masculine ("Overbright je otevřený", "aby se Overbright otevíral") — kept in review: Czech treats program names as masculine (Apple: "macOS spuštěný", "Finder nemůže"), and "Overbright" is also the name of the open panel (masculine "panel"). Every agreement in the file is masculine; neuter would read like an unknown foreign word ("taxi"), and "aplikace Overbright" everywhere would be wordy and wrong for the panel ("aplikace je otevřená").

Verified after the independent review: `validate.py cs` exits 0 (13 warnings, all Czech words identical to English or Apple's own Czech names: Panel, Symbol, Trackpad, video, min, +1 min, Funky, Mezzo, Pong, Sonar, Sonumi). With cs imported, the catalogs pass `lint-copy.py` and FlashLabelFitTests, BandCopyTests, FeaturedRowTests, SceneAndHeaderTests (header tabs), RenderedSurfacesTests (tutorial bubble) and WingTextMetricsTests for cs.

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

| English | cs | Note |
|---|---|---|
| Overbright | Overbright | never declined; "v aplikaci Overbright" when a case is needed |
| Shortcuts (Apple's app) · a shortcut in it | Zkratky (aplikace Zkratky) · zkratka | glossary; "Spustit zkratku" |
| keyboard shortcut | klávesová zkratka | plain „zkratka" only inside Settings ▸ Klávesnice where it is unambiguous |
| Settings (Overbright) · System Settings | Nastavení · Nastavení systému | "v Nastavení systému" |
| Welcome (window) / setup | Vítá vás Overbright · uvítání / průvodce | "Přeskočit průvodce", "Pokračovat v průvodci" (avoids a clash with Nastavení = Settings) |
| Allow / Allow… / Grant… | Povolit / Povolit… |  |
| Login Items | položky přihlášení | Apple's own wording („Obecné → Položky přihlášení“ in its Shortcuts actions); the macOS 27 pane is „Aktivace položek a rozšíření při přihlášení“, but the name differs between macOS versions and English names it loosely too, so the copy keeps the generic words |
| click (verb / noun) | kliknout / kliknutí | Apple Czech says „klikněte" |
| Preview (Settings stage) | Náhled |  |
| Reset to Default | Obnovit výchozí hodnotu |  |
| Changed from the default | Změněno oproti výchozí hodnotě |  |
| Cancel · Done · Undo | Zrušit · Hotovo · Odvolat | Apple |
| Never (timeout 0) | Nikdy |  |
| Off / On | Vypnuto / Zapnuto |  |
