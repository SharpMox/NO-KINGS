# Kings design worksheet

Groundwork for the King Powers & Abilities session, prepared 2026-08-31 right after slice 78
made Kings reachable. **Session opened 2026-08-31 — the rulings are at the top; everything
below them is the original groundwork, kept for context.**

---

# RULINGS (user, 2026-08-31)

## 1. Selection: one tier per RUN, four Kings from it — this replaces the shipped model

> *"We have 4 tiers of King with 4 in each tier. Starting a game will select a tier (randomly
> by default but we can add that selection with the difficulty choice) and randomize the order
> of the kings."*

| Wave | Boss |
| --- | --- |
| 50 | King 1 of the run's tier |
| 100 | King 2 |
| 150 | King 3 |
| 200 | King 4 |
| **201** | **Larry** — a near-impossible challenge |

**This is a different model from the one in `game/data/kings.gd` today.** The shipped code
walks `TIER_ORDER[N]` — Laurel@50, Hat@100, Uniform@150, Suit unreached. The new model picks
**one tier for the whole run** and draws all four of its Kings in shuffled order. So a run
meets four Kings of a single costume tier, not four tiers in ascending order.

Consequences to carry into implementation:

- Tier choice is **random by default**, with the difficulty picker as the place a deliberate
  choice could later hang off. Not built now, but do not close the door on it.
- Order within the tier is **shuffled**, and must stay seed-deterministic — it is drawn from
  the run's own RNG today and that property is load-bearing for the seed system (issue 75)
  and for any seeded leaderboard (issue 85).
- **Larry is a 17th boss**, outside the 4x4 cast, at wave 201.

## 2. The wave-50 end screen is unchanged; past it is Endless

> *"This behavior doesnt change the wave 50 end screen the rest will be 'endless' mode."*

Wave 50 remains the win condition and the end screen fires there as it does now. Waves
51-201 are **Endless**. So Kings 2-4 and Larry live entirely in Endless mode — they are
post-win content, and nothing about them may regress the wave-50 result.

## 3. A King wave is TWO segments, and it is deliberately long

> *"only during that kings wave but we will describe a King wave later. It is by design longer:
> in 2 segments, 15 turns of some buffed enemies before the King appears."*

- **Segment 1** — 15 turns of buffed enemies. No King on the board yet.
- **Segment 2** — the King appears; the fight proper.

The King's **Power is active for the King wave only** — but that wave is now long enough for a
wave-scoped Power to actually be felt, which is what makes "King-wave only" viable instead of
a single-wave flicker.

**Still to specify** (flagged, not guessed): whether the Power is live during segment 1 or only
once the King is on the board, and what "buffed" means for the segment-1 enemies.

## 4. Abilities cost the King an Action, once per Wave

Mirrors the player's Army Ability exactly (1/Wave, costs 1 Action). Reuses the enemy Action
economy that already exists — `Tuning.enemy_actions_per_turn(tier)`, seeded through
`Economy.enemy_actions`. A King spending an Action on an Ability is an Action it is not
attacking with: a visible, playable tradeoff.

## 5. Kits are bespoke and flavourful — but the pool is the raw material

The user chose "fully bespoke, grow the pool", **and then gave Trump's kit as Tariff +
Diplomatic Visit – JD Vance — which are both existing, implemented pool entries.**

So the working read is: **bespoke assignment and naming, drawing on the 19 built effects
wherever one fits the King thematically, inventing only where none does.** That is what the
worked example actually shows, and it is far cheaper than 48 new mechanics while still giving
every King a kit that reads as theirs. Flagged here rather than assumed — say so if the intent
was literally 48 new effects.

Trump's kit is open to a better proposal; the user invited one.

## Open, blocking the per-King design

- Power live during segment 1, or only once the King is on the board?
- What "buffed" means for the segment-1 enemies.
- Larry: what he is mechanically, beyond "near-impossible".
- Does the tier choice surface in the difficulty picker now, or stay random-only?

---

## Original groundwork (pre-session)

---

## Why this is now urgent

Before slice 78, autoplay runs ended around **wave 43-46** and **no run had ever reached a
King**. Kings appear at waves **50 / 100 / 150**, so the entire 16-King cast was content
almost nobody would meet.

After raising the starting Clock to 15 minutes, a 6-run Tier-1 sweep produced **4 wins, all by
checkmating the Wave-50 King**. Kings went from unreachable to the thing most runs end on.

So this design work now lands on the actual endgame rather than a hypothetical one.

## What exists

- **16 Kings**, four per costume tier, in `game/data/kings.gd` — identity and selection only.
  The file says so plainly: *"no per-King mechanics are specced anywhere, so none are invented
  here."* Fully greenfield.
- **Selection**: the Nth King wave draws from `TIER_ORDER[N]`, so Laurel@50, Hat@100,
  Uniform@150, with Suit reserved for deeper than the catalog currently generates. The specific
  King is sampled from the run's own RNG, so it is seed-deterministic.

| Tier | Kings |
| --- | --- |
| **Laurel** | Nebuchadnezzar II · Xerxes I · Qin Shi Huang · Nero |
| **Hat** | Genghis Khan · Tamerlane · Ivan the Terrible · Emperor Napoléon |
| **Uniform** | Mao Zedong · Joseph Stalin · Adolf Hitler · Hideki Tojo |
| **Suit** | Donald Trump · Benjamin Netanyahu · Vladimir Putin · Kim Jong Un |

**Only one mechanic is already assigned**: **Tariff is Donald Trump's King Power** (user
ruling, slice 66).

## The shape to fill in

Each King gets **one King Power** (static, always active while that King is the boss) and
**2-3 King Abilities** (active effects). This deliberately mirrors the Army structure that just
shipped, so the engine seams already exist.

## The design pool — 19 existing effects, already implemented

These are the old Tariff entries. They are **built and working**, currently switched off
(`TARIFFS_SCHEDULED := false`). Assigning them to Kings is far cheaper than inventing 16 new
mechanics, and the Notion catalog already describes them.

**Mild (6)** — `move_cost` · `ability_cost` · `capture_cost` · `pass_cost` ·
`long_range_cost` · `inflation`
*(the cost ones all read "X costs extra Gold"; Inflation reduces Gold gains 10%, stacking)*

**Moderate (8)** — `deploy_cost` · `fuse_cost` · Sanctions · Regulation · Austerity ·
Recession · Forced Audit · Hostile Takeover

**Severe (5)** — Trade War · Filibuster · Asset Seizure · Diplomatic Visit – JD Vance ·
Asset Freeze

*(Note the Box Pick tariff was deleted in slice 65 — the pool was 20.)*

## Questions the session has to answer

1. **Does the Mild/Moderate/Severe ladder survive?** It currently maps to *when* a Tariff is
   drawn. Under Kings it could map to **costume tier** — Laurel Kings get Mild Abilities, Suit
   Kings get Severe. That would be a clean reuse. Or it could be discarded.
2. **Are Abilities drawn from the pool, hand-assigned, or both?** Hand-assigning 16×3 = ~48
   Ability slots from a 19-entry pool means heavy reuse. Either the pool grows, Kings share
   Abilities, or some Kings get bespoke ones.
3. **What makes a Power different from an Ability in practice?** For Armies it is
   static-vs-activated. For a King — who is an *opponent* — "activated" needs a trigger: every
   N turns? on taking damage? at a wave threshold?
4. **Does the King's Power apply from wave 1 of its appearance, or only in the King fight?**
   The Tariff model was run-long and stacking; a King-scoped Power is a different feel.
5. **Do the four costume tiers mean anything mechanically**, or are they only flavour?

## Constraints worth keeping in view

- **Tariffs are off, and the rework is expected to restructure the code.** Slice 66
  deliberately left ~145 files' worth of `tariff` identifiers unrenamed for exactly this
  reason — the rename lands with the restructure, not before.
- **`TARIFF_ACTION_COST` is 10, `TARIFF_LR_PER_SQUARE` is 5.** The Notion catalog's Cost
  column still carries pre-scaling numbers (~10-20x too high) and is deliberately unreconciled
  pending this pass — see issue 62 item 5.
- **Score is now x10**, which moves what those numbers should be measured against.
- **Only one King fight happens in a typical run** (wave 50), so a King's kit is experienced
  once per run, not repeatedly. That argues for memorable and distinct over finely balanced.

## Not in scope for the session

Balance numbers. The user's standing position is that tuning waits until every lever is coded,
and Kings are the last one.
