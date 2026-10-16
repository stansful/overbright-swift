#!/usr/bin/env bash
# Soak under --qa-simulate (ARCHITECTURE.md §10.15, DESIGN.md §17): the Debug app runs off for 2 minutes, then scripted
# cycles of events for most of MINUTES (on, Max, Brighter, Less Bright, Low Power, lock, sleep, a reconfiguration, a
# screen-parameters change, a colour app, dimming, Dim All, Back to Standard, off), then off for 6 minutes. `top`
# samples the app every 10 s (IDLEW is cumulative), `footprint` and `vmmap` run at checkpoints, and the summary checks
# that the footprint after the last cycle is within LEAK_MB of the one after the first, and that idle wake-ups do not
# grow while off. Fakes only: no real display is touched (D24). `footprint` and `vmmap` read the process; nothing
# attaches a debugger.
#
#   make debug; make soak                  # 30 minutes → build/logs/soak/
#   MINUTES=10 scripts/soak.sh
source "$(dirname "$0")/lib.sh"

APP="${APP:-$BUILD_DIR/$APP_NAME.app}"
OUT="${OUT:-$BUILD_DIR/logs/soak}"
MINUTES="${MINUTES:-30}"
LEAK_MB="${LEAK_MB:-5}"
FIRST_OFF=120
FINAL_OFF=360
[[ -d "$APP" ]] || die "$APP not found; run make debug first"
codesign -d --entitlements - --xml "$APP" 2>/dev/null | grep -q "com.apple.security.get-task-allow" \
  || die "$APP is a Release build, which refuses --qa-simulate; run make debug"
CYCLES=$(( (MINUTES * 60 - FIRST_OFF - FINAL_OFF) / 66 ))
(( CYCLES >= 1 )) || die "MINUTES=$MINUTES leaves no time for a cycle (at least 10)"
SUITE=app.overbright.Overbright.soak
WELCOME_DONE='<22302e312e3022>'
CYCLE='on; wait 6; level max; wait 2; brighter; wait 1; less; wait 2; low-power on; wait 1; low-power off; wait 6; lock; wait 1; unlock; wait 6; sleep; wait 1; wake; wait 8; event reconfigured; wait 3; event screen-parameters; wait 1; conflict writer; wait 1; conflict none; wait 6; dim 40; wait 2; dim-all; wait 2; standard; wait 1; on; level bright-room; wait 6; off; wait 4; dump cycle-end'
SCRIPT="dump start; wait $FIRST_OFF; dump first-off-end"
for _ in $(seq 1 "$CYCLES"); do SCRIPT="$SCRIPT; $CYCLE"; done
SCRIPT="$SCRIPT; off; wait 2; dump final-off-start; wait $FINAL_OFF; dump final-off-end; wait 30; quit"

rm -rf "$OUT"; mkdir -p "$OUT"
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
echo "$pid" > "$OUT/pid.txt"
/usr/bin/top -l 0 -s 10 -pid "$pid" -stats pid,cpu,idlew,mem,th > "$OUT/top.txt" 2>&1 &
top_pid=$!
mark() {
  { echo "== $1 $(date +%s)"
    /usr/bin/footprint "$pid" 2>/dev/null | grep -E 'phys_footprint:' | head -1
  } >> "$OUT/footprint.txt"
  /usr/bin/vmmap --summary "$pid" 2>/dev/null | grep -E '^Physical footprint' >> "$OUT/footprint.txt" || true
}
sleep 20; mark first-off-start
sleep 95; mark first-off-end
while kill -0 "$pid" 2>/dev/null; do
  if grep -q '"cycle-end"' "$OUT/status.jsonl" 2>/dev/null && ! grep -q '== cycle1-end' "$OUT/footprint.txt"; then
    mark cycle1-end
  fi
  if grep -q '"final-off-start"' "$OUT/status.jsonl" 2>/dev/null && ! grep -q '== final-off-start' "$OUT/footprint.txt"; then
    sleep 10; mark final-off-start
  fi
  if grep -q '"final-off-end"' "$OUT/status.jsonl" 2>/dev/null; then mark final-off-end; break; fi
  sleep 5
done
sleep 5
kill "$top_pid" 2>/dev/null || true
for _ in $(seq 1 40); do kill -0 "$pid" 2>/dev/null || break; sleep 1; done
defaults delete "$SUITE" >/dev/null 2>&1 || true
rm -f "$HOME/Library/Preferences/$SUITE.plist"
/usr/bin/python3 -I - "$OUT" "$LEAK_MB" <<'PY' || die "soak failed (see $OUT)"
import datetime, json, re, sys
out, leak_mb = sys.argv[1], float(sys.argv[2])
marks, current = {}, None
for line in open(f"{out}/footprint.txt"):
    if line.startswith("== "):
        name, stamp = line.split()[1:3]; current = name; marks[name] = {"t": int(stamp)}
    elif "phys_footprint:" in line and current:
        value, unit = re.search(r"phys_footprint:\s+([\d.]+)\s*(\w+)", line).groups()
        marks[current]["mb"] = float(value) * {"KB": 1 / 1024, "MB": 1, "GB": 1024}.get(unit, 1)
samples, stamp = [], None
for line in open(f"{out}/top.txt"):
    if re.match(r"^\d{4}/\d\d/\d\d \d\d:\d\d:\d\d", line):
        stamp = datetime.datetime.strptime(line.strip(), "%Y/%m/%d %H:%M:%S").timestamp()
    elif re.match(r"^\d+\s", line) and stamp is not None:
        fields = line.split()
        samples.append((stamp, int(fields[2].rstrip("+-"))))
def idlew_at(t):
    before = [s for s in samples if s[0] <= t]
    return before[-1][1] if before else None
def window(a, b):
    if a not in marks or b not in marks: return None
    start, end = idlew_at(marks[a]["t"]), idlew_at(marks[b]["t"])
    return None if start is None or end is None else (end - start, marks[b]["t"] - marks[a]["t"])
cycles = sum(1 for line in open(f"{out}/status.jsonl") if '"cycle-end"' in line)
problems = []
for name, (a, b) in {"first off": ("first-off-start", "first-off-end"),
                     "final off": ("final-off-start", "final-off-end")}.items():
    w = window(a, b)
    if w is None: problems.append(f"{name}: no samples"); continue
    print(f"{name}: {w[0]} idle wake-ups in {w[1]} s")
    if w[0] > 0: problems.append(f"{name}: {w[0]} idle wake-ups while off")
first, last = marks.get("cycle1-end", {}).get("mb"), marks.get("final-off-end", {}).get("mb")
print(f"cycles: {cycles}; footprint MB: " + ", ".join(f"{k} {v.get('mb', '?')}" for k, v in marks.items()))
if first is None or last is None: problems.append("no footprint after the first cycle or at the end")
elif last - first > leak_mb: problems.append(f"footprint grew {last - first:.1f} MB after the first cycle")
print("\n".join(problems) or "soak OK: no growth beyond the first cycle, no idle wake-ups while off")
sys.exit(1 if problems else 0)
PY
log "Soak passed ($OUT)"
