#!/usr/bin/env bash
# Soak under --qa-simulate (ARCHITECTURE.md §10.15, DESIGN.md §17): the Debug app runs off for 2 minutes with its panel
# closed, then scripted cycles of events for most of MINUTES (on, the panel opened and closed, Max, Brighter, Less
# Bright, Low Power, lock, sleep, a reconfiguration, a screen-parameters change, a colour app, dimming, Dim All, Back
# to Standard, off), then off for 6 minutes. Beside it runs a control (scripts/soak-control.swift): a menu bar app that
# does nothing but subscribe to what Overbright subscribes to at rest (a status item, the keyboard layout). `top`
# samples both every 10 s (IDLEW is cumulative); `footprint` and `vmmap` run after every cycle and at the off phases.
# The summary checks that the footprint at the end is within LEAK_MB of the one after the third cycle (the caches the
# first cycles fill have settled by then; with fewer cycles, the last one), and judges the final off phase's
# idle wake-ups against the control: a wake-up in the same 10 s sample as one of the control's is the system's (a
# keyboard layout switch, the window server, which hand them to every such app); the rest are Overbright's own and must
# be neither periodic (4 or more at even gaps) nor more than one a minute. The first off phase, right after launch, is
# reported only. The literal "0 idle wake-ups while off" is the owner's quiet-machine run (HARDWARE-TEST §13). Fakes
# only: no real display is touched (D24). `footprint` and `vmmap` read the process; nothing attaches a debugger.
#
#   make debug; make soak                  # 30 minutes → build/logs/soak/
#   MINUTES=10 scripts/soak.sh
source "$(dirname "$0")/lib.sh"

APP="${APP:-$BUILD_DIR/$APP_NAME.app}"
CONTROL="$BUILD_DIR/SoakControl.app"
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
CYCLE='on; wait 6; panel open; wait 2; panel close; level max; wait 2; brighter; wait 1; less; wait 2; low-power on; wait 1; low-power off; wait 6; lock; wait 1; unlock; wait 6; sleep; wait 1; wake; wait 8; event reconfigured; wait 3; event screen-parameters; wait 1; conflict writer; wait 1; conflict none; wait 6; dim 40; wait 2; dim-all; wait 2; standard; wait 1; on; level bright-room; wait 6; off; wait 4; dump cycle-end'
SCRIPT="dump start; wait 3; panel close; wait $FIRST_OFF; dump first-off-end"
for _ in $(seq 1 "$CYCLES"); do SCRIPT="$SCRIPT; $CYCLE"; done
SCRIPT="$SCRIPT; off; wait 2; dump final-off-start; wait $FINAL_OFF; dump final-off-end; wait 30; quit"

ensure_xcode
rm -rf "$CONTROL"; mkdir -p "$CONTROL/Contents/MacOS"
xcrun swiftc -swift-version 6 -O -o "$CONTROL/Contents/MacOS/SoakControl" "$ROOT/scripts/soak-control.swift" \
  || die "the control did not build"
cat > "$CONTROL/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key><string>SoakControl</string>
  <key>CFBundleIdentifier</key><string>app.overbright.soak-control</string>
  <key>CFBundleName</key><string>SoakControl</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>LSUIElement</key><true/>
</dict>
</plist>
PLIST
codesign -s - --force "$CONTROL" >/dev/null 2>&1 || die "the control could not be signed"

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
/usr/bin/open -n -g "$CONTROL" --args --follow "$pid"            # quits when the app does
control_pid=""
for _ in $(seq 1 20); do
  control_pid="$(pgrep -f -- "SoakControl --follow $pid" | head -1 || true)"
  [[ -n "$control_pid" ]] && break
  sleep 0.5
done
[[ -n "$control_pid" ]] || die "the control did not start"
echo "$pid $control_pid" > "$OUT/pid.txt"
/usr/bin/top -l 0 -s 10 -pid "$pid" -pid "$control_pid" -stats pid,cpu,idlew,mem,th > "$OUT/top.txt" 2>&1 &
top_pid=$!
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
kill "$top_pid" 2>/dev/null || true
wait "$top_pid" 2>/dev/null || true
for _ in $(seq 1 40); do kill -0 "$pid" 2>/dev/null || break; sleep 1; done
for _ in $(seq 1 10); do kill -0 "$control_pid" 2>/dev/null || break; sleep 1; done
kill "$control_pid" 2>/dev/null || true
defaults delete "$SUITE" >/dev/null 2>&1 || true
rm -f "$HOME/Library/Preferences/$SUITE.plist"
/usr/bin/python3 -I - "$OUT" "$LEAK_MB" "$pid" "$control_pid" <<'PY' || die "soak failed (see $OUT)"
import datetime, re, sys
out, leak_mb, app, control = sys.argv[1], float(sys.argv[2]), sys.argv[3], sys.argv[4]
SAMPLE = 10                                                     # top's interval, s
marks, current = {}, None
for line in open(f"{out}/footprint.txt"):
    if line.startswith("== "):
        name, stamp = line.split()[1:3]; current = name; marks[name] = {"t": int(stamp)}
    elif "phys_footprint:" in line and current:
        value, unit = re.search(r"phys_footprint:\s+([\d.]+)\s*(\w+)", line).groups()
        marks[current]["mb"] = float(value) * {"KB": 1 / 1024, "MB": 1, "GB": 1024}.get(unit, 1)
samples = []                                                    # (stamp, {pid: cumulative idle wake-ups})
for line in open(f"{out}/top.txt"):
    if re.match(r"^\d{4}/\d\d/\d\d \d\d:\d\d:\d\d", line):
        samples.append((datetime.datetime.strptime(line.strip(), "%Y/%m/%d %H:%M:%S").timestamp(), {}))
    elif re.match(r"^\d+\s", line) and samples:
        fields = line.split()
        samples[-1][1][fields[0]] = int(fields[2].rstrip("+-"))
samples = [s for s in samples if app in s[1]]
def rows(a, b):
    """Per top sample between marks a and b: (seconds after a, the app's wake-ups, the control's or None)."""
    if a not in marks or b not in marks: return None
    ta, tb = marks[a]["t"], marks[b]["t"]
    first = [i for i, s in enumerate(samples) if s[0] <= ta]
    last = [i for i, s in enumerate(samples) if s[0] <= tb]
    if not first or not last: return None
    result = []
    for (t0, v0), (t1, v1) in zip(samples[first[-1]:last[-1]], samples[first[-1] + 1:last[-1] + 1]):
        theirs = v1[control] - v0[control] if control in v0 and control in v1 else None
        result.append((t1 - ta, v1[app] - v0[app], theirs))
    return result
cycles = sum(1 for line in open(f"{out}/status.jsonl") if '"cycle-end"' in line)
problems = []
# The first off phase follows the launch (AppKit and the system still settle the windows it opened): reported only.
# The final one follows a long active run: no periodic work while off (DESIGN.md §17). A wake-up the control has in the
# same sample is the system's (it hands the event to every menu bar app that follows the keyboard layout); the rest
# are Overbright's own, and those may be neither periodic nor more than one a minute.
for name, (a, b), strict in [("first off", ("first-off-start", "first-off-end"), False),
                             ("final off", ("final-off-start", "final-off-end"), True)]:
    r = rows(a, b)
    if r is None: problems.append(f"{name}: no samples"); continue
    span = marks[b]["t"] - marks[a]["t"]
    total = sum(mine for _, mine, _ in r)
    if any(theirs is None for _, _, theirs in r):
        problems.append(f"{name}: the control was not sampled throughout; nothing to compare with")
        r = [(at, mine, 0) for at, mine, _ in r]
    own = [(at, mine - min(mine, theirs)) for at, mine, theirs in r if mine > theirs]
    own_total = sum(n for _, n in own)
    when = ", ".join(f"+{int(at)}" for at, _ in own)
    print(f"{name}: {total} idle wake-ups in {span} s, the control {sum(t for _, _, t in r)}; "
          f"{total - own_total} shared, {own_total} Overbright's own" + (f" (at {when} s)" if own else "")
          + ("" if strict else "; after launch, reported only"))
    if not strict: continue
    gaps = [b2 - b1 for (b1, _), (b2, _) in zip(own, own[1:])]
    if own_total > span / 60:
        problems.append(f"{name}: {own_total} wake-ups of Overbright's own in {span} s, more than one a minute")
    if len(own) >= 4 and max(gaps) - min(gaps) <= SAMPLE:
        shown = ", ".join(str(int(gap)) for gap in gaps)
        problems.append(f"{name}: Overbright's own wake-ups come at even gaps ({shown} s)")
# A leak grows with every cycle; the first cycles also fill caches that then stay. So the footprint at the end is
# compared with the one after the third cycle (or the last one when there are fewer), and every cycle is reported.
settled = f"cycle{min(3, cycles)}-end"
first, last = marks.get(settled, {}).get("mb"), marks.get("final-off-end", {}).get("mb")
print(f"cycles: {cycles}; footprint MB: " + ", ".join(f"{k} {v.get('mb', '?')}" for k, v in marks.items()
                                                    if not re.match(r"cycle\d+-end", k) or k == settled))
print("after each cycle: " + " ".join(str(v.get("mb", "?")) for k, v in marks.items()
                                      if re.match(r"cycle\d+-end", k)))
if first is None or last is None: problems.append(f"no footprint at {settled} or at the end")
elif last - first > leak_mb: problems.append(f"footprint grew {last - first:.1f} MB after {settled}")
print("\n".join(problems)
      or "soak OK: no growth once settled; while off, no periodic wake-ups of Overbright's own")
sys.exit(1 if problems else 0)
PY
log "Soak passed ($OUT)"
