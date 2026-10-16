# Overbright — Portuguese (Portugal) (português (Portugal), `pt-PT`) terminology sheet

Carried from Cranny’s sheet for this language (ARCHITECTURE.md §10.2): the register, voice and
typography decisions are language facts and stay; Cranny’s notch, widget and ambient-light rows are
deleted, and examples and notes that named Cranny’s features (the notch, the Tray, widgets, Calendar, Notes,
Media, permissions) were replaced with Overbright’s or dropped. Overbright’s own names, its pane names among them,
were decided in WP15 (ARCHITECTURE.md §10.17, §8.8); the table shows them as the catalogs ship them.
`scripts/l10n/languages.json` has this language’s plural categories and quotation marks.

## Register and typography

European Portuguese only (pt-BR has its own file). Base: Apple's own `pt_PT` macOS 27 wording
(`apple-terms.py pt-PT` plus System Settings, Finder and Clock loctables), never Brazilian forms
(ficheiro, ecrã, câmara, aceder, utilizador, definições, aplicação — not arquivo, tela, câmera, acessar, usuário,
ajustes, app).


### Voice and typography

- Neutral formal address as macOS pt-PT: verbs in the 3rd person without a pronoun ("Clique…", "Arraste…", "Pode…"),
  possessives "o seu / a sua" only when needed ("os seus monitores"); never "tu", never "você" written out.
- **Buttons, menu items, toggles, commands, pickers: infinitive** ("Abrir o Overbright", "Procurar atualizações…",
  "Mostrar o valor"). **Instructions in sentences: imperative** ("Clique no ícone da barra de menus",
  "Prima ⌘"). Footnotes and statuses: present indicative.
- Sentence case everywhere; English title-case menu items become sentence case ("Check for Updates…" →
  "Procurar atualizações…").
- Quotes “…” (secondary ‘…’), as macOS 27 pt-PT writes them (not « »). One-character ellipsis …. Apostrophe ’.
- Hyphens inside words are U+2011 (non-breaking hyphen) as in Apple pt-PT ("ative‑o", "pré‑visualização",
  "Wi‑Fi", "e‑mail"); search keywords keep the plain hyphen-minus so typed queries match.
- Paths: "Definições ▸ Geral" with a no-break space before ▸ (Apple writes "Definições do Sistema > Teclado"
  with U+00A0); path parts are not quoted. Setting names and Overbright's option names in running text are quoted:
  “Reduzir movimento”, “Modo de baixo consumo”.
- Gender: **o Overbright** (masculine, with the article, as Apple writes "Sair do Safari", "Acerca do Safari",
  "Ocultar o Safari"); **o macOS**; **o Mac**; **a aplicação**.
- Errors: "Não foi possível …" (Apple pt-PT). Retry: "Tentar novamente". Loading: "A carregar…" (a + infinitive
  progressive, also "A verificar…").
- Plurals: pt-PT = one / many / other; one = exactly 1; many (millions) always has the same wording as other.
- Pronominal verbs when the thing itself changes state: "a câmara liga‑se / desliga‑se"; statuses say "Começa…", not a bare "Inicia…" (review).
- Picker values agree with the picker's noun (a feminine noun takes "Automática"); a shared generic "Off" stays
  "Desativado" (review).
- Lists: one determiner per noun ("Os monitores, a câmara e os atalhos…") (review).
- Keys in running text as Apple pt-PT names them: tecla Comando (⌘), Opção (⌥), Controlo (⌃), Shift, Escape/Esc,
  Return, Espaço, seta para cima / para baixo. Verb for keys: premir ("Prima ⌘", "Mantenha premida a tecla ⌘").

## Apple names (`apple-terms.py pt-PT` on macOS 27.0.1 — never paraphrased)

| English | pt-PT |
|---|---|
| System Settings | Definições |
| Finder | Finder |
| Shortcuts | Atalhos |
| Photos | Fotografias |
| TV | TV |
| QuickTime Player | QuickTime Player |
| Privacy & Security | Privacidade e segurança |
| Accessibility | Acessibilidade |
| General | Geral |
| Appearance | Apresentação |
| Menu Bar | Barra de menus |
| Control Center | Central de controlo |
| Focus | Concentração |
| Displays | Monitores |
| Keyboard | Teclado |
| Keyboard Shortcuts… | Atalhos de teclado… |
| Lock Screen | Ecrã bloqueado |
| Battery | Bateria |
| Energy | Energia |
| Screen Saver | Proteção de ecrã |
| Login Items | Início de sessão |
| Login Items & Extensions | Início de sessão e extensões |
| Brightness | Brilho |
| Automatically adjust brightness | Ajustar brilho automaticamente |
| True Tone | True Tone |
| High Dynamic Range | Gama dinâmica alta |
| Preset | Predefinição |
| Night Shift… | Night Shift… |
| Color profile | Perfil de cor |
| Refresh rate | Taxa de atualização |
| Allow in the Menu Bar | Permitir na barra de menus |
| Low Power Mode | Modo de baixo consumo |
| Do Not Disturb | Não incomodar |
| Camera | Câmara |
| Open Anyway | Abrir |
| Applications | Aplicações |
| Reduce motion | Reduzir movimento |
| Reduce transparency | Reduzir transparência |
| Increase contrast | Aumentar contraste |
| Differentiate without color | Distinguir sem cor |
| VoiceOver | VoiceOver |

## Overbright’s own names

| English | pt-PT | Note |
|---|---|---|
| Overbright | Overbright | never translated or transliterated |
| Settings panes: General · Displays · Automations · Shortcuts · Fill Light · Advanced · About | Geral · Monitores · Automatização · Atalhos de teclado · Luz de preenchimento · Avançado · Informações | the sidebar and window titles |
| Standard (the brightness macOS shows) | Padrão | never “100 %” or “normal mode” |
| extra brightness (the boost half) | “Usar brilho extra” (Use extra brightness) | never “boost”, “HDR mode”, “EDR” |
| Dim below minimum (the setting) | “Ativar ou desativar escurecimento abaixo do mínimo” (Dim Below Minimum On or Off) | the incumbent’s name for it is never used |
| Dimmed (the state) · Dim All Displays / Stop Dimming (actions) | Escurecido · Escurecer todos os monitores / Parar escurecimento | not “night mode” |
| Brighter · Less Bright (one step) | Mais brilho · Menos brilho | never “Dimmer”: it reads like Dim |
| Back to Standard (the instant off) | Voltar ao padrão | not “panic”, not “reset brightness” |
| Indoor · Bright room · Sunlight · Max (presets) | Interior · Luz forte · Luz solar · Máximo | “Max” is a preset only |
| Safe · Peak (ceilings) | Seguro · Pico | Peak, never “Max”, for a ceiling; one short word each (segments) |
| Compatibility mode · Color table (methods) | Modo de compatibilidade · Tabela de cores | never “fallback” or “overlay” |
| Fill Light (the edge light for video calls) | Luz de preenchimento | never “ring light” |
| extra range (headroom, in user copy) | Margem extra | “headroom” only in Advanced and diagnostics |
| Calibrate… · Run Self-Test… · Reset Display Colors… | Calibrar… · Executar autoteste… · Repor cores dos monitores… |  |
| Keep this level? · Go Back · Keep | Manter este nível? · Restabelecer · Manter | the very-dark-level prompt |
| Pause · Paused · Resume | “Pausar o Overbright” (Pause Overbright) · Em pausa · Retomar | a temporary stop; never “disabled” |

Fit (WP15): the footer’s default row (Battery, Auto-pause, Timer) must fit its 292 pt in full in every language (`FooterFitTests`), so the Auto-pause chip reads “Autopausa” (off: “Sem autopausa”) and the Timer chip “Sem limite” for No timer.

## Carried from Cranny (generic interface words)

| English | pt-PT | Note |
|---|---|---|
| Overbright | Overbright | never translated; masculine with article: "o Overbright", "do Overbright", "no Overbright"; also the open panel ("Abrir o Overbright") |
| click | clicar / clique |  |
| keyboard shortcut | atalho de teclado (short: atalho) |  |
| Shortcuts (Apple's app) | Atalhos | an item of it = atalho; Run = Executar (Apple pt-PT "Executar atalho") |
| Settings | Definições | as Apple pt-PT "Definições…"; always capitalised as the window's name ("Abrir Definições", "Definições ▸ Geral"); System Settings in running text = Definições do Sistema |
| About (Settings pane) | Informações | Apple pt-PT names System Settings ▸ Geral ▸ About "Informações"; the menu item "About Overbright" keeps AppKit's "Acerca do Overbright" (review) |
| Welcome | boas‑vindas | window title "Damos‑lhe as boas‑vindas ao Overbright" (Apple pt-PT formula) |
| Done (button) | OK | Apple pt-PT; Welcome's closing button: Concluído |
| App not installed | Aplicação não instalada |  |
| Reset to Default | Repor predefinição | "Alterado em relação à predefinição"; Reset = Repor |
| Preview | Pré‑visualização |  |
| Back (Welcome) | Anterior | Apple pt-PT |
