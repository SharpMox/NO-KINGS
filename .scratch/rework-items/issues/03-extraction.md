# 03 — Extraction: multi-select return to Stock + stock state contract

Status: done
Type: AFK

## Parent

`.scratch/rework-items/PRD.md` · ADR-0002

## What to build

Extraction as the first `multi`-target item (Tactical tier): valid tiles are
your own board pieces; taps toggle a selection; a confirm affordance appears
once ≥1 is selected; confirming spends the item and returns each selected
piece to Stock at its current identity. Implements the ADR-0002 stock entry
contract end-to-end: entries are a bare id or `{id + opaque piece state}`
(board-only fields stripped), stock UI stacks by whole-entry equality,
placement restores the state onto the board piece, merge inputs lose their
state, saves round-trip both entry shapes and old bare-string saves load
unchanged.

## Acceptance criteria

- [ ] Selecting N own pieces and confirming removes them from the board and appends them to Stock at their current ids (promoted/merged identity kept)
- [ ] Zero-selection confirm is impossible; cancel (tap the armed item again) leaves the item unspent and the board untouched
- [ ] A board piece carrying extra state (synthetic in tests) round-trips: extract → stock dict entry → own HUD stack → place → state back on the board piece
- [ ] Plain pieces extract to bare-id entries and group with existing stacks of the same id
- [ ] Merging a stateful stock piece discards the state; the merge result is the normal next piece
- [ ] Mid-run save/load preserves mixed String/Dictionary stocks; a pre-contract save (bare strings) loads unchanged
- [ ] Item costs 1 action + ability tariff on confirm, not on arming
- [ ] Headless items + save suites cover the above; an Extraction scenario joins the catalog; game click probe exercises toggle + confirm; full suite ALL GREEN

## Blocked by

None - can start immediately
