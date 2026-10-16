# Overbright — Portuguese (Portugal) (português (Portugal), `pt-PT`) terminology sheet

Carried from Cranny’s sheet for this language (ARCHITECTURE.md §10.2): the register, voice and
typography decisions are language facts and stay; Cranny’s notch, widget and ambient-light rows are
deleted. Overbright’s own names are decided in WP15 (ARCHITECTURE.md §10.17, §8.8); until then they
read “—”. `scripts/l10n/languages.json` has this language’s plural categories and quotation marks.

## Register and typography

European Portuguese only (pt-BR has its own file). Base: Apple's own `pt_PT` macOS 27 wording
(`apple-terms.py pt-PT` plus System Settings, Finder, Clock, Music and FaceTime loctables), never Brazilian forms
(ficheiro, ecrã, câmara, aceder, utilizador, definições, aplicação — not arquivo, tela, câmera, acessar, usuário,
ajustes, app).


### Voice and typography

- Neutral formal address as macOS pt-PT: verbs in the 3rd person without a pronoun ("Clique…", "Arraste…", "Pode…"),
  possessives "o seu / a sua" only when needed ("os seus eventos"); never "tu", never "você" written out.
- **Buttons, menu items, toggles, commands, pickers: infinitive** ("Abrir o Overbright", "Procurar atualizações…",
  "Mostrar o valor"). **Instructions in sentences and coach marks: imperative** ("Clique no entalhe", "Prima ⌘",
  "Pouse o cursor aqui"). Footnotes and statuses: present indicative.
- Sentence case everywhere; English title-case menu items become sentence case ("Check for Updates…" →
  "Procurar atualizações…").
- Quotes “…” (secondary ‘…’), as macOS 27 pt-PT writes them (not « »). One-character ellipsis …. Apostrophe ’.
- Hyphens inside words are U+2011 (non-breaking hyphen) as in Apple pt-PT ("ative‑o", "pré‑visualização",
  "Wi‑Fi", "e‑mail"); search keywords keep the plain hyphen-minus so typed queries match.
- Paths: "Definições ▸ Permissões" with a no-break space before ▸ (Apple writes "Definições do Sistema > Teclado"
  with U+00A0); path parts are not quoted. Setting names and Overbright's mode names in running text are quoted:
  “Reduzir movimento”, “Ao vivo”, “Entrar”.
- Gender: **o Overbright** (masculine, with the article, as Apple writes "Sair do Safari", "Acerca do Safari",
  "Ocultar o Safari"); **o macOS**; **o Mac**; **a aplicação**; **o widget**.
- Errors: "Não foi possível …" (Apple pt-PT). Retry: "Tentar novamente". Loading: "A carregar…" (a + infinitive
  progressive, also "A verificar…", "A reproduzir").
- Plurals: pt-PT = one / many / other; one = exactly 1; many (millions) always has the same wording as other.
- Pronominal verbs when the thing itself changes state: "a câmara liga‑se / desliga‑se", "as formas desvanecem‑se",
  "o puxador desaparece"; statuses say "Começa…", not a bare "Inicia…" (review).
- Picker values agree with the picker's noun: Linguagem ▸ "Automática"; Câmara ▸ "Automática"; Densidade ▸
  "Compacta / Espaçosa"; a shared generic "Off" stays "Desativado" (review).
- Lists: one determiner per noun ("A sua música, o calendário, os ficheiros e os atalhos…") (review).
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

| English | pt-PT | Note |
|---|---|---|
| Overbright | Overbright | never translated; masculine with article: "o Overbright", "do Overbright", "no Overbright"; also the open panel ("Abrir o Overbright") |
| click | clicar / clique |  |
| keyboard shortcut | atalho de teclado (short: atalho) |  |
| Shortcuts (Apple's app) | Atalhos | an item of it = atalho; pane "Atalhos"; Run = Executar (Apple pt-PT "Executar atalho") |
| Settings | Definições | as Apple pt-PT "Definições…"; always capitalised as the window's name ("Abrir Definições", "Definições ▸ Teclado"); System Settings in running text = Definições do Sistema |
| About (Settings pane) | Informações | Apple pt-PT names System Settings ▸ Geral ▸ About "Informações"; the menu item "About Overbright" keeps AppKit's "Acerca do Overbright" (review) |
| Welcome | boas‑vindas | window title "Damos‑lhe as boas‑vindas ao Overbright" (Apple pt-PT formula) |
| Done (button) | OK | Apple pt-PT; flash word: Concluído; Timer done (≤ 6): Fim; To-dos all done: Tudo feito |
| App not installed | Aplicação não instalada |  |
| Reset to Default | Repor predefinição | "Alterado em relação à predefinição"; Reset = Repor |
| Preview (Settings stage) | Pré‑visualização |  |
| Back (Welcome) | Anterior | Apple pt-PT |
