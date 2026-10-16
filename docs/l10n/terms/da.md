# Overbright — Danish (dansk, `da`) terminology sheet

Carried from Cranny’s sheet for this language (ARCHITECTURE.md §10.2): the register, voice and
typography decisions are language facts and stay; Cranny’s notch, widget and ambient-light rows are
deleted, and examples and notes that named Cranny’s features (the notch, the Tray, widgets, Calendar, Notes,
Media, permissions) were replaced with Overbright’s or dropped. Overbright’s own names, its pane names among them,
were decided in WP15 (ARCHITECTURE.md §10.17, §8.8); the table shows them as the catalogs ship them.
`scripts/l10n/languages.json` has this language’s plural categories and quotation marks.

## Register and typography

Register: informal **du**, sentence case everywhere (also menus and buttons, as Danish macOS does: “Søg efter
opdateringer…”, “Slut Overbright”). Buttons and menu items in the **imperative** (Åbn, Tilføj, Slet, Fjern, Vis);
toggles too (“Vis værdi”, “Vis symbol i menulinjen”), as Apple’s Danish System Settings does (“Afspil brugerfladens
lydeffekter”). Quotes “…” (inner ‘…’), apostrophe ’ (pc’er), ellipsis …, en dash with spaces “ – ” in running
text. Units: “pkt.” for points, “px”, “ms”, timer units “t.”, “min.”, “sek.” as Apple’s Danish Clock writes them.
Error lines in Apple’s passive, always with a subject: “Skærmfarverne kunne ikke nulstilles”, “Overbright kunne
ikke flyttes” (never a subjectless “Kunne ikke nulstille”). Genitive of the name: “Overbrights”.
Overbright is “den” (en app) when a pronoun is needed; adjectives in common gender (“Overbright, lukket / åben”). The user
opens Overbright, so Overbright “åbnes” (passive: “før Overbright åbnes”, “Åbnes kun med tasterne”), not “åbner”.
Imperatives without the accent, as Apple writes them: Aktiver, Sikkerhedskopier. “Springe … over” takes a definite
object: “Spring introduktionen over”, “Spring opsætningen over”. “Settings for X…” buttons follow Apple’s
“Indstillinger til …” (Indstillinger til Mission Control): “Indstillinger til denne skærm…”. Settings return to
their default with “nulstilles til standard” (the button is “Nulstil”). Apple names and button names inside a
sentence go in quotes (“Energibesparende funktion”, “Åbn alligevel”), pane names in a ▸ path do not.

## Apple names (`apple-terms.py da` on macOS 27.0.1 — never paraphrased)

| English | da |
|---|---|
| System Settings | Systemindstillinger |
| Finder | Finder |
| Shortcuts | Genveje |
| Photos | Fotos |
| TV | TV |
| QuickTime Player | QuickTime Player |
| Privacy & Security | Anonymitet & sikkerhed |
| Accessibility | Tilgængelighed |
| General | Generelt |
| Appearance | Udseende |
| Menu Bar | Menulinje |
| Control Center | Kontrolcenter |
| Focus | Fokus |
| Displays | Skærm |
| Keyboard | Tastatur |
| Keyboard Shortcuts… | Tastaturgenveje… |
| Lock Screen | Låseskærm |
| Battery | Batteri |
| Energy | Energi |
| Screen Saver | Skærmskåner |
| Login Items | Loginemner |
| Login Items & Extensions | Loginemner & udvidelser |
| Brightness | Lysstyrke |
| Automatically adjust brightness | Juster lysstyrke automatisk |
| True Tone | True Tone |
| High Dynamic Range | Højt dynamisk område (HDR) |
| Preset | Forindstilling |
| Night Shift… | Night Shift… |
| Color profile | Farveprofil |
| Refresh rate | Opdateringsfrekvens |
| Allow in the Menu Bar | Tillad på menulinjen |
| Low Power Mode | Energibesparende funktion |
| Do Not Disturb | Forstyr ikke |
| Camera | Kamera |
| Open Anyway | Åbn alligevel |
| Applications | Apps |
| Reduce motion | Formindsk bevægelse |
| Reduce transparency | Formindsk gennemsigtighed |
| Increase contrast | Forøg kontrast |
| Differentiate without color | Differentier uden farve |
| VoiceOver | VoiceOver |

## Overbright’s own names

| English | da | Note |
|---|---|---|
| Overbright | Overbright | never translated or transliterated |
| Settings panes: General · Displays · Automations · Shortcuts · Fill Light · Advanced · About | Generelt · Skærme · Automatiseringer · Tastaturgenveje · Udfyldningslys · Avanceret · Om | the sidebar and window titles |
| Standard (the brightness macOS shows) | Standard | never “100 %” or “normal mode” |
| extra brightness (the boost half) | “Brug ekstra lysstyrke” (Use extra brightness) | never “boost”, “HDR mode”, “EDR” |
| Dim below minimum (the setting) | “Dæmp under minimum til/fra” (Dim Below Minimum On or Off) | the incumbent’s name for it is never used |
| Dimmed (the state) · Dim All Displays / Stop Dimming (actions) | Dæmpet · Dæmp alle skærme / Stop dæmpning | not “night mode” |
| Brighter · Less Bright (one step) | Lysere · Mørkere | never “Dimmer”: it reads like Dim |
| Back to Standard (the instant off) | Tilbage til Standard | not “panic”, not “reset brightness” |
| Indoor · Bright room · Sunlight · Max (presets) | Indendørs · Lyst rum · Sollys · Maks. | “Max” is a preset only |
| Safe · Peak (ceilings) | Sikker · Top | Peak, never “Max”, for a ceiling; one short word each (segments) |
| Compatibility mode · Color table (methods) | Kompatibilitetstilstand · Farvetabel | never “fallback” or “overlay” |
| Fill Light (the edge light for video calls) | Udfyldningslys | never “ring light” |
| extra range (headroom, in user copy) | Lysreserve | “headroom” only in Advanced and diagnostics |
| Calibrate… · Run Self-Test… · Reset Display Colors… | Kalibrer… · Kør selvtest… · Nulstil skærmfarver… |  |
| Keep this level? · Go Back · Keep | Vil du beholde dette niveau? · Gå tilbage · Behold | the very-dark-level prompt |
| Pause · Paused · Resume | “Sæt Overbright på pause” (Pause Overbright) · Sat på pause · Genoptag | a temporary stop; never “disabled” |

## Carried from Cranny (generic interface words)

| English | da | Note |
|---|---|---|
| Overbright | Overbright | never translated; genitive “Overbrights” |
| pre-release | forhåndsudgivelse | “Medtag forhåndsudgivelser”; release = udgivelse |
| Settings | Indstillinger |  |
| welcome / setup | velkomst / opsætning | “Spring opsætning over” |
| click / press (a key) | klik (på) / tryk på |  |
| keyboard shortcut | tastaturgenvej | always “tastatur-” so it never reads as a Shortcuts shortcut |
| Reset to Default · Changed from the default | Nulstil til standard · Ændret fra standard |  |
| Never (timeout) | Aldrig |  |
| Off / On | Fra / Til |  |
| Remove | Fjern |  |
| App not installed | Appen er ikke installeret |  |
| Preview | Eksempel | Apple’s Danish |
