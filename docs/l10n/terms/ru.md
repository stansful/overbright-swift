# Overbright — Russian (русский, `ru`) terminology sheet

Russian is the owner's review language and the pivot for every other language (ARCHITECTURE.md §8.8): `export.py`
shows each translator the Russian next to the English. Cranny kept its Russian glossary in its architecture document
rather than in a sheet; Overbright's glossary is ARCHITECTURE.md §8.8, guarded by `TerminologyTests` (WP11), and is
confirmed in WP15. The names below marked “—” are WP15's decision.

## Register and typography

- Formal «вы» in sentences addressed to the user, lowercase as macOS writes it; buttons and menu items in the
  infinitive («Завершить Overbright», «Проверить сейчас»), as macOS Russian does.
- Quotes «…» (inner „…“); app names and Apple's setting names in running text in « » («Команды»,
  «Расширенный динамический диапазон»); one-character ellipsis …; the brand is never declined («в Overbright»).
- Plural forms one, few, many and other (fractions): fill all four for every count.
- Russian runs 15–35 % longer than English: constrained strings (chips, the readout, the HUD, Safe / Peak) are
  measured, never counted; shorten the wording first.

## Apple names (`apple-terms.py ru` on macOS 27.0.1 — never paraphrased)

| English | ru |
|---|---|
| System Settings | Системные настройки |
| Finder | Finder |
| Shortcuts | Команды |
| Photos | Фото |
| TV | TV |
| QuickTime Player | QuickTime Player |
| Privacy & Security | Конфиденциальность и безопасность |
| Accessibility | Универсальный доступ |
| General | Основные |
| Appearance | Оформление |
| Menu Bar | Строка меню |
| Control Center | Пункт управления |
| Focus | Фокусирование |
| Displays | Дисплеи |
| Keyboard | Клавиатура |
| Keyboard Shortcuts… | Сочетания клавиш… |
| Lock Screen | Экран блокировки |
| Battery | Аккумулятор |
| Energy | Энергопотребление |
| Screen Saver | Заставка |
| Login Items | Объекты входа |
| Login Items & Extensions | Объекты входа и расширения |
| Brightness | Яркость |
| Automatically adjust brightness | Автоматически настраивать яркость |
| True Tone | True Tone |
| High Dynamic Range | Расширенный динамический диапазон |
| Preset | Набор настроек |
| Night Shift… | Night Shift… |
| Color profile | Цветовой профиль |
| Refresh rate | Частота обновления |
| Allow in the Menu Bar | Разрешить в строке меню |
| Low Power Mode | Режим энергосбережения |
| Do Not Disturb | Не беспокоить |
| Camera | Камера |
| Open Anyway | Все равно открыть |
| Applications | Приложения |
| Reduce motion | Уменьшить движение |
| Reduce transparency | Понизить прозрачность |
| Increase contrast | Увеличить контрастность |
| Differentiate without color | Дифференцировать без цвета |
| VoiceOver | VoiceOver |

## Overbright’s own names

| English | ru | Note |
|---|---|---|
| Overbright | Overbright | never translated or transliterated |
| Standard (the brightness macOS shows) | Стандарт | never “100 %” or “normal mode” |
| extra brightness (the boost half) | Дополнительная яркость | never “boost”, “HDR mode”, “EDR” |
| Dim below minimum (the setting) | Затемнение ниже минимума | the incumbent’s name for it is never used |
| Dimmed (the state) · Dim All Displays / Stop Dimming (actions) | — | not “night mode” |
| Brighter · Less Bright (one step) | — · Менее ярко | never “Dimmer”: it reads like Dim |
| Back to Standard (the instant off) | — | not “panic”, not “reset brightness” |
| Indoor · Bright room · Sunlight · Max (presets) | — | “Max” is a preset only |
| Safe · Peak (ceilings) | Безопасно · Пик | Peak, never “Max”, for a ceiling; one short word each (segments) |
| Compatibility mode · Color table (methods) | Режим совместимости · — | never “fallback” or “overlay” |
| Fill Light (the edge light for video calls) | Подсветка лица | never “ring light” |
| extra range (headroom, in user copy) | — | “headroom” only in Advanced and diagnostics |
| Calibrate… · Run Self-Test… · Reset Display Colors… | — |  |
| Keep this level? · Go Back · Keep | — | the very-dark-level prompt |
| Pause · Paused · Resume | — | a temporary stop; never “disabled” |
