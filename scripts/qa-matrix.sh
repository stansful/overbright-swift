#!/usr/bin/env bash
# The QA matrix under --qa-simulate (ARCHITECTURE.md §10.15, §8.5): every display fixture of §3.9 runs the standard
# scenario in the Debug app (on, Low Power, lock, a booster, dimming, off), dumps what the menu bar symbol, the banner
# and each card's chip show, snapshots the panel, quits, and the dumps are checked against the expectations
# `EndToEndScenarioTests` uses (scripts/qa_check.py). Then Welcome opens at its first two steps over the simulated
# ports, in a fresh suite (not finished), and must leave gammaWrites and triggerWindows at 0 (§10.14). Fakes only: no
# real display is touched (D24). Four runs at a time, each in a defaults suite of its own, deleted afterwards.
#
#   make debug; make qa-matrix                     # every fixture and the Welcome runs → build/logs/qa-matrix/
#   scripts/qa-matrix.sh builtin-xdr-lid-open lcd-only
source "$(dirname "$0")/lib.sh"

APP="${APP:-$BUILD_DIR/$APP_NAME.app}"
OUT="${OUT:-$BUILD_DIR/logs/qa-matrix}"
[[ -d "$APP" ]] || die "$APP not found; run make debug first"
codesign -d --entitlements - --xml "$APP" 2>/dev/null | grep -q "com.apple.security.get-task-allow" \
  || die "$APP is a Release build, which refuses --qa-simulate; run make debug"
FIXTURES=("$@")
(( ${#FIXTURES[@]} )) || FIXTURES=(builtin-xdr-lid-open builtin-xdr-preset-600 mpg322ux-hdr-on mpg322ux-hdr-off
                                   pro-display-xdr studio-display-xdr lcd-only sidecar hardware-mirror
                                   neo-ignores-writes calibrated-profile russian-names)
SUITE=app.overbright.Overbright.qa-matrix
WELCOME_DONE='<22302e312e3022>'      # JSON "0.1.0": Welcome finished, so the launch UI shows the panel
WELCOME_STEPS=(hello displays)             # step 1, and step 2 with its per-display extra brightness switches
WELCOME_SCRIPT='wait 3; dump welcome; wait 1; quit'
SCRIPT='on; wait 8; dump on; low-power on; wait 1; dump low-power; low-power off; wait 8; dump resumed; lock; wait 0.1; dump locked; unlock; wait 8; dump unlocked; conflict booster; wait 1; dump booster; conflict none; wait 8; dump clear; level -0.5; wait 1; dump dimmed; off; wait 1; dump off; wait 1; quit'
rm -rf "$OUT"; mkdir -p "$OUT"

run() {
  local fixture="$1"
  mkdir -p "$OUT/$fixture"
  /usr/bin/perl -e 'alarm shift; exec @ARGV' 180 /usr/bin/open -n -g -W "$APP" --args \
    --qa-simulate "$fixture" --qa-defaults-suite "$SUITE.$fixture" \
    -overbright.onboarding.completedVersion "$WELCOME_DONE" --qa-panel --qa-snapshot "$OUT/$fixture" \
    --qa-snapshot-at 12 --qa-script "$SCRIPT" --qa-status "$OUT/$fixture.jsonl" \
    || warn "$fixture did not quit in time"
  defaults delete "$SUITE.$fixture" >/dev/null 2>&1 || true
  rm -f "$HOME/Library/Preferences/$SUITE.$fixture.plist"
  log "$fixture done"
}

# Welcome at `step`, in a suite of its own that has never finished it: the scripted dump reads the fakes' counters.
welcome() {
  local step="$1" name="welcome-$1"
  /usr/bin/perl -e 'alarm shift; exec @ARGV' 60 /usr/bin/open -n -g -W "$APP" --args \
    --qa-simulate builtin-xdr-lid-open --qa-defaults-suite "$SUITE.$name" --qa-welcome "$step" \
    --qa-script "$WELCOME_SCRIPT" --qa-status "$OUT/$name.jsonl" \
    || warn "$name did not quit in time"
  defaults delete "$SUITE.$name" >/dev/null 2>&1 || true
  rm -f "$HOME/Library/Preferences/$SUITE.$name.plist"
  log "$name done"
}

index=0
for fixture in "${FIXTURES[@]}"; do
  run "$fixture" &
  index=$((index + 1))
  (( index % 4 == 0 )) && wait
done
for step in "${WELCOME_STEPS[@]}"; do
  welcome "$step" &
  index=$((index + 1))
  (( index % 4 == 0 )) && wait
done
wait
welcome_runs=()
for step in "${WELCOME_STEPS[@]}"; do welcome_runs+=("welcome-$step"); done
/usr/bin/python3 -I "$ROOT/scripts/qa_check.py" "$OUT" "${FIXTURES[@]}" "${welcome_runs[@]}" \
  || die "QA matrix failed (dumps in $OUT)"
log "QA matrix passed ($OUT)"
