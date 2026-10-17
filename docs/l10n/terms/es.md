# Overbright — Spanish (español, `es`) terminology sheet

Carried from Cranny’s sheet for this language (ARCHITECTURE.md §10.2): the register, voice and
typography decisions are language facts and stay; Cranny’s notch, widget and ambient-light rows are
deleted, and examples and notes that named Cranny’s features (the notch, the Tray, widgets, Calendar, Notes,
Media, permissions) were replaced with Overbright’s or dropped. Overbright’s own names, its pane names among them,
were decided in WP15 (ARCHITECTURE.md §10.17, §8.8); the table shows them as the catalogs ship them.
`scripts/l10n/languages.json` has this language’s plural categories and quotation marks.

## Register and typography

One Spanish for Spain and Latin America (es-419 falls back here). Base: Apple's own `es` macOS wording
(`apple-terms.py es`, AppKit/Finder/System Settings loctables), which is Spain-flavoured; where Spain and Latin
America differ, prefer the neutral word, but keep Apple's term where people look for it on screen.


### Voice and typography

- Informal **tú**, as macOS: "Haz clic…", "Arrastra…", "tus pantallas".
- **Buttons, menu items, toggles, commands: infinitive** ("Abrir Overbright", "Mostrar el valor", "Buscar actualizaciones…").
  **Instructions to the user: imperative tú** ("Arrastra Overbright a la carpeta Aplicaciones", "Pulsa el atajo de teclado").
  Footnotes and statuses: present indicative, third person.
- Sentence case everywhere (English title-case menu items become sentence case: "Check for Updates…" → "Buscar actualizaciones…").
- Quotes “…” (secondary ‘…’); one-character ellipsis …; opening ¿ and ¡. App names are not quoted (Apple style:
  "Mostrar en el Finder", "la app Atajos"); Overbright's own pane names and Apple's settings and panes in running text
  are quoted: “Reducir movimiento”, “Modo de bajo consumo”, “General”, “Ítems de inicio”. Not quoted: Settings paths
  with ▸ ("Ajustes ▸ General", "Privacidad y seguridad ▸ Accesibilidad"), button titles ("Abrir Ítems de inicio…").
- Statuses about the future: future / subjunctive ("Se reanudará cuando conectes el Mac a la corriente").
  Confirmation messages describe what will happen: future ("volverán a su valor predeterminado", "Cada pantalla volverá a su perfil de color").
- Errors: "No se ha podido…" (Apple es). Unit symbols: "min", "h", "ms", "px", "pt"; numbers and durations come formatted.
- Key names (Apple es: Terminal "⌫ Suprimir", Calculator "Comando + Suprimir"): Comando (⌘), Opción (⌥), Control (⌃),
  Mayúsculas (⇧), Retorno (↩), **Suprimir (⌫)** — never "Eliminar" for the key —, Espacio, Esc, Flecha arriba / abajo.
  Combinations: "Opción + 1", "Comando + Flecha arriba". Hold a key = "mantener pulsada (la tecla) ⌥".
- Regional neutrality: avoid Peninsular-only phrasing where a neutral one exists ("Intenta…", not "Prueba a…";
  "almuerzo", not "comida"); keep Apple es terms people see on screen (ratón, vídeo, mando de videojuegos).
- Gender: **Overbright** masculine ("Overbright está abierto / cerrado / desactivado"); **macOS** masculine ("macOS no ha añadido…");
  **app** feminine ("la app", "las apps"); **el Mac**.
- Plurals: es = one / many / other; many (millions) always has the same wording as other.

## Apple names (`apple-terms.py es` on macOS 27.0.1 — never paraphrased)

| English | es |
|---|---|
| System Settings | Ajustes del Sistema |
| Finder | Finder |
| Shortcuts | Atajos |
| Photos | Fotos |
| TV | TV |
| QuickTime Player | QuickTime Player |
| Privacy & Security | Privacidad y seguridad |
| Accessibility | Accesibilidad |
| General | General |
| Appearance | Aspecto |
| Menu Bar | Barra de menús |
| Control Center | Centro de control |
| Focus | Modos de concentración |
| Displays | Pantallas |
| Keyboard | Teclado |
| Keyboard Shortcuts… | Atajos de teclado… |
| Lock Screen | Pantalla de bloqueo |
| Battery | Batería |
| Energy | Energía |
| Screen Saver | Salvapantallas |
| Login Items | Ítems de inicio |
| Login Items & Extensions | Ítems de inicio y extensiones |
| Brightness | Brillo |
| Automatically adjust brightness | Ajustar brillo automáticamente |
| True Tone | True Tone |
| High Dynamic Range | Alto rango dinámico |
| Preset | Preajuste |
| Night Shift… | Night Shift… |
| Color profile | Perfil de color |
| Refresh rate | Frecuencia de actualización |
| Allow in the Menu Bar | Permitir en la barra de menús |
| Low Power Mode | Modo de bajo consumo |
| Do Not Disturb | No molestar |
| Camera | Cámara |
| Open Anyway | Abrir igualmente |
| Applications | Aplicaciones |
| Reduce motion | Reducir movimiento |
| Reduce transparency | Reducir transparencia |
| Increase contrast | Aumentar contraste |
| Differentiate without color | Diferenciar sin color |
| VoiceOver | VoiceOver |

## Overbright’s own names

| English | es | Note |
|---|---|---|
| Overbright | Overbright | never translated or transliterated |
| Settings panes: General · Displays · Automations · Shortcuts · Fill Light · Advanced · About | General · Pantallas · Automatizaciones · Atajos de teclado · Luz de relleno · Avanzado · Acerca de | the sidebar and window titles |
| Standard (the brightness macOS shows) | Estándar | never “100 %” or “normal mode” |
| extra brightness (the boost half) | “Usar brillo extra” (Use extra brightness) | never “boost”, “HDR mode”, “EDR” |
| Dim below minimum (the setting) | “Activar o desactivar la atenuación por debajo del mínimo” (Dim Below Minimum On or Off) | the incumbent’s name for it is never used |
| Dimmed (the state) · Dim All Displays / Stop Dimming (actions) | Atenuado · Atenuar todas las pantallas / Dejar de atenuar | not “night mode” |
| Brighter · Less Bright (one step) | Más brillo · Menos brillo | never “Dimmer”: it reads like Dim |
| Back to Standard (the instant off) | Volver a Estándar | not “panic”, not “reset brightness” |
| Indoor · Bright room · Sunlight · Max (presets) | Interior · Luz intensa · Luz solar · Máximo | “Max” is a preset only |
| Safe · Peak (ceilings) | Seguro · Pico | Peak, never “Max”, for a ceiling; one short word each (segments) |
| Compatibility mode · Color table (methods) | Modo de compatibilidad · Tabla de colores | never “fallback” or “overlay” |
| Fill Light (the edge light for video calls) | Luz de relleno | never “ring light” |
| extra range (headroom, in user copy) | Margen de brillo | “headroom” only in Advanced and diagnostics |
| Calibrate… · Run Self-Test… · Reset Display Colors… | Calibrar… · Ejecutar autoprueba… · Restablecer colores de pantalla… |  |
| Keep this level? · Go Back · Keep | ¿Mantener este nivel? · Volver · Mantener | the very-dark-level prompt |
| Pause · Paused · Resume | “Pausar Overbright” (Pause Overbright) · En pausa · Reanudar | a temporary stop; never “disabled” |

Fit (WP15): the footer’s default row (Battery, Auto-pause, Timer) must fit its 304 pt in full in every language (`FooterFitTests`), so the Auto-pause chip reads “Autopausa” (off: “Sin autopausa”) and the Timer chip “Sin límite” for No timer.

## Carried from Cranny (generic interface words)

| English | es | Note |
|---|---|---|
| Overbright | Overbright | never translated; masculine; also the open panel ("Abrir Overbright") |
| click | hacer clic / clic | never "pinchar" |
| keyboard shortcut | atajo de teclado (short: atajo) | Apple es: "Atajos de teclado…" |
| Shortcuts (Apple's app) | Atajos | an item of it = atajo; Overbright's own key bindings are "atajos de teclado" to tell them apart |
| Settings | Ajustes | as Apple es ("Ajustes…"); System Settings = Ajustes del Sistema |
| Welcome | bienvenida | window title "Te damos la bienvenida a Overbright" (Apple es formula) |
| Done (button) | Aceptar | macOS es "Done" buttons (≈ 45 system strings; "OK" only in Shortcuts); Welcome's closing button, which VoiceOver also reads as the completed-step word: Hecho |
| App not installed | App no instalada |  |
| Reset to Default | Restablecer valor predeterminado | "Cambiado respecto al valor predeterminado" |
| Preview | Previsualización | never "Vista previa" (= the Preview app "Vista Previa") |
| Space (the space bar in key caps) | Espacio | as AppKit writes it in menu key equivalents (FunctionKeyNames.loctable “Space”), so Settings and Welcome show the same key caps as the menu; AppKit’s name for the physical key is Barra espaciadora |
