# Overbright — Ukrainian (українська, `uk`) terminology sheet

Carried from Cranny’s sheet for this language (ARCHITECTURE.md §10.2): the register, voice and
typography decisions are language facts and stay; Cranny’s notch, widget and ambient-light rows are
deleted, and examples and notes that named Cranny’s features (the notch, the Tray, widgets, Calendar, Notes,
Media, permissions) were replaced with Overbright’s or dropped. Overbright’s own names, its pane names among them,
are decided in WP15 (ARCHITECTURE.md §10.17, §8.8); until then they read “—”.
`scripts/l10n/languages.json` has this language’s plural categories and quotation marks.

## Register and typography

Register and style, as macOS writes Ukrainian (checked against this Mac's AppKit, Finder, Control Center,
System Settings and Shortcuts loctables):

- Formal **ви**, lowercase (ваш, ваші дисплеї).
- **Commands** (buttons, menu items, VoiceOver actions): perfective infinitive, as Apple —
  Відкрити, Скасувати, Вилучити, Скопіювати, Призупинити.
- **Settings switches and persistent options**: imperfective infinitive — Показувати…, Приховувати…,
  Відкривати під час входу в систему (Apple: “Open at Login”).
- **Instructions in sentences**: imperative, ви-form — Клацніть, Перетягніть, Спробуйте ще раз, Утримуйте ⌘.
- **Statuses**: impersonal passive — Призупинено, Скопійовано, Не збережено.
- Sentence case. Apple buttons: Скасувати (Cancel), Готово (Done), Продовжити, Назад, Пропустити, Зберегти,
  Видалити (Delete), Вилучити (Remove), Відмінити (Undo), Скинути (Reset), Вибрати… (Choose…), Пізніше.
- Typography: quotes «…» (secondary „…“); apostrophe **ʼ (U+02BC)** as macOS (обʼєкт, памʼять, зʼєднано);
  one-character ellipsis …; spaced en dash – or em dash — as in the source; ▸ for paths.
- Names are not declined: a free name or app name goes in « » after a noun that takes the case
  (програма «Фотографії», дисплей «%@»), as Apple does (“Програма «%@» зможе…”).
- **Overbright** is never translated or declined; sentences are turned so it stays in the nominative or after a
  noun/preposition that leaves it unchanged (Відкрити Overbright, у Overbright, для Overbright, Overbright не бачить…).
  Verbs agree with Overbright as masculine (Overbright закрився), as in the Russian reference.
- **macOS** is feminine (macOS не додала…), as “система”.

## Apple names (`apple-terms.py uk` on macOS 27.0.1 — never paraphrased)

| English | uk |
|---|---|
| System Settings | Системні параметри |
| Finder | Finder |
| Shortcuts | Команди |
| Photos | Фотографії |
| TV | TV |
| QuickTime Player | QuickTime Player |
| Privacy & Security | Приватність і безпека |
| Accessibility | Доступність |
| General | Загальні |
| Appearance | Вигляд |
| Menu Bar | Смуга меню |
| Control Center | Центр керування |
| Focus | Зосередження |
| Displays | Дисплеї |
| Keyboard | Клавіатура |
| Keyboard Shortcuts… | Клавіатурні скорочення… |
| Lock Screen | Замкнений екран |
| Battery | Акумулятор |
| Energy | Енергія |
| Screen Saver | Екранна заставка |
| Login Items | Автозапуск |
| Login Items & Extensions | Автозапуск і розширення |
| Brightness | Яскравість |
| Automatically adjust brightness | Автоматично настроювати яскравість |
| True Tone | True Tone |
| High Dynamic Range | Розширений динамічний діапазон |
| Preset | Набір параметрів |
| Night Shift… | Night Shift… |
| Color profile | Колірний профіль |
| Refresh rate | Частота оновлення |
| Allow in the Menu Bar | Дозволити на смузі меню |
| Low Power Mode | Режим економії заряду |
| Do Not Disturb | Не турбувати |
| Camera | Камера |
| Open Anyway | Все одно відкрити |
| Applications | Програми |
| Reduce motion | Зменшити рух |
| Reduce transparency | Зменшення прозорості |
| Increase contrast | Збільшення контрасту |
| Differentiate without color | Розрізнення без кольору |
| VoiceOver | VoiceOver |

## Overbright’s own names

| English | uk | Note |
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

| English | uk | Note |
|---|---|---|
| Overbright | Overbright | never translated or transliterated; also the open panel (“Відкрити Overbright”) |
| Preview | Попередній перегляд | short form “Перегляд” not used |
| Settings (Overbright) | Параметри | Apple's “Settings…” = “Параметри…”; Apple's “Загальні” for General; Overbright's other pane names are WP15's |
| Allow… / Grant… | Дозволити… | Apple's button “Дозволити” |
| Reset to Default | Скинути до типового значення | default = типовий (Apple: Restore Defaults = “Відновити типові”) |
| Changed from the default | Змінено порівняно з типовим значенням |  |
| Welcome | Вітаємо в Overbright | window title |
| keyboard shortcut | клавіатурне скорочення (short: скорочення) | Apple: “Клавіатурні скорочення” |
| Shortcuts (Apple app) | «Команди» | Finder's display name; bundle name “Швидкі команди” |
| Never (a timeout of 0) | Ніколи |  |
| Off (an option) | Вимк. | Apple segment style; VoiceOver values: вимкнено / увімкнено |
| Remove (from a list) | Вилучити | Apple; “Видалити” only for Delete |
| App not installed | Програму не встановлено |  |
| Login Items | Автозапуск | Apple |
| pre-release | тестова версія | “Включно з тестовими версіями”; “попередня версія” means *previous* |
| When Overbright quits | До завершення роботи Overbright | Apple: “до завершення її роботи” |
