# Overbright — Arabic (العربية, `ar`) terminology sheet

Carried from Cranny’s sheet for this language (ARCHITECTURE.md §10.2): the register, voice and
typography decisions are language facts and stay; Cranny’s notch, widget and ambient-light rows are
deleted, and examples and notes that named Cranny’s features (the notch, the Tray, widgets, Calendar, Notes,
Media, permissions) were replaced with Overbright’s or dropped. Overbright’s own names, its pane names among them,
are decided in WP15 (ARCHITECTURE.md §10.17, §8.8); until then they read “—”.
`scripts/l10n/languages.json` has this language’s plural categories and quotation marks.

## Register and typography

Register and style, following macOS 27 Arabic:

- Buttons, menu items, toggles and commands use the verbal noun (masdar), as Apple does: فتح، إغلاق، إظهار، إنهاء Overbright، التحقق من وجود تحديثات…، إعادة التعيين.
- Sentences that tell the user what to do use the masculine imperative, as Apple does: انقر، اسحب، افتح، حاول مرة أخرى.
- Prefer verb-first sentences (يعرض Overbright…، لا يسجّل Overbright…). This is natural Arabic and keeps paragraphs that start with a Latin name out of LTR.
- Punctuation: Arabic comma ، semicolon ؛ question mark ؟; one-character ellipsis …; names of apps and settings in straight double quotes "…" as macOS 27 writes them (تطبيق "الاختصارات"، "تقليل الحركة").
- Breadcrumb paths: English ▸ becomes ◂, which points the way an RTL reader reads (الخصوصية والأمن ◂ تسهيلات الاستخدام). This is Apple's own mapping: the Arabic loctables translate "▸" as "◂" and "START ▸ END" as "البداية ◂ النهاية".
- Never digits in a translation. Numbers come from placeholders, and English literals are written as words (لمدة ساعة، خلال عشر ثوانٍ). Exceptions: key names and versions (macOS 14.2).
- Plurals have six forms. zero and one/two drop the number where Arabic does (عنصر واحد، عنصران). Then the other placeholders are positional.

## Apple names (`apple-terms.py ar` on macOS 27.0.1 — never paraphrased)

| English | ar |
|---|---|
| System Settings | إعدادات النظام |
| Finder | فايندر |
| Shortcuts | الاختصارات |
| Photos | الصور |
| TV | التلفزيون |
| QuickTime Player | QuickTime Player |
| Privacy & Security | الخصوصية والأمن |
| Accessibility | تسهيلات الاستخدام |
| General | عام |
| Appearance | المظهر |
| Menu Bar | شريط القوائم |
| Control Center | مركز التحكم |
| Focus | التركيز |
| Displays | شاشات العرض |
| Keyboard | لوحة المفاتيح |
| Keyboard Shortcuts… | اختصارات لوحة المفاتيح… |
| Lock Screen | قفل الشاشة |
| Battery | البطارية |
| Energy | الطاقة |
| Screen Saver | شاشة التوقف |
| Login Items | عناصر تسجيل الدخول |
| Login Items & Extensions | عناصر الدخول والملحقات |
| Brightness | الإضاءة |
| Automatically adjust brightness | ضبط الإضاءة تلقائيًا |
| True Tone | انسجام اللون |
| High Dynamic Range | نطاق ديناميكي عالٍ |
| Preset | إعداد مسبق |
| Night Shift… | الإضاءة الدافئة… |
| Color profile | ملف تعريف اللون |
| Refresh rate | معدل التحديث |
| Allow in the Menu Bar | السماح في شريط القوائم |
| Low Power Mode | نمط الطاقة المنخفضة |
| Do Not Disturb | عدم الإزعاج |
| Camera | الكاميرا |
| Open Anyway | فتح على أية حال |
| Applications | التطبيقات |
| Reduce motion | تقليل الحركة |
| Reduce transparency | تقليل الشفافية |
| Increase contrast | زيادة التباين |
| Differentiate without color | التمييز بدون لون |
| VoiceOver | التعليق الصوتي |

## Overbright’s own names

| English | ar | Note |
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

| English | ar | Note |
|---|---|---|
| Overbright | Overbright | never translated or transliterated; masculine (التطبيق): «يعرض Overbright» |
| shortcut (Shortcuts app) | اختصار / اختصارات | the app is "الاختصارات" in quotes when it means the app |
| keyboard shortcut | اختصار لوحة المفاتيح / مفاتيح الاختصار | the bindings in Overbright's Shortcuts pane |
| Settings | الإعدادات |  |
| Allow… / Grant… | السماح… | Apple's «السماح» |
| Reset to Default | إعادة التعيين إلى الافتراضي | Apple |
| Changed from the default | تم تغييره عن القيمة الافتراضية |  |
| Preview | معاينة |  |
| click | انقر / النقر |  |
| Show … (switches) | إظهار … |  |
| Remove (from a list) | إزالة | «حذف» only for a real deletion |
| App not installed | التطبيق غير مثبّت |  |
| Never (a timeout of 0) | مطلقًا | Apple |
| Off / On (values) | إيقاف / تشغيل; VoiceOver states متوقف / مشغّل |  |
