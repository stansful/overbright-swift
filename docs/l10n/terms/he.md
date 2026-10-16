# Overbright — Hebrew (עברית, `he`) terminology sheet

Carried from Cranny’s sheet for this language (ARCHITECTURE.md §10.2): the register, voice and
typography decisions are language facts and stay; Cranny’s notch, widget and ambient-light rows are
deleted. Overbright’s own names are decided in WP15 (ARCHITECTURE.md §10.17, §8.8); until then they
read “—”. `scripts/l10n/languages.json` has this language’s plural categories and quotation marks.

## Register and typography

Direction: right to left. No bidi control characters are added (not even the U+200F that some of Apple's
loctable values start with). Quotes: gershayim ״…״ (U+05F4) around names; geresh ׳ (U+05F3) in abbreviations
and loanwords (וידג׳ט, דק׳). Prefix letters attach directly to a quoted name, as macOS does («ב״נגישות״»,
«ו״כיבוי״»), and with a hyphen to Latin words and placeholders («ב-Overbright», «ל-%@», «וה-Dock»).
Ellipsis is one character (…). Apple spelling where Apple has one: «גירסה», «תיקיה».

**First word (review rule).** SwiftUI and AppKit take a paragraph's direction from its first strong letter (Unicode
P2/P3; checked with CoreText and a SwiftUI render on macOS 27). A string that starts with a Latin word (Overbright,
macOS, GitHub, Liquid Glass) or with a key combination (⌃⌥N) is laid out left to right: the Latin word lands on
the left and the final period or colon on the right, so a Hebrew reader meets the period first. Never start a
string that contains Hebrew with a Latin word, a key combination or a placeholder that may hold Latin text
(shortcut names, keys): move a Hebrew word to the front («כעת Overbright מטפל במקשים.», «הקיצור %1$@ מוגדר גם עבור
״%2$@״.», «בצג הזה Overbright כבוי.»). This includes the permission prompts in InfoPlist. Strings that are only a
name (Overbright, AirDrop) and VoiceOver-only labels are exempt. Parentheses around Latin text are fine (bracket
pairs resolve correctly).

**Paths.** Apple's Hebrew writes Settings paths with ">" (mirrored, so it points along the reading direction)
between quoted names: «ב״פרטיות ואבטחה״ > ״נגישות״», «ב״הגדרות״ > ״מקלדת״». Never "▸": it does not mirror and
points backwards in right-to-left text.

**System Settings** is quoted as an app name in running text and in buttons, as Apple does: «ב״הגדרות המערכת״»,
«פתיחת ״הגדרות המערכת״». Only the bare menu-style item «הגדרות המערכת…» stays unquoted.


### Register

Grammatical gender: Overbright = masculine («Overbright פתוח», «Overbright מציג»); macOS = feminine, and as a subject it is
written «מערכת macOS» + feminine verb, as Apple does («מערכת macOS מבקשת…»; «מערכת macOS לא הוסיפה…»);
notch (מגרעת) = feminine; Tray (מדף) = masculine; widget (וידג׳ט) = masculine; activity (פעילות) = feminine.

## Apple names (`apple-terms.py he` on macOS 27.0.1 — never paraphrased)

| English | he |
|---|---|
| System Settings | הגדרות המערכת |
| Finder | Finder |
| Shortcuts | קיצורים |
| Photos | תמונות |
| TV | ‏TV |
| QuickTime Player | QuickTime Player |
| Privacy & Security | פרטיות ואבטחה |
| Accessibility | נגישות |
| General | כללי |
| Appearance | מראה |
| Menu Bar | שורת התפריטים |
| Control Center | מרכז הבקרה |
| Focus | ריכוז |
| Displays | צגים |
| Keyboard | מקלדת |
| Keyboard Shortcuts… | קיצורי מקלדת… |
| Lock Screen | מסך הנעילה |
| Battery | סוללה |
| Energy | אנרגיה |
| Screen Saver | שומר מסך |
| Login Items | פריטי התחברות |
| Login Items & Extensions | פריטי התחברות והרחבות |
| Brightness | בהירות |
| Automatically adjust brightness | התאמת בהירות אוטומטית |
| True Tone | ‏True Tone |
| High Dynamic Range | טווח דינמי גבוה |
| Preset | תצורה |
| Night Shift… | ‏Night Shift… |
| Color profile | פרופיל צבעים |
| Refresh rate | קצב ריענון |
| Allow in the Menu Bar | הצגה בשורת התפריטים |
| Low Power Mode | מצב חיסכון באנרגיה |
| Do Not Disturb | נא לא להפריע |
| Camera | מצלמה |
| Open Anyway | פתיחה בכל זאת |
| Applications | יישומים |
| Reduce motion | הפחתת תזוזות |
| Reduce transparency | הפחתת השקיפות |
| Increase contrast | הגברת הניגודיות |
| Differentiate without color | הבחנה ללא צבע |
| VoiceOver | ‏VoiceOver |

## Overbright’s own names

| English | he | Note |
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

| English | he | Note |
|---|---|---|
| Overbright | Overbright | never translated or transliterated; «ב-Overbright», «ל-Overbright», «כש-Overbright» |
| Settings | הגדרות | Overbright's Settings window |
| Welcome (window) | מסך הפתיחה |  |
| shortcut (Shortcuts app item) | קיצור / קיצורים |  |
| keyboard shortcut | קיצור מקלדת / קיצורי מקלדת | always with «מקלדת» to tell it apart from a Shortcuts item |
| Reset to Default | חזרה לברירת המחדל |  |
| Changed from the default | שונה מברירת המחדל |  |
| Allow… / Grant… | אישור… | Apple's Allow = «אישור» |
| Never (timeout 0) | אף פעם | Apple |
| Off | כבוי (masc.) / כבויה (camera) | Apple; as the value of a feminine picker («אזהרה ראשונה») use «ללא» |
| Undo | ביטול |  |
| Try again | ניסיון נוסף | Apple |
| Remove (from a list) | הסרה |  |
| Show … (toggles) | הצגת … | «הצגת הערך» |
