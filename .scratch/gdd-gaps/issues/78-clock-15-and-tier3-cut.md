# 78 — Clock starts at 15 minutes; Tier 3+ cuts it back to 5

Status: todo — SPECCED (user ruling 2026-08-31) · ready

## Parent

`.scratch/gdd-gaps/PRD.md`

## The change

- `Tuning.CLOCK_START_MS`: **5 min -> 15 min**
- A new tier rule: **Tier 3+ starts at 5 min** (the current value)

Tier ladder for reference — every rule is `tier_index(tier) >= N`, so **tiers are cumulative**
and a tier inherits everything below it:

| Tier | index | gains |
| --- | --- | --- |
| 1 | 0 | baseline |
| 2 | 1 | the Clock never pauses |
| 3 | 2 | -1 Shop row · **+ Clock cut to 5 min (this slice)** |
| 4 | 3 | starting Stock halved |
| 5 | 4 | -1 player Action · enemy takes 2 Actions |

Tier 3 is the middle rung, so "mid difficulty" lands there. Follow the established shape:

```gdscript
static func clock_start_ms(tier: String) -> int:
	return CLOCK_START_MS_HARD if tier_index(tier) >= 2 else CLOCK_START_MS
```

Read it wherever the run's starting clock is set — the value must come from the **tier**, not
the bare constant, or Tiers 1-2 will silently keep 5 minutes.

## This is a large balance change, and two consequences are worth stating up front

**1. Tiers 1-2 get 3x the clock.** That is not a tweak — the Clock is the primary loss
condition in most runs (`FLAGS.md` records Tier 5's sweeps ending in resource starvation, but
ordinary runs end on time). Expect low-tier runs to go substantially deeper.

**2. It may incidentally fix the King problem.** Kings appear at waves **50 / 100 / 150**, and
post-Score-x10 autoplay runs were ending around **wave 43-46** — so most runs never met a King
at all, a known parked issue. Tripling the starting Clock plausibly pushes runs past wave 50
for the first time.

**Measure this rather than assume it**: run an autoplay sweep at Tier 1 before and after, and
report the median wave reached. If runs now clear 50, that is a significant unlock and the
Kings design work becomes more urgent, not less. If they still do not, that is worth knowing
too — it would mean something other than the Clock is the binding constraint.

The high tiers are unaffected by design: Tier 3+ keeps 5 minutes, so this **widens** the gap
between low and high difficulty rather than shifting everything.

## Also update

- The Notion **Clock** page. It was corrected from a stale "30 min" to 5 only yesterday
  (issue 62's audit) — it now needs 15, with the Tier 3+ exception noted. Use the
  `> Reconciled <date>` convention; do not silently overwrite the previous correction.
- The **Difficulty Ranks** page: Tier 3 gains a second effect.

## Acceptance

- 15 min at Tiers 1-2, 5 min at Tiers 3-5 — assert **both** sides, and specifically assert
  Tier 3 (the boundary) rather than only Tiers 1 and 5.
- An autoplay sweep at Tier 1, before/after, with the median wave reported — and an explicit
  statement of whether runs now reach wave 50.
- Notion pages updated.
- `run_all.sh` ALL GREEN (`timeout: 600000`, blocking, alone). Note `test_clock.gd` and any
  scenario asserting the starting clock will move.

## Blocked by

- nothing
