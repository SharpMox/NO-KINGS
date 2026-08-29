# 49 — The four Box-dependent Artefacts

Status: todo — SPECCED (user rulings 2026-08-29) · **after 47**

## Parent

`.scratch/gdd-gaps/PRD.md`

## Why

These four were blocked because the prototype's Box did not match what they described.
Issue 47 rebuilds the Box system to match, and all four then ship. Three need their
catalog text corrected in `data/artefacts.js`; the fourth needs it rewritten outright.

Answers below are the user's, 2026-08-29 — these resolve `NOTION-QUESTIONS.md` question 1.

## 1. Loch Ness Stool Sample — Rare

> Every 1000 Score gained: open a random Piece Box

**Ships as written.** "Piece Box" names a real thing once issue 47 lands. Nothing to
re-text.

Needs a cumulative run-long "Score gained" tracker (gained, not current — spending must
not un-trigger it) crossing each 1000 threshold once. `on_score_change` is the hook.

## 2. Cicada Rejection Letter — Rare

> On declining a Box Pick: +Gold equal to the Shop value of the offered pieces

**Re-text**: `pieces` -> the Box's contents, whatever kind they are. The user's ruling is
"the value of whatever was in the box".

Valuation, all using **Shop prices** (user ruling):

- **Pieces** — `g.defs[id].value` *is* the Shop price (`Shop.price`, the `"piece"` branch),
  so every piece has one even outside the Shop's stocked pool.
- **Items** — `Tuning.SHOP_ITEM_PRICE[tier]`.
- **Artefacts** — `Tuning.SHOP_ARTEFACT_PRICE[rarity]`.

Score contents are not a case: issue 47 removes Score Boxes.

The decline path already exists (`_on_box_skipped`, paying `BOX_SKIP_CONSOLATION`) — this
adds to it. Note a Huge Box declines 7 contents, so the payout scales with size; that is
intended, not a bug.

## 3. Epstein's Black Book — Rare

> On your next Box Pick: take all 5 contents; this Artefact is then consumed

**Re-text**: `all 5 contents` -> all of the Box's contents, whatever that Box holds (3, 5
or 7).

**The consumption rule is the interesting part** and the user was explicit about it:

> it should only be consumed the moment you pick more than you should have been able to
> without the artefact

So holding it costs nothing until you actually over-take. Take a Big Box's normal 1 pick
while holding this, and it is **not** consumed — it waits. Take a 2nd, and it is spent.

Slice 46 already built the pick counter this reads (`box_picks_left`), so the check is
"did picks taken exceed the Box's native picks (plus any other pick-granting effects such
as Nostradamus Mad Libs)". Decide and document how it composes with Nostradamus: the
natural reading is that Black Book only spends on picks beyond *everything else you were
already entitled to*.

## 4. All-Seeing Eye Contact Lens — Legendary

> Box Picks show all 3 box types' contents at once

**Rewrite.** That text described the old 3-box-type world; there are now 9. What the user
actually wants is **X-ray on Boxes before you commit**:

> "Boxes reveal their contents before you buy or choose them."

Word it to your taste, but that is the meaning: in the Shop you see inside each Box slot
before purchase, and when Bounty (issue 48) offers 1 of 3 Boxes you see inside all three
before choosing.

**Most of the work is already done by issue 47**, which moves the content roll to stock
time unconditionally. This Artefact then gates only *display*. That split is deliberate:
the roll is not conditional on holding the Artefact, so there is no acquire-after-restock
edge case and no RNG-stream peeking.

What remains is genuinely UI: showing contents on a Shop Box slot in 480x800 portrait,
where a Huge Box has 7 entries. A summary (counts, rarity dots, best entry) may serve
better than 7 full tiles — that is a design call worth making explicitly rather than
letting the layout decide it.

## Acceptance

- All four `implemented: true` in `data/artefacts.js`, texts corrected, then
  `node tools/export-game-artefacts.mjs`. Never hand-edit `game/data/artefacts.json`.
- Cicada valuation covered for all three content kinds, and across Box sizes.
- Black Book: explicitly assert it is **not** consumed on a normal-sized pick, and **is**
  consumed on the first excess pick.
- All-Seeing Eye: assert revealed contents equal what the Box actually yields on open.
- Tests in the split suites, seeds pinned. `run_all.sh` ALL GREEN, click probes included.

## Blocked by

- issue 47
