# Overbright — Italian (italiano, `it`) terminology sheet

Carried from Cranny’s sheet for this language (ARCHITECTURE.md §10.2): the register, voice and
typography decisions are language facts and stay; Cranny’s notch, widget and ambient-light rows are
deleted. Overbright’s own names are decided in WP15 (ARCHITECTURE.md §10.17, §8.8); until then they
read “—”. `scripts/l10n/languages.json` has this language’s plural categories and quotation marks.

## Register and typography

Base: Apple's own Italian macOS wording (`apple-terms.py it`: System Settings, Finder, TCC, AppKit loctables).
Where Apple has a word for a concept, Overbright uses it; Overbright's own concepts get one fixed Italian term each.


### Voice and typography

- Informal **tu**, as macOS: "Fai clic…", "Trascina…", "i tuoi eventi", "Vuoi…?".
- **Menu items, buttons, toggles, commands: imperative tu**, as Apple's Italian menus ("Apri", "Chiudi finestra",
  "Mostra barra laterale", "Riduci movimento", "Verifica aggiornamenti…"). Confirmation titles use the infinitive
  question ("Ripristinare tutte le impostazioni?", "Eliminare “%@”?"). Footnotes and statuses: indicative, 3rd person.
- To-do sample items use the infinitive, as Italian lists do ("Annaffiare le piante").
- Sentence case everywhere; English title-case menu items become sentence case ("Check for Updates…" →
  "Verifica aggiornamenti…"). Apple's own names keep Apple's capitals ("Impostazioni di Sistema", "Comandi Rapidi",
  "Centro di Controllo").
- Quotes “…” (secondary ‘…’); apostrophe ’ (U+2019): l’app, dell’album, un’altra; one-character ellipsis ….
  Apple's settings and Overbright's option names quoted in running text: “Riduci movimento”, “Elementi login”,
  “Tieni sul ripiano”. App names are not quoted (Apple style: "Apri Comandi Rapidi", "Mostra nel Finder").
  Overbright's pane names in running text are quoted too: "in “Attività in tempo reale”". Buttons that open a pane do
  not quote it ("Apri Elementi login…", "Mostra in Layout e widget").
- Errors: "Impossibile …" (Apple Italian: "Impossibile salvare il risultato").
- Units: "min", "h", "s"/"sec", "ms", "px", "pt". Durations and times arrive formatted ("4 min", "1 h 30 min").
- Gender: **Overbright** masculine ("Overbright è aperto / aggiornato"); **app** feminine, invariable ("l’app", "le app");
  **widget** masculine, invariable ("il widget", "i widget"); **macOS** masculine ("macOS non ha aggiunto").
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

| English | it | Note |
|---|---|---|
| Overbright | Overbright | never translated; masculine; also the open panel ("Apri Overbright") |
| Welcome / setup | Benvenuto / configurazione | "Salta la configurazione" |
| keyboard shortcut | scorciatoia (da tastiera) | macOS 27 Italian: "Scorciatoie da tastiera…" |
| click | fai clic / clic | Apple Italian; never "clicca" |
| Never (timeout 0) | Mai |  |
| Off (option) | No | ambient light, display style, shortcut; Media visualizer/shuffle "Disattivato"; first warning "Nessuno" |
| Shortcuts (Apple's app, Settings pane) · a shortcut | Comandi Rapidi · comando rapido | Apple's Italian names |
| Allow… · Grant… | Consenti… | Apple's "Consenti" |
| Reset to Default | Ripristina valore predefinito |  |
| Changed from the default | Modificato rispetto al valore predefinito |  |
| Remove (from a list) | Rimuovi | "Rimuovi dal ripiano", "Rimuovi app"; Delete = "Elimina" (notes, to-dos, pipelines) |
| Cancel · Undo | Annulla · Annulla | Apple Italian uses one word for both |
| Launch / Open at login | Apri al login | Apple's Dock menu wording; pane "Elementi login" |
| Check for updates | Verifica aggiornamenti |  |
