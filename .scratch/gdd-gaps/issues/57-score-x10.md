# 57 — Score ×10 across the board

Status: todo — SPECCED (user ruling 2026-08-30)

## Parent

`.scratch/gdd-gaps/PRD.md`

## Why

The Shop's restock thresholds are unreachable. The GDD Shop page flags it itself: fleet data
has a median Crown run ending near **Score 300**, and the first threshold is **1000**. Either
the threshold drops or income rises. The user chose income (2026-08-30): **multiply Score by
10**.

## Scope

Multiply by 10:

- **Piece capture values** (`defs[id].value` as it feeds Score — see the caution below).
- **Regular Score-gain mechanics** — wave-clear bonuses, early-clear, streaks, every
  ordinary source.
- **Flat Artefact Score constants** — user follow-up: *"bump the flat artefact gains also"*.
  So `+10 score per Pawn captured` (Greed) becomes +100, Bounty's +30 becomes +300, Oak
  Island Wishing Well's +400 becomes +4000, and so on.

**Percentage-based effects need no change** — they scale automatically, and touching them
would compound the multiplier.

## The one thing that will go wrong if rushed

**A piece's `value` is not only a Score number.** `Shop.price()`'s `"piece"` branch returns
`float(g.defs[slot.key].value)` — the piece's value *is* its Gold price — and
`_sample_pieces` weights the Shop roll by `1.0 / value`. Cicada Rejection Letter (issue 49)
also values Box pieces at `defs[id].value`.

So multiplying `defs[].value` blindly would **multiply every piece's Shop price by 10** and
leave the Gold economy untouched, making pieces unaffordable overnight.

**Decide explicitly**: either scale Score at the point of scoring (leaving `value` as the
Gold/price number it also is), or scale `value` and divide it back out at every Gold site.
The first is almost certainly right — it keeps one meaning per field. Say which you chose
and why in the commit.

## Expect large test churn, and treat it carefully

Nearly every Score assertion in the suite will move. That is expected — but it is also the
perfect cover for a real regression. For each changed assertion, confirm the new number is
`old × 10` (or a documented exception) rather than simply pasting whatever the run printed.
An assertion that changes by a factor of anything other than 10 is a finding, not a chore.

`SCORE_BOX_CHUNKS` is gone (issue 47), so there is no Score Box to update.

## Acceptance

- Score sources ×10; percentage effects untouched; **Shop piece prices unchanged**.
- Assert a piece's Shop price is what it was before this slice — that is the guard against
  the `value` trap above.
- The Shop's first restock threshold is now plausibly reachable in a median run; say what a
  quick autoplay sweep shows rather than asserting a specific number.
- `run_all.sh` ALL GREEN, foreground.

## Blocked by

- nothing
