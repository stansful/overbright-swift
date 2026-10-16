#!/usr/bin/env python3
"""Apple's own names for Apple's UI, read from this Mac's system localizations: a glossary for translators.

    python3 -I scripts/l10n/apple-terms.py de                 # {"System Settings": "Systemeinstellungen", …}
    python3 -I scripts/l10n/apple-terms.py de -o de-terms.json
    python3 -I scripts/l10n/apple-terms.py de --details       # value, source file, key and conflicting alternatives
    python3 -I scripts/l10n/apple-terms.py --list             # the English terms

Overbright's copy names Apple's apps, System Settings panes and the settings inside them (Displays: Brightness, True
Tone, High Dynamic Range, Preset…), accessibility settings and a few system features; a translation must use macOS's
own words for them so people find the right switch ("Turn on High Dynamic Range for this display in Displays
settings": German "Hochkontrastbild"). Ported from Cranny; ARCHITECTURE.md §8.8. The tool reads them from the
system: app names from each app's
InfoPlist.loctable (or <lproj>/InfoPlist.strings), everything else by looking up the English text in the
loctables of System Settings' extensions (/System/Library/ExtensionKit/Extensions), TCC, Finder and a few
frameworks, then taking the same key in the language. A term macOS does not have (or names differently on
another macOS version) comes out as null, with a note on stderr. Soft hyphens (U+00AD, German line-break hints)
are removed; no-break spaces are kept as macOS writes them.

macOS's folder names differ from Xcode's codes for three languages: nb is "no", zh-Hans "zh_CN", zh-Hant "zh_TW"
(and pt-BR is "pt_BR" or "pt"); languages.json "appleCode" holds the name.
"""

import argparse
import glob
import json
import os
import plistlib
import sys

sys.dont_write_bytecode = True                     # keep the repo free of __pycache__
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import l10n  # noqa: E402

EXT = "/System/Library/ExtensionKit/Extensions"
APPS = "/System/Applications"
PRIVACY = f"{EXT}/SecurityPrivacyExtension.appex/Contents/Resources/Localizable.loctable"
CONTROL_CENTER = f"{EXT}/ControlCenterSettings.appex/Contents/Resources/Localizable.loctable"
ACCESSIBILITY = f"{EXT}/AccessibilitySettingsExtension.appex/Contents/Resources/Localizable.loctable"
DISPLAYS = f"{EXT}/DisplaysExt.appex/Contents/Resources/Localizable.loctable"
FINDER = "/System/Library/PrivateFrameworks/FinderKit.framework/Resources/LocalizableMerged.loctable"
TCC = "/System/Library/PrivateFrameworks/TCC.framework/Resources/Localizable.loctable"


def pane(name):
    """A System Settings pane's name: its extension's InfoPlist.loctable."""
    return f"{EXT}/{name}.appex/Contents/Resources/InfoPlist.loctable"


# English term -> where macOS keeps it, best first: ("app", bundle path) or ("table", loctable path or glob).
# Terms without sources are searched in DEFAULT_TABLES.
TERMS = {
    # Apps (the bundle's display name)
    "System Settings": [("app", f"{APPS}/System Settings.app")],
    "Finder": [("app", "/System/Library/CoreServices/Finder.app")],
    "Shortcuts": [("app", f"{APPS}/Shortcuts.app")],
    "Photos": [("app", f"{APPS}/Photos.app")],
    "TV": [("app", f"{APPS}/TV.app")],
    "QuickTime Player": [("app", f"{APPS}/QuickTime Player.app")],
    # System Settings panes
    "Privacy & Security": [("table", pane("SecurityPrivacyExtension"))],
    "Accessibility": [("table", pane("AccessibilitySettingsExtension")), ("table", PRIVACY)],
    "General": [("table", pane("GeneralSettings"))],
    "Appearance": [("table", pane("Appearance"))],
    "Menu Bar": [("table", pane("ControlCenterSettings"))],
    "Control Center": [("table", "/System/Applications/System Settings.app/Contents/Resources/Localizable.loctable")],
    "Focus": [("table", pane("FocusSettingsExtension"))],
    "Displays": [("table", pane("DisplaysExt"))],
    "Keyboard": [("table", pane("KeyboardSettings"))],
    "Keyboard Shortcuts…": [("table", f"{EXT}/KeyboardSettings.appex/Contents/Resources/Localizable.loctable")],
    "Lock Screen": [("table", pane("LockScreen"))],
    "Battery": [("table", CONTROL_CENTER)],
    "Energy": [],
    "Screen Saver": [],
    "Login Items": [("table", pane("LoginItems"))],
    "Login Items & Extensions": [("table", f"{EXT}/LoginItems.appex/Contents/Resources/Localizable.loctable")],
    # Settings inside Displays (pointed to by the verdicts and Help; ARCHITECTURE.md §8.8)
    **{name: [("table", DISPLAYS)] for name in ["Brightness", "Automatically adjust brightness", "True Tone",
                                               "High Dynamic Range", "Preset", "Night Shift…", "Color profile",
                                               "Refresh rate"]},
    # Menu bar and system features
    "Allow in the Menu Bar": [("table", CONTROL_CENTER)],
    "Low Power Mode": [("table", CONTROL_CENTER)],
    "Do Not Disturb": [("table", "/System/Library/PrivateFrameworks/DoNotDisturb.framework/Resources/Localizable.loctable")],
    "Camera": [("table", PRIVACY)],
    "Open Anyway": [("table", PRIVACY)],
    "Applications": [("table", FINDER)],
    # Accessibility settings named in copy
    "Reduce motion": [("table", ACCESSIBILITY)],
    "Reduce transparency": [("table", ACCESSIBILITY)],
    "Increase contrast": [("table", ACCESSIBILITY)],
    "Differentiate without color": [("table", ACCESSIBILITY)],
    "VoiceOver": [("table", ACCESSIBILITY)],
}

# Searched, in this order, for terms whose own sources do not have them.
DEFAULT_TABLES = [
    PRIVACY, CONTROL_CENTER, ACCESSIBILITY,
    f"{EXT}/*.appex/Contents/Resources/InfoPlist.loctable",
    "/System/Applications/System Settings.app/Contents/Resources/Localizable.loctable",
    f"{EXT}/*.appex/Contents/Resources/Localizable.loctable",
    FINDER,
    "/System/Library/CoreServices/ControlCenter.app/Contents/Resources/*.loctable",
    "/System/Library/Frameworks/AppKit.framework/Resources/*.loctable",
    TCC,
]

_cache = {}


def load_plist(path):
    if path not in _cache:
        try:
            with open(path, "rb") as handle:
                _cache[path] = plistlib.load(handle)
        except (OSError, plistlib.InvalidFileException, ValueError):
            _cache[path] = None
    return _cache[path]


def apple_codes(code):
    """macOS's names for a language, best first."""
    info = l10n.language(code)
    codes = [info.get("appleCode", code), code, code.replace("-", "_")]
    extra = {"pt-BR": ["pt"], "zh-Hans": ["zh-Hans", "zh_Hans"], "zh-Hant": ["zh-Hant", "zh_Hant"], "nb": ["nb", "no"],
             "en": ["English", "Base"]}
    codes += extra.get(code, [])
    return list(dict.fromkeys(codes))


def clean(value):
    return value.replace("­", "").strip() if isinstance(value, str) else None


def tables(spec):
    paths = sorted(glob.glob(spec)) if any(c in spec for c in "*?[") else [spec]
    for path in paths:
        table = load_plist(path)
        if isinstance(table, dict):
            yield path, table


def from_table(term, spec, codes):
    """(value, path, key) for every key of the loctables in `spec` whose English text is `term`."""
    for path, table in tables(spec):
        english = table.get("en")
        if not isinstance(english, dict):
            continue
        for key, text in english.items():
            if text != term:
                continue
            for code in codes:
                value = (table.get(code) or {}).get(key) if isinstance(table.get(code), dict) else None
                if isinstance(value, str):
                    yield clean(value), path, key
                    break


def from_app(path, codes):
    """The app's display name in the language (what Finder and the Dock show): InfoPlist.loctable, else
    <lproj>/InfoPlist.strings, else Info.plist (English). A different CFBundleName (pt-BR “Ajustes” /
    “Ajustes do Sistema”) is returned as an alternative."""
    path = os.path.realpath(path)
    resources = os.path.join(path, "Contents/Resources")
    table = load_plist(os.path.join(resources, "InfoPlist.loctable"))
    for code in codes:
        sources = []
        if isinstance(table, dict) and isinstance(table.get(code), dict):
            sources.append((table[code], os.path.join(resources, "InfoPlist.loctable")))
        strings = load_plist(os.path.join(resources, f"{code}.lproj", "InfoPlist.strings"))
        if isinstance(strings, dict):
            sources.append((strings, os.path.join(resources, f"{code}.lproj", "InfoPlist.strings")))
        for values, where in sources:
            names = [(key, clean(values[key])) for key in ("CFBundleDisplayName", "CFBundleName")
                     if isinstance(values.get(key), str)]
            if names:
                key, value = names[0]
                return value, where, key, [name for _, name in names[1:] if name != value]
    if "en" in codes or "English" in codes:
        info = load_plist(os.path.join(path, "Contents/Info.plist"))
        if isinstance(info, dict):
            for key in ("CFBundleDisplayName", "CFBundleName"):
                if isinstance(info.get(key), str):
                    return clean(info[key]), os.path.join(path, "Contents/Info.plist"), key, []
    return None


def lookup(term, code):
    """{"value", "source", "key", "alternatives"} for one term, or None."""
    codes = apple_codes(code)
    found = []
    extra = []
    for kind, spec in TERMS.get(term, []):
        if kind == "app":
            hit = from_app(spec, codes)
            if hit:
                found.append(hit[:3])
                extra = hit[3]
        else:
            found += list(from_table(term, spec, codes))
        if found:
            break
    if not found:
        for spec in DEFAULT_TABLES:
            found += list(from_table(term, spec, codes))
            if found:
                break
    found = [hit for hit in found if hit[0]]
    if not found:
        return None
    value, source, key = found[0]
    alternatives = sorted({hit[0] for hit in found[1:] if hit[0] != value} | set(extra))
    return {"value": value, "source": source, "key": key, "alternatives": alternatives}


def main(argv):
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("language", nargs="?", help="language code from scripts/l10n/languages.json")
    parser.add_argument("-o", "--output", help="write the JSON to this file instead of stdout")
    parser.add_argument("--details", action="store_true", help="value, source, key and alternatives per term")
    parser.add_argument("--list", action="store_true", help="print the English terms and exit")
    args = parser.parse_args(argv)
    if args.list:
        print("\n".join(TERMS))
        return 0
    if not args.language:
        parser.error("give a language code")
    l10n.language(args.language)                      # exits on an unknown code
    result = {}
    missing = []
    for term in TERMS:
        hit = lookup(term, args.language)
        if hit is None:
            missing.append(term)
        result[term] = hit if args.details else (hit or {}).get("value")
    text = json.dumps(result, ensure_ascii=False, indent=2) + "\n"
    if args.output:
        with open(args.output, "w", encoding="utf-8") as handle:
            handle.write(text)
    else:
        sys.stdout.write(text)
    if missing:
        print(f"note: not found on this Mac for {args.language}: {', '.join(missing)}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
