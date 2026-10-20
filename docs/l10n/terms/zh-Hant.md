# Overbright — Chinese, Traditional (繁體中文, `zh-Hant`) terminology sheet

Carried from Cranny’s sheet for this language (ARCHITECTURE.md §10.2): the register, voice and
typography decisions are language facts and stay; Cranny’s notch, widget and ambient-light rows are
deleted, and examples and notes that named Cranny’s features (the notch, the Tray, widgets, Calendar, Notes,
Media, permissions) were replaced with Overbright’s or dropped. Overbright’s own names, its pane names among them,
were decided in WP15 (ARCHITECTURE.md §10.17, §8.8); the table shows them as the catalogs ship them.
`scripts/l10n/languages.json` has this language’s plural categories and quotation marks.

## Register and typography

Register and typography (follow macOS 27 Traditional Chinese, Taiwan vocabulary; zh-HK falls back here):

- Address the user as 你 (never 您), as macOS does. Sentences (footnotes, errors, VoiceOver
  announcements) end in 。; buttons, menu items, toggles, pickers and headers are short verb or noun phrases without
  final punctuation (打開, 重置, 顯示選單列圖像).
- Apple's verbs: Open 打開 · Close 關閉 · Quit 結束 · Add 加入 · New 新增 · Remove 移除 · Delete 刪除 · Copy 拷貝
  (Duplicate = 複製) · Undo 還原 · Show/Hide 顯示/隱藏 · Turn on/off 開啟/關閉 · Click 按一下 · Double-click 按兩下 ·
  Drag 拖移 · Try again 再試一次 · Skip 略過 · Continue 繼續 · Cancel 取消 · Done 完成 · Rename 重新命名.
- Questions as Apple does: 要重置顯示器顏色嗎？ · 要重置所有設定嗎？
- No spaces between Chinese and Latin text, digits or placeholders (打開Overbright, %lld個項目, macOS 14.2或以上版本);
  Latin words keep their own spaces (Liquid Glass, True Tone, Night Shift).
- Quotes 「…」 (secondary 『…』) around app names, System Settings panes and settings in running text and in buttons that
  name them, exactly as macOS: 打開「系統設定」, 在「捷徑」中, 「隱私權與安全性」▸「輔助使用」, 打開「%@」. Overbright's own name
  is never quoted (關於Overbright, 結束Overbright). User content (a display's name) in 「%@」.
- Full-width punctuation ，。：；？！（）; full-width colon with no space (狀態：%@); full-width parentheses around
  Chinese or placeholders (自動（%@）, 版本%1$@（%2$@）). Separator " · " and arrows/keys (⌘, ⌥←) kept as in English;
  ▸ between Settings path parts without spaces (「設定」▸「一般」).
- Ellipsis: macOS zh_TW writes the midline ellipsis ⋯ (U+22EF) in every menu item and progress text (設定⋯, 載入中⋯,
  886 of 886 system strings that end in "…" in English). Overbright follows macOS: ⋯, never "..." and not U+2026.
  Review decision: keep ⋯, so Overbright's 設定⋯ / 檢查更新項目⋯ match the system menus beside them; the generic U+2026
  note in languages.json is the template line shared by every language (the validator accepts both).
- Instructions: Apple's zh_TW writes "verb + 來 + purpose" (按一下來評分此遊戲, 拖移來變更縮放, 用三指點兩下並拖移來…), and
  Overbright's instructions follow that pattern; don't "correct" them to 以.
- Literary particles (之, 其 in place of 它的) are avoided in short UI copy; plain modern phrasing as macOS.
- Search keyword lists keep the ASCII separator of the English key (", " or a space): the code splits on it. They may add
  the English word as an extra synonym (HDR, XDR, HUD).
- No grammatical plural: every plural key has the single form `other`; counters 個 (items, apps), 台 (displays), 天,
  分鐘, 毫秒. Units as macOS: %@點 (pt), %@像素 (px), %lld毫秒 (ms).
- Width: CJK glyphs are ≈ 1 em wide, so constrained strings (chips, the readout, the HUD) are measured, never
  counted.

## Apple names (`apple-terms.py zh-Hant` on macOS 27.0.1 — never paraphrased)

| English | zh-Hant |
|---|---|
| System Settings | 系統設定 |
| Finder | Finder |
| Shortcuts | 捷徑 |
| Photos | 照片 |
| TV | TV |
| QuickTime Player | QuickTime Player |
| Privacy & Security | 隱私權與安全性 |
| Accessibility | 輔助使用 |
| General | 一般 |
| Appearance | 外觀 |
| Menu Bar | 選單列 |
| Control Center | 控制中心 |
| Focus | 專注模式 |
| Displays | 顯示器 |
| Keyboard | 鍵盤 |
| Keyboard Shortcuts… | 鍵盤快速鍵⋯ |
| Lock Screen | 鎖定畫面 |
| Battery | 電池 |
| Energy | 電量 |
| Screen Saver | 螢幕保護程式 |
| Login Items | 登入項目 |
| Login Items & Extensions | 登入項目與延伸功能 |
| Brightness | 亮度 |
| Automatically adjust brightness | 自動調整亮度 |
| True Tone | 原彩 |
| High Dynamic Range | 高動態範圍 |
| Preset | 預設組 |
| Night Shift… | 夜覽⋯ |
| Color profile | 色彩描述 |
| Refresh rate | 更新頻率 |
| Allow in the Menu Bar | 在選單列中允許 |
| Low Power Mode | 低耗電模式 |
| Do Not Disturb | 勿擾模式 |
| Camera | 相機 |
| Open Anyway | 強制打開 |
| Applications | 應用程式 |
| Reduce motion | 減少動態效果 |
| Reduce transparency | 減少透明度 |
| Increase contrast | 增加對比 |
| Differentiate without color | 不以顏色來區分 |
| VoiceOver | 旁白 |

## Overbright’s own names

| English | zh-Hant | Note |
|---|---|---|
| Overbright | Overbright | never translated or transliterated |
| Settings panes: General · Displays · Automations · Shortcuts · Fill Light · Advanced · About | 一般 · 顯示器 · 自動化 · 快速鍵 · 補光 · 進階 · 關於 | the sidebar and window titles |
| Standard (the brightness macOS shows) | 標準 | never “100 %” or “normal mode” |
| extra brightness (the boost half) | “使用額外亮度” (Use extra brightness) | never “boost”, “HDR mode”, “EDR” |
| Dim below minimum (the setting) | “開啟或關閉調暗至最低亮度以下” (Dim Below Minimum On or Off) | the incumbent’s name for it is never used |
| Dimmed (the state) · Dim All Displays / Stop Dimming (actions) | 已調暗 · 調暗所有顯示器 / 停止調暗 | not “night mode” |
| Brighter · Less Bright (one step) | 更亮 · 更暗 | never “Dimmer”: it reads like Dim |
| Back to Standard (the instant off) | 回到標準 | not “panic”, not “reset brightness” |
| Indoor · Bright room · Sunlight · Max (presets) | 室內 · 明亮房間 · 陽光 · 最大 | “Max” is a preset only |
| Safe · Peak (ceilings) | 安全 · 峰值 | Peak, never “Max”, for a ceiling; one short word each (segments) |
| color table (in sentences: “macOS ignores color table changes”) | 色彩表 | never “gamma”; no “fallback” or “overlay” in copy |
| Fill Light (the edge light for video calls) | 補光 | never “ring light” |
| extra range (headroom, in user copy) | 亮度餘裕 | “headroom” only in Advanced and diagnostics |
| Calibrate… · Run Self-Test… · Reset Display Colors… | 校正⋯ · 執行自我測試⋯ · 重置顯示器顏色⋯ |  |
| Keep this level? · Go Back · Keep | 要保留此等級嗎？ · 返回 · 保留 | the very-dark-level prompt |
| Pause · Paused · Resume | “暫停Overbright” (Pause Overbright) · 已暫停 · 繼續 | a temporary stop; never “disabled” |

## Carried from Cranny (generic interface words)

| English | zh-Hant | Note |
|---|---|---|
| Overbright | Overbright | never translated or transliterated; no space around it (打開Overbright) |
| click | 按一下 | 按一下選單列圖像 |
| Welcome / setup | 歡迎使用 / 設定 | 略過設定 |
| Shortcuts (Apple's app) | 捷徑 | 「捷徑」 in running text and buttons |
| keyboard shortcut | 快速鍵 | Apple's 快速鍵 |
| Settings (Overbright) | 設定 | Settings… = 設定⋯ |
| Allow / Grant | 允許 | Allow… / Grant… = 允許⋯ |
| Reset to Default | 重置為預設值 | Changed from the default = 與預設值不同 |
| App not installed | App未安裝 |  |
| Never (timeout 0) | 永不 |  |
| Try again / Retry | 再試一次 |  |
| Space (the space bar in key caps) | 空白鍵 | as AppKit writes it in menu key equivalents (FunctionKeyNames.loctable “Space”), so Settings and Welcome show the same key caps as the menu; AppKit’s name for the physical key is 空白鍵 |
