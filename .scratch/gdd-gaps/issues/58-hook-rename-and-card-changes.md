# 58 — Rename `on_milestone`, and two card changes

Status: todo — SPECCED (user rulings 2026-08-30)

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

**Which Buff — open, needs the user's pick.** *Recommendation: **Shield*** (Tactical,
dormant, "prevents the next capture attempt on this piece"). It is thematically right for
clergy, it is the mildest of the dormant buffs, and the trigger — every capture by any of
three piece types — is frequent enough that a Strategic or Decisive buff would be far too
strong on an Uncommon. **Aura** (Strategic, "adjacent allies score double for 2 turns") is
the ambitious alternative and reads even better thematically, but it is a real power jump.

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

- the Buff choice in part 3 (recommendation given)
