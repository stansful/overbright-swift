# Translating Overbright

Overbright ships in 35 languages from day one: English, the source, and every UI language macOS 27 ships (the list is
in `scripts/l10n/languages.json` and in the README). Russian is the owner's review language and the pivot for the
others. Every language is complete: as of 2026-10-17 `validate.py --shipped --release` finds no key pending in any
of them. New English text that lands before its translations is marked *pending* (English text, state
`needs_review`) in every language and translated before a release. If something in your language is wrong, stiff,
too long or not what macOS says, a correction is very welcome: an issue that quotes the text is enough, a pull
request is better.

This guide covers fixing or reviewing a language, adding strings in code (the policy that keeps CI green), and adding
a language. The file format and every check in detail: [`scripts/l10n/README.md`](../scripts/l10n/README.md). Rules
for code: [ARCHITECTURE.md §8.8](ARCHITECTURE.md); the copy voice and vocabulary: [DESIGN.md §16](DESIGN.md).

## Where things are

| What | Where |
|---|---|
| Strings of the package, one or more tables per module | `Packages/OverbrightKit/Sources/<Target>/Resources/*.xcstrings` (`Localizable`, plus a co-tenant's table: AppShell's `StatusMenu` and `Calibration`; Boost's `Safety` and Boost's, Core's, Displays', Signals' and Triggers' `Localizable` exist but hold no key, because those modules show no text of their own) |
| Shortcuts actions, the Focus filter, Shortcuts phrases | `App/Localizable.xcstrings`, `App/AppShortcuts.xcstrings` |
| App name and copyright | `App/InfoPlist.xcstrings` (no permission prompts: Overbright asks for none) |
| Control Center control (only when it ships) | `Controls/Localizable.xcstrings` |
| Languages: codes, plural categories, quotation marks, register notes, `shipped` | `scripts/l10n/languages.json` |
| Terminology sheet per language: register, typography, Apple's names, Overbright's names, decisions | [`docs/l10n/terms/<code>.md`](l10n/terms/) |
| Russian glossary (the reference translation) | [ARCHITECTURE.md §8.8](ARCHITECTURE.md) |
| Tools: export, validate, import, pending, Apple's terms | `scripts/l10n/` (Python 3 from macOS, no Xcode needed) |

Keys are the English text itself. Every key has a comment `"<Surface>: <purpose>"` (`Panel ▸ Display card: …`,
`Settings ▸ Displays: …`, `Welcome ▸ Defaults: …`, `HUD: …`, `VoiceOver: …`) that says where the text appears and
what it does; read it before translating.

## Improving a language

The tools work on one JSON file per language, so you never edit the catalogs by hand. Run them from the repository
root, one command at a time (`-I` keeps Python from importing anything from the current directory):

```zsh
python3 -I scripts/l10n/export.py de -o de.json              # every string, with English, comment, Russian, current German
python3 -I scripts/l10n/apple-terms.py de -o de-terms.json   # Apple's own German names, read from this Mac
# edit the "translation" fields in de.json (only those)
python3 -I scripts/l10n/validate.py de de.json --glossary de-terms.json   # errors stop here; read the warnings too
python3 -I scripts/l10n/import.py de de.json                 # writes the catalogs (validates first)
make strings-check                                           # catalogs in sync, copy rules, every shipped language valid
make test                                                    # includes the measured-width tests (below)
```

`export.py de --missing-only` exports only what German lacks or has pending. Small fixes can also be made in Xcode's
String Catalog editor; then run `python3 -I scripts/l10n/validate.py de --catalogs` and `make strings-check` (and
undo the editor's reordering, docs/CONTRIBUTING.md ▸ Gotchas). When you change a term, change every string that uses
it (search the export for the old word) and update the language's sheet in `docs/l10n/terms/`, so the next translator
keeps it.

What to look at when you review a language:

- **The terminology sheet first.** Overbright's own names (Standard, extra brightness, Dim below minimum, Dimmed,
  Brighter, Less Bright, the presets Indoor · Bright room · Sunlight · Max, Safe · Peak, Compatibility mode, Fill
  Light, Back to Standard, extra range) have one fixed translation each; the sheet lists them with the reasons. The
  same word must never mean two things ("Max" is a preset, so the ceiling is "Peak"; "Dimmer" and "Dim" read alike in
  many languages, so the step down is "Less Bright").
- **Apple's words.** People look for System Settings panes and the settings inside them by the name macOS shows them.
  Overbright points at Displays settings by name — "Brightness", "Automatically adjust brightness", "True Tone",
  "High Dynamic Range" (German «Hochkontrastbild»), "Preset", "Night Shift…", "Color profile" — and at Battery, Low
  Power Mode, Focus, Login Items, Control Center, Menu Bar and "Allow in the Menu Bar", and spells the space bar's key
  cap as macOS menus do ("Space": German «Leertaste», Russian «Пробел»). `apple-terms.py <lang>` reads
  those names from this Mac (`--details` shows where each comes from); `validate.py --glossary` warns when an Apple
  term stayed English.
- **Register and tone** as macOS uses them in your language (du/Sie, tu/vous, siz…; the `notes` in `languages.json`
  and the sheet say which). Buttons and menu items follow macOS's form (infinitive, imperative or noun, whatever
  your language's macOS does).
- **Fit.** The panel, its chips and the HUD have little room. Look at the app (below), not only at the file.

To see the app in a language, build Debug and launch it with simulated displays and a settings suite of its own
(never without `--qa-simulate`: docs/CONTRIBUTING.md ▸ Running the app safely):

```zsh
QA=(--off --qa-simulate builtin-xdr-lid-open --qa-defaults-suite app.overbright.Overbright.qa)
scripts/run.sh -- "${QA[@]}" -AppleLanguages "(de)" -AppleLocale de_DE --qa-settings displays --qa-snapshot /tmp/de --qa-exit-after 8
scripts/run.sh -- "${QA[@]}" -AppleLanguages "(ar)" -AppleTextDirection YES -AppleLocale ar_SA --qa-panel --qa-snapshot /tmp/ar --qa-exit-after 8
defaults delete app.overbright.Overbright.qa
```

## The rules

These hold in every language. `validate.py` checks the mechanical ones; the rest need a reader.

- **Overbright** is a name: never translated or transliterated, always with its capital O. Attach grammar around it
  the way your language does with foreign names (Turkish «Overbright’ı», Finnish «Overbrightin», Hungarian
  «Overbrightot»; the sheets of fi, hu and tr record the suffix decisions).
- **Never write a competitor's name** — not the incumbent's, not its maker's, not another display tool's — not even
  as the translation of an ordinary word, and never look at other apps' translations. Overbright is a clean-room
  project (ARCHITECTURE.md D3); `validate.py` and `scripts/lint-copy.py` reject those names in every language,
  translator comments included. Other apps' names appear only at runtime.
- **Placeholders** stay: every `%@`, `%lld`, `%#@name@` of the English, with the same types. Reorder with positions
  (`%2$@ … %1$lld`), and never mix positional and plain specifiers in one string. Numbers, multipliers ("×1.29"),
  percentages, temperatures, times and durations arrive already formatted for the user's region: never write digits
  or units into a translation.
- **Key caps are never typed.** A sentence that names a shortcut gets the live key caps as a placeholder (`%@`), drawn
  in the user's keyboard layout (on a German layout the Brighter key is ´). A translation must not contain ⌃⌥⌘ and a
  key; `noLiteralKeyCapsInCatalogs` fails on it.
- **Plurals.** Every shown count has plural variations ("≈ %lld nits" too). Answer with exactly your language's CLDR
  categories (`languageInfo.pluralCategories` in the export). A category listed in `pluralExactValues` stands for one
  number and may leave the number out; then every other placeholder in that form must be positional.
- **Quotation marks and typography** as macOS writes them in your language (`quoteStyle`: „…“ in German, « … » with
  no-break spaces in French, straight quotes in Arabic). The apostrophe is ’, the ellipsis one character …; French puts
  a no-break space before : ; ! ?. No ASCII quotes unless your macOS uses them.
- **Case.** Sentence case, except where your language capitalizes otherwise and where English uses title case for
  standard macOS menus, Settings buttons, sheets and alerts — follow your macOS there.
- **System Settings by pane name**, never by a path ("in Displays settings"). Overbright's own Settings may use
  paths ("Settings ▸ Automations").
- **Constrained strings.** Items with `"constrained": true` sit in a fixed-width place; `maxWidth.hint` says how much
  room there is: a status chip ≤ 280 pt on its own line, the three footer guard chips ≤ 304 pt together (they drop to
  glyph + value when they do not fit), the readout ≤ 200 pt, the slider's value tag ≤ 240 pt, the HUD ≤ 200 pt of
  text, the Safe / Peak segments one short word each, Control Center titles about 14 columns. Prefer the shortest
  natural wording. Tooltips and help tags, VoiceOver labels, Settings search keywords and menus (including a footer
  chip's menu items and a chip's popover and buttons) are never constrained.
- **Measured-width tests** render the constrained strings of every language and fail when one does not fit:
  `ChipFitTests`, `ReadoutFitTests`, `FooterFitTests` (PanelUI), `HUDFitTests` (the shell's HUD),
  `BannerFitTests` (Design: a banner shows its whole sentence, never cut, in at most six lines),
  `WelcomeStepFitTests` and `WelcomeFooterFitTests` (Welcome) and `SettingsSegmentFitTests` (Settings). A failure
  names the language and the measured width. Shorten the wording; changing a layout to make room is a code change
  with its own review.
- **Right to left.** Arabic and Hebrew get a mirrored panel, cards, slider and Settings from the system; the menu bar
  symbol does not mirror, and names inside sentences are isolated by the code. Translate naturally; do not add
  direction marks yourself.

## New strings in code

A pull request that adds or changes English text (changing a key's English makes it a new key) has two choices for
each shipped language: **translate it, or mark it pending.** Either keeps CI green.

1. Write the code with `String(localized: "…", bundle: .module, comment: "<Surface>: <purpose>")` or
   `Text("…", bundle: .module, comment: …)` and run `make strings`: it adds the English keys to the module's catalogs.
2. Either **translate**: for a language you know, `export.py <lang> --missing-only -o <lang>.json`, fill in, validate,
   import (above). Or **mark it pending**: `make l10n-pending` (`scripts/l10n/pending.py`) gives every shipped
   language that lacks the key the English text, in that language's plural shape, with state `needs_review`. Do
   both: translate what you can, then mark the rest pending.
3. `make strings-check` must pass. It fails on a key that a shipped language has **no entry** for, and accepts a
   pending key, listing the pending keys per language as a warning.

Pending keys are translated before a release: `export.py <lang> --missing-only` lists them with `"translation": null`,
and `import.py` replaces them with state `translated`. The release workflow runs `validate.py --shipped --release`,
which fails while any key is pending. Keys ported from Cranny (search, Reset All, Undo, the recorder, the update
check, About, Welcome navigation) were seeded from Cranny's reviewed translations with the brand replaced; the forms
that carry the brand are marked `needs_review`, because Finnish, Hungarian and Turkish attach suffixes to it.

Only Overbright's own strings count: text that comes from the system (display names, app names) is never in a
catalog.

## Adding a language

`languages.json` already lists every language macOS 27 offers for its UI (English variants and regional variants that
fall back on their own, such as es-419 → es, are left out). When macOS adds one:

1. Add its entry to `scripts/l10n/languages.json`: code, macOS's `.lproj` name (`appleCode`), names, `rtl`, the CLDR
   plural categories, `pluralExactValues`, `quoteStyle` as macOS writes it, register and typography `notes`, and
   `"shipped": false`.
2. Add the code to `CFBundleLocalizations` in `App/Info.plist` and to `knownRegions` in the Xcode project
   (`make smoke` checks that the built app advertises every language of the file).
3. `export.py <code> -o <code>.json`, `apple-terms.py <code>`, translate everything, write the language's sheet in
   `docs/l10n/terms/<code>.md` (start from a related language's sheet), validate, import.
4. `make test`: the measured-width tests pick up the new `.lproj` on their own. Fix what does not fit by wording.
5. Look at the app in the language (above), then set `"shipped": true`. From then on `make strings-check` requires
   the language to be complete (or pending) for every key.

## Checks at a glance

| Command | Checks |
|---|---|
| `python3 -I scripts/l10n/validate.py <lang> <file>` | a translator file: completeness, placeholders, plural categories, quotes, “Overbright”, no competitor names |
| `python3 -I scripts/l10n/validate.py <lang> --catalogs` | the same for what the catalogs hold now |
| `make l10n-check` (`validate.py --shipped`) | every shipped language complete and valid; pending keys are warnings |
| `validate.py --shipped --release` | the same, and no key pending (release workflow) |
| `make copy-check` (`scripts/lint-copy.py`) | English copy rules; quotes and ellipses per language; competitor denylist |
| `make strings-check` | catalogs in sync with the code + copy rules + `l10n-check` (CI) |
| `make test` | the measured-width, terminology and catalog-lint tests, among all others |
