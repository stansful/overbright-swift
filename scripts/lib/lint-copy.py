#!/usr/bin/env python3
"""Copy rules for every String Catalog, and the clean-room scan of the sources. No Xcode needed.
Ported from Cranny; ARCHITECTURE.md D3, §8.7, §8.8.

The catalog rules apply per language, to every catalog: Packages/OverbrightKit/Sources/*/Resources/*.xcstrings,
App/*.xcstrings and Controls/*.xcstrings. English, the source (every key: the key itself, or its English value when
the key is an identifier or has a `defaultValue:`):

- American English: no British spellings ("colour", "customise", "licence", ...).
- Typographic punctuation: ' and " are written as ’ and “ ” and three dots as one ….
- System Settings is named by its pane ("Login Items in System Settings"), never by a ▸ path, because the
  path differs between macOS versions. Overbright's own "Settings ▸ Displays" paths are fine.

Every other language a catalog holds (each must be in scripts/lib/l10n/languages.json):

- Typographic punctuation: no ASCII " or ' unless that language's quote style (languages.json "quoteStyle", as
  macOS writes it: Arabic uses straight quotes) has them; one … instead of three dots.

Every language, the source included, in keys, values and translator comments:

- Clean room (D3): no competitor product or company names (the denylist below).

The source scan (D3; also the Core test noDenylistedNamesOutsideAllowlist) looks for the same names in every text file
of the repository: every file git tracks, and every untracked file .gitignore does not exclude (outside a git
checkout, every file under the root except build outputs, SwiftPM caches and per-user state). That covers the repo
root (README.md, THIRD_PARTY_NOTICES.md, Makefile, .gitattributes), .github/workflows, Overbright.xcodeproj and
Package.swift as well as the sources, tests, scripts and docs. Allowed:
(1) Packages/OverbrightKit/Sources/OverbrightPolicy/Conflicts/ConflictCatalog.swift, inside string literals shaped
like a bundle ID or an executable name only; (2) the denylist definitions in scripts/lib/lint-copy.py and
scripts/lib/l10n/l10n.py, only on lines marked denylist-ok; (3) Markdown lines carrying <!-- denylist-ok -->;
(4) docs/research/ as a whole.

scripts/lib/l10n/validate.py checks translations in depth (placeholders, plural forms, quote characters, "Overbright").

    python3 -I scripts/lib/lint-copy.py                       # every catalog + the source scan
    python3 -I scripts/lib/lint-copy.py OverbrightBoost App   # just these targets' catalogs ("App" = App/*.xcstrings,
                                                              # "Controls" = Controls/*.xcstrings); no source scan

Exit status 1 lists every problem as `catalog: "key": problem` or `path:line: problem`.
"""

import glob
import json
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
PACKAGE = "Packages/OverbrightKit"

# British spellings and the American form to use. Matched as whole words or word starts, case-insensitively.
BRITISH = {
    r"colour": "color",
    r"customis": "customiz",
    r"grey": "gray",
    r"behaviour": "behavior",
    r"licence": "license",
    r"organis": "organiz",
    r"favourit": "favorit",
    r"analys(?=e\b|ed\b|ing\b)": "analyz",            # not "analyses", the plural of "analysis"
    r"recognis": "recogniz",
    r"minimis": "minimiz",
    r"maximis": "maximiz",
    r"optimis": "optimiz",
    r"prioritis": "prioritiz",
    r"personalis": "personaliz",
    r"summaris": "summariz",
    r"synchronis": "synchroniz",
    r"visualis": "visualiz",
    r"authoris": "authoriz",
    r"initialis": "initializ",
    r"normalis": "normaliz",
    r"categoris": "categoriz",
    r"apologis": "apologiz",
    r"realis(?=e\b|ed\b|es\b|ing\b|ation)": "realiz",
    r"centre": "center",
    r"cancell(?=ed|ing)": "cancel",
    r"labell(?=ed|ing)": "label",
    r"travell": "travel",
    r"honour": "honor",
    r"neighbour": "neighbor",
    r"catalogue": "catalog",
    r"dialogue": "dialog",
    r"acknowledgement": "acknowledgment",
    r"judgement": "judgment",
    r"programme": "program",
    r"whilst": "while",
    r"amongst": "among",
    r"defence": "defense",
    r"artefact": "artifact",
}
BRITISH_RE = [(re.compile(r"\b" + stem, re.IGNORECASE), us) for stem, us in BRITISH.items()]
# Competitor product and company names (ARCHITECTURE.md D3); the same patterns are in scripts/lib/l10n/l10n.py.
# Case-insensitive, except the one name that is an ordinary word in Romanian, Spanish, Catalan and Portuguese.
DENYLIST = re.compile(r"v[iíì]v[iíì]d|lumen[\s-]*digital|bright[\s-]*intosh|better[\s-]*display", re.IGNORECASE)  # denylist-ok
DENYLIST_CASED = re.compile(r"\bLunar\b|lunar\.app|fyi\.lunar")  # denylist-ok
SETTINGS_PATH = re.compile(r"System Settings\s*▸")
LANGUAGES = os.path.join(ROOT, "scripts/lib/l10n/languages.json")

# The source scan (D3): every text file of the repository (scanned_files).
WALK_SKIPPED = {".git", ".swiftpm", "__pycache__", "build", "dist", "DerivedData", ".derived", "xcuserdata", ".idea"}
MUST_SCAN = ["README.md", "THIRD_PARTY_NOTICES.md", "Makefile", ".github/workflows/ci.yml", f"{PACKAGE}/Package.swift",
             "Overbright.xcodeproj/project.pbxproj", "docs/ARCHITECTURE.md"]
CONFLICT_CATALOG = f"{PACKAGE}/Sources/OverbrightPolicy/Conflicts/ConflictCatalog.swift"
MARKED_DEFINITIONS = {"scripts/lib/lint-copy.py", "scripts/lib/l10n/l10n.py"}
SKIP_SUFFIXES = (".png", ".jpg", ".jpeg", ".icns", ".pdf", ".mov", ".car", ".zip", ".dmg")
# A string literal shaped like a bundle ID or an executable name: no spaces, only these characters.
IDENTIFIER_LITERAL = re.compile(r'"[A-Za-z0-9._-]+"')


def denylisted(text):
    """The first denylisted name in `text`, or None."""
    match = DENYLIST.search(text) or DENYLIST_CASED.search(text)
    return match.group(0) if match else None


def quote_styles():
    """{language: set of ASCII quote characters its style allows} from scripts/lib/l10n/languages.json."""
    with open(LANGUAGES, encoding="utf-8") as handle:
        table = json.load(handle)
    return {entry["code"]: set("".join(entry["quoteStyle"]["primary"] + entry["quoteStyle"]["secondary"])) & {"'", '"'}
            for entry in table}


def catalogs(targets):
    if not targets:
        found = sorted(glob.glob(os.path.join(ROOT, PACKAGE, "Sources/*/Resources/*.xcstrings")))
        return found + sorted(glob.glob(os.path.join(ROOT, "App/*.xcstrings"))) + \
            sorted(glob.glob(os.path.join(ROOT, "Controls/*.xcstrings")))
    paths = []
    for target in targets:
        if target in ("App", "Controls"):
            found = sorted(glob.glob(os.path.join(ROOT, target, "*.xcstrings")))
        else:
            found = sorted(glob.glob(os.path.join(ROOT, PACKAGE, f"Sources/{target}/Resources/*.xcstrings")))
        if not found:
            sys.exit(f"error: no String Catalog for {target}")
        paths += found
    return paths


def values(node):
    """Every `value` string under a localization (string units, plural and device variations)."""
    if isinstance(node, dict):
        for name, child in node.items():
            if name == "value" and isinstance(child, str):
                yield child
            else:
                yield from values(child)
    elif isinstance(node, list):
        for child in node:
            yield from values(child)


def is_identifier(key):
    """Keys such as "display.verdict.supported" or "NSHumanReadableCopyright" are not English text."""
    return re.fullmatch(r"[a-z][A-Za-z0-9]*(\.[A-Za-z0-9]+)+|(NS|CF)[A-Za-z]+", key) is not None


def english(key, entry):
    texts = list(values(entry.get("localizations", {}).get("en", {})))
    if not is_identifier(key):
        texts.insert(0, key)
    return texts


def problems_in(text):
    for pattern, us in BRITISH_RE:
        match = pattern.search(text)
        if match:
            yield f"British spelling “{match.group(0)}…” (American: {us}…)"
    if "'" in text:
        yield "straight apostrophe (use ’)"
    if '"' in text:
        yield "straight quotation mark (use “ ”)"
    if "..." in text:
        yield "three dots (use …)"
    if SETTINGS_PATH.search(text):
        yield "System Settings path (name the pane instead: “Login Items in System Settings”)"


def translation_problems(text, language, allowed_ascii):
    """The rules for a language other than English: typographic quotes in its style, one-character ellipsis."""
    if "'" in text and "'" not in allowed_ascii:
        yield f"straight apostrophe or quote ' in {language} (use ’ or the language’s quotes)"
    if '"' in text and '"' not in allowed_ascii:
        yield f"straight quotation mark \" in {language} (use the language’s quotes)"
    if "..." in text:
        yield f"three dots in {language} (use …)"


def catalog_problems(paths):
    problems = []
    styles = quote_styles()
    for path in paths:
        name = os.path.relpath(path, ROOT)
        with open(path, encoding="utf-8") as handle:
            strings = json.load(handle).get("strings", {})
        for key, entry in sorted(strings.items()):
            shown = json.dumps(key, ensure_ascii=False)
            # Clean room first, and for every entry: stale and untranslatable keys and comments ship to translators too.
            for text in [key, entry.get("comment", ""), *values(entry.get("localizations", {}))]:
                found = denylisted(text)
                if found:
                    problems.append(f"{name}: {shown}: competitor name “{found}” (ARCHITECTURE.md D3)")
                    break
            if entry.get("extractionState") == "stale" or entry.get("shouldTranslate") is False:
                continue
            seen = set()
            for text in english(key, entry):
                for problem in problems_in(text):
                    if problem not in seen:
                        seen.add(problem)
                        problems.append(f"{name}: {shown}: {problem}")
            for language, localization in sorted(entry.get("localizations", {}).items()):
                if language == "en":
                    continue
                if language not in styles:
                    problems.append(f"{name}: {shown}: language “{language}” is not in scripts/lib/l10n/languages.json")
                    continue
                seen = set()
                for text in values(localization):
                    for problem in translation_problems(text, language, styles[language]):
                        if problem not in seen:
                            seen.add(problem)
                            problems.append(f"{name}: {shown}: {problem}")
    return problems


def allowed_line(rel, line, match_text):
    """Whether a denylisted name on this line is inside the allowlist of D3."""
    if rel.startswith("docs/research/"):
        return True
    if rel.endswith(".md") and "<!-- denylist-ok -->" in line:
        return True
    if rel in MARKED_DEFINITIONS and "denylist-ok" in line:
        return True
    if rel == CONFLICT_CATALOG:
        # Every occurrence must sit inside a bundle-ID-shaped or executable-name string literal.
        literals = IDENTIFIER_LITERAL.findall(line)
        stripped = IDENTIFIER_LITERAL.sub('""', line)
        return any(denylisted(literal) for literal in literals) and denylisted(stripped) is None
    return False


def scanned_files():
    """Repository-relative paths of the files the clean-room scan reads (binary formats left out): what git tracks plus
    the untracked files .gitignore does not exclude, or, outside a git checkout, a walk of the root without build
    outputs, SwiftPM caches and per-user state. The same set as SourceScan.repositoryFiles() in the Core tests."""
    try:
        listed = subprocess.run(["git", "-C", ROOT, "ls-files", "-z", "--cached", "--others", "--exclude-standard"],
                                capture_output=True, check=True).stdout.decode("utf-8")
        paths = {path for path in listed.split("\0") if path}
    except (OSError, subprocess.CalledProcessError, UnicodeDecodeError):
        paths = set()
        for current, dirs, files in os.walk(ROOT):
            dirs[:] = [d for d in dirs if not d.startswith(".build") and d not in WALK_SKIPPED]
            paths.update(os.path.relpath(os.path.join(current, file), ROOT) for file in files)
    return sorted(path for path in paths
                  if not path.endswith(SKIP_SUFFIXES) and os.path.basename(path) != ".DS_Store"
                  and os.path.isfile(os.path.join(ROOT, path)))


def source_problems():
    problems = []
    files = scanned_files()
    problems += [f"{path}: not in the clean-room scan (scripts/lib/lint-copy.py scanned_files)" for path in MUST_SCAN
                 if path not in files]
    for rel in files:
        try:
            with open(os.path.join(ROOT, rel), encoding="utf-8") as handle:
                lines = handle.readlines()
        except (UnicodeDecodeError, OSError):
            continue
        for number, line in enumerate(lines, 1):
            found = denylisted(line)
            if found and not allowed_line(rel, line, found):
                problems.append(f"{rel}:{number}: competitor name “{found}” outside the D3 allowlist")
    return problems


def main(argv):
    targets = argv[1:]
    problems = catalog_problems(catalogs(targets))
    if not targets:
        problems += source_problems()
    if problems:
        print("\n".join(problems))
        print(f"error: {len(problems)} copy problem(s); see docs/CONTRIBUTING.md, \"Copy\", and ARCHITECTURE.md D3",
              file=sys.stderr)
        return 1
    print("Copy rules OK" + ("" if targets else "; no competitor names outside the D3 allowlist"))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
