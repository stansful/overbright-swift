#!/usr/bin/env python3
"""Judges a soak run of scripts/lib/soak.sh (ARCHITECTURE.md §10.15, DESIGN.md §17). Standard library only.

Inputs, in the soak's output directory: footprint.txt (`== <mark> <epoch>` lines, each followed by `footprint`'s
phys_footprint in whole MB and `vmmap --summary`'s "Physical footprint" in tenths, which wins), pidstat.txt (every
10 s, perf.sh's read-only `pidstat` of the app and the control: proc_pid_rusage's cumulative interrupt wake-ups,
ri_interrupt_wkups, then the lock state), top.txt (`top -l 0 -s 10 -stats pid,cpu,idlew,…`, a cross-check that is
printed, not judged; a run without pidstat.txt, from before the energy work, is judged on its IDLEW) and status.jsonl
(one `dump` per scripted label; "cycle-end" once per cycle).

Wake-ups while off, per 10 s sample: a wake-up the control app (scripts/lib/soak-control.swift) has in the same sample
is the system's, handed to every menu bar app that follows the keyboard layout (shared); the rest are Overbright's own.
They are interrupt wake-ups, not `top`'s IDLEW: on a loaded Mac IDLEW reads 0 for every process while interrupt
wake-ups run at 0.5–1/s, so a judge of IDLEW sees no timer at all (energy work, H2). Off is "0 wake-ups/s" in
DESIGN.md §17's sense: no periodic wake-up. Interrupt wake-ups also count the irregular ones the system hands a
process (0.00–0.03/s of Overbright's own while off on the owner's Mac in use, at gaps of 1–134 s), so neither phase
fails on a single one:
- In the final off phase, after the cycles, Overbright's own wake-ups must not beat periodically (below) and must
  stay at or under OWN_RATE (0.05/s, 18 in the 6 minutes): a timer every 20 s or faster, a task the cycles left behind
  that keeps waking, and a beat at or faster than the sampling interval fail by their rate however irregularly they
  show.
- In the first off phase, which follows the launch, whose one-shot work may wake the app a few times, own wake-ups
  must only not beat periodically.
In either phase own wake-ups in every sample of the phase (4 or more over 30 s or more) are a beat at or faster than
the 10 s sampling and fail. Periodic: a run of 4 or more own wake-ups in a row (3 for the final phase's) spanning
30 s or more is scored by how evenly it beats: with median gap m and gaps straying at most d from it,
(L - 2) * ln((2d + one sample) / m), so each wake-up after the first two that lands in a narrow window around where
the beat puts it counts. The run is a timer only when as many wake-ups at random samples of the same phase beat as
evenly less than 2 % of the time (CHANCE; 2 000 seeded random placements, so a run is judged the same way twice). A
few wake-ups at random times line up now and then: a fixed tolerance (gaps within 25 % of their median) called 3, 4
and 5 random ones periodic 31, 55 and 73 % of the time, which brought back the flaky soak WP13 saw on a Mac in use.
Shared samples are counted, not dropped: in either phase, when the samples the app woke in beat that way and the
control's do not, a timer of Overbright's own is hiding behind the control's wake-ups. A timer slower than every
2 minutes shows 3 times or fewer in the final phase and cannot be told from chance; its rate (under 0.01/s) is far
below the limit, and the literal "0 idle wake-ups while off" on a quiet machine is the owner's run (HARDWARE-TEST
§13). The self-test refuses a planted 2 s timer in either phase, a 60 s timer, a 120 s one and 20 own wake-ups at
random in the final phase, accepts 18 at random and WP14's irregular off wake-ups, refuses at most 3 % of 1 000 seeded
draws of 4, 5 or 6 own wake-ups at random samples of the first phase (with or without 2 shared ones), of 6, 9 or 12 in
the final phase, and at most 5 % of draws in which the app shares 3, 4 or 5 of the control's random samples in the
final phase. Until the energy work's H2 the final phase allowed no own idle wake-up at all (WP14's last round), a
rule that counted `top`'s IDLEW and so could see nothing on a loaded Mac.

Footprint: the first cycles fill caches that then stay, so growth is judged from cycle 3 on. The footprint before
the cycles and after cycles 1 and 2 is reported, not judged (WP13's 30-minute run: 31 MB off before the cycles, 42
after cycle 1, 46 after cycle 2, 47 after cycle 3), so growth that stops by cycle 3 passes. The least-squares slope
of the footprint after cycles 3…N is a leak when it exceeds LEAK_KB per cycle even at its lower 2-standard-error
bound (a short run's slope is noisy: WP14's settling run, its first 17-minute one, read 129 ± 142 KB per cycle, ± 2
standard errors as printed, so its lower bound is -13; a real 0.29 MB per cycle leak reads 288 ± 102, at least 186,
even in a short run); the residual standard deviation of that fit is printed, as measured: 66 KB on main before the
energy work, 190 and 204 KB with H3's 16-record fakes, which lowered the footprint after cycles 3-8 (40.9-41.2 MB to
33.5-34.5 MB) but not this scatter; and the footprint at the end must be within LEAK_MB of the one after cycle 3. A run
needs at least 5 cycles after cycle 3 to be judged at all. Before the cycles, after the launch and one panel open and
close, the footprint at the end of the first off phase must be under PANEL_MB (40, DESIGN.md §17's Off budget: 40.0
fails, as perf.sh judges it).

    soak_judge.py <out> <leak_mb> <leak_kb_per_cycle> <app pid> <control pid>
    soak_judge.py --minimum-cycles        # the fewest cycles a run needs (scripts/lib/soak.sh refuses shorter runs)
    soak_judge.py --self-test             # make lint runs it
"""
import bisect
import datetime
import math
import os
import random
import re
import sys

SAMPLE = 10                 # the sampling interval, s
OWN_RATE = 0.05             # own wake-ups per second the final off phase may have at most
PANEL_MB = 40.0             # the footprint after the launch and one panel open and close must be under it (§17's Off)
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


def judge_off(name, rows, span, final):
    """rows: per sample of the phase, (seconds after its start, the app's wake-ups, the control's or None).
    Returns (report line, problems)."""
    problems = []
    if any(theirs is None for _, _, theirs in rows):
        problems.append(f"{name}: the control was not sampled throughout; nothing to compare with")
        rows = [(at, mine, theirs or 0) for at, mine, theirs in rows]
    total = sum(mine for _, mine, _ in rows)
    own = [(at, mine - theirs) for at, mine, theirs in rows if mine > theirs]
    shared = sum(min(mine, theirs) for _, mine, theirs in rows)
    own_total = sum(count for _, count in own)
    rate = own_total / span if span else 0.0
    when = ", ".join(f"+{int(at)}" for at, _ in own)
    report = (f"{name}: {total} interrupt wake-ups in {span} s, the control {sum(t for _, _, t in rows)}; {shared} "
              f"shared, {own_total} Overbright's own ({rate:.3f}/s)" + (f" (at {when} s)" if own else ""))
    minimum = 3 if final else 4
    slots = [at for at, _, _ in rows]
    if len(own) == len(slots) and len(slots) >= minimum and slots and slots[-1] - slots[0] >= MIN_SPAN:
        problems.append(f"{name}: Overbright's own wake-ups fall in every one of the {len(slots)} samples: a beat at "
                        f"or faster than the {SAMPLE} s sampling")
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
    if final and rate > OWN_RATE + 1e-9:
        problems.append(f"{name}: {own_total} wake-ups of Overbright's own in {span} s, {rate:.3f}/s; at most "
                        f"{OWN_RATE:g}/s once the cycles are over")
    return report, problems


def slope(points):
    """(least-squares slope, its standard error, the residuals' standard deviation) of (x, y) points; the error and
    the deviation are 0 with fewer than 3 points."""
    n = len(points)
    mean_x = sum(x for x, _ in points) / n
    mean_y = sum(y for _, y in points) / n
    spread = sum((x - mean_x) ** 2 for x, _ in points)
    if not spread:
        return 0.0, 0.0, 0.0
    b = sum((x - mean_x) * (y - mean_y) for x, y in points) / spread
    if n < 3:
        return b, 0.0, 0.0
    residual = sum((y - (mean_y + b * (x - mean_x))) ** 2 for x, y in points)
    deviation = (residual / (n - 2)) ** 0.5
    return b, deviation / spread ** 0.5, deviation


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
    panel = marks.get("first-off-end", {}).get("mb")
    if panel is None:
        problems.append("no footprint at the end of the first off phase (after the launch and one panel open and close)")
    else:
        lines.append(f"after the launch and one panel open and close: {panel:.1f} MB (under {PANEL_MB:g})")
        if panel >= PANEL_MB:
            problems.append(f"the footprint after the launch and one panel open and close is {panel:.1f} MB (under "
                            f"{PANEL_MB:g}, DESIGN.md §17's Off)")
    if cycles >= minimum_cycles():
        if len(points) < cycles - SETTLED_CYCLE + 1:
            problems.append(f"footprints missing after some of cycles {SETTLED_CYCLE}…{cycles}")
        if len(points) >= 2:
            b, error, deviation = slope(points)
            per_cycle, margin = b * 1024, 2 * error * 1024
            lines.append(f"growth over cycles {SETTLED_CYCLE}…{cycles}: {per_cycle:.0f} ± {margin:.0f} KB per cycle "
                         f"(a leak when above {leak_kb:.0f} even at {per_cycle - margin:.0f}); residuals "
                         f"{deviation * 1024:.0f} KB (standard deviation)")
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
    top = top_samples(out, app)
    samples = pidstat_samples(out, app, control) if os.path.exists(f"{out}/pidstat.txt") else top
    cycles = sum(1 for line in open(f"{out}/status.jsonl") if '"cycle-end"' in line)
    return marks, samples, top, cycles


def top_samples(out, app):
    """`top`'s samples: (stamp, {pid: cumulative idle wake-ups, IDLEW}); the cross-check."""
    samples = []
    if not os.path.exists(f"{out}/top.txt"):
        return samples
    for line in open(f"{out}/top.txt"):
        if re.match(r"^\d{4}/\d\d/\d\d \d\d:\d\d:\d\d", line):
            samples.append((datetime.datetime.strptime(line.strip(), "%Y/%m/%d %H:%M:%S").timestamp(), {}))
        elif re.match(r"^\d+\s", line) and samples:
            fields = line.split()
            samples[-1][1][fields[0]] = int(fields[2].rstrip("+-"))
    return [s for s in samples if app in s[1]]


def pidstat_samples(out, app, control):
    """pidstat.txt's samples: (stamp, {pid: cumulative interrupt wake-ups}). Each line holds the app's and the
    control's pidstat records (`<pid> <epoch ms> <cpu ns> <pkg idle> <interrupt> …`, 11 fields; `<pid> <ms> NA` for a
    process that is gone), then the lock state."""
    samples = []
    for line in open(f"{out}/pidstat.txt"):
        fields = line.split()
        values, i = {}, 0
        while i + 2 < len(fields) and fields[i].isdigit():
            if fields[i + 2] == "NA":
                i += 3
                continue
            if i + 4 < len(fields):
                values[fields[i]] = int(fields[i + 4])
                stamp = int(fields[i + 1]) / 1000
            i += 11
        if app in values:
            samples.append((stamp, values))
    return samples


def rows_between(marks, samples, a, b, app, control):
    """Per sample between marks a and b: (seconds after a, the app's wake-ups, the control's or None)."""
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
    marks, samples, top, cycles = parse(out, app, control)
    problems = []
    if samples is top:
        print("no pidstat.txt (a run from before the energy work's H2): judging top's IDLEW")
    for name, (a, b), final in [("first off", ("first-off-start", "first-off-end"), False),
                                ("final off", ("final-off-start", "final-off-end"), True)]:
        rows = rows_between(marks, samples, a, b, app, control)
        if rows is None:
            problems.append(f"{name}: no samples")
            continue
        report, found = judge_off(name, rows, marks[b]["t"] - marks[a]["t"], final)
        print(report)
        idle = rows_between(marks, top, a, b, app, control) if samples is not top else None
        if idle is not None:
            print(f"  cross-check, top's IDLEW (not judged): app {sum(m for _, m, _ in idle)}, control "
                  f"{sum(t or 0 for _, _, t in idle)}")
        problems += found
    print(f"cycles: {cycles}; footprint MB: " + ", ".join(f"{k} {v.get('mb', '?')}" for k, v in marks.items()
                                                        if not re.match(r"cycle\d+-end", k)))
    lines, found = judge_footprint(marks, cycles, leak_mb, leak_kb)
    print("\n".join(lines))
    problems += found
    print("\n".join(problems) or f"soak OK: no growth once settled; Overbright's own wake-ups neither periodic after "
                                     f"launch nor above {OWN_RATE:g}/s in the final off phase")
    return 1 if problems else 0


def self_test():
    """The judge against synthetic runs: what it must refuse and what it must accept."""
    def off(times, control=(), span=360, final=True, counts=None):
        rows = [(float(at), (counts or {}).get(at, 0) + (1 if at in times else 0), 1 if at in control else 0)
                for at in range(SAMPLE, span + 1, SAMPLE)]
        return judge_off("final off" if final else "first off", rows, span, final)[1]
    def refused_after_launch(k, shared=0, draws=1000):
        """The share of `draws` seeded placements of k own wake-ups at random samples of a 95 s first phase (plus
        `shared` samples the control woke in too) that the judge refuses: launch work, no timer."""
        draw = random.Random(100 * k + shared + 7)
        slots = list(range(SAMPLE, 91, SAMPLE))
        picks = [draw.sample(slots, k + shared) for _ in range(draws)]
        return sum(bool(off(pick, control=pick[k:], span=95, final=False)) for pick in picks) / draws
    def refused_final(k, draws=1000):
        """The share of `draws` seeded placements of k own wake-ups at random samples of a 360 s final phase that the
        judge refuses: the irregular wake-ups the system hands a process, under the rate limit, no timer."""
        draw = random.Random(10_000 + k)
        slots = list(range(SAMPLE, 361, SAMPLE))
        return sum(bool(off(draw.sample(slots, k))) for _ in range(draws)) / draws
    def refused_behind_control(k, extra=3, draws=1000):
        """The share of `draws` seeded placements of k + `extra` control wake-ups at random samples of a 360 s final
        phase, the app waking in the first k of them only, that the judge refuses: no own wake-up, no hidden timer."""
        draw = random.Random(1000 * k + extra)
        slots = list(range(SAMPLE, 361, SAMPLE))
        picks = [draw.sample(slots, k + extra) for _ in range(draws)]
        return sum(bool(off(pick[:k], control=pick)) for pick in picks) / draws
    def cycles(values, end=None, panel=31.0):
        marks = {f"cycle{i}-end": {"mb": mb} for i, mb in enumerate(values, 1)}
        marks["final-off-end"] = {"mb": values[-1] if end is None else end}
        marks["first-off-end"] = {"mb": panel}
        return judge_footprint(marks, len(values), 5, 100)[1]
    every_sample = list(range(SAMPLE, 361, SAMPLE))
    two_seconds = {at: 4 for at in every_sample}                    # 5 wake-ups in each 10 s sample
    eighteen = [10, 20, 50, 60, 70, 100, 110, 140, 160, 170, 190, 220, 230, 250, 280, 290, 320, 350]
    twenty = sorted(eighteen + [130, 300])
    cases = [
        ("final off: none", off([]), False),
        ("final off: one of Overbright's own (the system hands a process such irregular ones)", off([250]), False),
        ("final off: two at random", off([40, 250]), False),
        ("final off: three at uneven gaps", off([20, 50, 300]), False),
        ("final off: five at irregular gaps (WP13's review run had 5)", off([30, 100, 150, 260, 330]), False),
        ("final off: a timer every 125 s shows 3 times, as often as chance does (0.008/s)", off([60, 190, 310]), False),
        ("final off: only wake-ups the control shares", off([40, 250], control=[40, 250]), False),
        ("final off: one more than the control in a shared sample", off([40], control=[40], counts={40: 1}), False),
        ("final off: WP14's irregular off wake-ups (447 s timeline, 15 in 9 samples: 0.042/s)",
         off([10, 20, 150, 160, 200, 240, 270, 280, 310], counts={10: 2, 160: 2, 200: 1, 240: 1}), False),
        ("final off: 18 at irregular gaps (0.05/s, the limit)", off(eighteen), False),
        ("final off: 20 at irregular gaps (0.056/s)", off(twenty), True),
        ("final off: a planted 2 s timer (5 own wake-ups in every sample)", off(every_sample, counts=two_seconds), True),
        ("final off: every 120 s", off([10, 130, 250]), True),
        ("final off: every 100 s", off([60, 160, 260]), True),
        ("final off: every 65 s with 8 s of jitter", off([10, 70, 140, 200, 270, 330]), True),
        ("final off: every 60 s", off([10, 70, 130, 190, 250, 310]), True),
        ("final off: every 60 s, starting 100 s in", off([100, 160, 220, 280, 340]), True),
        ("final off: every 20 s (0.05/s: caught by its beat)", off(list(range(10, 361, 20))), True),
        ("final off: every sample", off(every_sample), True),
        ("final off: a burst right after off (the transition's last work)", off([10, 20, 30]), False),
        ("final off: seven at random", off([10, 40, 100, 110, 200, 230, 330]), False),
        ("final off: every 60 s, half of them in the control's samples",
         off([10, 70, 130, 190, 250, 310], control=[70, 200, 250]), True),
        ("final off: the control's own rhythm, shared", off([70, 130, 190, 250], control=[70, 130, 190, 250]), False),
        ("final off: every 60 s, all behind the control's irregular wake-ups",
         off([10, 70, 130, 190, 250, 310], control=[10, 20, 50, 70, 100, 130, 190, 220, 250, 290, 310]), True),
        ("first off: three after launch at even gaps", off([20, 50, 80], span=95, final=False), False),
        ("first off: five after launch at irregular gaps", off([10, 20, 50, 60, 90], span=95, final=False), False),
        ("first off: every 20 s", off([10, 30, 50, 70, 90], span=95, final=False), True),
        ("first off: a planted 2 s timer (5 own wake-ups in every sample)",
         off(list(range(10, 91, 10)), span=95, final=False, counts={at: 4 for at in range(10, 91, 10)}), True),
        ("footprint: WP13's 30-minute run", cycles([42.3, 46.5, 47.3, 47.5, 47.6, 47.4, 47.5, 47.7, 47.7, 47.7, 48.1, 48.0,
                                                    47.9, 48.1, 48.1, 47.9, 47.8, 48.1, 48.3, 48.2], end=48.0), False),
        ("footprint: the shortest run, settled", cycles([42.3, 46.5, 47.3, 47.5, 47.6, 47.4, 47.5, 47.7]), False),
        ("footprint: WP14's settling run (its first 17-minute run)",
         cycles([42.4, 46.2, 46.5, 46.7, 46.8, 47.5, 47.1, 47.0], end=46.0), False),
        ("footprint: a short run leaking 0.29 MB per cycle, noisy",
         cycles([42.4, 46.2] + [46.5 + 0.29 * i + e for i, e in enumerate([0, 0.2, -0.1, 0.3, -0.2, 0.1])]), True),
        ("footprint: a long run leaking 0.15 MB per cycle, noisy",
         cycles([42.4, 46.2] + [47 + 0.15 * i + e for i, e in enumerate([0, 0.2, -0.1, 0.3, -0.2, 0.1] * 3)]), True),
        ("footprint: 0.29 MB per cycle", cycles([31, 42, 46] + [46 + 0.29 * i for i in range(1, 15)]), True),
        ("footprint: a jump while off", cycles([31, 42, 46, 46, 46, 46, 46, 46, 46], end=53), True),
        ("footprint: too few cycles", cycles([31, 42, 46, 46, 46]), True),
        ("footprint: 39.6 MB after the launch and one panel open and close",
         cycles([42.3, 46.5, 47.3, 47.5, 47.6, 47.4, 47.5, 47.7], panel=39.6), False),
        ("footprint: 41 MB after the launch and one panel open and close",
         cycles([42.3, 46.5, 47.3, 47.5, 47.6, 47.4, 47.5, 47.7], panel=41.0), True),
        ("footprint: exactly 40.0 MB after the launch and one panel open and close (§17: under 40)",
         cycles([42.3, 46.5, 47.3, 47.5, 47.6, 47.4, 47.5, 47.7], panel=40.0), True),
    ]
    # Random wake-ups that no timer causes: a fixed 25 % tolerance refused 31, 55 and 73 % of 3, 4 and 5 of them.
    rates = [(f"first off: {k} own at random times", refused_after_launch(k), 0.03) for k in (4, 5, 6)]
    rates += [(f"first off: {k} own and 2 shared at random times", refused_after_launch(k, shared=2), 0.03)
              for k in (4, 5, 6)]
    rates += [(f"final off: {k} own at random times", refused_final(k), 0.03) for k in (6, 9, 12)]
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
