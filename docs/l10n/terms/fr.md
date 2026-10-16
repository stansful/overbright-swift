# Overbright — French (français, `fr`) terminology sheet

Carried from Cranny’s sheet for this language (ARCHITECTURE.md §10.2): the register, voice and
typography decisions are language facts and stay; Cranny’s notch, widget and ambient-light rows are
deleted. Overbright’s own names are decided in WP15 (ARCHITECTURE.md §10.17, §8.8); until then they
read “—”. `scripts/l10n/languages.json` has this language’s plural categories and quotation marks.

## Register and typography

Register and typography: formal **vous**, as macOS. Buttons and menu items use the **infinitive** ("Ouvrir",
"Afficher", "Ajouter"); instructions to the user use the imperative ("Faites glisser…", "Cliquez sur…"). Sentence
case everywhere (English Title Case menu items become "Vérifier les mises à jour…" style). Guillemets « … » with a
no-break space (U+00A0) inside; no-break space before : ; ! ? ; apostrophe ’; ellipsis … attached ("Réglages…").
Numbers, dates and durations come pre-formatted (French ICU: "4min", "1h 30min", "50 %"). Plural: one (0 and 1),
many (millions; same wording as other), other.

**Overbright** is never translated, never inflected; it takes masculine agreement ("Overbright est ouvert").

## Apple names (`apple-terms.py fr` on macOS 27.0.1 — never paraphrased)

| English | fr |
|---|---|
| System Settings | Réglages Système |
| Finder | Finder |
| Shortcuts | Raccourcis |
| Photos | Photos |
| TV | TV |
| QuickTime Player | QuickTime Player |
| Privacy & Security | Confidentialité et sécurité |
| Accessibility | Accessibilité |
| General | Général |
| Appearance | Apparence |
| Menu Bar | Barre des menus |
| Control Center | Centre de contrôle |
| Focus | Concentration |
| Displays | Moniteurs |
| Keyboard | Clavier |
| Keyboard Shortcuts… | Raccourcis clavier… |
| Lock Screen | Écran verrouillé |
| Battery | Batterie |
| Energy | Énergie |
| Screen Saver | Économiseur d’écran |
| Login Items | Ouverture |
| Login Items & Extensions | Ouverture et extensions |
| Brightness | Luminosité |
| Automatically adjust brightness | Régler la luminosité automatiquement |
| True Tone | True Tone |
| High Dynamic Range | Plage dynamique étendue |
| Preset | Préréglage |
| Night Shift… | Night Shift… |
| Color profile | Profil de couleur |
| Refresh rate | Taux de rafraîchissement |
| Allow in the Menu Bar | Autoriser dans la barre des menus |
| Low Power Mode | Mode Économie d’énergie |
| Do Not Disturb | Ne pas déranger |
| Camera | Caméra |
| Open Anyway | Ouvrir quand même |
| Applications | Applications |
| Reduce motion | Réduire les animations |
| Reduce transparency | Réduire la transparence |
| Increase contrast | Augmenter le contraste |
| Differentiate without color | Différencier sans couleur |
| VoiceOver | VoiceOver |

## Overbright’s own names

| English | fr | Note |
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

| English | fr | Note |
|---|---|---|
| Overbright | Overbright | brand; masculine ("Garder Overbright ouvert", "Overbright est fermé") |
| Preview (Settings stage) | Aperçu | "Aperçu : Overbright dit bonjour" |
| click | cliquer / clic | Apple FR "Cliquez sur…"; "Ouvrir Overbright par : Clic" |
| Shortcuts (Apple app) | Raccourcis | Apple’s name; a Shortcuts item = "raccourci" |
| keyboard shortcut | raccourci clavier | always with "clavier" when ambiguous; Settings ▸ Keyboard section "Raccourcis clavier" |
| launcher (search keyword) | lanceur |  |
| Settings | Réglages | macOS 13+ wording ("Réglages…", "Réglages ▸ Clavier") |
| Reset to Default | Rétablir la valeur par défaut |  |
| Changed from the default | Modifié par rapport à la valeur par défaut |  |
| Allow… / Grant… | Autoriser… |  |
| Delete | Supprimer |  |
| App not installed | App non installée |  |
| Welcome | Bienvenue | "Bienvenue dans Overbright" |
| Never (timeout 0) | Jamais |  |
| Show … (switches) | Afficher … |  |
| Done (editor / welcome button) | OK / Terminé | layout editor "OK" (Apple FR); welcome/tutorial closing "Terminé" |
| Symbol | Symbole |  |
| Login Items | Ouverture et extensions | Apple’s pane name in macOS 27 (Général ▸ Ouverture et extensions), always quoted in sentences; button « Ouvrir les réglages « Ouverture et extensions »… » (pattern of « Ouvrir les réglages Batterie »); footnotes « autorisez Overbright sous « Ouverture et extensions » dans Réglages Système »; the list inside is « Ouvrir avec la session » (« à la liste « Ouvrir avec la session » ») |
| System Audio Recording | Enregistrement des sons du système | follows Apple’s pane « Enregistrement de l’écran et des sons du système » |
| Launch / Open at login | Ouvrir avec la session | Apple’s "Open at Login" (Dock menu, Ouverture et extensions) |
| Esc / Return / Space / Delete / Command | Échap / Retour / Espace / Supprimer / Commande | Apple FR key names in prose; key caps stay symbols |
| Paused / Done states | En pause / Terminé |  |
