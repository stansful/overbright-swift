#!/usr/bin/env bash
# scripts/perf.sh — runtime and energy baseline of the Debug app under --qa-simulate (DESIGN.md §17's budget,
# ARCHITECTURE.md §4.2, §7.1, §8.7, D22, D28). Each run launches the app once with a scripted scenario (`--qa-script`,
# ScenarioScript's step language) whose phases are marked by `dump` labels; beside it runs the soak's control app
# (scripts/soak-control.swift), so wake-ups the window server hands every menu bar app are subtracted.
#
# Steady phases (`dump start.<phase>` … `dump end.<phase>`) are measured over one clean window (SETTLE s after the
# start mark, MEASURE s long, nothing attached):
#   - CPU time delta (proc_pid_rusage user + system, ns), %CPU of one core;
#   - interrupt wake-ups (ri_interrupt_wkups; `top`'s IDLEW, ri_pkg_idle_wkups, stays 0 on a loaded Apple silicon Mac)
#     of the app and of the control; own = app − control, per second;
#   - the kernel's billed energy delta (ri_billed_energy, nJ → mW), instructions;
#   - threads at both ends;
# then, after the window: `sample <pid> SAMPLE` (hot stacks), `footprint <pid>` and `vmmap --summary <pid>`.
# Counted phases (`dump begin.<phase>` … `dump clean.<phase>` … `dump finish.<phase>`) do a known number of things
# (events, panel opens): the clean part is measured from its first step to its last, and the work per thing is
# reported (CPU per event, per open); a short tail of the same work after `clean` is what `sample` watches, and the
# footprint is read 3 s after the last step. The lock state (CGSessionCopyCurrentDictionary) and the load average
# are recorded with every reading.
#
# Runs (default: launch, base, ruleoff, two, in this order; the others on request):
#   launch     launch to ready, with a `sample` over the first SAMPLE s (its timing is perturbed; every other run's
#              launch is clean and is reported too)
#   base       builtin-xdr-lid-open: off ×2, boosted ×2, panel open boosted, panel open while the level moves at
#              10 Hz, a ramp storm (1 Hz, panel closed), the HUD every 2 s, dimmed ×2, panel open while off, back to
#              off ×2
#   ruleoff    the same fixture with the full-screen-video rule off: boosted ×2 (under --qa-simulate Signals is a
#              fake, so the watch of D28 never runs either way; `signals` runs the real one)
#   two        russian-names (built-in + MSI, the MSI's boost switched on): off, boosted ×2, back to off
#   ui         off, then the panel opened and closed once, a ramp storm and the HUD with the panel closed, back to
#              off: a short run for UI changes
#   events     screen-parameters events (counted): EVENTS (1500) of them 10 ms apart while off and while boosted,
#              then bursts of 120 at 8 ms every 5 s while boosted, with the panel closed and open; CPU per event
#   panelcycle the panel opened and closed PANEL_CYCLES (10) times 2 s apart while off (counted): CPU per open, and
#              the footprint after
#   timeline   russian-names boosted (both displays): the app's and the control's interrupt wake-ups every second
#              for TIMELINE s (300): seconds with two wake-ups, gaps between own wake-ups
#
#   make debug; make perf                              # → build/logs/perf/<variant>/
#   make perf RUNS="ui events" APP=build/Overbright-opt.app VARIANT=opt
#   make perf-compare A=build/logs/perf/main B=build/logs/perf/Overbright
#   scripts/perf.sh summarize build/logs/perf/Overbright   # tables + hot stacks again (perf.md in that folder)
#   scripts/perf.sh compare <dirA> <dirB>                  # per phase: own CPU, own wake-ups, footprint, busy split
#
# Env: APP (a Debug build: it must carry get-task-allow), VARIANT (label), OUT, PHASE (s per steady phase, 90),
# MEASURE (60), SETTLE (5), SAMPLE (10; 0 = no sample and no sampled tails), EVENTS (1500), PANEL_CYCLES (10),
# TIMELINE (300). Fakes only: no real display is touched (D24); nothing attaches a debugger. Never synthesizes input.
# Run each command on its own (CONTRIBUTING: `a && b` chains can abort silently).
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
if [[ -f "$HERE/lib.sh" ]]; then
  # shellcheck source=/dev/null
  source "$HERE/lib.sh"
  ensure_xcode
else
  ROOT="${ROOT:?set ROOT to an Overbright checkout (scripts/perf.sh finds it by itself)}"
  BUILD_DIR="$ROOT/build"
  APP_NAME="Overbright"
  log()  { printf '\033[1;34m==>\033[0m %s\n' "$*" >&2; }
  warn() { printf '\033[1;33mwarning:\033[0m %s\n' "$*" >&2; }
  die()  { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }
  export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
fi

APP="${APP:-$BUILD_DIR/$APP_NAME.app}"
VARIANT="${VARIANT:-$(basename "$APP" .app)}"
PERF_ROOT="${PERF_ROOT:-$BUILD_DIR/logs/perf}"
OUT="${OUT:-$PERF_ROOT/$VARIANT}"
TOOLS="${TOOLS:-$PERF_ROOT/tools}"
PHASE="${PHASE:-90}"
MEASURE="${MEASURE:-60}"
SETTLE="${SETTLE:-5}"
SAMPLE="${SAMPLE:-10}"
EVENTS="${EVENTS:-1500}"
PANEL_CYCLES="${PANEL_CYCLES:-10}"
TIMELINE="${TIMELINE:-300}"
WELCOME_DONE='<22302e312e3022>'           # "0.1.0": Welcome is finished
FALSE='<66616c7365>'                      # JSON false, as the settings store keeps it

report() {   # <summarize|compare> <dir> [<dir>]
  /usr/bin/python3 -I - "$@" <<'PY'
"""Tables, hot stacks and comparisons of perf runs (scripts/perf.sh). Standard library only."""
import glob, json, os, re, sys

IDLE = {"mach_msg2_trap", "mach_msg_trap", "mach_msg_overwrite_trap", "__workq_kernreturn", "__psynch_cvwait",
        "__semwait_signal", "kevent_id", "kevent64", "kevent", "__select", "__ulock_wait", "__ulock_wait2",
        "semaphore_wait_trap", "semaphore_timedwait_trap", "__sigsuspend", "poll", "__wait4", "read", "__read_nocancel",
        "__recvfrom", "swtch_pri", "thread_suspend", "__pthread_kill", "__open", "start_wqthread", "thread_start"}
BUDGET = {  # DESIGN.md §17
    "off": ("Off", 0.0, None, 40.0), "boosted": ("Boosted steady", 1.5, 0.1, None),
    "panel": ("Panel open", None, 2.0, None)}
# Busy samples by what their stack contains; the first class that matches wins.
SPLIT = [("conflicts", r"ConflictMatcher|RunningAppsConflictProbe"),
         ("engine", r"BoostEngine|DisplayController|TableWriter|FakeGammaPort|DriftCheck|RampPlanner|GainCeiling|"
                    r"ScriptedHeadroom|HangWatchdog|SafetyLedger"),
         ("signals", r"SignalsMonitor|FullScreenTracker|LiveSignalsPlatform|RunningAppInfo|FakeSystemSignals"),
         ("panel views", r"DisplayCardView|PanelView|BoostSlider|ValueText|ReadoutText|Footer|PanelContent|"
                         r"DisplayCardModel|CardChip"),
         ("HUD", r"HUDController|HUDView"),
         ("status item", r"StatusItem|StatusSymbol"),
         ("settings", r"SettingsStore|SettingBox"),
         ("observation", r"Observer\.fire|Observer\.arm|withObservationTracking"),
         ("SwiftUI/AG", r"AttributeGraph|SwiftUI|AG::"),
         ("CA/AppKit", r"QuartzCore|CA::|AppKit|NSView|NSWindow")]
ORDER = {"launch": 0, "base": 1, "ruleoff": 2, "two": 3, "ui": 4, "events": 5, "panelcycle": 6, "timeline": 7,
         "signals": 8}

def budget_of(phase):
    if phase.startswith("off"):
        return BUDGET["off"]
    if phase.startswith("boosted"):
        return BUDGET["boosted"]
    if phase.startswith("panel-"):
        return BUDGET["panel"]
    return None

def fnum(x, nd=2):
    return "—" if x is None else f"{x:.{nd}f}"

def read_stats(path):
    rows = {}
    for line in open(path):
        parts = line.rstrip("\n").split("\t")
        if len(parts) < 5:
            continue
        name, tag, nums, lock, load = parts[:5]
        f = nums.split()
        def rec(off):
            if len(f) < off + 11 or f[off + 2] == "NA":
                return None
            pid, ms, cpu, pkg, intr, fp, res, th, energy, instr, cyc = f[off:off + 11]
            return dict(ms=int(ms), cpu=int(cpu), intr=int(intr), fp=int(fp), res=int(res), th=int(th),
                        energy=int(energy), instr=int(instr))
        rows[(name, tag)] = dict(app=rec(0), ctl=rec(11), lock=lock, load=float(load or 0))
    return rows

def footprint_mb(path):
    try:
        text = open(path).read()
    except OSError:
        return None, []
    m = re.search(r"Footprint:\s+([\d.]+)\s+(KB|MB|GB)", text)
    val = None
    if m:
        val = float(m.group(1)) * {"KB": 1 / 1024, "MB": 1, "GB": 1024}[m.group(2)]
    cats = []
    for line in text.splitlines():
        mm = re.match(r"\s*([\d.]+)\s+(B|KB|MB|GB)\s+([\d.]+)\s+(B|KB|MB|GB)\s+([\d.]+)\s+(B|KB|MB|GB)\s+(\d+)\s+(.+)$", line)
        if mm and mm.group(8).strip() != "TOTAL":
            mb = float(mm.group(1)) * {"B": 1 / 1048576, "KB": 1 / 1024, "MB": 1, "GB": 1024}[mm.group(2)]
            cats.append((mb, mm.group(8).strip()))
    cats.sort(reverse=True)
    return val, cats[:4]

def vmmap_mb(path):
    try:
        text = open(path).read()
    except OSError:
        return None
    m = re.search(r"Physical footprint:\s+([\d.]+)([KMG])", text)
    if not m:
        return None
    return float(m.group(1)) * {"K": 1 / 1024, "M": 1, "G": 1024}[m.group(2)]

def parse_sample(path, top=6):
    """Heaviest non-idle self-time frames with their call path (condensed to the app's frames), the busy and total
    thread-samples, the app frames by busy samples beneath them, and the busy samples split by SPLIT."""
    empty = ([], 0, 0, [], {})
    try:
        lines = open(path, errors="replace").read().splitlines()
    except OSError:
        return empty
    try:
        start = lines.index("Call graph:") + 1
    except ValueError:
        return empty
    nodes = []          # (depth, count, symbol)
    for line in lines[start:]:
        if not line.strip():
            break
        m = re.match(r"^([\s+|!:]*)(\d+)\s+(.*)$", line)
        if m:
            nodes.append((len(m.group(1)), int(m.group(2)), m.group(3)))
    if not nodes:
        return empty
    top_depth = min(n[0] for n in nodes)
    child_sum = [0] * len(nodes)
    parents = []        # stack of node indices
    paths = []
    for i, (depth, count, sym) in enumerate(nodes):
        while parents and nodes[parents[-1]][0] >= depth:
            parents.pop()
        if parents:
            child_sum[parents[-1]] += count
        paths.append(list(parents))
        parents.append(i)
    total_samples = sum(c for d, c, s in nodes if d == top_depth)
    busy = 0
    results = {}
    inclusive = {}
    split = {}
    for i, (depth, count, sym) in enumerate(nodes):
        selfc = count - child_sum[i]
        if selfc <= 0:
            continue
        name = re.sub(r"\s+\(in [^)]*\).*$", "", sym).strip()
        lib = re.search(r"\(in ([^)]*)\)", sym)
        lib = lib.group(1) if lib else "?"
        if name in IDLE or name.startswith("Thread_") or name.startswith("DispatchQueue") or name.startswith("???"):
            continue
        busy += selfc
        stack = " ".join(nodes[k][2] for k in paths[i]) + " " + sym
        for label, pattern in SPLIT:
            if re.search(pattern, stack):
                split[label] = split.get(label, 0) + selfc
                break
        else:
            split["other"] = split.get("other", 0) + selfc
        app = [re.sub(r"\s+\(in [^)]*\).*$", "", nodes[k][2]).strip() for k in paths[i] if "(in Overbright)" in nodes[k][2]]
        for sym_name in set(a for a in app if not a.startswith("main") and "thunk" not in a
                            and a not in ("???", "<deduplicated_symbol>")):
            inclusive[sym_name] = inclusive.get(sym_name, 0) + selfc
        key = (name, lib)
        entry = results.setdefault(key, [0, {}])
        entry[0] += selfc
        p = " ← ".join(reversed(app[-4:])) if app else "(no app frame)"
        entry[1][p] = entry[1].get(p, 0) + selfc
    ranked = sorted(results.items(), key=lambda kv: -kv[1][0])[:top]
    return ([(n, lib, c, max(paths.items(), key=lambda kv: kv[1])[0]) for (n, lib), (c, paths) in ranked], busy,
            total_samples, sorted(inclusive.items(), key=lambda kv: -kv[1])[:top], split)

def split_text(split, busy, limit=4):
    if not busy:
        return "—"
    ranked = sorted(split.items(), key=lambda kv: -kv[1])[:limit]
    return ", ".join(f"{label} {count * 100 / busy:.0f} %" for label, count in ranked)

def short(s, n=150):
    s = s.replace("|", "/")
    return s if len(s) <= n else s[:n - 1] + "…"

def runs_of(out):
    """Run folders of a variant folder (or the folder itself when it is one run), in ORDER."""
    if os.path.isfile(os.path.join(out, "stats.tsv")):
        return [out]
    runs = [d for d in glob.glob(os.path.join(out, "*")) if os.path.isfile(os.path.join(d, "stats.tsv"))]
    return sorted(runs, key=lambda d: (ORDER.get(os.path.basename(d), 99), os.path.basename(d)))

def read_units(run):
    units = {}
    path = os.path.join(run, "units.tsv")
    if os.path.exists(path):
        for line in open(path):
            p = line.rstrip("\n").split("\t")
            if len(p) >= 3:
                units[p[0]] = (int(p[1]), p[2])
    return units

def timeline_of(run):
    """Per-second interrupt wake-ups of the app and the control (timeline.txt: pidstat of both, then the lock)."""
    path = os.path.join(run, "timeline.txt")
    if not os.path.exists(path):
        return None
    rows = [l.split() for l in open(path) if l.strip() and "NA" not in l]
    rows = [r for r in rows if len(r) >= 22]
    if len(rows) < 2:
        return None
    t0 = int(rows[0][1])
    seconds, own_times, locks = [], [], set()
    for prev, r in zip(rows, rows[1:]):
        da, dc = int(r[4]) - int(prev[4]), int(r[15]) - int(prev[15])
        seconds.append(((int(r[1]) - t0) / 1000, da, dc, int(r[2]) - int(prev[2]), r[22] if len(r) > 22 else "?"))
        if da > dc:
            own_times.append((int(r[1]) - t0) / 1000)
        locks.add(r[22] if len(r) > 22 else "?")
    dur = (int(rows[-1][1]) - t0) / 1000
    app = int(rows[-1][4]) - int(rows[0][4])
    ctl = int(rows[-1][15]) - int(rows[0][15])
    own = sum(max(da - dc, 0) for _, da, dc, _, _ in seconds)
    cpu_ms = (int(rows[-1][2]) - int(rows[0][2])) / 1e6
    ctl_cpu_ms = (int(rows[-1][13]) - int(rows[0][13])) / 1e6
    gaps = {}
    for a, b in zip(own_times, own_times[1:]):
        g = round(b - a)
        gaps[g] = gaps.get(g, 0) + 1
    return dict(seconds=seconds, dur=dur, app=app, ctl=ctl, own=own, app_rate=app / dur, own_rate=own / dur,
                two=sum(1 for _, da, _, _, _ in seconds if da >= 2),
                own_seconds=len(own_times), cpu_ms=cpu_ms, ctl_cpu_ms=ctl_cpu_ms,
                own_pct=max(cpu_ms - ctl_cpu_ms, 0) / 1000 / dur * 100, gaps=gaps,
                locked="locked" if any("locked=1" in l for l in locks) else "unlocked")

def engine_at_starts(run):
    """What the engine showed at each phase's start mark (the scenario's own dump: phase and reasons per display)."""
    states = {}
    path = os.path.join(run, "status.jsonl")
    if not os.path.exists(path):
        return states
    for line in open(path):
        try:
            dump = json.loads(line)
        except ValueError:
            continue
        label = dump.get("label", "")
        if label.startswith(("start.", "begin.")):
            states[label.split(".", 1)[1]] = "; ".join(
                f"{d.get('display', '?')} {d.get('phase', '?')}"
                + (f" ({', '.join(d['reasons'])})" if d.get("reasons") else "") for d in dump.get("displays", []))
    return states

def collect(run):
    """Every measured phase of one run, in the order the scenario ran them."""
    stats = read_stats(os.path.join(run, "stats.tsv"))
    units = read_units(run)
    phases, rows = [], {}
    for (ph, tag) in stats:
        if tag == "A" and ph not in phases:
            phases.append(ph)
    for ph in phases:
        a, b = stats.get((ph, "A")), stats.get((ph, "B"))
        if not a or not b or not a["app"] or not b["app"]:
            continue
        dt = (b["app"]["ms"] - a["app"]["ms"]) / 1000
        if dt <= 0:
            continue
        cpu = (b["app"]["cpu"] - a["app"]["cpu"]) / 1e6
        ccpu = (b["ctl"]["cpu"] - a["ctl"]["cpu"]) / 1e6 if a["ctl"] and b["ctl"] else None
        aw = (b["app"]["intr"] - a["app"]["intr"]) / dt
        cw = (b["ctl"]["intr"] - a["ctl"]["intr"]) / dt if a["ctl"] and b["ctl"] else None
        fp, cats = footprint_mb(os.path.join(run, f"footprint-{ph}.txt"))
        hot, busy, total, incl, split = parse_sample(os.path.join(run, f"sample-{ph}.txt"))
        row = dict(dt=dt, cpu=cpu, ccpu=ccpu, pct=cpu / 1000 / dt * 100,
                   own_pct=max(cpu - (ccpu or 0), 0) / 1000 / dt * 100, aw=aw, cw=cw,
                   own=max(aw - cw, 0) if cw is not None else None,
                   mw=(b["app"]["energy"] - a["app"]["energy"]) / 1e9 / dt * 1000,
                   fp=fp, cats=cats, vm=vmmap_mb(os.path.join(run, f"vmmap-{ph}.txt")),
                   th=f"{a['app']['th']}→{b['app']['th']}",
                   lock="locked" if "locked=1" in a["lock"] + b["lock"] else "unlocked",
                   load=(a["load"] + b["load"]) / 2, busy=busy, total=total, split=split, hot=hot, incl=incl,
                   units=None, unit=None, per_unit=None)
        if ph in units:
            count, unit = units[ph]
            row.update(units=count, unit=unit, per_unit=max(cpu - (ccpu or 0), 0) / count if count else None)
        bud = budget_of(ph)
        row["verdict"], row["ok"] = "—", None
        if bud:
            label, wk, cpup, mem = bud
            bits, ok = [], True
            if wk is not None and row["own"] is not None:
                bits.append(f"≤{wk:g} wk/s"); ok &= row["own"] <= wk + 1e-9
            if cpup is not None:
                bits.append(f"<{cpup:g}% CPU"); ok &= row["pct"] < cpup
            if mem is not None and fp is not None:
                bits.append(f"<{mem:g} MB"); ok &= fp < mem
            row["verdict"] = f"{label}: {', '.join(bits)} → {'pass' if ok else '**MISS**'}"
            row["ok"] = ok
        rows[ph] = row
    return [ph for ph in phases if ph in rows], rows, stats

def summarize(out):
    report = [f"# perf: {os.path.basename(os.path.normpath(out))}\n"]
    csv = ["run,phase,seconds,cpu_ms,ctl_cpu_ms,cpu_pct,app_wk_s,ctl_wk_s,own_wk_s,energy_mW,footprint_MB,vmmap_MB,"
           "threads,lock,load,units,unit,own_cpu_ms_per_unit"]
    for run in runs_of(out):
        name = os.path.basename(run)
        phases, rows, stats = collect(run)
        marks = {}
        if os.path.exists(os.path.join(run, "marks.tsv")):
            for line in open(os.path.join(run, "marks.tsv")):
                p = line.rstrip("\n").split("\t")
                if len(p) >= 2:
                    marks.setdefault(p[0], int(p[1]))
        report.append(f"## {name}\n")
        if "open" in marks and "ready" in marks:
            r = stats.get(("launch", "R"), {}).get("app")
            fp, cats = footprint_mb(os.path.join(run, "footprint-ready.txt"))
            report.append(f"Launch to ready: {(marks['ready'] - marks['open']) / 1000:.2f} s; CPU at ready "
                          f"{(r['cpu'] / 1e6 if r else float('nan')):.0f} ms; threads {r['th'] if r else '—'}; "
                          f"footprint {fnum(fp, 1)} MB (vmmap {fnum(vmmap_mb(os.path.join(run, 'vmmap-ready.txt')), 1)} MB); "
                          f"lock {stats.get(('launch', 'R'), {}).get('lock', '?')}\n")
        if phases:
            report.append("| Phase | s | CPU ms | ctl CPU ms | CPU % (own) | wk/s app | wk/s ctl | **own wk/s** | billed mW | footprint MB | vmmap MB | threads | lock | load | per unit, own CPU ms | §17 budget |")
            report.append("|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|")
        for ph in phases:
            r = rows[ph]
            per = f"{r['per_unit']:.3f} per {r['unit']} ({r['units']})" if r["per_unit"] is not None else "—"
            report.append(f"| {ph} | {r['dt']:.0f} | {r['cpu']:.1f} | {fnum(r['ccpu'], 1)} | {r['pct']:.3f} ({r['own_pct']:.3f}) | "
                          f"{r['aw']:.2f} | {fnum(r['cw'])} | **{fnum(r['own'])}** | {r['mw']:.2f} | {fnum(r['fp'], 1)} | "
                          f"{fnum(r['vm'], 1)} | {r['th']} | {r['lock']} | {r['load']:.1f} | {per} | {r['verdict']} |")
            csv.append(f"{name},{ph},{r['dt']:.1f},{r['cpu']:.2f},{fnum(r['ccpu'], 2)},{r['pct']:.4f},{r['aw']:.3f},"
                       f"{fnum(r['cw'], 3)},{fnum(r['own'], 3)},{r['mw']:.3f},{fnum(r['fp'], 1)},{fnum(r['vm'], 1)},"
                       f"{r['th']},{r['lock']},{r['load']:.1f},{r['units'] or ''},{r['unit'] or ''},"
                       f"{fnum(r['per_unit'], 4) if r['per_unit'] is not None else ''}")
        states = engine_at_starts(run)
        if states and phases:
            report.append("\nEngine at each phase's start (the scenario's dump): " +
                          "; ".join(f"**{ph}** {states[ph]}" for ph in phases if ph in states))
        tl = timeline_of(run)
        if tl:
            gaps = ", ".join(f"{g} s ×{n}" for g, n in sorted(tl["gaps"].items()))
            report.append(f"\nTimeline: {tl['dur']:.0f} s ({tl['locked']}); interrupt wake-ups: app {tl['app']} "
                          f"({tl['app_rate']:.2f}/s), control {tl['ctl']}, own {tl['own']} ({tl['own_rate']:.2f}/s); "
                          f"**seconds with two or more app wake-ups: {tl['two']}**; seconds with own wake-ups: "
                          f"{tl['own_seconds']}; own CPU {tl['own_pct']:.3f} %; gaps between own wake-ups: {gaps or '—'}")
            csv.append(f"{name},timeline,{tl['dur']:.1f},{tl['cpu_ms']:.2f},{tl['ctl_cpu_ms']:.2f},,"
                       f"{tl['app_rate']:.3f},{tl['ctl'] / tl['dur']:.3f},{tl['own_rate']:.3f},,,,,{tl['locked']},,"
                       f"{tl['two']},seconds with two,")
            with open(os.path.join(run, "timeline.csv"), "w") as f:
                f.write("t_s,app_wk,ctl_wk,app_cpu_us,lock\n")
                for t, da, dc, dcpu, lock in tl["seconds"]:
                    f.write(f"{t:.3f},{da},{dc},{dcpu / 1e3:.0f},{lock}\n")
        report.append("")
        report.append("Hot stacks (self samples outside idle waits, `sample` 1 ms × SAMPLE s; steady phases after the "
                      "window, counted phases over their tail):\n")
        hot, busy, total, incl, split = parse_sample(os.path.join(run, "sample-launch.txt"))
        sampled = [("launch", hot, busy, total, incl, split)] if total else []
        sampled += [(ph, rows[ph]["hot"], rows[ph]["busy"], rows[ph]["total"], rows[ph]["incl"], rows[ph]["split"])
                    for ph in phases if rows[ph]["total"]]
        for ph, hot, busy, total, incl, split in sampled:
            report.append(f"- **{ph}**: {busy} busy of {total} thread-samples; split: {split_text(split, busy, 6)}")
            for n, lib, c, p in hot:
                report.append(f"  - self {c} `{short(n, 90)}` ({lib}) ← {short(p)}")
            if incl:
                report.append("  - app frames by busy samples beneath them: " +
                              "; ".join(f"`{short(n, 70)}` {c}" for n, c in incl))
        fps = [f"- {ph}: " + ", ".join(f"{c} {mb:.1f} MB" for mb, c in rows[ph]["cats"]) for ph in phases
               if rows[ph]["cats"]]
        if fps:
            report.append("\nLargest footprint categories (dirty):\n")
            report += fps
        report.append("")
    open(os.path.join(out, "perf.md"), "w").write("\n".join(report) + "\n")
    open(os.path.join(out, "perf.csv"), "w").write("\n".join(csv) + "\n")
    print("\n".join(report))

def delta(a, b, nd=3, relative=False):
    if a is None or b is None:
        return "—"
    text = f"{b - a:+.{nd}f}"
    if relative and abs(a) > 1e-9:
        text += f" ({(b - a) / a * 100:+.0f} %)"
    return text

def compare(dir_a, dir_b):
    name_a = os.path.basename(os.path.normpath(dir_a))
    name_b = os.path.basename(os.path.normpath(dir_b))
    runs_a = {os.path.basename(r): r for r in runs_of(dir_a)}
    runs_b = {os.path.basename(r): r for r in runs_of(dir_b)}
    if len(runs_a) == 1 and len(runs_b) == 1 and set(runs_a) != set(runs_b):   # one run each: compare them anyway
        runs_a = {"run": list(runs_a.values())[0]}
        runs_b = {"run": list(runs_b.values())[0]}
    common = sorted(set(runs_a) & set(runs_b), key=lambda r: (ORDER.get(r, 99), r))
    out = [f"# perf compare: A = {name_a}, B = {name_b}\n",
           f"A: `{dir_a}`  \nB: `{dir_b}`\n",
           "Own CPU % = (app − control) CPU time per window, of one core; own wk/s = interrupt wake-ups, app − control; "
           "footprint = `footprint` total after the window; per unit = own CPU ms per event or panel open (counted "
           "phases); busy split = `sample` busy samples by stack. One window per phase and variant: read repeats, "
           "never a single pair.\n"]
    if not common:
        out.append("No run in common.")
    for run in common:
        pa, ra, _ = collect(runs_a[run])
        pb, rb, _ = collect(runs_b[run])
        out.append(f"## {run}\n")
        phases = [p for p in pa if p in rb] + [p for p in pb if p in ra and p not in pa]
        if phases:
            out.append("| Phase | own CPU % A → B | Δ | own wk/s A → B | Δ | footprint MB A → B | Δ | per unit A → B (own CPU ms) | busy split A | busy split B | lock A / B | §17 A → B |")
            out.append("|---|---|---|---|---|---|---|---|---|---|---|---|")
        for ph in phases:
            a, b = ra[ph], rb[ph]
            unit = a["unit"] or b["unit"]
            per = (f"{fnum(a['per_unit'], 3)} → {fnum(b['per_unit'], 3)} per {unit} ({delta(a['per_unit'], b['per_unit'], 3, True)})"
                   if unit else "—")
            verdict = "—"
            if a["ok"] is not None or b["ok"] is not None:
                word = lambda ok: "—" if ok is None else ("pass" if ok else "**MISS**")
                verdict = f"{word(a['ok'])} → {word(b['ok'])}"
            out.append(f"| {ph} | {a['own_pct']:.3f} → {b['own_pct']:.3f} | {delta(a['own_pct'], b['own_pct'], 3, True)} | "
                       f"{fnum(a['own'])} → {fnum(b['own'])} | {delta(a['own'], b['own'], 2)} | "
                       f"{fnum(a['fp'], 1)} → {fnum(b['fp'], 1)} | {delta(a['fp'], b['fp'], 1)} | {per} | "
                       f"{split_text(a['split'], a['busy'])} | {split_text(b['split'], b['busy'])} | "
                       f"{a['lock']} / {b['lock']} | {verdict} |")
        only = sorted((set(pa) ^ set(pb)) - set(phases))
        if only:
            out.append(f"\nPhases in one variant only: {', '.join(only)}")
        ta, tb = timeline_of(runs_a[run]), timeline_of(runs_b[run])
        if ta and tb:
            out.append(f"\nTimeline: app wake-ups {ta['app_rate']:.2f} → {tb['app_rate']:.2f}/s, own "
                       f"{ta['own_rate']:.2f} → {tb['own_rate']:.2f}/s, seconds with two or more {ta['two']} → "
                       f"{tb['two']} (of {ta['dur']:.0f} / {tb['dur']:.0f} s), own CPU {ta['own_pct']:.3f} → "
                       f"{tb['own_pct']:.3f} %, lock {ta['locked']} / {tb['locked']}")
        out.append("")
    only_runs = sorted(set(runs_a) ^ set(runs_b))
    if only_runs and len(runs_a) + len(runs_b) > 2:
        out.append(f"Runs in one variant only: {', '.join(only_runs)}\n")
    text = "\n".join(out) + "\n"
    target = os.path.join(dir_b, f"compare-vs-{name_a}.md")
    open(target, "w").write(text)
    print(text)
    print(f"(saved to {target})")

mode = sys.argv[1]
if mode == "summarize":
    summarize(sys.argv[2])
elif mode == "compare":
    compare(sys.argv[2], sys.argv[3])
PY
}

case "${1:-}" in
  summarize)
    report summarize "${2:-$OUT}"
    exit 0 ;;
  compare)
    [[ -n "${2:-}" && -n "${3:-}" ]] || die "usage: scripts/perf.sh compare <dirA> <dirB>"
    [[ -d "$2" && -d "$3" ]] || die "compare needs two perf output folders (build/logs/perf/<variant> or one run in it)"
    report compare "$2" "$3"
    exit 0 ;;
esac

[[ -d "$APP" ]] || die "$APP not found; run make debug first"
codesign -d --entitlements - --xml "$APP" 2>/dev/null | grep -q "com.apple.security.get-task-allow" \
  || die "$APP is a Release build, which refuses --qa-simulate; use a Debug build"
(( PHASE >= SETTLE + MEASURE + SAMPLE + 8 )) || die "PHASE ($PHASE) must cover SETTLE + MEASURE + SAMPLE + 8 s"

# Tools: built from source into $TOOLS (no binary in the repository).
mkdir -p "$TOOLS"
PIDSTAT="$TOOLS/pidstat"
SESSION="$TOOLS/sessionstate"
CONTROL="$TOOLS/PerfControl.app"
if [[ ! -x "$PIDSTAT" ]]; then
  cat > "$TOOLS/pidstat.c" <<'C'
// pidstat: read-only counters of processes (proc_pid_rusage, proc_pidinfo); never attaches. No arguments: epoch ms.
//   <pid> <epoch_ms> <cpu_ns> <pkg_idle_wkups> <interrupt_wkups> <phys_footprint_B> <resident_B> <threads>
//   <billed_energy_nJ> <instructions> <cycles>
#include <libproc.h>
#include <mach/mach_time.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/resource.h>
#include <sys/time.h>
int main(int argc, char **argv) {
    mach_timebase_info_data_t tb; mach_timebase_info(&tb);
    struct timeval tv; gettimeofday(&tv, NULL);
    long long ms = (long long)tv.tv_sec * 1000 + tv.tv_usec / 1000;
    if (argc == 1) { printf("%lld\n", ms); return 0; }
    int status = 0;
    for (int i = 1; i < argc; i++) {
        int pid = atoi(argv[i]);
        struct rusage_info_v4 ru;
        if (proc_pid_rusage(pid, RUSAGE_INFO_V4, (rusage_info_t *)&ru) != 0) { printf("%d %lld NA\n", pid, ms); status = 1; continue; }
        struct proc_taskinfo ti; int threads = -1;
        if (proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &ti, sizeof ti) == (int)sizeof ti) threads = ti.pti_threadnum;
        unsigned long long cpu = (ru.ri_user_time + ru.ri_system_time) * tb.numer / tb.denom;   // ticks → ns
        printf("%d %lld %llu %llu %llu %llu %llu %d %llu %llu %llu\n", pid, ms, cpu,
               (unsigned long long)ru.ri_pkg_idle_wkups, (unsigned long long)ru.ri_interrupt_wkups,
               (unsigned long long)ru.ri_phys_footprint, (unsigned long long)ru.ri_resident_size, threads,
               (unsigned long long)ru.ri_billed_energy, (unsigned long long)ru.ri_instructions,
               (unsigned long long)ru.ri_cycles);
    }
    return status;
}
C
  xcrun clang -O2 -Wall -o "$PIDSTAT" "$TOOLS/pidstat.c" || die "pidstat did not build"
fi
if [[ ! -x "$SESSION" ]]; then
  cat > "$TOOLS/sessionstate.swift" <<'SWIFT'
// sessionstate: "locked=<0|1> onConsole=<0|1>" from CGSessionCopyCurrentDictionary (read-only).
import CoreGraphics
let d = (CGSessionCopyCurrentDictionary() as? [String: Any]) ?? [:]
let locked = (d["CGSSessionScreenIsLocked"] as? Bool) ?? false
let console = (d[kCGSessionOnConsoleKey as String] as? Bool) ?? false
print("locked=\(locked ? 1 : 0) onConsole=\(console ? 1 : 0)")
SWIFT
  xcrun swiftc -O -o "$SESSION" "$TOOLS/sessionstate.swift" || die "sessionstate did not build"
fi
if [[ ! -x "$CONTROL/Contents/MacOS/PerfControl" ]]; then
  rm -rf "$CONTROL"; mkdir -p "$CONTROL/Contents/MacOS"
  xcrun swiftc -swift-version 6 -O -o "$CONTROL/Contents/MacOS/PerfControl" "$ROOT/scripts/soak-control.swift" \
    || die "the control did not build"
  cat > "$CONTROL/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key><string>PerfControl</string>
  <key>CFBundleIdentifier</key><string>app.overbright.perf-control</string>
  <key>CFBundleName</key><string>PerfControl</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>LSUIElement</key><true/>
</dict>
</plist>
PLIST
  codesign -s - --force "$CONTROL" >/dev/null 2>&1 || die "the control could not be signed"
fi

now_ms() { "$PIDSTAT"; }

# Scenario builders. A steady phase is `dump start.<name>; <body>; dump end.<name>`.
steady() { printf 'dump start.%s; wait %s; dump end.%s' "$1" "$PHASE" "$1"; }
# Alternate the slider between positions every `$2` seconds for PHASE seconds (a ramp storm or a drag).
moving() {
  local name="$1" every="$2" body="" t=0 i=0 positions
  positions=(0.30 0.36 0.42 0.48 0.54 0.60 0.66 0.72 0.78 0.84 0.90 0.84 0.78 0.72 0.66 0.60 0.54 0.48 0.42 0.36)
  if [[ "$every" == 1 ]]; then positions=(0.40 0.80); fi
  local limit
  limit="$(awk -v p="$PHASE" -v e="$every" 'BEGIN { printf "%d", p / e }')"
  while (( i < limit )); do
    body="$body level ${positions[$(( i % ${#positions[@]} ))]}; wait $every;"
    i=$(( i + 1 ))
  done
  printf 'dump start.%s;%s dump end.%s' "$name" "$body" "$name"
}
# Brighter and Less Bright as global shortcuts every 2 s: each shows the HUD.
hud() {
  local body="" i=0 limit=$(( PHASE / 4 ))
  while (( i < limit )); do body="$body brighter; wait 2; less; wait 2;"; i=$(( i + 1 )); done
  printf 'dump start.hud;%s dump end.hud' "$body"
}
# `$1` repetitions of the steps `$2` (the step language has no repeat).
repeat() {
  local body="" i=0
  while (( i < $1 )); do body="$body $2"; i=$(( i + 1 )); done
  printf '%s' "$body"
}
# A counted phase: `begin.<name>`, the clean part (`$3` steps doing `$2` things of kind `$4`) between two 1 s rests
# (so both readings fall where the app is idle, whatever the 0.25 s polling of the status file), `clean.<name>`, the
# tail `$5` that `sample` watches for `$6` s (no tail with SAMPLE=0), 3 s of rest, `finish.<name>` (footprint).
# Records the count in units.tsv, which `summarize` divides by.
counted() {
  local name="$1" count="$2" clean="$3" unit="$4" tail="$5" seconds="$6"
  (( SAMPLE > 0 )) || { tail=""; seconds=0; }
  (( seconds <= SAMPLE )) || seconds="$SAMPLE"
  printf '%s\t%s\t%s\t%s\n' "$name" "$count" "$unit" "$seconds" >> "$RUN_OUT/units.tsv"
  printf 'dump begin.%s; wait 1;%s wait 1; dump clean.%s;%s wait 3; dump finish.%s' "$name" "$clean" "$name" "$tail" "$name"
}
screen_events() {   # <count> <gap s>
  repeat "$1" "event screen-parameters; wait $2;"
}
bursts() {   # <count>: bursts of 120 events 8 ms apart, one every 5 s
  repeat "$1" "$(screen_events 120 0.008) wait 4;"
}

# Every script ends with a rest before `quit`: the status file is read every 0.25 s while the app runs, so a label
# dumped right before the app quits would never be seen (and a counted phase's footprint never read).
script_for() {
  local pre="dump ready; wait 2; panel close; wait 2"
  case "$1" in
    launch)  printf '%s; wait 20; quit' "$pre" ;;
    base)    printf '%s; %s; %s; on; wait 12; %s; %s; panel open; wait 3; %s; %s; panel close; level bright-room; wait 3; %s; level bright-room; wait 3; %s; level bright-room; wait 3; dim 40; wait 5; %s; %s; off; wait 5; panel open; wait 3; %s; panel close; wait 5; %s; %s; quit' \
               "$pre" "$(steady off-1)" "$(steady off-2)" "$(steady boosted-1)" "$(steady boosted-2)" \
               "$(steady panel-boosted)" "$(moving panel-drag 0.1)" "$(moving storm 1)" "$(hud)" \
               "$(steady dimmed-1)" "$(steady dimmed-2)" "$(steady panel-off)" "$(steady off-final-1)" \
               "$(steady off-final-2)" ;;
    ruleoff) printf '%s; on; wait 12; %s; %s; off; wait 3; quit' "$pre" "$(steady boosted-1)" "$(steady boosted-2)" ;;
    ui)      printf '%s; %s; on; wait 12; panel open; wait 3; panel close; wait 3; level bright-room; wait 3; %s; level bright-room; wait 3; %s; off; wait 5; %s; quit' \
               "$pre" "$(steady off-1)" "$(moving storm 1)" "$(hud)" "$(steady off-final-1)" ;;
    two)     printf '%s; boost msi on; wait 2; %s; on; wait 15; %s; %s; off; wait 5; %s; quit' \
               "$pre" "$(steady off-1)" "$(steady boosted-1)" "$(steady boosted-2)" "$(steady off-final-1)" ;;
    events)  printf '%s; wait 3; %s; on; wait 12; %s; %s; panel open; wait 3; %s; panel close; off; wait 3; dump done; wait 2; quit' "$pre" \
               "$(counted events-off "$EVENTS" "$(screen_events "$EVENTS" 0.01)" event "$(screen_events 500 0.01)" 5)" \
               "$(counted events-boosted "$EVENTS" "$(screen_events "$EVENTS" 0.01)" event "$(screen_events 500 0.01)" 5)" \
               "$(counted bursts-boosted 720 "$(bursts 6)" event "$(bursts 2)" 10)" \
               "$(counted bursts-panel 720 "$(bursts 6)" event "$(bursts 2)" 10)" ;;
    panelcycle) printf '%s; wait 3; %s; wait 2; dump done; wait 2; quit' "$pre" \
               "$(counted panelcycle "$PANEL_CYCLES" "$(repeat "$PANEL_CYCLES" "panel open; wait 2; panel close; wait 2;")" open \
                  "$(repeat 5 "panel open; wait 2; panel close; wait 2;")" 10)" ;;
    timeline) printf '%s; boost msi on; wait 2; on; wait 15; dump timeline.start; wait %s; dump timeline.end; off; wait 3; dump done; wait 2; quit' \
               "$pre" "$TIMELINE" ;;
    *) die "unknown run $1 (launch, base, ruleoff, two, ui, events, panelcycle, timeline)" ;;
  esac
}
fixture_for() { case "$1" in two|timeline) echo russian-names ;; *) echo builtin-xdr-lid-open ;; esac; }
extra_args_for() {
  case "$1" in
    ruleoff) echo "-overbright.automations.pauseForFullScreenVideo $FALSE" ;;
    *) echo "" ;;
  esac
}

pid=""; control_pid=""; RUN_OUT=""
stats() {   # <phase> <tag>
  local line lock load
  line="$("$PIDSTAT" "$pid" "$control_pid" 2>/dev/null | tr '\n' ' ' || true)"
  lock="$("$SESSION" 2>/dev/null || echo "locked=? onConsole=?")"
  load="$(sysctl -n vm.loadavg | tr -d '{}' | awk '{print $1}')"
  printf '%s\t%s\t%s\t%s\t%s\n' "$1" "$2" "$line" "$lock" "$load" >> "$RUN_OUT/stats.tsv"
}
memory() {  # <label>
  /usr/bin/footprint "$pid" > "$RUN_OUT/footprint-$1.txt" 2>&1 || true
  /usr/bin/vmmap --summary "$pid" > "$RUN_OUT/vmmap-$1.txt" 2>&1 || true
}
phase_job() {   # <phase>: SETTLE, the clean window, then sample, footprint, vmmap
  local name="$1"
  sleep "$SETTLE"
  stats "$name" A
  sleep "$MEASURE"
  stats "$name" B
  if (( SAMPLE > 0 )); then /usr/bin/sample "$pid" "$SAMPLE" -file "$RUN_OUT/sample-$name.txt" >/dev/null 2>&1 || true; fi
  memory "$name"
  stats "$name" M
  touch "$RUN_OUT/.done-$name"
}
timeline_job() {   # one line per second (both processes' counters, then the lock) until the run marks the end
  while [[ ! -f "$RUN_OUT/.timeline-end" ]] && kill -0 "$pid" 2>/dev/null; do
    { "$PIDSTAT" "$pid" "$control_pid" 2>/dev/null | tr '\n' ' ' || true; "$SESSION" 2>/dev/null || echo "locked=?"; } \
      | tr '\n' ' ' >> "$RUN_OUT/timeline.txt"
    echo >> "$RUN_OUT/timeline.txt"
    sleep 1
  done
}

run_one() {
  local run="$1" suite script fixture extra status_file seen total label t job_pids="" sample_pid="" seconds
  RUN_OUT="$OUT/$run"
  rm -rf "${RUN_OUT:?}"; mkdir -p "$RUN_OUT"
  suite="app.overbright.Overbright.perf.$VARIANT.$run.$$"
  defaults delete "$suite" >/dev/null 2>&1 || true
  script="$(script_for "$run")"; fixture="$(fixture_for "$run")"; extra="$(extra_args_for "$run")"
  status_file="$RUN_OUT/status.jsonl"
  printf '%s\n' "$script" > "$RUN_OUT/script.txt"
  log "perf $VARIANT/$run: $fixture; output in $RUN_OUT"
  printf 'open\t%s\n' "$(now_ms)" > "$RUN_OUT/marks.tsv"
  # shellcheck disable=SC2086
  /usr/bin/open -n -g "$APP" --args --qa-simulate "$fixture" --qa-defaults-suite "$suite" --qa-panel \
    -overbright.onboarding.completedVersion "$WELCOME_DONE" $extra --qa-script "$script" --qa-status "$status_file"
  pid=""
  for _ in $(seq 1 200); do
    pid="$(pgrep -f -- "--qa-defaults-suite $suite" | head -1 || true)"
    [[ -n "$pid" ]] && break
    sleep 0.05
  done
  [[ -n "$pid" ]] || die "the app did not start"
  printf 'pid\t%s\n' "$(now_ms)" >> "$RUN_OUT/marks.tsv"
  /usr/bin/open -n -g "$CONTROL" --args --follow "$pid"
  control_pid=""
  for _ in $(seq 1 100); do
    control_pid="$(pgrep -f -- "PerfControl --follow $pid" | head -1 || true)"
    [[ -n "$control_pid" ]] && break
    sleep 0.1
  done
  [[ -n "$control_pid" ]] || die "the control did not start"
  echo "$pid $control_pid" > "$RUN_OUT/pid.txt"
  stats launch P
  if [[ "$run" == launch ]] && (( SAMPLE > 0 )); then
    /usr/bin/sample "$pid" "$SAMPLE" -file "$RUN_OUT/sample-launch.txt" >/dev/null 2>&1 &
  fi
  /usr/bin/top -l 0 -s 10 -pid "$pid" -pid "$control_pid" -stats pid,cpu,idlew,power,mem,th,time > "$RUN_OUT/top.txt" 2>&1 &
  local top_pid=$!
  seen=0
  while kill -0 "$pid" 2>/dev/null; do
    total=0
    [[ -f "$status_file" ]] && total="$(wc -l < "$status_file" | tr -d ' ')"
    while (( seen < ${total:-0} )); do
      seen=$(( seen + 1 ))
      label="$(sed -n "${seen}p" "$status_file" | sed -E 's/.*"label":"([^"]*)".*/\1/')"
      t="$(now_ms)"
      printf '%s\t%s\n' "$label" "$t" >> "$RUN_OUT/marks.tsv"
      case "$label" in
        ready) stats launch R; memory ready ;;
        start.*) phase_job "${label#start.}" & job_pids="$job_pids $!" ;;
        end.*) [[ -f "$RUN_OUT/.done-${label#end.}" ]] || warn "$run: ${label#end.} ended before its measurement finished" ;;
        begin.*) stats "${label#begin.}" A ;;
        clean.*)
          stats "${label#clean.}" B
          seconds="$(awk -F'\t' -v p="${label#clean.}" '$1 == p { print $4 }' "$RUN_OUT/units.tsv")"
          if (( ${seconds:-0} > 0 )); then
            /usr/bin/sample "$pid" "$seconds" -file "$RUN_OUT/sample-${label#clean.}.txt" >/dev/null 2>&1 &
            sample_pid=$!
          fi ;;
        finish.*)
          if [[ -n "$sample_pid" ]]; then wait "$sample_pid" 2>/dev/null || true; sample_pid=""; fi
          memory "${label#finish.}"; stats "${label#finish.}" M ;;
        timeline.start) timeline_job & job_pids="$job_pids $!" ;;
        timeline.end) touch "$RUN_OUT/.timeline-end" ;;
      esac
    done
    sleep 0.25
  done
  for j in $job_pids; do wait "$j" 2>/dev/null || true; done
  kill "$top_pid" 2>/dev/null || true
  wait "$top_pid" 2>/dev/null || true
  for _ in $(seq 1 20); do kill -0 "$control_pid" 2>/dev/null || break; sleep 0.5; done
  kill "$control_pid" 2>/dev/null || true
  defaults delete "$suite" >/dev/null 2>&1 || true
  rm -f "$HOME/Library/Preferences/$suite.plist" "$RUN_OUT"/.done-* "$RUN_OUT/.timeline-end"
  # Every phase must have run in the simulated wiring: no real table write, no window ordered in (D24).
  if grep -q '"gammaWrites"' "$status_file"; then
    log "  phases: $(grep -c -E '"label":"(start|begin)\.' "$status_file") measured; the fakes' counters: $(tail -1 "$status_file" | sed -E 's/.*("gammaWrites":[0-9]+).*("triggerWindows":[0-9]+).*/\1 \2/')"
  fi
}

mkdir -p "$OUT"
runs=("$@")
(( ${#runs[@]} )) || runs=(launch base ruleoff two)
KNOWN_RUNS="launch base ruleoff two ui events panelcycle timeline"
for run in "${runs[@]}"; do                                        # an unknown run fails before anything starts
  [[ " $KNOWN_RUNS " == *" $run "* ]] || die "unknown run $run ($KNOWN_RUNS)"
done
for run in "${runs[@]}"; do run_one "$run"; done
report summarize "$OUT" > /dev/null
log "perf $VARIANT done: $OUT/perf.md"
