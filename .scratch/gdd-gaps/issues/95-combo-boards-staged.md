# 95 — Combo boards that stage the interaction, and Item ↔ Item

Status: todo (planned 2026-09-01)

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
