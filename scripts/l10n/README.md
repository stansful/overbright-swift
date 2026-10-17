# Translating Overbright

Overbright's text lives in String Catalogs: every table of every OverbrightKit target
(`Packages/OverbrightKit/Sources/<Target>/Resources/*.xcstrings`: `Localizable` plus a co-tenant's own table such as
AppShell's `StatusMenu` and `Calibration`; Boost's `Safety` is reserved and empty), the app target's `App/InfoPlist.xcstrings`,
`App/Localizable.xcstrings` (App Intents and the Focus filter) and `App/AppShortcuts.xcstrings`, and
`Controls/Localizable.xcstrings` once the Control Center extension ships. English is the source; all 35 languages of
`languages.json` ship from day one (ARCHITECTURE.md §8.8). Russian is the owner's review language and the pivot for
the others. These tools let you translate all of it as one JSON file, check it, and write it back. They need only the
Python 3 that ships with macOS (`/usr/bin/python3`, standard library) and no Xcode. They are ported from Cranny.

| Command | Does |
|---|---|
| `python3 -I scripts/l10n/export.py de -o de.json` | Every string for German translators (`--missing-only`: only what German lacks) |
| `python3 -I scripts/l10n/apple-terms.py de -o de-terms.json` | Apple's own German names for Apple's apps, panes and settings, read from this Mac |
| `python3 -I scripts/l10n/validate.py de de.json --glossary de-terms.json` | Checks the file; exit status 1 on errors |
| `python3 -I scripts/l10n/import.py de de.json` | Writes the translations into the catalogs (validates first) |
| `python3 -I scripts/l10n/validate.py de --catalogs` | Checks what the catalogs hold for German |
| `make l10n-check` (= `validate.py --shipped`) | Every shipped language complete and valid; part of `make strings-check` and CI |
| `make l10n-pending` (= `pending.py`) | Marks new English keys “pending translation” (English text, state `needs_review`) in every shipped language that lacks them |
| `validate.py --shipped --release` | Also fails on pending keys (the release workflow) |

New English strings follow this flow: `make strings` (sync the catalogs from code) → `make l10n-pending` →
`make strings-check`. A pending key is a warning in `strings-check` and an error in a release.

`languages.json` lists the languages Overbright is translated into — every language macOS 27 itself ships, except
English variants and regional variants that fall back on their own (es-419 → es, fr-CA → fr, zh-HK → zh-Hant) — with
each language's CLDR plural categories, the categories that stand for a single number (`pluralExactValues`), its
quotation marks as macOS writes them (`quoteStyle`) and notes on its typography. `App/Info.plist`
(`CFBundleLocalizations`) and the Xcode project (`knownRegions`) list every language of the file; `scripts/smoke.sh`
checks the built app.

## The file

`export.py` writes `{"language", "languageInfo", "howTo", "strings": [...]}`. Translate only the `"translation"`
field of each item:

```json
{
  "catalog": "Packages/OverbrightKit/Sources/OverbrightDesign/Resources/Localizable.xcstrings",
  "key": "≈ %lld nits",
  "comment": "Panel ▸ Display card: readout, the estimated light of the display",
  "surface": "Panel ▸ Display card",
  "english": {"plural": {"one": "≈ %lld nit", "other": "≈ %lld nits"}},
  "placeholders": [{"arg": 1, "specifier": "%lld", "type": "integer", "plural": true}],
  "russian": {"plural": {"one": "≈ %lld нит", "few": "≈ %lld нита", "many": "≈ %lld нит", "other": "≈ %lld нита"}},
  "translation": {"plural": {"one": "≈ %lld Nit", "other": "≈ %lld Nits"}},
  "state": null,
  "constrained": true,
  "maxWidth": {"kind": "readout", "maxWidthPt": 200, "hint": "…", "ratio": 1.3, "budget": 33}
}
```

- **comment** says where the text appears and what it does (`"<surface>: <purpose>"`). Read it first. Surfaces:
  `Panel: …`, `Panel ▸ Display card: …`, `Panel ▸ Footer chip: …`, `Menu: …`, `HUD: …`, `Help: …`,
  `Settings ▸ <Pane>: …`, `Welcome ▸ <Step>: …`, `Calibration: …`, `Self-test: …`, `Shortcuts app: …`,
  `Focus filter: …`, `Control Center: …`, `VoiceOver: …`.
- **english** is a string, `{"plural": {category: text}}`, or `{"value": "… %2$#@cells@ …", "substitutions":
  {"cells": {"argNum": 2, "formatSpecifier": "lld", "plural": {…}}}}` (each `%#@name@` in the value is replaced by
  the plural form chosen by argument `argNum`; `%arg` in a form is that number). Answer in the same shape.
- **Plural forms**: exactly the categories in `languageInfo.pluralCategories` (German: one, other; Russian: one, few,
  many, other; Arabic: zero, one, two, few, many, other; Japanese: other only). Every shown count is a plural
  (“≈ %lld nits” too). The multiplier “×%@” arrives preformatted and needs no plural. A form whose category stands
  for a single number (`pluralExactValues`, e.g. Arabic two = 2) may leave the number out; then any other placeholder
  in that form must be positional (`%2$@`).
- **Placeholders**: keep every one (`%@` text, `%lld` integer, `%#@name@`); change their order with positions
  (`%2$@ … %1$lld`); never mix positional and plain specifiers in one string. Numbers, percentages, durations and
  key caps arrive already formatted for the user's region and keyboard — don't write digits or key symbols into a
  translation.
- **russian** is the reviewed Russian translation, an extra reference for meaning and tone.
- **translation** already holds the language's text where the catalogs have it; `state` is `"translated"` then.
- **constrained** / **maxWidth**: the text sits in a fixed-width place. `maxWidth.hint` says how much room there is:
  a status chip ≤ 280 pt on its own line, the three footer chips ≤ 304 pt together, the readout ≤ 200 pt, the slider's
  value tag ≤ 240 pt, the HUD ≤ 200 pt, the Safe / Peak segments, Control Center titles about 14 columns.
  Measured-width tests render these strings in every language and fail when one does not fit, so prefer the shortest
  natural wording.

How the exporter decides `constrained` (`l10n.SURFACE_RULES`): it reads the comment; text only VoiceOver speaks,
tooltips and help tags, Settings search keywords and every `Menu: …` comment are never constrained; otherwise the
first of these that the comment mentions decides — an explicit limit ("at most 48 pt", "≤ 10 characters"), "keep it
short" / "very short", the HUD, a readout, the value tag, a chip's own label (a "status chip", a `Panel ▸ Footer
chip:` label or a "chip label"; a chip's popover, chip actions, buttons, menu items and submenus are not its label),
a picker segment, a Control Center title, a table column header. The column budget is about 36 for a status chip and
16 for a footer chip. `validate.py --self-test` (run by `make lint`) checks the rules on known comments.

## Rules for every language

- **Overbright** is a name: never translate or transliterate it, keep its spelling and capital O. Attach grammar
  around it the way the language does with foreign names (Turkish “Overbright’ı”); the terms sheets in
  `docs/l10n/terms/` settle the forms.
- Never write a competitor's product or company name, not even as a translation of an ordinary English word
  (clean room, ARCHITECTURE.md D3; the denylist is in `l10n.py` and `scripts/lint-copy.py`). Never look at other
  brightness apps' translations.
- **Apple's names for Apple's things**: apps, System Settings panes and the settings inside Displays (Brightness,
  True Tone, High Dynamic Range, Preset…), accessibility settings and system features are written exactly as macOS
  shows them in your language — take them from `apple-terms.py` (`--details` shows where each one comes from and the
  alternatives macOS also uses). People look for these words on screen (German “Hochkontrastbild” for High Dynamic
  Range).
- Overbright's own names (Standard, extra brightness, Dim below minimum, Safe, Peak, Compatibility mode, Fill Light,
  Back to Standard, the presets Indoor · Bright room · Sunlight · Max) get one fixed translation each, used everywhere
  (the Russian glossary in docs/ARCHITECTURE.md §8.8 shows how the reviewed translation does it).
- Sentence case everywhere, except where the language capitalizes otherwise (German nouns) and where English uses
  title case for standard macOS menus and buttons — follow your language's macOS convention there.
- Typography: your language's quotation marks (`quoteStyle`), the apostrophe ’, one-character ellipsis …, the
  no-break spaces your language uses (French before : ; ! ? and inside « »). No straight quotes unless macOS uses
  them in your language (Arabic).
- Use the register macOS uses in your language (du/Sie, tu/vous… — the `notes` in `languages.json`).

## Checks (`validate.py`)

Errors (exit status 1): a key without a translation (in the catalogs: a shipped language with no entry; an entry
whose every form is `needs_review` is *pending*, listed as one warning per language, and an error only with
`--release`); a placeholder lost, added or of another type; positional and plain specifiers mixed; plural categories
that are not exactly the language's; an empty string; a denylisted name in a value, a key or a translator comment;
"Overbright" missing or misspelled; quotation marks of another language or straight quotes; three dots; French
spaces. Warnings: a string identical to English (unless it is only names macOS keeps, such as Sidecar or True Tone),
a constrained string much longer than English, English that changed since the export, plural forms collapsed into one
string where English varies, and (with `--glossary`) an Apple term left in English. `import.py` refuses a file with
errors (`--force` writes only the items without errors).
