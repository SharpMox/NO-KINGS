# 63 — The 85 remaining Notion drift findings

Status: todo — triage first; most are cheap, a few are real

## Parent

`.scratch/gdd-gaps/PRD.md`

## Why

`tools/check-notion-drift.mjs`, re-run 2026-08-30 against a fresh snapshot (180 Artefacts /
16 Items / 39 Pieces / 21 Tariffs), reports **85 findings**. Its first run on `main` found 59;
the number went *up* because the catalog kept moving while Notion held still.

Slice 50 reported these rather than fixing them — correctly, since most need a judgement call
about which side is stale, and that is exactly what the checker refuses to decide for you.

**Do not treat this as 85 equal items.** They fall into three very different groups.

## Group 1 — stale `(needs: …)` notes, the large majority

Notion still carries `(needs: choice UI)`-style notes on Artefacts whose mechanics have since
been built. Every one of the 180 is now implemented, so **every remaining `(needs: …)` note is
wrong by definition**. Mechanical, low-risk, high-volume — the ideal thing to batch.

## Group 2 — real semantic drift, four rows

These say genuinely different things on each side and need a ruling per row:

- **Mar-a-Lago Toilet Papers** and **Silk Road Coupon** — trigger mismatch. Notion says "Shop
  restock"; the repo implements the 5-Wave Milestone. This one has been known since slice 39's
  first run and has survived several passes.
- **Pegasus Free Trial** — mechanic mismatch. Almost certainly Notion still carrying the
  original *"can move twice each Turn"* text, which the user **replaced** on 2026-08-30 with
  *"the first move or capture each Turn costs no Action"* (issue 54). If so this is Notion
  being behind, not a real disagreement — verify before ruling.
- **Spare Organ Receipt** — check against issue 53's ruling (50% of **both** consumed pieces).

## Group 3 — two genuine gaps, not drift

- **"Tariff on Promotion" exists in Notion with no `tariffs.gd` entry at all.** Not a text
  mismatch — a Tariff the design has and the game does not. Decide whether to build it or
  retire it. Note Tariffs are currently paused (`TARIFFS_SCHEDULED := false`), so this is not
  urgent, but it should be resolved in the Kings + Tariffs pass rather than found again then.
- **`king` exists in Notion Pieces but not in `data/pieces-codex.js`.** Almost certainly
  intentional — that file's header describes a *curated 38-piece* set and the King is the boss
  piece — but the exclusion was never written down, so the checker will keep reporting it every
  run. Log it as a deliberate exclusion and it stops being noise.

## Suggested order

Group 3 first (two decisions, both small), then Group 2 (four rulings), then batch Group 1.
Doing Group 1 first would feel productive and leave every finding that actually matters still
sitting there.

## Note

`items.gd`'s header claim *"STATUS triage synced 2026-07-14: only KEEP items ship"* remains
**unverifiable** — the checker only sees current Notion state, not a July snapshot. Two agents
have now reached the same conclusion independently and correctly left it alone. Either accept
it as unprovable or delete the claim; do not keep re-investigating it.

## Blocked by

- nothing
