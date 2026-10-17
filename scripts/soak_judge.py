#!/usr/bin/env python3
"""Judges a soak run of scripts/soak.sh (ARCHITECTURE.md §10.15, DESIGN.md §17). Standard library only.

Inputs, in the soak's output directory: footprint.txt (`== <mark> <epoch>` lines, each followed by `footprint`'s
phys_footprint in whole MB and `vmmap --summary`'s "Physical footprint" in tenths, which wins), top.txt (`top -l 0 -s 10 -stats pid,cpu,idlew,…` for the app and the control) and status.jsonl
(one `dump` per scripted label; "cycle-end" once per cycle).

Idle wake-ups while off, per 10 s top sample: a wake-up the control app (scripts/soak-control.swift) has in the same
sample is the system's, handed to every menu bar app that follows the keyboard layout (shared); the rest are
Overbright's own. In the final off phase, after the cycles, Overbright may have none of its own: one fails the run
(DESIGN.md §17: off is 0 wake-ups/s, no periodic timers or tasks), so a slow timer, a task the cycles left behind and
a beat at the sampling interval itself fail however irregularly they show. The first off phase follows the launch,
whose one-shot work may wake the app a few times; there own wake-ups must only not beat periodically. A run of 4 or
more of them in a row (3 for the final phase's shared samples, below) spanning 30 s or more is scored by how evenly
it beats: with median gap m and gaps straying at most d from it, (L - 2) * ln((2d + one sample) / m), so each
wake-up after the first two that lands in a narrow window around where the beat puts it counts. The run is a timer
only when as many wake-ups at random samples of the same phase beat as evenly less than 2 % of the time (CHANCE;
2 000 seeded random placements, so a run is judged the same way twice). A few wake-ups at random times line up now
and then: a fixed tolerance (gaps within 25 % of their median) called 3, 4 and 5 random ones periodic 31, 55 and
73 % of the time, which brought back the flaky soak WP13 saw on a Mac in use. Shared samples are counted, not
dropped: in either phase, when the samples the app woke in beat that way and the control's do not, a timer of
Overbright's own is hiding behind the control's wake-ups. The self-test refuses at most 3 % of 1 000 seeded draws of
4, 5 or 6 own wake-ups at random samples of the first phase (with or without 2 shared ones) and at most 5 % of draws
in which the app shares 3, 4 or 5 of the control's random samples in the final phase, while timers every 20 s after
launch and every 60 s behind the control's samples are caught. Until WP14's last round the final phase allowed one
own wake-up a minute that did not beat periodically, which let a slow timer showing only 3 or 4 times pass. The
literal "0 idle wake-ups while off" on a quiet machine is the owner's run (HARDWARE-TEST §13).

Footprint: the first cycles fill caches that then stay, so growth is judged from cycle 3 on. The footprint before
the cycles and after cycles 1 and 2 is reported, not judged (WP13's 30-minute run: 31 MB off before the cycles, 42
after cycle 1, 46 after cycle 2, 47 after cycle 3), so growth that stops by cycle 3 passes. The least-squares slope
of the footprint after cycles 3…N is a leak when it exceeds LEAK_KB per cycle even at its lower 2-standard-error
bound (a short run's slope is noisy: the 17-minute run's settling read 129 ± 142 KB per cycle, ± 2 standard errors
as printed, so its lower bound is -13; a real 0.29 MB per cycle leak reads 288 ± 102, at least 186, even in a short
run); and the footprint at the end must be within LEAK_MB of the one after cycle 3. A run needs at least 5 cycles
after cycle 3 to be judged at all.

    soak_judge.py <out> <leak_mb> <leak_kb_per_cycle> <app pid> <control pid>
    soak_judge.py --minimum-cycles        # the fewest cycles a run needs (scripts/soak.sh refuses shorter runs)
    soak_judge.py --self-test             # make lint runs it
"""
import bisect
import datetime
import math
import random
import re
import sys

SAMPLE = 10                 # top's interval, s
SETTLED_CYCLE = 3           # the footprint baseline
JUDGED_CYCLES = 5           # cycles after the baseline a run needs
MIN_SPAN = 3 * SAMPLE       # a burst of wake-ups in neighbouring samples is not a timer
CHANCE = 0.02               # a run is a timer when random times beat as evenly less often than this
DRAWS = 2000                # random placements the chance is estimated from
SEED = 2026                 # their seed: the same run is judged the same way every time


def minimum_cycles():
    return SETTLED_CYCLE + JUDGED_CYCLES


def median(values):
    ordered = sorted(values)
    middle = len(ordered) // 2
    return ordered[middle] if len(ordered) % 2 else (ordered[middle - 1] + ordered[middle]) / 2


def evenness(times, minimum):
    """(score, run) of the most evenly beating run of `minimum` or more consecutive wake-up times that spans MIN_SPAN
    or more: (L - 2) * ln((2d + SAMPLE) / m) for L times with median gap m whose gaps stray at most d from it; lower
    is more even. (0, None) when no run's window, 2d + SAMPLE, is narrower than its median gap."""
    best, best_run = 0.0, None
    for start in range(len(times)):
        gaps = []                                               # sorted gaps of times[start:end]
        for end in range(start + 2, len(times) + 1):
            bisect.insort(gaps, times[end - 1] - times[end - 2])
            if end - start < minimum or times[end - 1] - times[start] < MIN_SPAN:
                continue
            middle = median(gaps)
            stray = max(middle - gaps[0], gaps[-1] - middle)
            score = (end - start - 2) * math.log((2 * stray + SAMPLE) / middle)
            if score < best:
                best, best_run = score, times[start:end]
    return best, best_run


_placements = {}                                                # sorted scores of DRAWS placements, per phase and count


def share(chance):
    """`chance` as a percentage; the estimate's floor is 1 in DRAWS + 1."""
    return f"{chance:.1%}" if chance >= 0.001 else "under 0.1%"


def periodic(times, slots, minimum):
    """(run, chance) when the wake-ups at `times`, among the phase's sample times `slots`, beat more evenly than as
    many wake-ups at random samples do in CHANCE of DRAWS seeded placements; None otherwise."""
    score, run = evenness(times, minimum)
    if run is None or len(times) >= len(slots):
        return None                                             # every sample: no placement differs
    key = (tuple(slots), len(times), minimum)
    if key not in _placements:
        draw = random.Random(SEED)
        _placements[key] = sorted(evenness(sorted(draw.sample(slots, len(times))), minimum)[0] for _ in range(DRAWS))
    chance = (bisect.bisect_right(_placements[key], score + 1e-9) + 1) / (DRAWS + 1)
    return (run, chance) if chance < CHANCE else None


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
    slots = [at for at, _, _ in rows]
    found = periodic([at for at, _ in own], slots, minimum)
    if found:
        run, chance = found
        gaps = [int(b - a) for a, b in zip(run, run[1:])]
        problems.append(f"{name}: Overbright's own wake-ups beat periodically (at {', '.join(f'+{int(t)}' for t in run)} "
                        f"s, gaps {', '.join(map(str, gaps))} s; random times beat as evenly {share(chance)} of the time)")
    else:
        mine = periodic([at for at, count, _ in rows if count > 0], slots, minimum)
        if mine and not periodic([at for at, _, theirs in rows if theirs > 0], slots, minimum):
            problems.append(f"{name}: Overbright's wake-ups beat periodically once the samples the control also woke in "
                            f"count (at {', '.join(f'+{int(t)}' for t in mine[0])} s, random times {share(mine[1])}); "
                            f"the control's do not")
    if strict and own:
        problems.append(f"{name}: {own_total} idle wake-up{'s' if own_total > 1 else ''} of Overbright's own in "
                        f"{span} s (at {when} s); none is allowed once the cycles are over")
    return report, problems


def slope(points):
    """(least-squares slope, its standard error) of (x, y) points; the error is 0 with fewer than 3 points."""
    n = len(points)
    mean_x = sum(x for x, _ in points) / n
    mean_y = sum(y for _, y in points) / n
    spread = sum((x - mean_x) ** 2 for x, _ in points)
    if not spread:
        return 0.0, 0.0
    b = sum((x - mean_x) * (y - mean_y) for x, y in points) / spread
    if n < 3:
        return b, 0.0
    residual = sum((y - (mean_y + b * (x - mean_x))) ** 2 for x, y in points)
    return b, (residual / (n - 2)) ** 0.5 / spread ** 0.5


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
            b, error = slope(points)
            per_cycle, margin = b * 1024, 2 * error * 1024
            lines.append(f"growth over cycles {SETTLED_CYCLE}…{cycles}: {per_cycle:.0f} ± {margin:.0f} KB per cycle "
                         f"(a leak when above {leak_kb:.0f} even at {per_cycle - margin:.0f})")
            if per_cycle - margin > leak_kb:
                problems.append(f"the footprint grows {per_cycle:.0f} ± {margin:.0f} KB per cycle over cycles "
                                f"{SETTLED_CYCLE}…{cycles} (at most {leak_kb:.0f})")
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
    print("\n".join(problems) or "soak OK: no growth once settled; no wake-up of Overbright's own in the final off "
                                     "phase and none periodic after launch")
    return 1 if problems else 0


def self_test():
    """The judge against synthetic runs: what it must refuse and what it must accept."""
    def off(times, control=(), span=360, strict=True, counts=None):
        rows = [(float(at), (counts or {}).get(at, 0) + (1 if at in times else 0), 1 if at in control else 0)
                for at in range(SAMPLE, span + 1, SAMPLE)]
        return judge_off("final off" if strict else "first off", rows, span, strict)[1]
    def refused_after_launch(k, shared=0, draws=1000):
        """The share of `draws` seeded placements of k own wake-ups at random samples of a 95 s first phase (plus
        `shared` samples the control woke in too) that the judge refuses: launch work, no timer."""
        draw = random.Random(100 * k + shared + 7)
        slots = list(range(SAMPLE, 91, SAMPLE))
        picks = [draw.sample(slots, k + shared) for _ in range(draws)]
        return sum(bool(off(pick, control=pick[k:], span=95, strict=False)) for pick in picks) / draws
    def refused_behind_control(k, extra=3, draws=1000):
        """The share of `draws` seeded placements of k + `extra` control wake-ups at random samples of a 360 s final
        phase, the app waking in the first k of them only, that the judge refuses: no own wake-up, no hidden timer."""
        draw = random.Random(1000 * k + extra)
        slots = list(range(SAMPLE, 361, SAMPLE))
        picks = [draw.sample(slots, k + extra) for _ in range(draws)]
        return sum(bool(off(pick[:k], control=pick)) for pick in picks) / draws
    def cycles(values, end=None):
        marks = {f"cycle{i}-end": {"mb": mb} for i, mb in enumerate(values, 1)}
        marks["final-off-end"] = {"mb": values[-1] if end is None else end}
        return judge_footprint(marks, len(values), 5, 100)[1]
    cases = [
        ("final off: none", off([]), False),
        ("final off: one of Overbright's own", off([250]), True),
        ("final off: two at random", off([40, 250]), True),
        ("final off: three at uneven gaps", off([20, 50, 300]), True),
        ("final off: five at irregular gaps (WP13's review run had 5)", off([30, 100, 150, 260, 330]), True),
        ("final off: a slow timer showing three times (every 125 s)", off([60, 190, 310]), True),
        ("final off: only wake-ups the control shares", off([40, 250], control=[40, 250]), False),
        ("final off: one more than the control in a shared sample", off([40], control=[40], counts={40: 1}), True),
        ("final off: every 120 s", off([10, 130, 250]), True),
        ("final off: every 100 s", off([60, 160, 260]), True),
        ("final off: every 65 s with 8 s of jitter", off([10, 70, 140, 200, 270, 330]), True),
        ("final off: every 60 s", off([10, 70, 130, 190, 250, 310]), True),
        ("final off: every 60 s, starting 100 s in", off([100, 160, 220, 280, 340]), True),
        ("final off: every sample", off(list(range(10, 361, 10))), True),
        ("final off: a burst after off", off([10, 20, 30]), True),
        ("final off: seven at random", off([10, 40, 100, 110, 200, 230, 330]), True),
        ("final off: every 60 s, half of them in the control's samples",
         off([10, 70, 130, 190, 250, 310], control=[70, 200, 250]), True),
        ("final off: the control's own rhythm, shared", off([70, 130, 190, 250], control=[70, 130, 190, 250]), False),
        ("final off: every 60 s, all behind the control's irregular wake-ups",
         off([10, 70, 130, 190, 250, 310], control=[10, 20, 50, 70, 100, 130, 190, 220, 250, 290, 310]), True),
        ("first off: three after launch at even gaps", off([20, 50, 80], span=95, strict=False), False),
        ("first off: five after launch at irregular gaps", off([10, 20, 50, 60, 90], span=95, strict=False), False),
        ("first off: every 20 s", off([10, 30, 50, 70, 90], span=95, strict=False), True),
        ("footprint: WP13's 30-minute run", cycles([42.3, 46.5, 47.3, 47.5, 47.6, 47.4, 47.5, 47.7, 47.7, 47.7, 48.1, 48.0,
                                                    47.9, 48.1, 48.1, 47.9, 47.8, 48.1, 48.3, 48.2], end=48.0), False),
        ("footprint: the shortest run, settled", cycles([42.3, 46.5, 47.3, 47.5, 47.6, 47.4, 47.5, 47.7]), False),
        ("footprint: WP14's 17-minute run, still settling",
         cycles([42.4, 46.2, 46.5, 46.7, 46.8, 47.5, 47.1, 47.0], end=46.0), False),
        ("footprint: a short run leaking 0.29 MB per cycle, noisy",
         cycles([42.4, 46.2] + [46.5 + 0.29 * i + e for i, e in enumerate([0, 0.2, -0.1, 0.3, -0.2, 0.1])]), True),
        ("footprint: a long run leaking 0.15 MB per cycle, noisy",
         cycles([42.4, 46.2] + [47 + 0.15 * i + e for i, e in enumerate([0, 0.2, -0.1, 0.3, -0.2, 0.1] * 3)]), True),
        ("footprint: 0.29 MB per cycle", cycles([31, 42, 46] + [46 + 0.29 * i for i in range(1, 15)]), True),
        ("footprint: a jump while off", cycles([31, 42, 46, 46, 46, 46, 46, 46, 46], end=53), True),
        ("footprint: too few cycles", cycles([31, 42, 46, 46, 46]), True),
    ]
    # Random wake-ups that no timer causes: a fixed 25 % tolerance refused 31, 55 and 73 % of 3, 4 and 5 of them.
    rates = [(f"first off: {k} own at random times", refused_after_launch(k), 0.03) for k in (4, 5, 6)]
    rates += [(f"first off: {k} own and 2 shared at random times", refused_after_launch(k, shared=2), 0.03)
              for k in (4, 5, 6)]
    rates += [(f"final off: {k} of the control's {k + 3} random samples shared", refused_behind_control(k), 0.05)
              for k in (3, 4, 5)]
    failures = [f"{label}: {'expected a problem' if refuse else 'expected none'}, got {found}"
                for label, found, refuse in cases if bool(found) != refuse]
    failures += [f"{label}: {rate:.1%} of 1000 seeded draws refused, at most {limit:.0%}"
                 for label, rate, limit in rates if rate > limit]
    print("\n".join(failures) or f"soak judge self-test OK ({len(cases)} cases; random times refused: "
                                  + ", ".join(f"{label} {rate:.1%}" for label, rate, _ in rates) + ")")
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
