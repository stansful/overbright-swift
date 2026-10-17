# Overbright — French (français, `fr`) terminology sheet

Carried from Cranny’s sheet for this language (ARCHITECTURE.md §10.2): the register, voice and
typography decisions are language facts and stay; Cranny’s notch, widget and ambient-light rows are
deleted, and examples and notes that named Cranny’s features (the notch, the Tray, widgets, Calendar, Notes,
Media, permissions) were replaced with Overbright’s or dropped. Overbright’s own names, its pane names among them,
were decided in WP15 (ARCHITECTURE.md §10.17, §8.8); the table shows them as the catalogs ship them.
`scripts/l10n/languages.json` has this language’s plural categories and quotation marks.

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
| Settings panes: General · Displays · Automations · Shortcuts · Fill Light · Advanced · About | Général · Écrans · Automatisations · Raccourcis clavier · Lumière d’appoint · Avancé · À propos | the sidebar and window titles |
| Standard (the brightness macOS shows) | Standard | never “100 %” or “normal mode” |
| extra brightness (the boost half) | “Utiliser la luminosité supplémentaire” (Use extra brightness) | never “boost”, “HDR mode”, “EDR” |
| Dim below minimum (the setting) | “Activer ou désactiver l’assombrissement sous le minimum” (Dim Below Minimum On or Off) | the incumbent’s name for it is never used |
| Dimmed (the state) · Dim All Displays / Stop Dimming (actions) | Assombri · Assombrir tous les écrans / Arrêter l’assombrissement | not “night mode” |
| Brighter · Less Bright (one step) | Plus lumineux · Moins lumineux | never “Dimmer”: it reads like Dim |
| Back to Standard (the instant off) | Revenir au standard | not “panic”, not “reset brightness” |
| Indoor · Bright room · Sunlight · Max (presets) | Intérieur · Pièce claire · Plein soleil · Maximum | “Max” is a preset only |
| Safe · Peak (ceilings) | Sécurité · Pic | Peak, never “Max”, for a ceiling; one short word each (segments) |
| Compatibility mode · Color table (methods) | Mode de compatibilité · Table des couleurs | never “fallback” or “overlay” |
| Fill Light (the edge light for video calls) | Lumière d’appoint | never “ring light” |
| extra range (headroom, in user copy) | Marge de luminosité | “headroom” only in Advanced and diagnostics |
| Calibrate… · Run Self-Test… · Reset Display Colors… | Calibrer… · Lancer l’autotest… · Réinitialiser les couleurs des écrans… |  |
| Keep this level? · Go Back · Keep | Garder ce niveau ? · Revenir · Garder | the very-dark-level prompt |
| Pause · Paused · Resume | “Suspendre Overbright” (Pause Overbright) · En pause · Reprendre | a temporary stop; never “disabled” |

## Carried from Cranny (generic interface words)

| English | fr | Note |
|---|---|---|
| Overbright | Overbright | brand; masculine ("Garder Overbright ouvert", "Overbright est fermé") |
| Preview | Aperçu |  |
| click | cliquer / clic | Apple FR "Cliquez sur…" |
| Shortcuts (Apple app) | Raccourcis | Apple’s name; a Shortcuts item = "raccourci" |
| keyboard shortcut | raccourci clavier | always with "clavier" when ambiguous (Overbright's Shortcuts pane holds key bindings) |
| Settings | Réglages | macOS 13+ wording ("Réglages…", "Réglages ▸ Général") |
| Reset to Default | Rétablir la valeur par défaut |  |
| Changed from the default | Modifié par rapport à la valeur par défaut |  |
| Allow… / Grant… | Autoriser… |  |
| Delete | Supprimer |  |
| App not installed | App non installée |  |
| Welcome | Bienvenue | "Bienvenue dans Overbright" |
| Never (timeout 0) | Jamais |  |
| Show … (switches) | Afficher … |  |
| Done (sheet / welcome button) | OK / Terminé | a sheet's Done (Acknowledgments) "OK" (Apple FR); Welcome's closing button "Terminé" |
| Symbol | Symbole |  |
| Login Items | Ouverture et extensions | Apple’s pane name in macOS 27 (Général ▸ Ouverture et extensions), always quoted in sentences; button « Ouvrir les réglages « Ouverture et extensions »… » (pattern of « Ouvrir les réglages Batterie »); footnotes « autorisez Overbright sous « Ouverture et extensions » dans Réglages Système »; the list inside is « Ouvrir avec la session » (« à la liste « Ouvrir avec la session » ») |
| Launch / Open at login | Ouvrir avec la session | Apple’s "Open at Login" (Dock menu, Ouverture et extensions) |
| Esc / Return / Space / Delete / Command | Échap / Retour / Espace / Supprimer / Commande | Apple FR key names in prose; key caps stay symbols |
| Paused / Done states | En pause / Terminé |  |
| Space (the space bar in key caps) | Espace | as AppKit writes it in menu key equivalents (FunctionKeyNames.loctable “Space”), so Settings and Welcome show the same key caps as the menu; AppKit’s name for the physical key is Barre d’espace |

Fit (WP14): the footer’s default row (Battery, Auto-pause, Timer) must fit its 304 pt in full in every language, measured with its glyphs (`FooterFitTests`), so the Timer chip reads “Sans limite” for No timer.
