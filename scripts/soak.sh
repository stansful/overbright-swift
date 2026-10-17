#!/usr/bin/env bash
# Soak under --qa-simulate (ARCHITECTURE.md §10.15, DESIGN.md §17): the Debug app opens and closes its panel once, runs
# off for 2 minutes with the panel closed, then scripted cycles of events for most of MINUTES (on, the panel opened and
# closed, Max, Brighter, Less Bright, Low Power, lock, sleep, a reconfiguration, a screen-parameters change, a colour
# app, dimming, Dim All, Back to Standard, off), then off for 6 minutes. Beside it runs a control
# (scripts/soak-control.swift): a menu bar app that does nothing but subscribe to what Overbright subscribes to at
# rest (a status item, the keyboard layout). perf.sh's read-only `pidstat` (lib.sh `build_perf_tools`) reads both
# every 10 s: cumulative interrupt wake-ups (proc_pid_rusage), which the judge counts; `top` samples both too, as a
# cross-check of its IDLEW, which reads 0 for every process on a loaded Mac. `footprint` and `vmmap` run after every
# cycle and at the off phases. scripts/soak_judge.py then judges the run (its header has the rules): a wake-up in the
# same 10 s sample as one of the control's is the system's (a keyboard layout switch, the window server, which hand
# them to every such app) and is counted as shared. In the final off phase Overbright's own may neither beat
# periodically nor exceed 0.05/s; after launch they must not beat periodically (4 or more in a row that beat more
# evenly than random times do 98 % of the time); in every phase, own wake-ups in every sample fail, and shared ones
# must not hide a rhythm of Overbright's own. The footprint after the launch and one panel open and close stays under
# 40 MB (40.0 fails); its least-squares growth over cycles 3…N, at its lower 2-standard-error bound, stays within
# LEAK_KB per cycle (100), and the end within LEAK_MB (5) of cycle 3; the footprint before the cycles and after cycles
# 1 and 2 (caches filling) is reported, not judged. A run must have 5 cycles after cycle 3, so MINUTES is at least
# 17. The app's own preferences domain must read the same after the run as before (§8.5; `defaults export`,
# read-only). The literal "0 idle wake-ups while off" on a quiet machine is the owner's run (HARDWARE-TEST §13).
# Fakes only: no real display is touched (D24). `pidstat`, `footprint` and `vmmap` read the process; nothing attaches
# a debugger.
#
#   make debug; make soak                  # 30 minutes → build/logs/soak/
#   MINUTES=17 scripts/soak.sh             # the shortest run that is judged
source "$(dirname "$0")/lib.sh"

APP="${APP:-$BUILD_DIR/$APP_NAME.app}"
TOOLS="${TOOLS:-$BUILD_DIR/logs/perf/tools}"
OUT="${OUT:-$BUILD_DIR/logs/soak}"
MINUTES="${MINUTES:-30}"
LEAK_MB="${LEAK_MB:-5}"
LEAK_KB="${LEAK_KB:-100}"
FIRST_OFF=120
FINAL_OFF=360
[[ -d "$APP" ]] || die "$APP not found; run make debug first"
codesign -d --entitlements - --xml "$APP" 2>/dev/null | grep -q "com.apple.security.get-task-allow" \
  || die "$APP is a Release build, which refuses --qa-simulate; run make debug"
CYCLES=$(( (MINUTES * 60 - FIRST_OFF - FINAL_OFF) / 66 ))
MIN_CYCLES="$(/usr/bin/python3 -I "$ROOT/scripts/soak_judge.py" --minimum-cycles)"
min_minutes=$(( (MIN_CYCLES * 66 + FIRST_OFF + FINAL_OFF + 59) / 60 ))
(( CYCLES >= MIN_CYCLES )) \
  || die "MINUTES=$MINUTES gives $CYCLES cycles; growth is judged over $MIN_CYCLES or more, so MINUTES must be at least $min_minutes"
SUITE="app.overbright.Overbright.soak.$$"
WELCOME_DONE='<22302e312e3022>'
CYCLE='on; wait 6; panel open; wait 2; panel close; level max; wait 2; brighter; wait 1; less; wait 2; low-power on; wait 1; low-power off; wait 6; lock; wait 1; unlock; wait 6; sleep; wait 1; wake; wait 8; event reconfigured; wait 3; event screen-parameters; wait 1; conflict writer; wait 1; conflict none; wait 6; dim 40; wait 2; dim-all; wait 2; standard; wait 1; on; level bright-room; wait 6; off; wait 4; dump cycle-end'
SCRIPT="dump start; wait 3; panel open; wait 2; panel close; wait $FIRST_OFF; dump first-off-end"
for _ in $(seq 1 "$CYCLES"); do SCRIPT="$SCRIPT; $CYCLE"; done
SCRIPT="$SCRIPT; off; wait 2; dump final-off-start; wait $FINAL_OFF; dump final-off-end; wait 30; quit"

ensure_xcode
build_perf_tools "$TOOLS"

rm -rf "$OUT"; mkdir -p "$OUT"
app_domain_export "$OUT/app-domain-before.plist"
defaults delete "$SUITE" >/dev/null 2>&1 || true
log "Soak: $MINUTES minutes, $CYCLES cycles, output in $OUT"
/usr/bin/open -n -g "$APP" --args --qa-simulate builtin-xdr-lid-open --qa-defaults-suite "$SUITE" \
  -overbright.onboarding.completedVersion "$WELCOME_DONE" --qa-script "$SCRIPT" --qa-status "$OUT/status.jsonl"
pid=""
for _ in $(seq 1 20); do
  pid="$(pgrep -f -- "--qa-defaults-suite $SUITE" | head -1 || true)"
  [[ -n "$pid" ]] && break
  sleep 0.5
done
[[ -n "$pid" ]] || die "the app did not start"
/usr/bin/open -n -g "$CONTROL" --args --follow "$pid"            # quits when the app does
control_pid=""
for _ in $(seq 1 20); do
  control_pid="$(pgrep -f -- "PerfControl --follow $pid" | head -1 || true)"
  [[ -n "$control_pid" ]] && break
  sleep 0.5
done
[[ -n "$control_pid" ]] || die "the control did not start"
echo "$pid $control_pid" > "$OUT/pid.txt"
/usr/bin/top -l 0 -s 10 -pid "$pid" -pid "$control_pid" -stats pid,cpu,idlew,mem,th > "$OUT/top.txt" 2>&1 &
top_pid=$!
# Interrupt wake-ups of both, every 10 s (what the judge counts), with the lock state.
( while kill -0 "$pid" 2>/dev/null; do
    { "$PIDSTAT" "$pid" "$control_pid" 2>/dev/null || true; "$SESSION" 2>/dev/null || echo "locked=?"; } | tr '\n' ' ' \
      >> "$OUT/pidstat.txt"
    echo >> "$OUT/pidstat.txt"
    sleep 10
  done ) &
pidstat_pid=$!
mark() {
  { echo "== $1 $(date +%s)"
    /usr/bin/footprint "$pid" 2>/dev/null | grep -E 'phys_footprint:' | head -1
  } >> "$OUT/footprint.txt"
  /usr/bin/vmmap --summary "$pid" 2>/dev/null | grep -E '^Physical footprint' >> "$OUT/footprint.txt" || true
}
sleep 20; mark first-off-start
sleep 95; mark first-off-end
marked=0
while kill -0 "$pid" 2>/dev/null; do
  ended="$(grep -c '"cycle-end"' "$OUT/status.jsonl" 2>/dev/null || true)"
  if (( ${ended:-0} > marked )); then marked=${ended:-0}; mark "cycle$marked-end"; fi
  if grep -q '"final-off-start"' "$OUT/status.jsonl" 2>/dev/null && ! grep -q '== final-off-start' "$OUT/footprint.txt"; then
    sleep 10; mark final-off-start
  fi
  if grep -q '"final-off-end"' "$OUT/status.jsonl" 2>/dev/null; then mark final-off-end; break; fi
  sleep 5
done
sleep 5
kill "$top_pid" "$pidstat_pid" 2>/dev/null || true
wait "$top_pid" 2>/dev/null || true
wait "$pidstat_pid" 2>/dev/null || true
for _ in $(seq 1 40); do kill -0 "$pid" 2>/dev/null || break; sleep 1; done
for _ in $(seq 1 10); do kill -0 "$control_pid" 2>/dev/null || break; sleep 1; done
kill "$control_pid" 2>/dev/null || true
defaults delete "$SUITE" >/dev/null 2>&1 || true
rm -f "$HOME/Library/Preferences/$SUITE.plist"
domain=0
app_domain_unchanged "$OUT/app-domain-before.plist" "the soak" || domain=1
/usr/bin/python3 -I "$ROOT/scripts/soak_judge.py" "$OUT" "$LEAK_MB" "$LEAK_KB" "$pid" "$control_pid" \
  || die "soak failed (see $OUT)"
(( domain == 0 )) || die "soak failed: the app's own preferences domain changed during the run (§8.5)"
log "Soak passed ($OUT)"
