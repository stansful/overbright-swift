#!/usr/bin/env bash
# Launch smoke test of build/Overbright.app without UI. ARCHITECTURE.md §8.4, §8.7, D24.
# `Overbright --diagnostics <json>` writes a read-only report and quits before any service starts: it may read
# tables, profile bases and EDR values, never write a table, arm a trigger or open a window. Checks:
#   - the report: gammaWrites == 0 and triggerWindows == 0 (nothing touched the displays), `displays` is a list
#     (CI VMs have none), every OverbrightKit resource bundle is embedded, the Edit menu exists;
#   - privacy: no entitlement except Debug's get-task-allow, no *UsageDescription key, LSUIElement is true;
#   - the update check (D2): OverbrightGitHubRepository is empty (no network) or "owner/repo", and equals
#     $OVERBRIGHT_GITHUB_REPOSITORY when that is set (release.yml builds with it);
#   - languages: CFBundleLocalizations lists exactly the languages of scripts/lib/l10n/languages.json; every translation
#     the String Catalogs hold is compiled into its bundle and no stale .lproj is left (scripts/lib/check-lproj.py); the
#     report's Design sentence in Russian is Russian (a package bundle without its table falls back to English);
#   - the Controls extension (D18): Contents/PlugIns holds OverbrightControls.appex exactly when CONTROLS=1, and the
#     extension's entitlements are the sandbox and the read-only preference exception only;
#   - App Intents: Contents/Resources/Metadata.appintents lists every intent of §7.7 and the Focus filter
#     (the type names of DESIGN.md §12.8);
#   - no shader source in the bundle (D22);
#   - a Release build refuses a Debug-only switch (`--qa-simulate`): exit 64, nothing written (§8.5).
#
#   scripts/lib/smoke.sh                       # uses build/Overbright.app
#   APP=/path/Overbright.app scripts/lib/smoke.sh
#   CONTROLS=1 scripts/lib/smoke.sh            # after `CONTROLS=1 make build`
#   SIMULATE=1 scripts/lib/smoke.sh            # agents (D24, CONTRIBUTING): never launches on the real ports. A Debug
#                                              # build reports over `--qa-simulate`'s fakes; a Release build (which
#                                              # refuses the switch) gets the static checks and the refusal check only,
#                                              # and the read-only report on the real ports is left to CI and the owner.
source "$(dirname "$0")/lib.sh"

APP="${APP:-$BUILD_DIR/$APP_NAME.app}"
[[ -d "$APP" ]] || die "$APP not found; run scripts/lib/build.sh first"
OUT="$BUILD_DIR/logs/diagnostics.json"
REFUSED_OUT="$BUILD_DIR/logs/diagnostics-refused.json"
mkdir -p "$BUILD_DIR/logs"; rm -f "$OUT" "$REFUSED_OUT"
ENTITLEMENTS="$BUILD_DIR/logs/entitlements.plist"
codesign -d --entitlements - --xml "$APP" > "$ENTITLEMENTS" 2>/dev/null || die "codesign could not read $APP's entitlements"
# Only a Debug build carries get-task-allow, and only a Debug build honours the QA switches of §8.5.
grep -q "com.apple.security.get-task-allow" "$ENTITLEMENTS" && debug_build=1 || debug_build=0
# No `timeout` on macOS: perl's alarm kills the app if it hangs (exit 142).
# `--diagnostics` writes no preference; a Debug build also reads its settings from a suite of its own
# (`--qa-defaults-suite`), never from the user's. A Release build gets no QA switch: it would refuse to start.
qa_args=()
(( debug_build )) && qa_args=(--qa-defaults-suite app.overbright.Overbright.smoke)
simulate="${SIMULATE:-0}"
(( debug_build )) && [[ "$simulate" == 1 ]] && qa_args+=(--qa-simulate builtin-xdr-lid-open)
report=1
if [[ "$simulate" == 1 ]] && (( ! debug_build )); then
  report=0
  warn "SIMULATE=1 on a Release build: the --diagnostics report on the real ports is skipped (CI and the owner run it)"
else
  /usr/bin/perl -e 'alarm shift; exec @ARGV' 60 "$APP/Contents/MacOS/$APP_NAME" \
    ${qa_args[@]+"${qa_args[@]}"} --diagnostics "$OUT" >/dev/null 2>&1 \
    || die "$APP_NAME --diagnostics failed or timed out"
  [[ -s "$OUT" ]] || die "no diagnostics written"
fi

# A Release build never ignores a Debug-only switch (it would then run on the real ports): it exits with
# EX_USAGE (64) before anything starts, so not even the read-only report is written.
if (( ! debug_build )); then
  set +e
  /usr/bin/perl -e 'alarm shift; exec @ARGV' 60 "$APP/Contents/MacOS/$APP_NAME" \
    --qa-simulate builtin-xdr-lid-open --qa-defaults-suite app.overbright.Overbright.smoke \
    --diagnostics "$REFUSED_OUT" >/dev/null 2>&1
  status=$?
  set -e
  (( status == 64 )) || die "a Release build must refuse --qa-simulate with exit 64, got $status"
  [[ ! -e "$REFUSED_OUT" ]] || die "a Release launch with --qa-simulate wrote $REFUSED_OUT"
  log "Release build refuses Debug-only switches (exit 64)"
fi

# Only compiled code ships: no shader sources or headers in any bundle (D22).
sources="$(find "$APP/Contents" \( -name '*.metal' -o -name '*.h' \) -print | head -5)"
[[ -z "$sources" ]] || die "shader sources or headers are in the app: $sources"

APPEX="$APP/Contents/PlugIns/$CONTROLS_APPEX"
APPEX_ENTITLEMENTS="$BUILD_DIR/logs/entitlements-controls.plist"
rm -f "$APPEX_ENTITLEMENTS"
if [[ -d "$APPEX" ]]; then
  codesign -d --entitlements - --xml "$APPEX" > "$APPEX_ENTITLEMENTS" 2>/dev/null \
    || die "codesign could not read the Controls extension's entitlements"
fi
controls_enabled && want_controls=1 || want_controls=0
/usr/bin/python3 -I - "$APP" "$ENTITLEMENTS" "$APPEX_ENTITLEMENTS" "$want_controls" "$ROOT/scripts/lib/l10n/languages.json" \
  "${OVERBRIGHT_GITHUB_REPOSITORY:-}" <<'PY' \
  || die "the app's entitlements, privacy keys, update check, languages, extension or intents are wrong (see above)"
import json, os, plistlib, re, sys
app, entitlements_path, appex_entitlements_path, want_controls, languages_path, wanted_repository = sys.argv[1:7]

def entitlements_at(path):
    if not os.path.exists(path):
        return None
    raw = open(path, "rb").read()
    return {k for k, v in (plistlib.loads(raw) if raw.strip() else {}).items() if v}

problems = []
# Privacy surface (ARCHITECTURE.md §8.6): not sandboxed, no TCC resource, so no entitlement at all.
debug_only = {"com.apple.security.get-task-allow"}
entitlements = entitlements_at(entitlements_path) or set()
problems += [f"unexpected entitlement {e}" for e in sorted(entitlements - debug_only)]
info = plistlib.load(open(os.path.join(app, "Contents/Info.plist"), "rb"))
problems += [f"{k} present: Overbright asks for no permission" for k in sorted(info) if k.endswith("UsageDescription")]
if info.get("LSUIElement") is not True:
    problems.append("LSUIElement is not true (Overbright is a menu bar app)")
# The update check (D2): empty = off and no network; otherwise the GitHub repository it asks.
repository = info.get("OverbrightGitHubRepository")
if not isinstance(repository, str) or (repository and not re.fullmatch(r"[A-Za-z0-9._-]+/[A-Za-z0-9._-]+", repository)):
    problems.append(f"OverbrightGitHubRepository is {repository!r}: it must be empty or owner/repo")
elif wanted_repository and repository != wanted_repository:
    problems.append(f"OverbrightGitHubRepository is {repository!r}, but the build asked for {wanted_repository!r}")

languages = json.load(open(languages_path, encoding="utf-8"))
codes = [l["code"] for l in languages]
advertised = info.get("CFBundleLocalizations", [])
missing = [c for c in codes if c not in advertised]
if missing:
    problems.append("CFBundleLocalizations lacks " + ", ".join(missing) + " (App/Info.plist; macOS would show the "
                    "packages' translations in English)")
problems += [f"CFBundleLocalizations has {c}, which is not in scripts/lib/l10n/languages.json" for c in advertised
             if c not in codes]

# The dormant Controls extension (D18): present exactly when CONTROLS=1, sandboxed with one read-only exception.
plugins = os.path.join(app, "Contents/PlugIns")
appexes = sorted(os.listdir(plugins)) if os.path.isdir(plugins) else []
if want_controls == "1":
    if appexes != ["OverbrightControls.appex"]:
        problems.append(f"CONTROLS=1 but Contents/PlugIns holds {appexes or 'nothing'}")
    allowed = {"com.apple.security.app-sandbox", "com.apple.security.temporary-exception.shared-preference.read-only"}
    found = entitlements_at(appex_entitlements_path) or set()
    problems += [f"Controls extension: unexpected entitlement {e}" for e in sorted(found - allowed - debug_only)]
    if "com.apple.security.app-sandbox" not in found:
        problems.append("Controls extension is not sandboxed (WidgetKit extensions must be)")
elif appexes:
    problems.append(f"Contents/PlugIns holds {appexes} without CONTROLS=1 (scripts/lib/build.sh removes the extension)")

# App Intents (§7.7): every intent and the Focus filter are in the extracted metadata, by the type names of
# DESIGN.md §12.8. WP0a created App/Intents/ with placeholder declarations under exactly these names (§10.1), so the
# check is the same before and after WP8 replaces their bodies; the Focus filter must carry the FocusConfiguration
# system protocol (a SetFocusFilterIntent).
intents = ["ToggleOverbrightIntent", "TurnOnOverbrightIntent", "TurnOffOverbrightIntent", "SetExtraBrightnessIntent",
           "DimDisplaysIntent", "PauseOverbrightIntent", "ResumeOverbrightIntent", "GetOverbrightStateIntent",
           "ReturnToStandardIntent", "OverbrightFocusFilter"]
metadata = os.path.join(app, "Contents/Resources/Metadata.appintents/extract.actionsdata")
if not os.path.exists(metadata):
    problems.append("Contents/Resources/Metadata.appintents/extract.actionsdata is missing (no App Intents extracted)")
else:
    actions = json.load(open(metadata, encoding="utf-8")).get("actions", {})
    problems += [f"App Intents metadata lacks {name}" for name in intents if name not in actions]
    focus = actions.get("OverbrightFocusFilter", {}).get("systemProtocols", [])
    if "OverbrightFocusFilter" in actions and not any(p.endswith(".FocusConfiguration") for p in focus):
        problems.append("OverbrightFocusFilter is not a Focus filter (no FocusConfiguration system protocol)")

print("\n".join(problems) or "privacy OK: no entitlements, no usage strings, LSUIElement; update check %s; "
      "%d languages advertised; Controls extension %s; %d intents in the metadata"
      % (f"asks {repository}" if repository else "off", len(advertised), "present" if appexes else "absent", len(intents)))
sys.exit(1 if problems else 0)
PY

/usr/bin/python3 -I "$ROOT/scripts/lib/check-lproj.py" "$APP" || die "the app lacks compiled translations (see above)"

if (( report )); then
expected=$(find "$PACKAGE_DIR/Sources" -mindepth 2 -maxdepth 2 -name Resources -type d | wc -l | tr -d ' ')
/usr/bin/python3 -I - "$OUT" "$expected" "$simulate" <<'PY' || die "smoke test failed (see $OUT)"
import json, sys
r = json.load(open(sys.argv[1])); expected = int(sys.argv[2]); simulate = sys.argv[3] == "1"
problems = []
if simulate and not r.get("simulatedFixture"):
    problems.append("SIMULATE=1 but the report did not come from the simulated ports")
bundles = r.get("resourceBundles", [])
if len(bundles) != expected:
    problems.append(f"resource bundles {len(bundles)} != {expected} (Sources/*/Resources)")
if not any(len(items) >= 4 for m in r.get("mainMenu", []) for items in m.values()):
    problems.append("no Edit menu key equivalents")
# D24: diagnostics is read-only. Nothing may have written a table or opened a trigger window.
for key in ("gammaWrites", "triggerWindows"):
    if r.get(key) != 0:
        problems.append(f"{key} is {r.get(key, '(missing)')}, must be 0 (diagnostics must not touch the displays)")
if not isinstance(r.get("displays"), list):
    problems.append("displays is missing or not a list")
# The catalog wiring: Design's bundle answers in Russian. "(no bundle)", "(no ru localization)", "(missing)" or the
# English key itself mean the bundle's ru table did not ship, and every Russian user would read English.
english = "Overbright is reading this display."
russian = r.get("designString.ru")
if not isinstance(russian, str) or russian == english or (russian.startswith("(") and russian.endswith(")")):
    problems.append(f"designString.ru is {russian!r}: Design's Russian table is not in the app")
print("\n".join(problems) or "smoke OK: %d bundles, Edit menu present, diagnostics read-only (%d displays), "
      "privacy: none" % (expected, len(r["displays"])))
sys.exit(1 if problems else 0)
PY
fi
if (( report )); then log "Smoke test passed ($OUT)"; else log "Smoke test passed (static and refusal checks; no report on real ports)"; fi
