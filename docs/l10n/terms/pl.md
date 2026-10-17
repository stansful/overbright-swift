# Overbright — Polish (polski, `pl`) terminology sheet

Carried from Cranny’s sheet for this language (ARCHITECTURE.md §10.2): the register, voice and
typography decisions are language facts and stay; Cranny’s notch, widget and ambient-light rows are
deleted, and examples and notes that named Cranny’s features (the notch, the Tray, widgets, Calendar, Notes,
Media, permissions) were replaced with Overbright’s or dropped. Overbright’s own names, its pane names among them,
were decided in WP15 (ARCHITECTURE.md §10.17, §8.8); the table shows them as the catalogs ship them.
`scripts/l10n/languages.json` has this language’s plural categories and quotation marks.

## Register and typography

Register and style, as macOS writes Polish:

- Informal **Ty**, with the polite forms capitalised as macOS does: Twój, Twoje, Twoich, Ci, Cię („Twoje wyświetlacze”).
- **Commands** (buttons, menu items): perfective imperative, 2nd person singular — Otwórz, Pokaż, Usuń, Dodaj, Wstrzymaj.
- **Settings switches and persistent options**: imperfective imperative, as in System Settings — Pokazuj…, Ukrywaj…, Otwieraj podczas logowania.
- **Progress / in-flight states**: 1st person present as macOS does — Wczytuję…, Sprawdzam…, Obliczam…; static statuses use nouns or participles (Uruchamianie, Działa, Wstrzymano).
- Sentence case. Apple's standard buttons: Anuluj, Dalej, Wróć, Pomiń, Gotowe, Zachowaj (Save), Wyzeruj (Reset), Przywróć domyślne.
- Typography: „…” (secondary «…»), apostrophe ’, ellipsis …, en dash – with spaces; no-break space (U+00A0) after the one-letter words w, z, i, o, u, a (as macOS does: „w aplikacji”).
- Placeholders are never declined: „aplikacja %@”, „w aplikacji %@”, „wyświetlacz „%@””; the name is quoted „%@” when it is a free name (a display, a pane, a shortcut) and left bare for app names and keys.
- **Overbright** stays as written and is not declined; where a case ending would be needed, the sentence is turned (Otwórz Overbright, w Overbright, aplikacja Overbright, Witaj w Overbright). Overbright is masculine wherever an adjective, participle or pronoun agrees with it („Overbright jest otwarty”, „włącz go”, „Aby Overbright otwierał się…”).
- **Spelled-out durations** (VoiceOver gets „1 minuta”, „4 minuty”, „5 minut” in the nominative): put them only after a colon („pozostało: %@”, „minęło: %@”, „Ustawiono: %@”), after „jeszcze”, or before „później”; never after „za”, „na”, „po” or „przez”, which need another case („za 1 minuta” is wrong). The short forms („4 min”) may follow „Za”.
- **Purpose clauses**: „Aby + bezokolicznik” only when the main clause has the same subject; otherwise „Aby Overbright otwierał się…, aplikacja musi…”.
- **„nigdy” always takes „nie”** with its verb, also in elliptical clauses („…i nigdy nie robi tego podczas pisania”).
- **Toggles vs. buttons**: a toggle that names a state uses a noun or participle, a toggle that names a behaviour the imperfective („Pokazuj…”); one-off buttons the perfective („Sprawdź teraz”).

## Apple names (`apple-terms.py pl` on macOS 27.0.1 — never paraphrased)

| English | pl |
|---|---|
| System Settings | Ustawienia systemowe |
| Finder | Finder |
| Shortcuts | Skróty |
| Photos | Zdjęcia |
| TV | TV |
| QuickTime Player | QuickTime Player |
| Privacy & Security | Prywatność i ochrona |
| Accessibility | Dostępność |
| General | Ogólne |
| Appearance | Wygląd |
| Menu Bar | Pasek menu |
| Control Center | Centrum sterowania |
| Focus | Tryb skupienia |
| Displays | Wyświetlacze |
| Keyboard | Klawiatura |
| Keyboard Shortcuts… | Skróty klawiszowe… |
| Lock Screen | Ekran blokady |
| Battery | Bateria |
| Energy | Energia |
| Screen Saver | Wygaszacz ekranu |
| Login Items | Logowanie |
| Login Items & Extensions | Rzeczy i rozszerzenia otwierane podczas logowania |
| Brightness | Jasność |
| Automatically adjust brightness | Dostosowuj jasność automatycznie |
| True Tone | True Tone |
| High Dynamic Range | Szeroki zakres tonalny |
| Preset | Ustawienie wstępne |
| Night Shift… | Night Shift… |
| Color profile | Profil kolorów |
| Refresh rate | Częstotliwość odświeżania |
| Allow in the Menu Bar | Pozwalaj na pasku menu |
| Low Power Mode | Tryb Niskie zużycie energii |
| Do Not Disturb | Nie przeszkadzać |
| Camera | Kamera |
| Open Anyway | Otwórz mimo to |
| Applications | Aplikacje |
| Reduce motion | Redukuj ruch |
| Reduce transparency | Zmniejsz przezroczystość |
| Increase contrast | Zwiększ kontrast |
| Differentiate without color | Różnicuj bez koloru |
| VoiceOver | VoiceOver |

## Overbright’s own names

| English | pl | Note |
|---|---|---|
| Overbright | Overbright | never translated or transliterated |
| Settings panes: General · Displays · Automations · Shortcuts · Fill Light · Advanced · About | Ogólne · Wyświetlacze · Automatyzacja · Skróty klawiszowe · Światło wypełniające · Zaawansowane · Informacje | the sidebar and window titles |
| Standard (the brightness macOS shows) | Standard | never “100 %” or “normal mode” |
| extra brightness (the boost half) | “Używaj dodatkowej jasności” (Use extra brightness) | never “boost”, “HDR mode”, “EDR” |
| Dim below minimum (the setting) | “Włącz lub wyłącz przyciemnianie poniżej minimum” (Dim Below Minimum On or Off) | the incumbent’s name for it is never used |
| Dimmed (the state) · Dim All Displays / Stop Dimming (actions) | Przyciemniono · Przyciemnij wszystkie wyświetlacze / Zakończ przyciemnianie | not “night mode” |
| Brighter · Less Bright (one step) | Jaśniej · Mniej jasno | never “Dimmer”: it reads like Dim |
| Back to Standard (the instant off) | Wróć do standardu | not “panic”, not “reset brightness” |
| Indoor · Bright room · Sunlight · Max (presets) | W pomieszczeniu · Mocne światło · Na słońcu · Maksimum | “Max” is a preset only |
| Safe · Peak (ceilings) | Bezpieczny · Szczyt | Peak, never “Max”, for a ceiling; one short word each (segments) |
| Compatibility mode · Color table (methods) | Tryb zgodności · Tabela kolorów | never “fallback” or “overlay” |
| Fill Light (the edge light for video calls) | Światło wypełniające | never “ring light” |
| extra range (headroom, in user copy) | Zapas jasności | “headroom” only in Advanced and diagnostics |
| Calibrate… · Run Self-Test… · Reset Display Colors… | Skalibruj… · Uruchom autotest… · Wyzeruj kolory wyświetlaczy… |  |
| Keep this level? · Go Back · Keep | Pozostawić ten poziom? · Przywróć · Pozostaw | the very-dark-level prompt |
| Pause · Paused · Resume | “Wstrzymaj Overbright” (Pause Overbright) · Wstrzymano · Wznów | a temporary stop; never “disabled” |

Fit (WP15): the footer’s default row (Battery, Auto-pause, Timer) must fit its 304 pt in full in every language (`FooterFitTests`), so the Timer chip reads “Bez limitu” for No timer.

## Carried from Cranny (generic interface words)

| English | pl | Note |
|---|---|---|
| Overbright | Overbright | never translated or transliterated; also the open panel („Otwórz Overbright”) |
| Preview | Podgląd |  |
| Settings (Overbright) | Ustawienia | Apple's „Ogólne” for General; Overbright's other pane names are WP15's |
| Allow… / Grant… | Pozwól… | Apple's button „Pozwól” |
| Reset to Default | Przywróć wartość domyślną | row menu |
| Changed from the default | Zmieniono względem wartości domyślnej |  |
| Welcome (window) | Witaj w Overbright |  |
| keyboard shortcut | skrót klawiszowy (short: skrót) | the Shortcuts **app** is „Skróty”; its items are „skróty” |
| Shortcuts (Apple app) | Skróty | Apple's name; „w aplikacji Skróty” |
| Save (Apple's button) · Undo · Retry | Zachowaj · Cofnij · Ponów / Spróbuj ponownie |  |
| Option key | klawisz Option („Przytrzymaj klawisz Option”) | ⌥ symbol stays a symbol |
| Launch at login | Otwieraj podczas logowania | Apple's term; Login Items = „Rzeczy otwierane podczas logowania” |
| updates | uaktualnienia | Apple's word („Sprawdź uaktualnienia…”) |
| Remove (from a list) | Usuń z listy | never just „Usuń aplikację” (reads as uninstall) |
| App not installed | Aplikacja nie jest zainstalowana |  |
