#!/usr/bin/env python3
"""Judges a soak run of scripts/soak.sh (ARCHITECTURE.md §10.15, DESIGN.md §17). Standard library only.

Inputs, in the soak's output directory: footprint.txt (`== <mark> <epoch>` lines, each followed by `footprint`'s
phys_footprint in whole MB and `vmmap --summary`'s "Physical footprint" in tenths, which wins), top.txt (`top -l 0 -s 10 -stats pid,cpu,idlew,…` for the app and the control) and status.jsonl
(one `dump` per scripted label; "cycle-end" once per cycle).

Idle wake-ups while off, per 10 s top sample: a wake-up the control app (scripts/soak-control.swift) has in the same
sample is the system's, handed to every menu bar app that follows the keyboard layout (shared); the rest are
Overbright's own. In both off phases, own wake-ups must not recur: 3 or more in a row (4 in the first phase, which
follows the launch) whose gaps agree within 25 % of their median (at least one sample, the quantization) and that
span 30 s or more. Shared samples are counted, not dropped: when the samples the app woke in recur that way and the
control's do not, a timer of Overbright's own is hiding behind the control's wake-ups. In the final off phase own
wake-ups must also stay at one a minute or fewer. The literal "0 idle wake-ups while off" is the owner's quiet-machine
run (HARDWARE-TEST §13).

Footprint: the first cycles fill caches that then stay, so growth is judged from cycle 3 on: the least-squares slope
of the footprint after cycles 3…N must stay within LEAK_KB per cycle, and the footprint at the end within LEAK_MB of
the one after cycle 3. A run needs at least 5 cycles after cycle 3 to be judged at all.

    soak_judge.py <out> <leak_mb> <leak_kb_per_cycle> <app pid> <control pid>
    soak_judge.py --minimum-cycles        # the fewest cycles a run needs (scripts/soak.sh refuses shorter runs)
    soak_judge.py --self-test             # make lint runs it
"""
import datetime
import re
import sys

SAMPLE = 10                 # top's interval, s
SETTLED_CYCLE = 3           # the footprint baseline
JUDGED_CYCLES = 5           # cycles after the baseline a run needs
TOLERANCE = 0.25            # gaps that agree: within 25 % of their median
MIN_SPAN = 3 * SAMPLE       # a burst of wake-ups in neighbouring samples is not a timer


def minimum_cycles():
    return SETTLED_CYCLE + JUDGED_CYCLES


def median(values):
    ordered = sorted(values)
    middle = len(ordered) // 2
    return ordered[middle] if len(ordered) % 2 else (ordered[middle - 1] + ordered[middle]) / 2


def recurring(times, minimum):
    """The longest run of `minimum` or more consecutive wake-up times whose gaps agree (each within
    max(25 % of their median, one sample) of it) and that spans MIN_SPAN or more; None without one."""
    best = None
    for start in range(len(times)):
        for end in range(start + minimum, len(times) + 1):
            run = times[start:end]
            gaps = [b - a for a, b in zip(run, run[1:])]
            middle = median(gaps)
            if run[-1] - run[0] >= MIN_SPAN and all(abs(gap - middle) <= max(TOLERANCE * middle, SAMPLE)
                                                    for gap in gaps):
                if best is None or len(run) > len(best):
                    best = run
    return best


def judge_off(name, rows, span, strict):
    """rows: per top sample of the phase, (seconds after its start, the app's wake-ups, the control's or None).
    Returns (report line, problems)."""
    problems = []
    if any(theirs is None for _, _, theirs in rows):
        problems.append(f"{name}: the control was not sampled throughout; nothing to compare with")
        rows = [(at, mine, theirs or 0) for at, mine, theirs in rows]
    total = sum(mine for _, mine, _ in rows)
    own = [(at, mine - theirs) for at, mine, theirs in rows if mine > theirs]
    shared = sum(min(mine, theirs) for _, mine, theirs in rows)
    own_total = sum(count for _, count in own)
    when = ", ".join(f"+{int(at)}" for at, _ in own)
    report = (f"{name}: {total} idle wake-ups in {span} s, the control {sum(t for _, _, t in rows)}; {shared} shared, "
              f"{own_total} Overbright's own" + (f" (at {when} s)" if own else ""))
    minimum = 3 if strict else 4
    run = recurring([at for at, _ in own], minimum)
    if run:
        gaps = [int(b - a) for a, b in zip(run, run[1:])]
        problems.append(f"{name}: Overbright's own wake-ups recur (at {', '.join(f'+{int(t)}' for t in run)} s, "
                        f"gaps {', '.join(map(str, gaps))} s)")
    else:
        mine = recurring([at for at, count, _ in rows if count > 0], minimum)
        if mine and not recurring([at for at, _, theirs in rows if theirs > 0], minimum):
            problems.append(f"{name}: Overbright's wake-ups recur once the samples the control also woke in count "
                            f"(at {', '.join(f'+{int(t)}' for t in mine)} s); the control's do not")
    if strict and own_total > span / 60:
        problems.append(f"{name}: {own_total} wake-ups of Overbright's own in {span} s, more than one a minute")
    return report, problems


def slope(points):
    """Least-squares slope of (x, y) points."""
    n = len(points)
    mean_x = sum(x for x, _ in points) / n
    mean_y = sum(y for _, y in points) / n
    spread = sum((x - mean_x) ** 2 for x, _ in points)
    return sum((x - mean_x) * (y - mean_y) for x, y in points) / spread if spread else 0.0


def judge_footprint(marks, cycles, leak_mb, leak_kb):
    """marks: {name: {"mb": footprint}}. Returns (report lines, problems)."""
    problems = []
    if cycles < minimum_cycles():
        problems.append(f"only {cycles} cycles: growth is judged over cycles {SETTLED_CYCLE}…N and needs "
                        f"{JUDGED_CYCLES} after cycle {SETTLED_CYCLE} (run at least {minimum_cycles()} cycles)")
    points = [(i, marks[f"cycle{i}-end"]["mb"]) for i in range(SETTLED_CYCLE, cycles + 1)
              if "mb" in marks.get(f"cycle{i}-end", {})]
    end = marks.get("final-off-end", {}).get("mb")
    lines = ["after each cycle: " + " ".join(str(marks[k].get("mb", "?")) for k in marks if re.match(r"cycle\d+-end", k))]
    if cycles >= minimum_cycles():
        if len(points) < cycles - SETTLED_CYCLE + 1:
            problems.append(f"footprints missing after some of cycles {SETTLED_CYCLE}…{cycles}")
        if len(points) >= 2:
            per_cycle = slope(points) * 1024
            lines.append(f"growth over cycles {SETTLED_CYCLE}…{cycles}: {per_cycle:.0f} KB per cycle "
                         f"(at most {leak_kb:.0f})")
            if per_cycle > leak_kb:
                problems.append(f"the footprint grows {per_cycle:.0f} KB per cycle over cycles {SETTLED_CYCLE}…{cycles}"
                                f" (at most {leak_kb:.0f})")
        if end is None or not points:
            problems.append(f"no footprint after cycle {SETTLED_CYCLE} or at the end")
        elif end - points[0][1] > leak_mb:
            problems.append(f"the footprint at the end is {end - points[0][1]:.1f} MB above cycle {SETTLED_CYCLE}'s "
                            f"(at most {leak_mb:.0f})")
    return lines, problems


def parse(out, app, control):
    marks, current = {}, None
    for line in open(f"{out}/footprint.txt"):
        if line.startswith("== "):
            name, stamp = line.split()[1:3]
            current = name
            marks[name] = {"t": int(stamp)}
        elif "phys_footprint:" in line and current and "vmmap" not in marks[current]:
            value, unit = re.search(r"phys_footprint:\s+([\d.]+)\s*(\w+)", line).groups()
            marks[current]["mb"] = float(value) * {"KB": 1 / 1024, "MB": 1, "GB": 1024}.get(unit, 1)
        elif line.startswith("Physical footprint:") and current:
            value, unit = re.search(r"Physical footprint:\s+([\d.]+)([KMG])", line).groups()
            marks[current]["mb"] = float(value) * {"K": 1 / 1024, "M": 1, "G": 1024}[unit]
            marks[current]["vmmap"] = True
    samples = []                                                # (stamp, {pid: cumulative idle wake-ups})
    for line in open(f"{out}/top.txt"):
        if re.match(r"^\d{4}/\d\d/\d\d \d\d:\d\d:\d\d", line):
            samples.append((datetime.datetime.strptime(line.strip(), "%Y/%m/%d %H:%M:%S").timestamp(), {}))
        elif re.match(r"^\d+\s", line) and samples:
            fields = line.split()
            samples[-1][1][fields[0]] = int(fields[2].rstrip("+-"))
    samples = [s for s in samples if app in s[1]]
    cycles = sum(1 for line in open(f"{out}/status.jsonl") if '"cycle-end"' in line)
    return marks, samples, cycles


def rows_between(marks, samples, a, b, app, control):
    """Per top sample between marks a and b: (seconds after a, the app's wake-ups, the control's or None)."""
    if a not in marks or b not in marks:
        return None
    ta, tb = marks[a]["t"], marks[b]["t"]
    first = [i for i, s in enumerate(samples) if s[0] <= ta]
    last = [i for i, s in enumerate(samples) if s[0] <= tb]
    if not first or not last:
        return None
    result = []
    for (t0, v0), (t1, v1) in zip(samples[first[-1]:last[-1]], samples[first[-1] + 1:last[-1] + 1]):
        theirs = v1[control] - v0[control] if control in v0 and control in v1 else None
        result.append((t1 - ta, v1[app] - v0[app], theirs))
    return result


def judge(out, leak_mb, leak_kb, app, control):
    marks, samples, cycles = parse(out, app, control)
    problems = []
    for name, (a, b), strict in [("first off", ("first-off-start", "first-off-end"), False),
                                 ("final off", ("final-off-start", "final-off-end"), True)]:
        rows = rows_between(marks, samples, a, b, app, control)
        if rows is None:
            problems.append(f"{name}: no samples")
            continue
        report, found = judge_off(name, rows, marks[b]["t"] - marks[a]["t"], strict)
        print(report)
        problems += found
    print(f"cycles: {cycles}; footprint MB: " + ", ".join(f"{k} {v.get('mb', '?')}" for k, v in marks.items()
                                                        if not re.match(r"cycle\d+-end", k)))
    lines, found = judge_footprint(marks, cycles, leak_mb, leak_kb)
    print("\n".join(lines))
    problems += found
    print("\n".join(problems) or "soak OK: no growth once settled; while off, no recurring wake-ups of Overbright's own")
    return 1 if problems else 0


def self_test():
    """The judge against synthetic runs: what it must refuse and what it must accept."""
    def off(times, control=(), span=360, strict=True, counts=None):
        rows = [(float(at), (counts or {}).get(at, 0) + (1 if at in times else 0), 1 if at in control else 0)
                for at in range(SAMPLE, span + 1, SAMPLE)]
        return judge_off("final off" if strict else "first off", rows, span, strict)[1]
    def cycles(values, end=None):
        marks = {f"cycle{i}-end": {"mb": mb} for i, mb in enumerate(values, 1)}
        marks["final-off-end"] = {"mb": values[-1] if end is None else end}
        return judge_footprint(marks, len(values), 5, 100)[1]
    cases = [
        ("final off: none", off([]), False),
        ("final off: two at random", off([40, 250]), False),
        ("final off: three at uneven gaps", off([20, 50, 300]), False),
        ("final off: every 120 s", off([10, 130, 250]), True),
        ("final off: every 100 s", off([60, 160, 260]), True),
        ("final off: every 65 s with 8 s of jitter", off([10, 70, 140, 200, 270, 330]), True),
        ("final off: every 60 s", off([10, 70, 130, 190, 250, 310]), True),
        ("final off: every sample", off(list(range(10, 361, 10))), True),
        ("final off: a burst after off", off([10, 20, 30]), False),
        ("final off: seven at random (more than one a minute)", off([10, 40, 100, 110, 200, 230, 330]), True),
        ("final off: every 60 s, half of them in the control's samples",
         off([10, 70, 130, 190, 250, 310], control=[70, 200, 250]), True),
        ("final off: the control's own rhythm, shared", off([70, 130, 190, 250], control=[70, 130, 190, 250]), False),
        ("first off: three after launch at even gaps", off([20, 50, 80], span=95, strict=False), False),
        ("first off: every 20 s", off([10, 30, 50, 70, 90], span=95, strict=False), True),
        ("footprint: WP13's 30-minute run", cycles([42.3, 46.5, 47.3, 47.5, 47.6, 47.4, 47.5, 47.7, 47.7, 47.7, 48.1, 48.0,
                                                    47.9, 48.1, 48.1, 47.9, 47.8, 48.1, 48.3, 48.2], end=48.0), False),
        ("footprint: the shortest run, settled", cycles([42.3, 46.5, 47.3, 47.5, 47.6, 47.4, 47.5, 47.7]), False),
        ("footprint: 0.29 MB per cycle", cycles([31, 42, 46] + [46 + 0.29 * i for i in range(1, 15)]), True),
        ("footprint: a jump while off", cycles([31, 42, 46, 46, 46, 46, 46, 46, 46], end=53), True),
        ("footprint: too few cycles", cycles([31, 42, 46, 46, 46]), True),
    ]
    failures = [f"{label}: {'expected a problem' if refuse else 'expected none'}, got {found}"
                for label, found, refuse in cases if bool(found) != refuse]
    print("\n".join(failures) or f"soak judge self-test OK ({len(cases)} cases)")
    return 1 if failures else 0


if __name__ == "__main__":
    if sys.argv[1:] == ["--self-test"]:
        sys.exit(self_test())
    if sys.argv[1:] == ["--minimum-cycles"]:
        print(minimum_cycles())
        sys.exit(0)
    if len(sys.argv) != 6:
        sys.exit(__doc__)
    out, leak_mb, leak_kb, app, control = sys.argv[1:6]
    sys.exit(judge(out, float(leak_mb), float(leak_kb), app, control))
