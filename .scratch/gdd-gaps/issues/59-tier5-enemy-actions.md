# 59 — Tier 5 gains: the enemy takes 2 Actions

Status: done

## Parent

`.scratch/gdd-gaps/PRD.md`

## Why

Divergence #2: the enemy takes **1** Action per turn, the GDD says **2**. That has been a
playtest override since 2026-07-02, predating the wave-catalog rebalance, the Tariff system
and the unified Action economy.

The user's resolution (2026-08-30): don't change the base — **make it a difficulty rank, at
the last rank.**

## Scope

`Tuning.ENEMY_ACTIONS_PER_TURN` becomes tier-aware, in the same shape as the existing
tier rules in `tuning.gd`:

```gdscript
static func enemy_actions_per_turn(tier: String) -> int:
	return ENEMY_ACTIONS_PER_TURN + (1 if tier_index(tier) >= 4 else 0)
```

The value already flows through `Economy` — `on_enemy_turn_start` is seeded from
`Tuning.ENEMY_ACTIONS_PER_TURN` (`economy.gd:277`) and Filibuster and Y2K Patch Floppy Disk
both modify it there — so this is a single-site change, not a sweep. Make sure the tier
value is what seeds the hook, so those two Artefacts still compose on top of it.

## STOP AND READ: both halves of this change are independently measured as unwinnable

Two fleet sweeps already exist in the repo, and they were run separately. This slice stacks
them.

**1. Enemy at 2 Actions/turn, at BASE difficulty: 0/60 wins.** From `tuning.gd:32`'s own
comment — a 60-run sweep (Crown / Wild Hunt / Old Guard, 20 each) re-run on 2026-08-28 under
the current wave catalog, tariffs and unified action economy:

> at 2 actions/turn put every run at **0/60 wins** (was 2/60 at 1) and collapsed median
> survival from wave 17.5 to wave 8

That is with **no other difficulty modifiers at all**.

**2. Tier 5 as it stands today: 0/24 wins**, median survival 38.5 -> 9.5, every loss to
resource starvation (`FLAGS.md`).

Tier 5 also carries -1 player Action, halved starting Stock, -1 Shop row and no Clock pause —
so **Tier 5 + enemy 2 Actions is strictly worse than the scenario that already scored 0/60.**
This is not "a top tier is allowed to be brutal"; it is a tier that two independent
measurements say cannot be won.

**That may be exactly what the user wants** — an unwinnable summit is a legitimate design
choice, and the user has parked Tier-5 tuning as "later". But it should be a decision taken
with these numbers in hand, not a surprise found in a playtest. Surface it before building,
and if it goes ahead, the post-landing sweep below is not optional.

## The mechanics: difficulties are cumulative

Confirmed by reading `tuning.gd` — every rule is `tier_index(tier) >= N`, so a tier inherits
every lower tier's debuff. **Tier 5 today is all four at once:**

| From | Effect |
| --- | --- |
| Tier 2+ | the Clock never pauses |
| Tier 3+ | −1 Shop row of each kind |
| Tier 4+ | starting Stock halved |
| Tier 5 | −1 Action per Turn |

This slice adds a **fifth**: the enemy acts twice.

`FLAGS.md` already records a 24-run sweep of Tier 5 as it stands *without* this: median
survival wave **38.5 -> 9.5**, **0 wins in 24**, every loss to resource starvation. Doubling
the enemy's Actions on top of that is a large multiplier on an already-unwon tier.

That is not an objection — the user parked Tier-5 tuning as "later" and a top tier is allowed
to be brutal. But **run the 24-run sweep again after this lands and record the new numbers**,
so the tuning pass starts from measurement rather than from a guess. If the median drops
below wave ~5 the tier stops teaching the player anything, which is worth knowing early.

## Acceptance

- Enemy takes 2 Actions at Tier 5, 1 at Tiers 1-4.
- Filibuster and Y2K Patch Floppy Disk still compose correctly on top of the tier value —
  assert Y2K still skips exactly one enemy Turn at Tier 5.
- A fresh autoplay sweep at Tier 5, with the numbers recorded in the Outcome next to the
  previous 38.5 -> 9.5 / 0-of-24 baseline.
- `run_all.sh` ALL GREEN, foreground.

## Blocked by

- nothing

## The GDD sweep found this ruling settles a long-standing divergence

Recorded 2026-08-30, from the Notion sweep.

The **[Enemy AI Behaviors](https://app.notion.com/p/367f1559c99b81a8958edbf4a0f30762)** page
states the AI takes **2 Actions per Turn by default, unconditionally**. The code has
`ENEMY_ACTIONS_PER_TURN := 1` — *"playtest override, re-justified 2026-08-28"* — which is
**divergence #2**, open since 2026-07-02 and the reason issue 11 exists.

The user's ruling resolves it without either side simply losing: **baseline stays 1, and Tier
5 restores the GDD's 2.** The GDD value becomes the top-difficulty value rather than the
default.

So this slice must also **update that Notion page**, or the sweep just moves the divergence
rather than closing it. State plainly there: baseline 1, Tier 5 = 2, and that this supersedes
the unconditional "2 by default" (following the page convention of a `> Reconciled <date>`
blockquote rather than silently overwriting).

**Issue 11 should be closed at the same time.** It existed to re-test the enemy-action count
with fleet data; a difficulty rank answers the question differently and makes the re-test
moot.

## Outcome

**`Tuning.enemy_actions_per_turn(tier)`** added exactly as specced — `ENEMY_ACTIONS_PER_TURN
+ (1 if tier_index(tier) >= 4 else 0)`, same shape as `actions_per_turn`/`shop_row_delta`/
`clock_never_pauses`. `Economy.enemy_actions(g)` (the single seed point, `economy.gd`) now
reads `Tuning.enemy_actions_per_turn(g.next_tier)` instead of the bare constant, so every
caller of `_run_enemy_actions` picks up the tier automatically — no other call site touched.

**Filibuster and Y2K Patch Floppy Disk still compose on top of the tier value**, unchanged
handler logic — they only ever read/write `ctx.actions` on `on_enemy_turn_start`, which is
now seeded from the tier-aware number instead of the bare constant. Added Tier-5 coverage
next to the existing Tier-1 cases in `test_items_tariffs.gd`: Y2K alone at Tier 5 zeroes the
first enemy Turn (0, not 1) and the next Turn is back to the normal Tier-5 2; Y2K + Filibuster
at Tier 5 is 1 on the first Turn (Y2K's zeroed Tier-5 base + Filibuster's +1) and 3 on the
next (2 + 1). `test_tiers.gd` also gained a pure-math check across all 5 tiers and a live-boot
check (`Economy.enemy_actions`) at Tier 1, Tier 4, and Tier 5 — 1/1/2 respectively.

**Fresh Tier-5 autoplay sweep, 24 runs (Crown/Wild Hunt/Old Guard x8, `godot --headless
--path game -- --autoplay --army <name> --tier "Tier 5"`), against the two pre-existing
baselines this slice explicitly stacks:**

| Sweep | Wins | Median survival wave |
| --- | --- | --- |
| Enemy 2 actions/turn, BASE difficulty (`tuning.gd:32`, 60 runs) | 0/60 | 17.5 -> 8 |
| Tier 5 today, enemy 1 action/turn (`FLAGS.md`, 24 runs) | 0/24 | 38.5 -> 9.5 |
| **Tier 5 + enemy 2 actions/turn (this slice, 24 runs)** | **0/24** | **-> 7.5** |

0 wins, every loss `Resource starvation` except one `Back-row breach` (wave range 5-15,
mode 7-8). Reported honestly, as the issue asked: this is worse than either baseline it
stacks, which is the expected direction, not a surprise — Tier 5's -1 Action / halved Stock
/ -1 Shop row was already unwon on its own, and doubling the enemy's Actions on top of an
already-unwon tier compounds rather than offsets. Median dropped from Tier 5's own 9.5 to
7.5, under the "~5" threshold the issue flagged as "stops teaching the player anything" —
worth flagging plainly, but per the issue's own framing this was disclosed and proceeded on
deliberately; the tuning pass (parked as "later") now starts from this number instead of a
guess.

**Notion.** [Enemy AI Behaviors](https://app.notion.com/p/367f1559c99b81a8958edbf4a0f30762)
updated with a `> Reconciled 2026-08-30` blockquote under the "2 Actions per Turn by default"
line: baseline is 1, Tier 5 restores the GDD's 2 — the unconditional "2 by default" reading
is superseded, not deleted.

**Issue 11 closed** — see its own Outcome for the note.

`game/tests/run_all.sh` — ALL GREEN (final line: `ALL GREEN`).
