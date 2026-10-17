# Overbright — Chinese, Simplified (简体中文, `zh-Hans`) terminology sheet

Carried from Cranny’s sheet for this language (ARCHITECTURE.md §10.2): the register, voice and
typography decisions are language facts and stay; Cranny’s notch, widget and ambient-light rows are
deleted, and examples and notes that named Cranny’s features (the notch, the Tray, widgets, Calendar, Notes,
Media, permissions) were replaced with Overbright’s or dropped. Overbright’s own names, its pane names among them,
were decided in WP15 (ARCHITECTURE.md §10.17, §8.8); the table shows them as the catalogs ship them.
`scripts/l10n/languages.json` has this language’s plural categories and quotation marks.

## Register and typography

Register and typography (as macOS 27 writes zh_CN):

- 你, never 您. Buttons and menu items are short verb phrases without 请 (打开、添加、移除); sentences and
  instructions may use 请 sparingly (macOS: “若要节能，请点按‘还原’。”).
- Full-width punctuation ，。：；？！（）; quotes “…” (secondary ‘…’); one-character ellipsis …; no exclamation marks.
- No spaces between Chinese and Latin letters, numbers or placeholders: 打开Overbright、%lld台显示器、版本%@、App管理.
- Apple's names come from the apple-terms glossary and are quoted in running text the way macOS does it:
  “系统设置”>“键盘” → Overbright keeps its ▸: “设置”▸“通用”, “隐私与安全”▸“无障碍”.
- click = 点按, double-click = 连按两次, drag = 拖移/拖到, swipe = 轻扫, hover = 悬停, pointer = 指针 (Apple's verbs).
- Copy (to the pasteboard) = 拷贝 (macOS Edit ▸ 拷贝); 复制 is Duplicate and is not used.
- No plural: the single category other holds every count; counters take a measure word (%lld个项目, %lld台显示器, %lld天).

Reviewed by an independent review pass; the rows above include its changes.

## Apple names (`apple-terms.py zh-Hans` on macOS 27.0.1 — never paraphrased)

| English | zh-Hans |
|---|---|
| System Settings | 系统设置 |
| Finder | 访达 |
| Shortcuts | 快捷指令 |
| Photos | 照片 |
| TV | TV |
| QuickTime Player | QuickTime Player |
| Privacy & Security | 隐私与安全 |
| Accessibility | 无障碍 |
| General | 通用 |
| Appearance | 外观 |
| Menu Bar | 菜单栏 |
| Control Center | 控制中心 |
| Focus | 专注模式 |
| Displays | 显示器 |
| Keyboard | 键盘 |
| Keyboard Shortcuts… | 键盘快捷键… |
| Lock Screen | 锁屏 |
| Battery | 电池 |
| Energy | 能耗 |
| Screen Saver | 屏幕保护程序 |
| Login Items | 登录项 |
| Login Items & Extensions | 登录项与扩展 |
| Brightness | 亮度 |
| Automatically adjust brightness | 自动调节亮度 |
| True Tone | 原彩显示 |
| High Dynamic Range | 高动态范围 |
| Preset | 预置 |
| Night Shift… | 夜览… |
| Color profile | 颜色描述文件 |
| Refresh rate | 刷新率 |
| Allow in the Menu Bar | 允许在菜单栏显示 |
| Low Power Mode | 低电量模式 |
| Do Not Disturb | 勿扰模式 |
| Camera | 摄像头 |
| Open Anyway | 仍要打开 |
| Applications | 应用程序 |
| Reduce motion | 减弱动态效果 |
| Reduce transparency | 降低透明度 |
| Increase contrast | 增强对比度 |
| Differentiate without color | 无需用颜色区分 |
| VoiceOver | 旁白 |

## Overbright’s own names

| English | zh-Hans | Note |
|---|---|---|
| Overbright | Overbright | never translated or transliterated |
| Settings panes: General · Displays · Automations · Shortcuts · Fill Light · Advanced · About | 通用 · 显示器 · 自动化 · 快捷键 · 补光 · 高级 · 关于 | the sidebar and window titles |
| Standard (the brightness macOS shows) | 标准 | never “100 %” or “normal mode” |
| extra brightness (the boost half) | “使用额外亮度” (Use extra brightness) | never “boost”, “HDR mode”, “EDR” |
| Dim below minimum (the setting) | “开启或关闭调暗至最低亮度以下” (Dim Below Minimum On or Off) | the incumbent’s name for it is never used |
| Dimmed (the state) · Dim All Displays / Stop Dimming (actions) | 已调暗 · 调暗所有显示器 / 停止调暗 | not “night mode” |
| Brighter · Less Bright (one step) | 提高亮度 · 降低亮度 | never “Dimmer”: it reads like Dim |
| Back to Standard (the instant off) | 恢复标准 | not “panic”, not “reset brightness” |
| Indoor · Bright room · Sunlight · Max (presets) | 室内 · 明亮房间 · 阳光 · 最大 | “Max” is a preset only |
| Safe · Peak (ceilings) | 安全 · 峰值 | Peak, never “Max”, for a ceiling; one short word each (segments) |
| Compatibility mode · Color table (methods) | 兼容模式 · 颜色表 | never “fallback” or “overlay” |
| Fill Light (the edge light for video calls) | 补光 | never “ring light” |
| extra range (headroom, in user copy) | 亮度余量 | “headroom” only in Advanced and diagnostics |
| Calibrate… · Run Self-Test… · Reset Display Colors… | 校准… · 运行自检… · 重置显示器颜色… |  |
| Keep this level? · Go Back · Keep | 保持此级别？ · 还原 · 保持 | the very-dark-level prompt |
| Pause · Paused · Resume | “暂停Overbright” (Pause Overbright) · 已暂停 · 继续 | a temporary stop; never “disabled” |

## Carried from Cranny (generic interface words)

| English | zh-Hans | Note |
|---|---|---|
| Overbright | Overbright | never translated or transliterated; also the open panel (“打开Overbright”, “退出Overbright”) |
| Settings | 设置 |  |
| Allow… / Grant… | 允许… |  |
| Reset to Default | 恢复默认值 |  |
| Changed from the default | 与默认值不同 | VoiceOver hint and tooltip of the dot (the translation always used this; the sheet said 已更改（非默认值）) |
| Preview | 预览 |  |
| welcome / setup | 欢迎 / 设置向导 |  |
| Never (timeout 0) | 永不 |  |
| Off | 关闭 | Apple: 关闭 |
| keyboard shortcut | 快捷键 |  |
| shortcut (Shortcuts app item) / Shortcuts (app) | 快捷指令 / “快捷指令” | Apple's names |
| Remove (from a list) | 移除 | 删除 only for really deleting |
| App not installed | App未安装 | never the bundle ID |
| Symbol | 符号 |  |
| Login Items | 登录项 | Apple |
| Undo | 撤销 | Apple |
| Try again / Retry | 重试 | Apple |
| Space (the space bar in key caps) | 空格键 | as AppKit writes it in menu key equivalents (FunctionKeyNames.loctable “Space”), so Settings and Welcome show the same key caps as the menu; AppKit’s name for the physical key is 空格键 |
