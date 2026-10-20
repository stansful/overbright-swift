#!/usr/bin/env python3
"""Checks the QA matrix's dumps (scripts/qa-matrix.sh) against the expectations EndToEndScenarioTests uses.

Each dump is one JSON line of the app's `StatusSummary` (ARCHITECTURE.md §8.5 `--qa-status`): the menu bar symbol,
the banner's English sentence and each card's chip (DESIGN.md §4.1, §12.2, §12.3). A `welcome-<step>` run (Welcome
opened at that step by `--qa-welcome`, ARCHITECTURE.md §10.14) must have written no table and opened no trigger window.
Usage:
    qa_check.py <dir> [fixture | welcome-<step> ...]
"""
import json
import os
import sys

LOW = "Paused because Low Power Mode is on."
BOOSTER = "Paused because ⁨QA booster⁩ also changes display brightness. Quit it to continue."
ON = ["on", "low-power", "resumed", "locked", "unlocked", "booster", "clear"]


def boosting(role, others=None):
    rows = [("on", "on", None, (None, "boosted")), ("low-power", "paused", LOW, (None, "idle")),
            ("resumed", "on", None, (None, "boosted")), ("locked", "paused", None, (None, "suspended")),
            ("unlocked", "on", None, (None, "boosted")), ("booster", "attention", BOOSTER, (None, "idle")),
            ("clear", "on", None, (None, "boosted")), ("dimmed", "dimming", None, (None, "dimmed")),
            ("off", "off", None, (None, "idle"))]
    expected = {}
    for label, symbol, banner, card in rows:
        cards = {role: card}
        cards.update((others or {}).get(label, {}))
        expected[label] = (symbol, banner, cards)
    return expected


def others(role, card, dimmed):
    result = {label: {role: card} for label in ON}
    result["dimmed"] = {role: dimmed}
    result["off"] = {role: (None, "idle")}
    return result


def not_boosting(role, chip, dimmed_chip, quiet=()):
    expected = {label: ("on", None, {role: (None if label in quiet else chip, "idle")}) for label in ON}
    expected["dimmed"] = ("dimming", None, {role: (dimmed_chip, "dimmed")})
    expected["off"] = ("off", None, {role: (None, "idle")})
    return expected


def preset600():
    expected = boosting("built-in")
    for label in ["on", "resumed", "unlocked", "clear"]:
        expected[label] = ("preparing", None, {"built-in": ("Preparing…", "preparing")})
    return expected


EXPECTED = {
    "builtin-xdr-lid-open": boosting("built-in"),
    "calibrated-profile": boosting("built-in"),
    "neo-ignores-writes": boosting("built-in"),
    "pro-display-xdr": boosting("pro"),
    "sidecar": boosting("built-in", others("sidecar", (None, "idle"), (None, "idle"))),
    "hardware-mirror": boosting("built-in", others("projector", ("Mirrored", "idle"), ("Mirrored", "dimmed"))),
    "russian-names": boosting("built-in", others("msi", ("Extra brightness off", "idle"), (None, "dimmed"))),
    "mpg322ux-hdr-on": not_boosting("msi", "Extra brightness off", None),
    "mpg322ux-hdr-off": not_boosting("msi", "HDR is off", "HDR is off"),
    "lcd-only": not_boosting("built-in", "Not supported", "Not supported"),
    "studio-display-xdr": not_boosting("studio", "Safe limit", None, ("low-power", "locked", "booster")),
    "builtin-xdr-preset-600": preset600(),
}


def state(phase):
    for name in ["boosted", "dimmed", "suspended", "failed"]:
        if phase.startswith(name):
            return name
    return "preparing" if phase.startswith(("arming", "gating")) else "idle"


def check(directory, fixture):
    path = os.path.join(directory, fixture + ".jsonl")
    dumps = {}
    if os.path.exists(path):
        for line in open(path, encoding="utf-8"):
            if line.strip():
                dump = json.loads(line)
                dumps[dump["label"]] = dump
    problems = []
    for label, (symbol, banner, cards) in EXPECTED[fixture].items():
        dump = dumps.get(label)
        if dump is None:
            problems.append(f"{label}: no dump")
            continue
        if dump["symbol"] != symbol:
            problems.append(f"{label}: symbol {dump['symbol']} != {symbol}")
        if dump.get("banner") != banner:
            problems.append(f"{label}: banner {dump.get('banner')!r} != {banner!r}")
        for role, (chip, expected_state) in cards.items():
            display = next((d for d in dump["displays"] if d["display"] == role), None)
            if display is None:
                problems.append(f"{label}: no {role}")
                continue
            if display.get("chip") != chip:
                problems.append(f"{label}: {role} chip {display.get('chip')!r} != {chip!r}")
            if state(display["phase"]) != expected_state:
                problems.append(f"{label}: {role} state {state(display['phase'])} != {expected_state}")
    if dumps.get("off", {}).get("triggerWindows") != 0:
        problems.append("off: trigger windows left open")
    # A Mac that ignores color table changes still gets them (ARCHITECTURE.md §7.5): the color table is the only method.
    if fixture == "neo-ignores-writes" and not dumps.get("on", {}).get("gammaWrites"):
        problems.append("on: no color table written")
    return problems


WELCOME_STEPS = ["hello", "displays", "defaults", "findIt", "done"]


def check_welcome(directory, name):
    """§10.14: Welcome under --qa-simulate leaves the displays alone: gammaWrites and triggerWindows stay 0."""
    path = os.path.join(directory, name + ".jsonl")
    dumps = [json.loads(line) for line in open(path, encoding="utf-8") if line.strip()] if os.path.exists(path) else []
    welcome = [dump for dump in dumps if dump.get("label") == "welcome"]
    if not welcome:
        return ["welcome: no dump"]
    problems = []
    for key in ("gammaWrites", "triggerWindows"):
        if welcome[-1].get(key) != 0:
            problems.append(f"welcome: {key} is {welcome[-1].get(key)!r}, must be 0 (Welcome touches no display)")
    return problems


def main():
    directory = sys.argv[1]
    fixtures = sys.argv[2:] or sorted(EXPECTED)
    failed = 0
    for fixture in fixtures:
        if fixture.startswith("welcome-") and fixture[len("welcome-"):] in WELCOME_STEPS:
            problems = check_welcome(directory, fixture)
            failed += bool(problems)
            print(("FAIL " if problems else "ok   ") + fixture + (": " + "; ".join(problems) if problems else ""))
            continue
        if fixture not in EXPECTED:
            print(f"?    {fixture}: no expectations")
            failed += 1
            continue
        problems = check(directory, fixture)
        failed += bool(problems)
        print(("FAIL " if problems else "ok   ") + fixture + (": " + "; ".join(problems) if problems else ""))
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
