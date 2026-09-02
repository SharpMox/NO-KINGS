# 95 — Combo boards that stage the interaction, and Item ↔ Item

Status: (b) done (2026-09-02) — 14 staged boards. (a) still blocked, see below.

## Parent

`.scratch/gdd-gaps/issues/94-combo-detector.md`

## Why

94 shipped 34 boards and they do what they were specced to do: prove two effects can reach
each other. They are **not** what the user actually wanted, which is a board built *for* an
interaction. Two concrete gaps, both recorded in 94's Outcome:

1. **All 34 boards share ONE template** — same queen/rook/two pawns, same three enemies, same
   400 Gold / 500 Score. Only the payload changes. Nothing is staged.
2. **No Item ↔ Item boards exist at all.** Verified: `boards with 2+ Items: 0`. This is
   structural, not an oversight — 94's rule pairs a producer with *Artefact* listeners, and
   `REGISTRY` is the only listen-side data in the game. **Items do not listen to anything.**

## Scope

### (a) The listen half for Items

`fires` exists on Items (94). `listens` does not, so an Item that reacts to another Item's
effect cannot be expressed. Add it in the same place and the same vocabulary, hand-written
and traced to call sites like 94's `fires` was.

Open first: **is there anything for an Item to listen to?** An Item's effect resolves
immediately inside `_use_item`'s match; nothing dispatches to Items. So this may need a real
mechanism, not just a declaration — that question gates (a) and should be answered before
any code.

### (b) Staged boards for the pairs worth staging

Take 94's graph as the INPUT to curation rather than the output. ~20-25 pairs, each with a
board built for it in 81's style: named for the question it answers, interaction visible in a
couple of moves, pieces and resources placed so the effect has something to bite.

81's rule stands: *pick the ones that teach the most, not the ones that are easiest to
build.* The 34 generated boards stay — they are the reference shelf; these are the ones that
get opened twice.

## Acceptance

- Each staged board is named for the question, not the effect.
- The interaction resolves within a couple of moves from the starting position.
- Boots under `test_scenarios.gd`; `run_all.sh` ALL GREEN, foreground, alone.

## Blocked by

- (a) is blocked on the design question above: nothing currently dispatches to an Item, so
  "Item listens" may not be a declaration at all but a new hook consumer.
- (b) is not blocked and can ship alone.

## Outcome (2026-09-02) — part (b) only

**14 hand-built boards in `game/data/scenarios_staged.gd`. 365 scenarios total.**

Picked FROM 94's graph (`scenarios_combos.pairs()`) rather than invented, but picked for
**disputability**: every board answers something a reasonable player would get wrong. Named
for the question, never for the effect held — 81's rule, and it is also what keeps the board
honest, since a question cannot assert a wrong answer.

Several build the **control into the same board**, so the answer is a contrast rather than a
memory of what usually happens:

- *"does a Shield-blocked attack still pay your capture Artefacts?"* — the shielded pawn and a
  bare one sit at the same distance, so the Score difference between taking them IS the answer
- *"Reflect kills your attacker — does that pay capture or loss Artefacts?"* — holds one of
  each, so a single attack settles both halves
- *"Destruction is not a capture — so what does Air Strike actually pay?"* — one on-destroy
  listener against two on-capture ones
- *"which Items survive use with both 'not consumed' Artefacts held?"* — three Items, both veto
  Artefacts, and Tape Eraser Magnet as the one that must NOT fire

The rest cover hostile Item use (Demoting an **enemy**, which is the half nobody tries),
Artefact-vs-Artefact vetoes (Radar Jamming against Antikythera Warranty Card, Fireproof Pajamas
against your own Bomb), Army Powers feeding Artefacts (Hold the Line's refund into the Gold
percentages, Hostile Takeover landing on exactly 0 Gold to trip Zero-Point Energy Drink, the
Cult's Ritual into the on-Buff listeners), and the Shop as a trigger surface.

Every key — artefact, item, piece and buff — was validated against the live catalogs rather
than typed from memory, and every board is inside the 5-Artefact cap.

**Every board carries Gold**, because 98 priced merging and 97 priced conversion: a staged
board with no budget stops demonstrating anything the moment it needs either. That is the same
trap 98 found in the hand-written `Promote:` boards.

Shop-triggered boards sit at Wave 9, clear of 101's Wave-5 Shop lock.

`run_all.sh` ALL GREEN, foreground, alone — `test_scenarios` boots and bot-plays all 365.

## Part (a) — Item <-> Item — still blocked, and the blocker is real

Not built, and it should not be until the design question is answered: **nothing in the game
dispatches TO an Item.** An Item's effect resolves immediately inside `_use_item`'s match, so
"this Item listens for that one" is not a declaration that can be added — it needs a mechanism
that does not exist. Writing a `listens` field today would describe nothing.
