# Overbright — Greek (Ελληνικά, `el`) terminology sheet

Carried from Cranny’s sheet for this language (ARCHITECTURE.md §10.2): the register, voice and
typography decisions are language facts and stay; Cranny’s notch, widget and ambient-light rows are
deleted. Overbright’s own names are decided in WP15 (ARCHITECTURE.md §10.17, §8.8); until then they
read “—”. `scripts/l10n/languages.json` has this language’s plural categories and quotation marks.

## Register and typography

Register and style, as macOS writes Greek:

- Formal plural (σας): «Κάντε κλικ», «Επιλέξτε», «Σύρετε», «Πατήστε».
- Buttons, menu items, toggles and row labels use the verbal noun, as macOS does («Άνοιγμα», «Προσθήκη»,
  «Αφαίρεση», «Εμφάνιση εικονιδίου στη γραμμή μενού»). Instructions, coach marks and tutorial bubbles use the
  formal imperative. Try again / Retry buttons say «Νέα δοκιμή», as Apple's do (80 strings; «Δοκιμή ξανά» is not
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
  «Διαφοροποίηση χωρίς χρώμα», «Λειτουργία χαμηλής ισχύος», «Εγγραφή ήχου συστήματος», «Λήψεις», «Εφαρμογές».
- Text that a style draws in capitals keeps its accents in the catalog; locale-aware uppercasing drops them
  («Ζωντανά» → ΖΩΝΤΑΝΑ, checked with `uppercased(with: el)`).

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

| English | el | Note |
|---|---|---|
| Overbright | Overbright | never translated or transliterated; neuter: το Overbright, του Overbright, στο Overbright |
| Shortcuts (Apple's app) · a shortcut | Συντομεύσεις · συντόμευση | app named in quotes «Συντομεύσεις» in sentences |
| login · Launch / Open at login | είσοδος · Άνοιγμα κατά την είσοδο | Apple's «Άνοιγμα κατά την είσοδο», «Στοιχεία εισόδου»; never «κατά τη σύνδεση» (= while connecting); search words keep «σύνδεση» |
| Acknowledgments | Αναγνωρίσεις | Apple's section name |
| Try again · Retry (buttons) | Νέα δοκιμή | Apple's button; Mirror chip 63 of 74 pt at the narrowest card |
| keyboard shortcut · keys | συντόμευση (πληκτρολογίου) · πλήκτρα | key combination in a sentence: «ο συνδυασμός ⌃⌥N» |
| Reset to Default · Changed from the default | Επαναφορά προεπιλογής · Διαφέρει από την προεπιλογή |  |
| Allow (shows the system prompt) · Allow… / Grant… | Να επιτραπεί · Να επιτραπεί… | Apple's own TCC button; the narrow Mirror chip says «Επιτρέψτε…» |
| click | κλικ / κάντε κλικ |  |
| App not installed | Η εφαρμογή δεν είναι εγκατεστημένη | never the bundle ID |
| Remove · Delete | Αφαίρεση · Διαγραφή | Remove = from a list (does not uninstall/delete) |
| Show … / Hide … (switches) | Εμφάνιση … / Απόκρυψη … |  |
| Never · Off · On · Automatic | Ποτέ · Ανενεργό · Ενεργό · Αυτόματα | picker values; “X is off” in a sentence = «είναι απενεργοποιημένη/-ο» |
| subject (Remove background) | θέμα | Apple: «Αντιγραφή θέματος»; «Δεν βρέθηκε θέμα» |
