# Overbright — Japanese (日本語, `ja`) terminology sheet

Carried from Cranny’s sheet for this language (ARCHITECTURE.md §10.2): the register, voice and
typography decisions are language facts and stay; Cranny’s notch, widget and ambient-light rows are
deleted, and examples and notes that named Cranny’s features (the notch, the Tray, widgets, Calendar, Notes,
Media, permissions) were replaced with Overbright’s or dropped. Overbright’s own names, its pane names among them,
are decided in WP15 (ARCHITECTURE.md §10.17, §8.8); until then they read “—”.
`scripts/l10n/languages.json` has this language’s plural categories and quotation marks.

## Register and typography

Register and typography (follow macOS 27 Japanese):

- Sentences (footnotes, errors, VoiceOver announcements) in polite です／ます; buttons, menu items,
  toggles, pickers and headers are short noun phrases or verb dictionary forms (開く, 追加, 削除, 〜を表示).
- Card descriptions on the Welcome window use ます (メニューバーのアイコンをクリックして開きます).
- VoiceOver hints describe the result in ます form (パネルを開きます).
- No spaces between Japanese and Latin text or digits (Overbrightを開く, 3台, macOS 14.2以降); spaces stay between two
  Latin words or a Latin word and a number (Overbright %@, 名称未設定 %lld as in Finder/TextEdit).
- Quotes “…” (never 「」, the validator rejects them) around names that could be misread: app names in running text
  (“写真”, “ショートカット”), System Settings panes and settings (“プライバシーとセキュリティ”,
  “カラー以外で区別”), user content (“%@”を削除しますか?). No quotes in a button that names the app it opens
  (システム設定を開く, %@を開く) — Apple writes it that way.
- Half-width colon + space (状況: %@), full-width parentheses （ ） around Japanese and placeholders as macOS
  (自動（%@）, バージョン%@（%@）), half-width ? after a question, 、。 punctuation, … (U+2026), 〜 (U+301C) for ranges
  in running text, ▸ with spaces in Settings paths (設定 ▸ 一般).
- Search keyword lists keep the English separator (", " or a space): the code splits on it.
- No grammatical plural: every plural key has the single form `other`; counters 台 (displays), 項目 (items, as
  Finder), 個, 日, 分, ミリ秒.

Reviewed 2026-10-14 (independent review).

## Apple names (`apple-terms.py ja` on macOS 27.0.1 — never paraphrased)

| English | ja |
|---|---|
| System Settings | システム設定 |
| Finder | Finder |
| Shortcuts | ショートカット |
| Photos | 写真 |
| TV | TV |
| QuickTime Player | QuickTime Player |
| Privacy & Security | プライバシーとセキュリティ |
| Accessibility | アクセシビリティ |
| General | 一般 |
| Appearance | 外観 |
| Menu Bar | メニューバー |
| Control Center | コントロールセンター |
| Focus | 集中モード |
| Displays | ディスプレイ |
| Keyboard | キーボード |
| Keyboard Shortcuts… | キーボードショートカット… |
| Lock Screen | ロック画面 |
| Battery | バッテリー |
| Energy | エネルギー |
| Screen Saver | スクリーンセーバ |
| Login Items | ログイン項目 |
| Login Items & Extensions | ログイン項目と機能拡張 |
| Brightness | 輝度 |
| Automatically adjust brightness | 輝度を自動調節 |
| True Tone | True Tone |
| High Dynamic Range | ハイダイナミックレンジ |
| Preset | プリセット |
| Night Shift… | Night Shift… |
| Color profile | カラープロファイル |
| Refresh rate | リフレッシュレート |
| Allow in the Menu Bar | メニューバーに追加することを許可 |
| Low Power Mode | 低電力モード |
| Do Not Disturb | おやすみモード |
| Camera | カメラ |
| Open Anyway | このまま開く |
| Applications | アプリケーション |
| Reduce motion | 視差効果を減らす |
| Reduce transparency | 透明度を下げる |
| Increase contrast | コントラストを上げる |
| Differentiate without color | カラー以外で区別 |
| VoiceOver | VoiceOver |

## Overbright’s own names

| English | ja | Note |
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

| English | ja | Note |
|---|---|---|
| Overbright | Overbright | never translated or transliterated; no space before particles (Overbrightを開く) |
| click | クリック |  |
| Welcome / setup | ようこそ / セットアップ |  |
| Shortcuts (Apple's app) | ショートカット | “ショートカット” in running text |
| keyboard shortcut | キーボードショートカット | so it is not confused with Apple's Shortcuts; short ショートカット only in rows inside Overbright's Shortcuts pane (ショートカットを記録, “%@”のショートカット) |
| Settings (Overbright) | 設定 | Settings… = 設定… |
| Allow / Grant | 許可 | Allow… / Grant… = 許可… |
| Reset to Default | デフォルトに戻す | Changed from the default = デフォルトから変更済み |
| App not installed | インストールされていないアプリ |  |
| Never (timeout 0) | しない |  |
| Try again / Retry | 再試行 |  |
