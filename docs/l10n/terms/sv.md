# Overbright — Swedish (svenska, `sv`) terminology sheet

Carried from Cranny’s sheet for this language (ARCHITECTURE.md §10.2): the register, voice and
typography decisions are language facts and stay; Cranny’s notch, widget and ambient-light rows are
deleted, and examples and notes that named Cranny’s features (the notch, the Tray, widgets, Calendar, Notes,
Media, permissions) were replaced with Overbright’s or dropped. Overbright’s own names, its pane names among them,
were decided in WP15 (ARCHITECTURE.md §10.17, §8.8); the table shows them as the catalogs ship them.
`scripts/l10n/languages.json` has this language’s plural categories and quotation marks.

## Register and typography

Register: informal **du**, sentence case everywhere — also menu items, buttons and pane names, as Swedish macOS
writes them (“Leta efter uppdateringar…”, “Avsluta Overbright”, “Visa i Finder”). Buttons, menu items and toggles in the
**imperative** (Öppna, Lägg till, Ta bort, Radera, Visa, Pausa), as Apple’s Swedish System Settings does (“Visa i
menyraden”, “Minska rörelse”). Status words standing alone take the neuter participle (“Kopierat”, “Pausat”,
“Klart”) unless they describe a specific common-gender noun (bildskärmen är “Pausad”).
Typography: quotes ”…” (U+201D on both sides), inner ’…’, apostrophe ’, ellipsis …, spaced en dash “ – ” in running
text (never the English em dash), no apostrophe in the genitive (“Overbrights”). Compounds with foreign names take a
hyphen (“HDR-video”, “OLED-skärm”, “Overbright-panelen”). Units: pt, px, ms, timer units tim/min/sek.
Error lines in Apple’s style: “Det gick inte att …” / “Kunde inte …”. Overbright is “den” (en app) when a pronoun is
needed, adjectives in common gender (“Overbright är öppen”).

## Apple names (`apple-terms.py sv` on macOS 27.0.1 — never paraphrased)

| English | sv |
|---|---|
| System Settings | Systeminställningar |
| Finder | Finder |
| Shortcuts | Genvägar |
| Photos | Bilder |
| TV | TV |
| QuickTime Player | QuickTime Player |
| Privacy & Security | Integritet och säkerhet |
| Accessibility | Hjälpmedel |
| General | Allmänt |
| Appearance | Utseende |
| Menu Bar | Menyrad |
| Control Center | Kontrollcenter |
| Focus | Fokus |
| Displays | Bildskärmar |
| Keyboard | Tangentbord |
| Keyboard Shortcuts… | Kortkommandon… |
| Lock Screen | Låsskärmen |
| Battery | Batteri |
| Energy | Ström |
| Screen Saver | Skärmsläckare |
| Login Items | Startobjekt |
| Login Items & Extensions | Startobjekt och tillägg |
| Brightness | Ljusstyrka |
| Automatically adjust brightness | Justera ljusstyrka automatiskt |
| True Tone | True Tone |
| High Dynamic Range | HDR |
| Preset | Förinställning |
| Night Shift… | Night Shift… |
| Color profile | Färgprofil |
| Refresh rate | Uppdateringsfrekvens |
| Allow in the Menu Bar | Tillåt i menyraden |
| Low Power Mode | Strömsparläge |
| Do Not Disturb | Stör ej |
| Camera | Kamera |
| Open Anyway | Öppna ändå |
| Applications | Appar |
| Reduce motion | Minska rörelse |
| Reduce transparency | Minska genomskinlighet |
| Increase contrast | Öka kontrast |
| Differentiate without color | Differentiera utan färg |
| VoiceOver | VoiceOver |

## Overbright’s own names

| English | sv | Note |
|---|---|---|
| Overbright | Overbright | never translated or transliterated |
| Settings panes: General · Displays · Automations · Shortcuts · Fill Light · Advanced · About | Allmänt · Skärmar · Automatiseringar · Kortkommandon · Fyllnadsljus · Avancerat · Om | the sidebar and window titles |
| Standard (the brightness macOS shows) | Standard | never “100 %” or “normal mode” |
| extra brightness (the boost half) | “Använd extra ljusstyrka” (Use extra brightness) | never “boost”, “HDR mode”, “EDR” |
| Dim below minimum (the setting) | “Tona ned under minimum på/av” (Dim Below Minimum On or Off) | the incumbent’s name for it is never used |
| Dimmed (the state) · Dim All Displays / Stop Dimming (actions) | Nedtonad · Tona ned alla skärmar / Sluta tona ned | not “night mode” |
| Brighter · Less Bright (one step) | Ljusare · Mörkare | never “Dimmer”: it reads like Dim |
| Back to Standard (the instant off) | Tillbaka till Standard | not “panic”, not “reset brightness” |
| Indoor · Bright room · Sunlight · Max (presets) | Inomhus · Ljust rum · Solljus · Max | “Max” is a preset only |
| Safe · Peak (ceilings) | Säker · Topp | Peak, never “Max”, for a ceiling; one short word each (segments) |
| Compatibility mode · Color table (methods) | Kompatibilitetsläge · Färgtabell | never “fallback” or “overlay” |
| Fill Light (the edge light for video calls) | Fyllnadsljus | never “ring light” |
| extra range (headroom, in user copy) | Ljusreserv | “headroom” only in Advanced and diagnostics |
| Calibrate… · Run Self-Test… · Reset Display Colors… | Kalibrera… · Kör självtest… · Återställ skärmfärger… |  |
| Keep this level? · Go Back · Keep | Vill du behålla den här nivån? · Gå tillbaka · Behåll | the very-dark-level prompt |
| Pause · Paused · Resume | “Pausa Overbright” (Pause Overbright) · Pausad · Återuppta | a temporary stop; never “disabled” |

## Carried from Cranny (generic interface words)

| English | sv | Note |
|---|---|---|
| Overbright | Overbright | never translated; genitive “Overbrights”; the open panel is also called Overbright (“Öppna Overbright”) |
| Settings | Inställningar |  |
| welcome / setup | välkomst / konfigurering | “Hoppa över konfigureringen” |
| click / press (a key) | klicka (på) / tryck på | never “trycka” for a mouse click |
| keyboard shortcut | kortkommando | never “genväg” (that is a Shortcuts shortcut) |
| Reset to Default · Changed from the default | Återställ förval · Ändrat från förval | a reset message: “… återställs till förval” (never “återgår till förval”) |
| Never (timeout) | Aldrig |  |
| Off / On | Av / På |  |
| Remove · Delete | Ta bort · Radera | Apple: Remove = Ta bort, Delete = Radera |
| App not installed | Appen är inte installerad |  |
| Preview | Förhandsvisning |  |
| Done | Klar | Apple’s “Klar” button |
