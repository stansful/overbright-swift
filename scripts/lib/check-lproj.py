#!/usr/bin/env python3
"""Checks that a built Overbright.app ships every translation its String Catalogs hold (ARCHITECTURE.md §8.7, §8.8).
scripts/lib/build.sh and scripts/lib/smoke.sh run it; no Xcode needed.

Each package bundle falls back to English on its own while the app's locale follows the main bundle, so a build whose
bundles lack their compiled tables shows English text with, say, Russian number formats, and nothing else notices.
For every catalog and every language other than the source with a translated or needs_review unit, the built
<lang>.lproj must hold <Table>.strings (plain strings and string sets) and <Table>.stringsdict (plural, device and
substitution variations):

- Packages/OverbrightKit/Sources/<T>/Resources/<Table>.xcstrings → Contents/Resources/OverbrightKit_<T>.bundle;
- App/<Table>.xcstrings, except InfoPlist (Xcode merges it into InfoPlist.strings on its own) → Contents/Resources;
- Controls/<Table>.xcstrings → Contents/PlugIns/OverbrightControls.appex, when the build keeps the extension.

A <lang>.lproj that is empty, or whose language no catalog of that bundle has, is a stale output of an earlier build
(a language removed from a catalog): scripts/lib/build.sh clears the bundles when a catalog changes.

    python3 -I scripts/lib/check-lproj.py build/Overbright.app
    python3 -I scripts/lib/check-lproj.py --self-test
"""

import glob
import json
import os
import shutil
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SHIPPED_STATES = {"translated", "needs_review"}
CONTROLS_APPEX = "OverbrightControls.appex"


def catalogs(app, root=ROOT):
    """(repository-relative catalog path, Resources directory of the built bundle that holds it), for every catalog."""
    resources = os.path.join(app, "Contents/Resources")
    found = []
    for path in sorted(glob.glob(os.path.join(root, "Packages/OverbrightKit/Sources/*/Resources/*.xcstrings"))):
        target = os.path.basename(os.path.dirname(os.path.dirname(path)))
        found.append((path, os.path.join(resources, f"OverbrightKit_{target}.bundle/Contents/Resources")))
    for path in sorted(glob.glob(os.path.join(root, "App/*.xcstrings"))):
        found.append((path, resources))
    appex = os.path.join(app, "Contents/PlugIns", CONTROLS_APPEX)
    if os.path.isdir(appex):
        for path in sorted(glob.glob(os.path.join(root, "Controls/*.xcstrings"))):
            found.append((path, os.path.join(appex, "Contents/Resources")))
    return [(os.path.relpath(path, root), path, directory) for path, directory in found]


def shipped(node):
    """Whether a localization node holds a unit Xcode compiles: a string unit or string set that is translated or
    needs review, anywhere under it."""
    if isinstance(node, dict):
        for name in ("stringUnit", "stringSet"):
            unit = node.get(name)
            if isinstance(unit, dict) and unit.get("state") in SHIPPED_STATES:
                return True
        return any(shipped(child) for child in node.values())
    if isinstance(node, list):
        return any(shipped(child) for child in node)
    return False


def required(data):
    """{language: set of compiled suffixes (".strings", ".stringsdict")} a catalog's build must contain."""
    source = data.get("sourceLanguage", "en")
    needs = {}
    for entry in data.get("strings", {}).values():
        if entry.get("shouldTranslate") is False:
            continue
        for language, localization in entry.get("localizations", {}).items():
            if language == source or not shipped(localization):
                continue
            plain = "stringUnit" in localization or "stringSet" in localization
            varied = "variations" in localization or "substitutions" in localization
            if plain:
                needs.setdefault(language, set()).add(".strings")
            if varied:
                needs.setdefault(language, set()).add(".stringsdict")
    return needs


def languages_of(data):
    """Every language a catalog has, the source included."""
    found = {data.get("sourceLanguage", "en")}
    for entry in data.get("strings", {}).values():
        found.update(entry.get("localizations", {}))
    return found


def problems(app, root=ROOT):
    found = []
    known = {}                                       # Resources directory -> languages its catalogs have
    for name, path, directory in catalogs(app, root):
        with open(path, encoding="utf-8") as handle:
            data = json.load(handle)
        known.setdefault(directory, {"Base"}).update(languages_of(data))
        table = os.path.splitext(os.path.basename(path))[0]
        if os.path.dirname(name) == "App" and table == "InfoPlist":
            continue
        needs = required(data)
        if needs and not os.path.isdir(directory):
            found.append(f"{name}: {os.path.relpath(directory, app)} is missing")
            continue
        for language in sorted(needs):
            for suffix in sorted(needs[language]):
                compiled = os.path.join(directory, f"{language}.lproj", table + suffix)
                if not os.path.isfile(compiled) or os.path.getsize(compiled) == 0:
                    found.append(f"{name}: {os.path.relpath(compiled, app)} is missing ({language} would show English)")
    for directory, languages in sorted(known.items()):
        if not os.path.isdir(directory):
            continue
        for lproj in sorted(glob.glob(os.path.join(directory, "*.lproj"))):
            language = os.path.basename(lproj)[: -len(".lproj")]
            where = os.path.relpath(lproj, app)
            if not os.listdir(lproj):
                found.append(f"{where} is empty (a stale output; run make clean)")
            elif language not in languages:
                found.append(f"{where}: no catalog of this bundle has {language} (a stale output; run make clean)")
    return found


def self_test():
    """The checker passes a complete fake app and fails each way a build can lose a translation."""
    work = tempfile.mkdtemp(prefix="check-lproj.")
    try:
        root, app = os.path.join(work, "repo"), os.path.join(work, "Overbright.app")
        catalog_dir = os.path.join(root, "Packages/OverbrightKit/Sources/OverbrightDesign/Resources")
        os.makedirs(catalog_dir)
        os.makedirs(os.path.join(root, "App"))
        unit = lambda value, state="translated": {"stringUnit": {"state": state, "value": value}}
        design = {"sourceLanguage": "en", "version": "1.0", "strings": {
            "Done": {"localizations": {"ru": unit("Готово"), "de": unit("Fertig", "needs_review")}},
            "%lld nits": {"localizations": {"ru": {"variations": {"plural": {
                "one": unit("%lld нит"), "few": unit("%lld нита"), "many": unit("%lld нит"), "other": unit("%lld нита")}}}}},
            "Later": {"localizations": {"fr": unit("Plus tard", "new")}},
        }}
        info = {"sourceLanguage": "en", "version": "1.0", "strings": {
            "CFBundleDisplayName": {"localizations": {"ru": unit("Overbright"), "ja": unit("Overbright")}}}}
        json.dump(design, open(os.path.join(catalog_dir, "Localizable.xcstrings"), "w", encoding="utf-8"))
        json.dump(info, open(os.path.join(root, "App/InfoPlist.xcstrings"), "w", encoding="utf-8"))
        bundle = os.path.join(app, "Contents/Resources/OverbrightKit_OverbrightDesign.bundle/Contents/Resources")
        files = [f"{bundle}/ru.lproj/Localizable.strings", f"{bundle}/ru.lproj/Localizable.stringsdict",
                 f"{bundle}/de.lproj/Localizable.strings", f"{app}/Contents/Resources/ja.lproj/InfoPlist.strings"]
        for path in files:
            os.makedirs(os.path.dirname(path), exist_ok=True)
            open(path, "w").write("x")
        failures = []
        if problems(app, root):
            failures.append(f"a complete app fails: {problems(app, root)}")
        cases = [
            ("a missing .strings", lambda: os.remove(files[0]), "ru.lproj/Localizable.strings is missing"),
            ("a missing .stringsdict", lambda: os.remove(files[1]), "ru.lproj/Localizable.stringsdict is missing"),
            ("a needs_review language", lambda: os.remove(files[2]), "de.lproj/Localizable.strings is missing"),
            ("an empty lproj", lambda: os.makedirs(f"{bundle}/fr.lproj"), "fr.lproj is empty"),
            ("a removed language", lambda: (os.makedirs(f"{bundle}/it.lproj"), open(f"{bundle}/it.lproj/x.strings", "w")),
             "no catalog of this bundle has it"),
            ("a missing bundle", lambda: shutil.rmtree(os.path.dirname(os.path.dirname(bundle))),
             "OverbrightKit_OverbrightDesign.bundle/Contents/Resources is missing"),
        ]
        for label, damage, expected in cases:
            damage()
            found = problems(app, root)
            if not any(expected in problem for problem in found):
                failures.append(f"{label}: expected “{expected}”, got {found}")
            shutil.rmtree(app)
            for path in files:
                os.makedirs(os.path.dirname(path), exist_ok=True)
                open(path, "w").write("x")
        print("\n".join(failures) or f"check-lproj self-test OK ({len(cases) + 1} cases)")
        return 1 if failures else 0
    finally:
        shutil.rmtree(work, ignore_errors=True)


def main(argv):
    if argv[1:] == ["--self-test"]:
        return self_test()
    if len(argv) != 2:
        sys.exit(__doc__)
    app = argv[1]
    found = problems(app)
    if found:
        print("\n".join(found))
        print(f"error: {len(found)} localization(s) missing from {app}", file=sys.stderr)
        return 1
    pairs = sum(len(suffixes) for name, path, _ in catalogs(app) if name != os.path.join("App", "InfoPlist.xcstrings")
                for suffixes in required(json.load(open(path, encoding="utf-8"))).values())
    print(f"localizations OK: {pairs} compiled tables present, no stale .lproj")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
