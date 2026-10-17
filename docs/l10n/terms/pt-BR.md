# Overbright — Portuguese (Brazil) (português (Brasil), `pt-BR`) terminology sheet

Carried from Cranny’s sheet for this language (ARCHITECTURE.md §10.2): the register, voice and
typography decisions are language facts and stay; Cranny’s notch, widget and ambient-light rows are
deleted, and examples and notes that named Cranny’s features (the notch, the Tray, widgets, Calendar, Notes,
Media, permissions) were replaced with Overbright’s or dropped. Overbright’s own names, its pane names among them,
were decided in WP15 (ARCHITECTURE.md §10.17, §8.8); the table shows them as the catalogs ship them.
`scripts/l10n/languages.json` has this language’s plural categories and quotation marks.

## Register and typography

Base: Apple's own Brazilian macOS wording (`apple-terms.py pt-BR`, AppKit/Finder/System Settings/Clock loctables
read on this Mac). Brazilian vocabulary only: arquivo, tela, câmera, app, apagar, Ajustes do Sistema.


### Voice and typography

- **você**, as macOS ("suas telas", "Clique…", "Arraste…"). Instructions to the user: imperative with você
  forms (Clique, Arraste, Pressione, Mantenha pressionada).
- **Buttons, menu items, toggles, commands: infinitive** ("Abrir o Overbright", "Mostrar valor", "Buscar Atualizações…").
- **Capitalization:** where English uses title case for standard macOS chrome (menu bar menu, AppKit-style buttons
  such as "Check for Updates…", "Reset to Default", "Move to Applications"), follow Apple pt-BR title case: nouns,
  verbs and adjectives capitalized, articles/prepositions lower case ("Buscar Atualizações…", "Mover para
  Aplicativos", "Redefinir para o Padrão"). Everything else is sentence case, like the English source.
- Quotes “…” (secondary ‘…’), apostrophe ’, one-character ellipsis …. Apple names of settings and panes in running
  text are written as macOS writes them, without quotes ("em Privacidade e Segurança ▸ Acessibilidade"); Apple app
  names that are also common words get "app" in front instead of quotes ("os apps Fotos e Atalhos").
  User content (display names, app names passed as arguments) in “%@” where Apple quotes them.
- Errors: "Não foi possível…" (Apple pt-BR). Units: "min", "h", "ms", "px", "pt"; numbers/durations arrive formatted
  (pt-BR durations are "4min", "1h 30min").
- Gender: **o Overbright** (masculine, like "o app"); **o macOS**; **o app / os apps**; **o Mac**.
  Commands with the brand (menu items, buttons, shortcut names) have no article, as Apple pt-BR
  ("Encerrar Safari" → "Encerrar Overbright", "Abrir Overbright"); running text and row labels take
  it ("o Overbright mostra…", "Sobre o Overbright", row label "Abrir o Overbright").
- Confirmation messages and footnotes about what an action will do use the **future** ("Todos os ajustes do Overbright
  voltarão ao padrão", "Cada tela voltará ao seu perfil de cor").
- Key combinations as Apple pt-BR writes them, with " + ": "Option + 1", "Command + Seta para Cima"; key names
  Option, Command, Shift, Return, Esc, Delete, Espaço (Spotlight pane), "Mantenha Option pressionada".
- Plurals: pt = one / many / other. **one covers 0 and 1** (Apple pt-BR also writes the singular there:
  "%d item"); **many** (millions) always has the same wording as other. The singular for 0 is the normative
  Brazilian rule (numbers below 2 take the singular: "zero hora", "zero grau"), so "0 dia" / "0 tela" are
  correct and stay; no key is reworded to dodge it.

## Apple names (`apple-terms.py pt-BR` on macOS 27.0.1 — never paraphrased)

| English | pt-BR |
|---|---|
| System Settings | Ajustes |
| Finder | Finder |
| Shortcuts | Atalhos |
| Photos | Fotos |
| TV | TV |
| QuickTime Player | QuickTime Player |
| Privacy & Security | Privacidade e Segurança |
| Accessibility | Acessibilidade |
| General | Geral |
| Appearance | Aparência |
| Menu Bar | Barra de Menus |
| Control Center | Central de Controle |
| Focus | Foco |
| Displays | Telas |
| Keyboard | Teclado |
| Keyboard Shortcuts… | Atalhos de Teclado… |
| Lock Screen | Tela Bloqueada |
| Battery | Bateria |
| Energy | Energia |
| Screen Saver | Protetor de Tela |
| Login Items | Itens de Início |
| Login Items & Extensions | Itens de Início de Sessão e Extensões |
| Brightness | Brilho |
| Automatically adjust brightness | Ajustar brilho automaticamente |
| True Tone | True Tone |
| High Dynamic Range | Grande Alcance Dinâmico |
| Preset | Pré-ajuste |
| Night Shift… | Night Shift… |
| Color profile | Perfil de cores |
| Refresh rate | Taxa de atualização |
| Allow in the Menu Bar | Permitir na Barra de Menus |
| Low Power Mode | Modo Pouca Energia |
| Do Not Disturb | Não Perturbe |
| Camera | Câmera |
| Open Anyway | Abrir Mesmo Assim |
| Applications | Aplicativos |
| Reduce motion | Reduzir movimento |
| Reduce transparency | Reduzir transparência |
| Increase contrast | Aumentar contraste |
| Differentiate without color | Diferenciar sem cor |
| VoiceOver | VoiceOver |

## Overbright’s own names

| English | pt-BR | Note |
|---|---|---|
| Overbright | Overbright | never translated or transliterated |
| Settings panes: General · Displays · Automations · Shortcuts · Fill Light · Advanced · About | Geral · Telas · Automações · Atalhos de teclado · Luz de Preenchimento · Avançado · Sobre | the sidebar and window titles |
| Standard (the brightness macOS shows) | Padrão | never “100 %” or “normal mode” |
| extra brightness (the boost half) | “Usar brilho extra” (Use extra brightness) | never “boost”, “HDR mode”, “EDR” |
| Dim below minimum (the setting) | “Ativar ou Desativar Escurecimento Abaixo do Mínimo” (Dim Below Minimum On or Off) | the incumbent’s name for it is never used |
| Dimmed (the state) · Dim All Displays / Stop Dimming (actions) | Escurecido · Escurecer Todas as Telas / Parar de Escurecer | not “night mode” |
| Brighter · Less Bright (one step) | Mais Brilho · Menos Brilho | never “Dimmer”: it reads like Dim |
| Back to Standard (the instant off) | Voltar ao Padrão | not “panic”, not “reset brightness” |
| Indoor · Bright room · Sunlight · Max (presets) | Ambiente interno · Luz intensa · Luz do sol · Máximo | “Max” is a preset only |
| Safe · Peak (ceilings) | Seguro · Pico | Peak, never “Max”, for a ceiling; one short word each (segments) |
| Compatibility mode · Color table (methods) | Modo de Compatibilidade · Tabela de cores | never “fallback” or “overlay” |
| Fill Light (the edge light for video calls) | Luz de Preenchimento | never “ring light” |
| extra range (headroom, in user copy) | Margem de brilho | “headroom” only in Advanced and diagnostics |
| Calibrate… · Run Self-Test… · Reset Display Colors… | Calibrar… · Executar Autoteste… · Redefinir Cores da Tela… |  |
| Keep this level? · Go Back · Keep | Manter este nível? · Voltar · Manter | the very-dark-level prompt |
| Pause · Paused · Resume | “Pausar Overbright” (Pause Overbright) · Pausado · Retomar | a temporary stop; never “disabled” |

Fit (WP15): the footer’s default row (Battery, Auto-pause, Timer) must fit its 304 pt in full in every language (`FooterFitTests`), so the Auto-pause chip reads “Autopausa” (off: “Sem autopausa”) and, measured with its glyphs (WP14), the Battery chip “Menos de 20 %” for Below 20 %.

## Carried from Cranny (generic interface words)

| English | pt-BR | Note |
|---|---|---|
| Overbright | Overbright | never translated; masculine ("o Overbright"); also the open panel ("Abrir Overbright") |
| click | clicar / clique | Apple pt-BR |
| keyboard shortcut | atalho de teclado (short: atalho) | Apple: "Atalhos de Teclado…"; the key bindings in Overbright's Shortcuts pane |
| Shortcuts (Apple's app) | Atalhos | an item of it = atalho |
| Welcome | boas-vindas | window title "Boas-vindas ao Overbright" (Apple's current neutral form) |
| Done (button) | OK | Apple pt-BR; Welcome's closing button (also VoiceOver's word for a finished step) = Concluído |
| App not installed | App não instalado |  |
| Reset to Default | Redefinir para o Padrão | "Alterado em relação ao padrão"; Reset = Redefinir |
| Preview | Pré-visualização | the Preview app is "Pré-Visualização" |
| Undo / Cancel | Desfazer / Cancelar |  |
| Space (the space bar in key caps) | Espaço | as AppKit writes it in menu key equivalents (FunctionKeyNames.loctable “Space”), so Settings and Welcome show the same key caps as the menu; AppKit’s name for the physical key is Barra de espaço |
