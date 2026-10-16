# Overbright — Greek (Ελληνικά, `el`) terminology sheet

Carried from Cranny’s sheet for this language (ARCHITECTURE.md §10.2): the register, voice and
typography decisions are language facts and stay; Cranny’s notch, widget and ambient-light rows are
deleted, and examples and notes that named Cranny’s features (the notch, the Tray, widgets, Calendar, Notes,
Media, permissions) were replaced with Overbright’s or dropped. Overbright’s own names, its pane names among them,
were decided in WP15 (ARCHITECTURE.md §10.17, §8.8); the table shows them as the catalogs ship them.
`scripts/l10n/languages.json` has this language’s plural categories and quotation marks.

## Register and typography

Register and style, as macOS writes Greek:

- Formal plural (σας): «Κάντε κλικ», «Επιλέξτε», «Σύρετε», «Πατήστε».
- Buttons, menu items, toggles and row labels use the verbal noun, as macOS does («Άνοιγμα», «Προσθήκη»,
  «Αφαίρεση», «Εμφάνιση εικονιδίου στη γραμμή μενού»). Instructions use the formal
  imperative. Try again / Retry buttons say «Νέα δοκιμή», as Apple's do (80 strings; «Δοκιμή ξανά» is not
  an Apple form); «δοκιμάστε ξανά» stays inside sentences.
- Commands that name the app follow Apple's menu pattern without an article: «Τερματισμός Overbright»,
  «Άνοιγμα Overbright», but «Πληροφορίες για το Overbright» (Apple: «Πληροφορίες για το Mail»). In running text the
  article is used: «το Overbright».
- Sentence case. Quotes « » (inner “ ”). Ellipsis …. Question mark is the semicolon ; (U+003B).
- Final -ν: «την/στην/αυτήν/δεν/μην» keep it before a vowel and κ π τ ξ ψ μπ ντ γκ τσ τζ («αυτήν την έκδοση»,
  «αυτήν τη λίστα»; Apple never writes «αυτή την»); «τον» always keeps it. «Διαδίκτυο» is capitalised, as Apple does.
- A switched-off state is «απενεργοποιημένη/-ο» («Η πρόσβαση … είναι απενεργοποιημένη»); «Ανενεργό/Ανενεργή» is only
  the Off value of a picker or a VoiceOver state value.
- Apple's names come from the glossary (apple-terms.py) and are quoted when named in a sentence:
  «Απόρρητο και ασφάλεια» ▸ «Προσβασιμότητα», «Στοιχεία εισόδου», «Μείωση κίνησης», «Μείωση διαφάνειας»,
  «Διαφοροποίηση χωρίς χρώμα», «Λειτουργία χαμηλής ισχύος», «Εφαρμογές».
- Text that a style draws in capitals keeps its accents in the catalog; locale-aware uppercasing drops them
  («Αυτόματα» → ΑΥΤΟΜΑΤΑ, checked with `uppercased(with: el)`).

## Apple names (`apple-terms.py el` on macOS 27.0.1 — never paraphrased)

| English | el |
|---|---|
| System Settings | Ρυθμίσεις συστήματος |
| Finder | Finder |
| Shortcuts | Συντομεύσεις |
| Photos | Φωτογραφίες |
| TV | TV |
| QuickTime Player | QuickTime Player |
| Privacy & Security | Απόρρητο και ασφάλεια |
| Accessibility | Προσβασιμότητα |
| General | Γενικά |
| Appearance | Εμφάνιση |
| Menu Bar | Γραμμή μενού |
| Control Center | Κέντρο ελέγχου |
| Focus | Συγκέντρωση |
| Displays | Οθόνες |
| Keyboard | Πληκτρολόγιο |
| Keyboard Shortcuts… | Συντομεύσεις πληκτρολογίου… |
| Lock Screen | Οθόνη κλειδώματος |
| Battery | Μπαταρία |
| Energy | Ενέργεια |
| Screen Saver | Προφύλαξη οθόνης |
| Login Items | Στοιχεία εισόδου |
| Login Items & Extensions | Στοιχεία εισόδου και επεκτάσεις |
| Brightness | Φωτεινότητα |
| Automatically adjust brightness | Αυτόματη προσαρμογή φωτεινότητας |
| True Tone | True Tone |
| High Dynamic Range | Υψηλό δυναμικό εύρος |
| Preset | Προεπιλογή |
| Night Shift… | Night Shift… |
| Color profile | Προφίλ χρωμάτων |
| Refresh rate | Ρυθμός ανανέωσης |
| Allow in the Menu Bar | Να επιτρέπεται στη γραμμή μενού |
| Low Power Mode | Λειτουργία χαμηλής ισχύος |
| Do Not Disturb | Μην ενοχλείτε |
| Camera | Κάμερα |
| Open Anyway | Άνοιγμα οπωσδήποτε |
| Applications | Εφαρμογές |
| Reduce motion | Μείωση κίνησης |
| Reduce transparency | Μείωση διαφάνειας |
| Increase contrast | Αύξηση αντίθεσης |
| Differentiate without color | Διαφοροποίηση χωρίς χρώμα |
| VoiceOver | VoiceOver |

## Overbright’s own names

| English | el | Note |
|---|---|---|
| Overbright | Overbright | never translated or transliterated |
| Settings panes: General · Displays · Automations · Shortcuts · Fill Light · Advanced · About | Γενικά · Οθόνες · Αυτοματισμοί · Συντομεύσεις πληκτρολογίου · Φωτισμός προσώπου · Προηγμένα · Πληροφορίες | the sidebar and window titles |
| Standard (the brightness macOS shows) | Τυπικό | never “100 %” or “normal mode” |
| extra brightness (the boost half) | “Χρήση επιπλέον φωτεινότητας” (Use extra brightness) | never “boost”, “HDR mode”, “EDR” |
| Dim below minimum (the setting) | “Εναλλαγή χαμηλώματος κάτω από το ελάχιστο” (Dim Below Minimum On or Off) | the incumbent’s name for it is never used |
| Dimmed (the state) · Dim All Displays / Stop Dimming (actions) | Σε χαμήλωμα · Χαμήλωμα όλων των οθονών / Διακοπή χαμηλώματος | not “night mode” |
| Brighter · Less Bright (one step) | Φωτεινότερα · Λιγότερο φωτεινά | never “Dimmer”: it reads like Dim |
| Back to Standard (the instant off) | Επιστροφή στο Τυπικό | not “panic”, not “reset brightness” |
| Indoor · Bright room · Sunlight · Max (presets) | Κλειστός χώρος · Φωτεινό δωμάτιο · Ηλιακό φως · Μέγιστο | “Max” is a preset only |
| Safe · Peak (ceilings) | Ασφαλές · Αιχμή | Peak, never “Max”, for a ceiling; one short word each (segments) |
| Compatibility mode · Color table (methods) | Λειτουργία συμβατότητας · Πίνακας χρωμάτων | never “fallback” or “overlay” |
| Fill Light (the edge light for video calls) | Φωτισμός προσώπου | never “ring light” |
| extra range (headroom, in user copy) | Περιθώριο φωτεινότητας | “headroom” only in Advanced and diagnostics |
| Calibrate… · Run Self-Test… · Reset Display Colors… | Βαθμονόμηση… · Εκτέλεση αυτοελέγχου… · Επαναφορά χρωμάτων οθόνης… |  |
| Keep this level? · Go Back · Keep | Να μείνει αυτό το επίπεδο; · Επιστροφή · Διατήρηση | the very-dark-level prompt |
| Pause · Paused · Resume | “Παύση Overbright” (Pause Overbright) · Σε παύση · Συνέχιση | a temporary stop; never “disabled” |

Fit (WP15): the footer’s default row (Battery, Auto-pause, Timer) must fit its 292 pt in full in every language (`FooterFitTests`), so the Auto-pause chip reads “Παύσεις” (off: “Χωρίς παύσεις”) and the Timer chip “Χωρίς όριο” for No timer. The Indoor preset is “Κλειστός χώρος”: the HUD shows a preset and its value in 200 pt (`HUDFitTests`).

## Carried from Cranny (generic interface words)

| English | el | Note |
|---|---|---|
| Overbright | Overbright | never translated or transliterated; neuter: το Overbright, του Overbright, στο Overbright |
| Shortcuts (Apple's app) · a shortcut | Συντομεύσεις · συντόμευση | app named in quotes «Συντομεύσεις» in sentences |
| login · Launch / Open at login | είσοδος · Άνοιγμα κατά την είσοδο | Apple's «Άνοιγμα κατά την είσοδο», «Στοιχεία εισόδου»; never «κατά τη σύνδεση» (= while connecting); search words keep «σύνδεση» |
| Acknowledgments | Αναγνωρίσεις | Apple's section name |
| Try again · Retry (buttons) | Νέα δοκιμή | Apple's button; the chip, the banner and the card menu of a display that failed or stopped |
| keyboard shortcut · keys | συντόμευση (πληκτρολογίου) · πλήκτρα | key combination in a sentence: «ο συνδυασμός %@» (the live key caps) |
| Reset to Default · Changed from the default | Επαναφορά προεπιλογής · Διαφέρει από την προεπιλογή |  |
| click | κλικ / κάντε κλικ |  |
| App not installed | Η εφαρμογή δεν είναι εγκατεστημένη | never the bundle ID |
| Remove · Delete | Αφαίρεση · Διαγραφή | Remove = from a list (does not uninstall/delete) |
| Show … / Hide … (switches) | Εμφάνιση … / Απόκρυψη … |  |
| Never · Off · On · Automatic | Ποτέ · Ανενεργό · Ενεργό · Αυτόματα | picker values; “X is off” in a sentence = «είναι απενεργοποιημένη/-ο» |
