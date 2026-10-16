# Overbright — Hebrew (עברית, `he`) terminology sheet

Carried from Cranny’s sheet for this language (ARCHITECTURE.md §10.2): the register, voice and
typography decisions are language facts and stay; Cranny’s notch, widget and ambient-light rows are
deleted, and examples and notes that named Cranny’s features (the notch, the Tray, widgets, Calendar, Notes,
Media, permissions) were replaced with Overbright’s or dropped. Overbright’s own names, its pane names among them,
were decided in WP15 (ARCHITECTURE.md §10.17, §8.8); the table shows them as the catalogs ship them.
`scripts/l10n/languages.json` has this language’s plural categories and quotation marks.

## Register and typography

Direction: right to left. No bidi control characters are added (not even the U+200F that some of Apple's
loctable values start with). Quotes: gershayim ״…״ (U+05F4) around names; geresh ׳ (U+05F3) in abbreviations
and loanwords (צ׳יפ, דק׳). Prefix letters attach directly to a quoted name, as macOS does («ב״נגישות״»,
«ו״כיבוי״»), and with a hyphen to Latin words and placeholders («ב-Overbright», «ל-%@», «וה-Dock»).
Ellipsis is one character (…). Apple spelling where Apple has one: «גירסה», «תיקיה».

**First word (review rule).** SwiftUI and AppKit take a paragraph's direction from its first strong letter (Unicode
P2/P3; checked with CoreText and a SwiftUI render on macOS 27). A string that starts with a Latin word (Overbright,
macOS, GitHub, Liquid Glass) or with a key combination (⌃⌥N) is laid out left to right: the Latin word lands on
the left and the final period or colon on the right, so a Hebrew reader meets the period first. Never start a
string that contains Hebrew with a Latin word, a key combination or a placeholder that may hold Latin text
(shortcut names, keys): move a Hebrew word to the front («כעת Overbright מטפל במקשים.», «הקיצור %1$@ מוגדר גם עבור
״%2$@״.», «בצג הזה Overbright כבוי.»). This includes the InfoPlist strings. Strings that are only a
name (Overbright, Finder) and VoiceOver-only labels are exempt. Parentheses around Latin text are fine (bracket
pairs resolve correctly).

**Paths.** Apple's Hebrew writes Settings paths with ">" (mirrored, so it points along the reading direction)
between quoted names: «ב״פרטיות ואבטחה״ > ״נגישות״», «ב״הגדרות״ > ״כללי״». Never "▸": it does not mirror and
points backwards in right-to-left text.

**System Settings** is quoted as an app name in running text and in buttons, as Apple does: «ב״הגדרות המערכת״»,
«פתיחת ״הגדרות המערכת״». Only the bare menu-style item «הגדרות המערכת…» stays unquoted.


### Register

Grammatical gender: Overbright = masculine («Overbright פתוח», «Overbright מציג»); macOS = feminine, and as a subject it is
written «מערכת macOS» + feminine verb, as Apple does («מערכת macOS מבקשת…»; «מערכת macOS לא הוסיפה…»);
display (צג) = masculine; camera (מצלמה) = feminine.

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
| Settings panes: General · Displays · Automations · Shortcuts · Fill Light · Advanced · About | כללי · צגים · פעולות אוטומטיות · קיצורי מקלדת · אור מילוי · מתקדם · מידע | the sidebar and window titles |
| Standard (the brightness macOS shows) | סטנדרט | never “100 %” or “normal mode” |
| extra brightness (the boost half) | “שימוש בבהירות נוספת” (Use extra brightness) | never “boost”, “HDR mode”, “EDR” |
| Dim below minimum (the setting) | “הפעלה או כיבוי של עמעום מתחת למינימום” (Dim Below Minimum On or Off) | the incumbent’s name for it is never used |
| Dimmed (the state) · Dim All Displays / Stop Dimming (actions) | מעומעם · עמעום כל הצגים / הפסקת העמעום | not “night mode” |
| Brighter · Less Bright (one step) | בהיר יותר · פחות בהיר | never “Dimmer”: it reads like Dim |
| Back to Standard (the instant off) | חזרה לסטנדרט | not “panic”, not “reset brightness” |
| Indoor · Bright room · Sunlight · Max (presets) | בתוך הבית · חדר מואר · אור שמש · מקסימום | “Max” is a preset only |
| Safe · Peak (ceilings) | בטוח · שיא | Peak, never “Max”, for a ceiling; one short word each (segments) |
| Compatibility mode · Color table (methods) | מצב תאימות · טבלת צבעים | never “fallback” or “overlay” |
| Fill Light (the edge light for video calls) | אור מילוי | never “ring light” |
| extra range (headroom, in user copy) | טווח נוסף | “headroom” only in Advanced and diagnostics |
| Calibrate… · Run Self-Test… · Reset Display Colors… | כיול… · הרצת בדיקה עצמית… · איפוס צבעי הצגים… |  |
| Keep this level? · Go Back · Keep | להשאיר את הרמה הזו? · חזרה · השארה | the very-dark-level prompt |
| Pause · Paused · Resume | “השהיית Overbright” (Pause Overbright) · מושהה · המשך | a temporary stop; never “disabled” |

Fit (WP15): the footer’s default row (Battery, Auto-pause, Timer) must fit its 292 pt in full in every language (`FooterFitTests`), so the Auto-pause chip reads “השהיות” (off: “ללא השהיות”).

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
| Off | כבוי (masc.) / כבויה (camera) | Apple |
| Undo | ביטול |  |
| Try again | ניסיון נוסף | Apple |
| Remove (from a list) | הסרה |  |
| Show … (toggles) | הצגת … | «הצגת הערך» |
| Space (the space bar in key caps) | רווח | as AppKit writes it in menu key equivalents (FunctionKeyNames.loctable “Space”), so Settings and Welcome show the same key caps as the menu; AppKit’s name for the physical key is מקש רווח |
