# 88 — The intermittent click-probe failure

Status: OPEN — not reproduced in 82 runs, but that result is caveated (2026-08-31)

## Parent

`.scratch/gdd-gaps/PRD.md`

## What is known

A windowed click probe fails intermittently. **Reproduced at 1 failure in 20 runs** on a quiet
machine, 2026-08-31 — the hunt was paused mid-way, not concluded.

This is a **real intermittent bug, not a load artifact.** The 20 runs were sequential and
alone, which is what distinguishes it from the two known false alarms below.

## Two false alarms this must not be confused with

Both are recorded in CLAUDE.md because both cost real time:

1. **Concurrency (2026-08-29).** Three `game-clicks` cases failed while four suites ran in
   parallel across worktrees; all three passed on three sequential re-runs. The probes are
   windowed and fight over focus. **A probe failure during a concurrent run is not evidence of
   a bug — and a pass during one is not evidence of correctness.**
2. **Batched A/B (2026-08-29).** 3/15 on a branch vs 0/20 on `main` "proved" a regression and
   blocked a PR. An **interleaved** 20-and-20 in the same window came back 0 and 0. The
   batches had measured machine load, not the branch.

So: **run alone, and interleave any comparison.** Never batch.

## How to run it

Reproduction is a loop of the probes alone, not `run_all.sh`:

```sh
godot --path game -s tests/test_menu_clicks.gd
godot --path game -s tests/test_game_clicks.gd
```

At 1-in-20, a run of 40-60 is needed before absence means anything. Capture **which case**
fails and the full output each time — with a rate this low, a discarded failure is expensive
to reproduce again.

## Approach

Straight `diagnose` loop: reproduce -> minimise -> hypothesise -> instrument -> fix ->
regression-test. The reproduce step is done; **start at minimise.**

Prime suspects, in order of how cheap they are to rule out:

- **A frame-timing race** — the probe injecting input before the control is laid out or after
  a deferred call has rearranged it. Most likely given the symptom shape.
- **An animation still in flight.** `animations_on` gates a queue; a probe that clicks mid-pop
  may hit a moved target. A probe run with animations off is a cheap discriminator.
- **Window focus** on the developer machine — a notification stealing focus mid-run. Cheap to
  rule out by running with nothing else open, and it would make the bug environmental rather
  than a code defect.

**Weigh a reachability argument above a rate comparison** — CLAUDE.md's rule, learned from the
false alarm above. "That code cannot execute at the failure site" is stronger evidence than
any pass rate.

## Acceptance

- The failing case named, with a mechanism — not "it seems flaky".
- A fix, **or** a documented finding if it turns out to be environmental (that is a legitimate
  outcome here and closes the issue honestly).
- A regression check that would have caught it, if the cause admits one.
- `run_all.sh` ALL GREEN, foreground, alone.

## Blocked by

- nothing — but scheduled **after** 79-87 per the user (2026-08-31)


## Attempt 1 (2026-08-31) — not reproduced, and the result is NOT clean

**82 sequential runs, 0 failures**: 26 game-clicks, 26 menu-clicks, then 30 interleaved.

If the rate were still 1-in-20, the chance of seeing zero failures across 82 runs is about
**1.5%** (0.95^82). That is strong evidence the rate has dropped — *if the measurement counts*.

### Why it may not count

**The Godot EDITOR was open the whole time** — pid 58525, running 9h43m, discovered only when
the new hunt script refused to start. That is precisely the contention condition CLAUDE.md
warns about, and its rule is explicit that **a pass under contention is not evidence of
correctness** any more than a failure under one is evidence of a bug.

The honest reading is narrower than "0/82 proves it is gone":

- Contention causes *false failures*, so seeing none despite it is mildly reassuring.
- But the repo's own rule exists because this exact class of reasoning has produced a
  confident wrong answer here before (2026-08-29, twice). **So this issue stays OPEN.**

### The other reason a zero here proves less than it looks

**The probes have been substantially rewritten since the flake was seen.** Slice 79 replaced
the whole scenario-list assertion block (sections now collapse, so reachability became a
two-step property), 83 added the login-screen block and a guest-account precondition, and 85
added a Scores status assertion. **The assertion that failed may no longer exist.**

And it cannot be checked, because **the original failing case was never recorded** — the hunt
was interrupted mid-way and the output discarded. That is the single most costly detail here,
and it is why attempt 1 produced a tool rather than a diagnosis.

### What was built instead: `game/tests/flake_hunt.sh`

```sh
game/tests/flake_hunt.sh [runs]   # default 40 of each probe, interleaved
```

It keeps the **full output of every failing run**, which is exactly what the last hunt lacked.
Both of CLAUDE.md's hard-won rules are baked in: it **interleaves** rather than batching (a
batched A/B measures machine load, not the branch), and it **refuses to start** when another
Godot process is up rather than merely warning as `run_all.sh` does — a hunt's entire output is
a pass/fail rate, and a rate measured under contention is not a rate for anything.

### Next step

Re-run with the editor closed:

```sh
pkill -f '[Gg]odot'          # or just close the editor window
game/tests/flake_hunt.sh 40  # 80 runs, clean
```

A clean 0/80 would take P(miss) under 1.7% and justify closing this as
**not-reproducible-after-the-probe-rewrites**. A failure gives the case name and full output
the diagnosis needs. Either outcome is worth more than the current one.
