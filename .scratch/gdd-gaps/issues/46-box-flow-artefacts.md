# 46 — Box-flow Artefacts: extra pick and rerolls

Status: done (2026-08-29)

## Parent

`.scratch/gdd-gaps/PRD.md`

## Why this slice exists

Three of the remaining Artefacts change the **Box Pick flow** and nothing else. None of
them needs the combined-Box UI that issue 32 is blocked on — that is a different, larger
thing (showing all three box types at once). These three each add one control or one
repeat to the Box modal that already exists.

The Box surface is small and already has the shape needed: `Modals.show_box(options)`
builds a button per option plus a Skip button, and reports back through `box_chosen(opt)`
/ `box_skipped`. `game.gd` owns `_open_box_pick` / `_box_options` / `_box_choose` /
`_box_close` / `_on_box_skipped`.

## Scope

### 1. Nostradamus Mad Libs — Rare

> On opening a Box: +1 extra pick

Take **two** of the three offered options instead of one. The natural reading of "+1
extra pick" on an existing offer is a second pick **from the same offer** (the remaining
two), not a fresh roll — implement that and say so in a comment.

Held twice = 3 picks, i.e. the whole offer. Additive per copy, per the stacking rule; do
not cap it below the offer size for its own sake, just stop when the offer is exhausted.

Note `_box_choose` currently ends by calling `_box_close()`. The extra pick has to reopen
the modal with the remaining options rather than closing — keep `box_open`/`pass_after_box`
bookkeeping correct across the repeat, since `_box_close` is what triggers a queued pass.

### 2 & 3. Bible Gag Reel Scroll and Snowden's Rubik's Cube — both Uncommon

> Bible Gag Reel Scroll: On Box Pick: you may reject the contents once and reroll them
>
> Snowden's Rubik's Cube: Once per Box: you may reroll the offered Picks

**These two are functionally identical** — one reroll of the offer, per Box, each. That is
almost certainly not deliberate at the same rarity, and it is worth raising on Notion as a
catalog observation. It is **not** a blocker, though: implement both the same way and let
them stack additively (holding both, or two copies of either, gives two rerolls), which is
exactly what the stacking rule already prescribes. Do not try to special-case them into
different behaviours to justify their both existing — that would be inventing design.

Implementation: a reroll budget for the current Box, seeded from the held count when the
Box opens and decremented per use. A "Reroll" button appears in the modal only while the
budget is above zero. Rerolling calls `_box_options` again for a fresh offer.

**Reroll must not re-charge `box_cost`.** `_open_box_pick` calls
`Economy.charge(self, "box_cost")` on open; a reroll is a reroll of the offer, not a new
Box. Getting this wrong turns a reward into a tax, and it will not be obvious from a
passing test unless you assert the charge count explicitly — so assert it.

## Autoplay

`_open_box_pick` already resolves itself under `autoplay` rather than showing the modal.
Every path added here must stay inside that branch too, or the autoplay leg and
`test_scenarios.gd` will **hang** rather than fail. Exercise the extra-pick and reroll
branches under the bot, not just under the modal.

## Not in this slice

- **Cicada Rejection Letter** and **Loch Ness Stool Sample** both name *pieces* in a Box
  ("the Shop value of the offered pieces", "a random **Piece** Box") and `Box.roll_options`
  only ever offers Item / Artefact / Score. Same open Notion question; do not guess.
- **All-Seeing Eye Contact Lens** — the combined-Box UI, issue 32.
- **Epstein's Black Book** ("take all 5 contents; this Artefact is then consumed") needs
  consumable Artefacts, which is issue 34. It also says **5** contents where the prototype
  offers 3 — a second mismatch worth carrying into the same Notion question.

## Acceptance

- `implemented: true` in `data/artefacts.js`, stale `(needs: …)` notes cleared, then
  `node tools/export-game-artefacts.mjs`. Never hand-edit `game/data/artefacts.json`.
- Tests in the split suites (issue 37), seeds pinned, asserting observable behaviour:
  the extra pick actually banks two rewards; the reroll replaces the offer; the reroll
  budget is per-Box and does not leak into the next Box; and `box_cost` is charged
  **once** across a Box with rerolls.
- Click probe coverage for the new Reroll button — it is interactive UI, and Godot
  headless drops GUI picking, which is why `run_all.sh` runs the windowed probes first.
- `game/tests/run_all.sh` ALL GREEN.

## Blocked by

- nothing (sequence after 45)

## Outcome

Shipped in PR #168. All three implemented; catalog 149 -> 152.

- **Nostradamus Mad Libs** — the extra pick comes from the *same* offer, as specced.
  `_box_choose` erases the taken option and re-shows the modal while picks remain,
  otherwise closes as before. Two copies take all 3 options; it stops when the offer is
  exhausted rather than being capped for its own sake.
- **Bible Gag Reel Scroll + Snowden's Rubik's Cube** — implemented identically, sharing
  one `box_rerolls_left` budget seeded from the sum of both held counts, so they stack
  additively. No invented difference between them; the duplicate-effect question went to
  `NOTION-QUESTIONS.md` (#2) instead of being resolved in code.

**Both traps held.** `Economy.charge(self, "box_cost")` still appears at exactly one site
(`_open_box_pick`); `_box_reroll` never touches `Economy` at all. The test asserts this the
only way that actually catches it — boots with a `box_cost` Tariff, checks Gold drops by
exactly 10 on open, then that it is unchanged across two rerolls. Verified independently
by grepping every charge site before merge.

**Autoplay** resolves both new branches without ever calling `modals.show_box`: the bot
rolls a reroll chance before picking, and `_box_choose` recurses for the extra pick. The
tests prove the branches *ran* (asserting the budgets ended below their seeded values)
rather than merely proving nothing hung — the weaker assertion would pass even if the
feature were dead.

**Click probe extended** for the Reroll button: it appears while budget remains, keeps the
box open when clicked, and disappears once spent. Needed a `_button_prefix` helper because
the label carries a dynamic "(N left)" suffix.

**One real defect the suite caught:** `test_items_artefacts_4.gd`'s REGISTRY-coverage audit
failed, because all three of these are UI-only reads via `_artefact_count()` and have no
REGISTRY entry — the same shape as `numbers-station-sudoku`. Added to that test's
documented-exception list rather than given hollow REGISTRY entries.

**Process note:** this agent stalled once by backgrounding the suite and waiting on it,
despite being told not to. Nothing was lost — no run was live and nothing had been pushed,
so it was resumed with its context intact and finished the slice normally.
