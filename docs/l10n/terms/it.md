# Overbright — Italian (italiano, `it`) terminology sheet

Carried from Cranny’s sheet for this language (ARCHITECTURE.md §10.2): the register, voice and
typography decisions are language facts and stay; Cranny’s notch, widget and ambient-light rows are
deleted, and examples and notes that named Cranny’s features (the notch, the Tray, widgets, Calendar, Notes,
Media, permissions) were replaced with Overbright’s or dropped. Overbright’s own names, its pane names among them,
were decided in WP15 (ARCHITECTURE.md §10.17, §8.8); the table shows them as the catalogs ship them.
`scripts/l10n/languages.json` has this language’s plural categories and quotation marks.

## Register and typography

Base: Apple's own Italian macOS wording (`apple-terms.py it`: System Settings, Finder, AppKit loctables).
Where Apple has a word for a concept, Overbright uses it; Overbright's own concepts get one fixed Italian term each.


### Voice and typography

- Informal **tu**, as macOS: "Fai clic…", "Trascina…", "i tuoi schermi", "Vuoi…?".
- **Menu items, buttons, toggles, commands: imperative tu**, as Apple's Italian menus ("Apri", "Chiudi finestra",
  "Mostra barra laterale", "Riduci movimento", "Verifica aggiornamenti…"). Confirmation titles use the infinitive
  question ("Ripristinare tutte le impostazioni?", "Ripristinare i colori degli schermi?"). Footnotes and statuses: indicative, 3rd person.
- Sentence case everywhere; English title-case menu items become sentence case ("Check for Updates…" →
  "Verifica aggiornamenti…"). Apple's own names keep Apple's capitals ("Impostazioni di Sistema", "Comandi Rapidi",
  "Centro di Controllo").
- Quotes “…” (secondary ‘…’); apostrophe ’ (U+2019): l’app, dell’app, un’altra; one-character ellipsis ….
  Apple's settings and Overbright's option names quoted in running text: “Riduci movimento”, “Elementi login”,
  “Risparmio energetico”. App names are not quoted (Apple style: "Apri Comandi Rapidi", "Mostra nel Finder").
  Overbright's pane names in running text are quoted too. Buttons that open a pane do not quote it ("Apri Elementi
  login…").
- Errors: "Impossibile …" (Apple Italian: "Impossibile salvare il risultato").
- Units: "min", "h", "s"/"sec", "ms", "px", "pt". Durations and times arrive formatted ("4 min", "1 h 30 min").
- Gender: **Overbright** masculine ("Overbright è aperto / aggiornato"); **app** feminine, invariable ("l’app", "le app");
  **macOS** masculine ("macOS non ha aggiunto").
- Plurals: one / many / other; many (millions) always has the same wording as other.
- Key names as Apple Italian: Opzione, Comando, A capo, Spazio, Esc, Elimina.

## Apple names (`apple-terms.py it` on macOS 27.0.1 — never paraphrased)

| English | it |
|---|---|
| System Settings | Impostazioni di Sistema |
| Finder | Finder |
| Shortcuts | Comandi Rapidi |
| Photos | Foto |
| TV | TV |
| QuickTime Player | QuickTime Player |
| Privacy & Security | Privacy e sicurezza |
| Accessibility | Accessibilità |
| General | Generali |
| Appearance | Aspetto |
| Menu Bar | Barra dei menu |
| Control Center | Centro di Controllo |
| Focus | Full immersion |
| Displays | Schermi |
| Keyboard | Tastiera |
| Keyboard Shortcuts… | Scorciatoie da tastiera… |
| Lock Screen | Schermata di blocco |
| Battery | Batteria |
| Energy | Energia |
| Screen Saver | Salvaschermo |
| Login Items | Elementi login |
| Login Items & Extensions | Elementi login ed estensioni |
| Brightness | Luminosità |
| Automatically adjust brightness | Regola automaticamente la luminosità |
| True Tone | True Tone |
| High Dynamic Range | HDR (High Dynamic Range) |
| Preset | Preset |
| Night Shift… | Night Shift… |
| Color profile | Profilo colore |
| Refresh rate | Frequenza di aggiornamento |
| Allow in the Menu Bar | Consenti nella barra dei menu |
| Low Power Mode | Risparmio energetico |
| Do Not Disturb | Non disturbare |
| Camera | Fotocamera |
| Open Anyway | Apri comunque |
| Applications | Applicazioni |
| Reduce motion | Riduci movimento |
| Reduce transparency | Riduci la trasparenza |
| Increase contrast | Aumenta contrasto |
| Differentiate without color | Differenzia senza colore |
| VoiceOver | VoiceOver |

## Overbright’s own names

| English | it | Note |
|---|---|---|
| Overbright | Overbright | never translated or transliterated |
| Settings panes: General · Displays · Automations · Shortcuts · Fill Light · Advanced · About | Generali · Schermi · Automazioni · Scorciatoie · Luce di riempimento · Avanzate · Informazioni | the sidebar and window titles |
| Standard (the brightness macOS shows) | Standard | never “100 %” or “normal mode” |
| extra brightness (the boost half) | “Usa luminosità extra” (Use extra brightness) | never “boost”, “HDR mode”, “EDR” |
| Dim below minimum (the setting) | “Attiva o disattiva l’oscuramento sotto il minimo” (Dim Below Minimum On or Off) | the incumbent’s name for it is never used |
| Dimmed (the state) · Dim All Displays / Stop Dimming (actions) | Oscurato · Oscura tutti gli schermi / Interrompi oscuramento | not “night mode” |
| Brighter · Less Bright (one step) | Più luminoso · Meno luminoso | never “Dimmer”: it reads like Dim |
| Back to Standard (the instant off) | Torna a Standard | not “panic”, not “reset brightness” |
| Indoor · Bright room · Sunlight · Max (presets) | Interni · Luce intensa · Luce solare · Massimo | “Max” is a preset only |
| Safe · Peak (ceilings) | Sicuro · Picco | Peak, never “Max”, for a ceiling; one short word each (segments) |
| Compatibility mode · Color table (methods) | Modalità compatibilità · Tabella colori | never “fallback” or “overlay” |
| Fill Light (the edge light for video calls) | Luce di riempimento | never “ring light” |
| extra range (headroom, in user copy) | Margine di luminosità | “headroom” only in Advanced and diagnostics |
| Calibrate… · Run Self-Test… · Reset Display Colors… | Calibra… · Esegui autotest… · Ripristina colori schermo… |  |
| Keep this level? · Go Back · Keep | Mantenere questo livello? · Torna indietro · Mantieni | the very-dark-level prompt |
| Pause · Paused · Resume | “Metti in pausa Overbright” (Pause Overbright) · In pausa · Riprendi | a temporary stop; never “disabled” |

Fit (WP15): the footer’s default row (Battery, Auto-pause, Timer) must fit its 304 pt in full in every language (`FooterFitTests`), so the Auto-pause chip reads “Autopausa” (off: “Senza autopausa”) and, measured with its glyphs (WP14), the Timer chip “Senza timer” for No timer.

## Carried from Cranny (generic interface words)

| English | it | Note |
|---|---|---|
| Overbright | Overbright | never translated; masculine; also the open panel ("Apri Overbright") |
| Welcome / setup | Benvenuto / configurazione | "Salta la configurazione" |
| keyboard shortcut | scorciatoia (da tastiera) | macOS 27 Italian: "Scorciatoie da tastiera…" |
| click | fai clic / clic | Apple Italian; never "clicca" |
| Never (timeout 0) | Mai |  |
| Off (option) | No | a picker's Off option |
| Shortcuts (Apple's app) · a shortcut | Comandi Rapidi · comando rapido | Apple's Italian names |
| Allow… · Grant… | Consenti… | Apple's "Consenti" |
| Reset to Default | Ripristina valore predefinito |  |
| Changed from the default | Modificato rispetto al valore predefinito |  |
| Remove (from a list) | Rimuovi | "Rimuovi app"; Delete = "Elimina" |
| Cancel · Undo | Annulla · Annulla | Apple Italian uses one word for both |
| Launch / Open at login | Apri al login | Apple's Dock menu wording; pane "Elementi login" |
| Check for updates | Verifica aggiornamenti |  |
