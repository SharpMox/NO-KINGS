# Kings design worksheet

Groundwork for the King Powers & Abilities session. **Nothing here is decided** — this is the
material laid out so the session is about design choices, not about looking things up.

Prepared 2026-08-31, right after slice 78 made Kings reachable.

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
