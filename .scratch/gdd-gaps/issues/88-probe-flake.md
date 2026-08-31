# 88 — The intermittent click-probe failure

Status: todo — reproduced, undiagnosed

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
