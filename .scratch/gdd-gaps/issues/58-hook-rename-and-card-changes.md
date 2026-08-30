# 58 — Rename `on_milestone`, and two card changes

Status: done (2026-08-30)

## Parent

`.scratch/gdd-gaps/PRD.md`

Three unrelated-but-small changes, grouped so they are one review rather than three.

---

## 1. Rename the hook `on_milestone` -> `on_clock_refill`

`on_milestone` is the **global 10-Wave clock-refill** trigger (`Tuning.MILESTONE_WAVES == 10`),
used only by the "timer" core effect and the Recession Tariff. It has nothing to do with the
per-Artefact **"5-Wave Milestone"** cadence, which hooks `on_wave_clear` and calls
`_milestone5_hit`.

That collision has already caused one real spec error (issue 43 named the wrong hook, and the
implementing agent had to catch it). The user's fix: **call it what it is.**

Pure mechanical rename — the hook string, its `HOOKS` entry, its REGISTRY entries, its
`_dispatch` cases, and the comments that explain the confusion. No behaviour change.

Update `FLAGS.md`'s entry on this collision to record that it is resolved.

---

## 2. Manna Vending Machine — Common

**Was:** *"On 5-Wave Milestone: +2 Items"*. Issue 53's base Item cap of 3 made this grant
partly or wholly wasted at a full inventory — flagged, and the user's answer is a redesign
rather than an exception:

> The point is to spend Items so you are not at the cap. Change this to open a **Big Item
> Box**.

**Now:** *on 5-Wave Milestone, open a Big Item Box* (5 choices, 1 pick).

This sidesteps the cap problem instead of carving a hole in it: a Box is a *choice*, so a
full inventory is the player's problem to solve rather than a silently dropped grant. Same
shape as SETI's redesign in issue 56.

Keep the per-copy `_milestone5_hit` cadence. Re-text the card.

---

## 3. Bible Gag Reel Scroll — Uncommon

**Was:** *"On Box Pick: you may reject the contents once and reroll them"* — functionally
identical to Snowden's Rubik's Cube at the same rarity (`NOTION-QUESTIONS.md` question 2).
The user chose to give it a new effect, and possibly a new name.

**Now (user, 2026-08-30):** *Bishop, Cardinal and Archbishop gain a specific Piece Buff when
they capture.*

The chain is real and verified: `bishop` (value 30) -> `dragon-horse` **"Cardinal"** (50) ->
`archbishop` **"Archbishop"** (70). Note the id convention — `dragon-horse` is the id,
"Cardinal" is only the display name, so **match on ids**, never on display names.

**The Buff is SHIELD** (user, 2026-08-30) — Tactical, dormant, "prevents the next capture
attempt on this piece". The mildest of the dormant buffs, which suits a trigger that fires
on every capture by any of three piece types; anything Strategic or Decisive would have been
far too strong on an Uncommon.

**Watch out:** the Piece Buff cap is **2** since issue 53, and this grants on *every* capture
— so it will hit the cap constantly. It must route through `_apply_buff` (the existing choke
point) so a refused grant floats "Buffs full" rather than silently vanishing. Do not
special-case around the cap.

Rename is optional. If the effect no longer reads as "gag reel", say so and propose one.

## Acceptance

- Rename complete, no behaviour change, `FLAGS.md` entry updated.
- Manna and Bible re-texted in `data/artefacts.js`, exported via
  `node tools/export-game-artefacts.mjs`.
- Assert Bible's grant fires for all **three** ids and not for other pieces, and that it
  respects the buff cap.
- Assert Manna opens a Big Item Box on its own per-copy cadence.
- `run_all.sh` ALL GREEN, foreground.

## Blocked by

- nothing

## Outcome

Shipped in PR `feat/rename-and-card-changes-58`. All three changes landed as one review.

- **`on_milestone` -> `on_clock_refill`**: pure mechanical rename across the HOOKS array,
  both REGISTRY entries ("timer", "recession"), both `_dispatch` cases, `wave_logic.gd`'s
  call site, and every comment that explained the collision (`artefact_hooks.gd`,
  `wave_logic.gd`, and two test-file comments). No behaviour change. Proved with a new
  direct test (`test_items_artefacts_1.gd`): booted at wave 9 with "timer" held, called
  `WaveLogic.queue(g, 10)` (the real production call site for the GLOBAL 10-Wave beat) and
  asserted `clock_ms == CLOCK_REFILL_MS + 5000`; a second boot adds the Recession tariff and
  asserts the halved total, confirming the artefact-base-then-tariff-modifier ordering
  (header's "Tariff/artefact ordering" note) survived the rename untouched. `FLAGS.md`'s
  entry is marked resolved.
- **Manna Vending Machine** re-texted *"On 5-Wave Milestone: open a Big Item Box"* (was
  "+2 Items", partly wasted against issue 53's Item cap). `artefact_hooks.gd`'s
  `["manna-vending-machine", "on_wave_clear"]` case now calls `g._open_box_pick` with a
  `{"key": "item", "size": "big", ...}` slot built from `Box.roll_options`, same shape as
  SETI's Red Marker (issue 56) and guarded `not g.box_open` like Trojan Horse Assembly
  Manual. The per-copy `_milestone5_hit` cadence is untouched. Rewired the
  `test_items_artefacts_4.gd` "two copies fire on different beats" test off `items.size()`
  onto `box_open`/`box_only_kind`/`box_size`, resolving copy A's Box with one `_box_choose`
  call between beats so its `not g.box_open` guard doesn't swallow copy B's later firing.
- **Bible Gag Reel Scroll** re-texted *"Bishop, Cardinal and Archbishop gain Shield when
  they capture"* (was a duplicate of Snowden's Rubik's Cube's Box reroll — question 2 in
  `NOTION-QUESTIONS.md`). New `["bible-gag-reel-scroll", "on_capture"]` REGISTRY entry +
  `_dispatch` case matches `ctx.attacker_id` against the **id** chain
  `["bishop", "dragon-horse", "archbishop"]` — never the display name "Cardinal"
  (`dragon-horse`'s display name, confirmed against `data/pieces-codex.js`/`promotions.js`)
  — and calls `g._apply_buff(..., "shield", ...)` directly (no `_random_buff_key`, a
  specific grant per the user's ruling). Routing through `_apply_buff` means the issue-53
  Piece Buff cap (base 2) refuses cleanly with a floating "Buffs full" label when a
  capturing piece is already full, same as every other grant path — asserted directly.
  Its old contribution to `box_rerolls_left` was removed from `game.gd`'s
  `_open_box_pick` (Snowden's Rubik's Cube keeps the reroll alone); the
  `test_items_artefacts_3.gd` reroll-stacking test was moved onto two held Snowden copies,
  and `bible-gag-reel-scroll` was dropped from `test_items_artefacts_4.gd`'s
  REGISTRY-coverage exception list (it now has a real entry). Rename: **not applied** — kept
  "Bible Gag Reel Scroll" and its Vatican Secret Archives conspiracy/URL anchor (same
  precedent as SETI's Red Marker keeping its name through its own redesign), but the closing
  line of `summary` no longer described the removed reroll and was rewritten to fit the new
  effect. If a rename is still wanted, "Vatican Secret Archive Blackmail File" was
  considered and fits (a file that protects a Church official from consequences maps
  cleanly onto Shield) but was left for the user to decide.

Tested in `test_items_artefacts_1.gd` (rename), `test_items_artefacts_3.gd` (Bible: all
three ids, a non-matching piece, and the buff-cap refusal), and `test_items_artefacts_4.gd`
(Manna's per-copy cadence, REGISTRY-coverage guard). `game/tests/run_all.sh` ran ALL GREEN
in the foreground on the first attempt — no pinned-seed assertion moved (Holy Lint's
`test_items_artefacts_1.gd` coverage doesn't hold Bible, and the new Bible handler draws no
RNG itself, so its stream position was never at risk).
