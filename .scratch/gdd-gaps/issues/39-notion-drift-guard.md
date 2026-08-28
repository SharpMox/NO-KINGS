# 39 — Notion drift guard

Status: done (2026-08-29)

## Parent

`.scratch/gdd-gaps/PRD.md`

## Problem

This entire 39-issue backlog exists because the Notion GDD and the game drifted apart
unnoticed. We have now fixed that drift by hand **twice**: once for the Items DB (Blitz and
Demote had silently changed) and once for artefact text (the 27 Club Punch Card re-text was
applied to the repo but missed in Notion — caught only because the user asked).

Hand-checking does not scale to 180 artefacts, 15 items, 39 pieces and 20 tariffs, and the
failure is silent by construction.

## What to build

A checker — `tools/check-notion-drift.mjs` or similar — that pulls the Notion catalogs and
diffs them against `data/artefacts.js`, `game/data/items.gd`, `data/pieces-codex.js` and
`game/data/tariffs.gd`, reporting any row whose name/effect/tier disagrees.

Report only; do not auto-sync. The direction of truth is a judgement call each time — this
session had cases where Notion was stale and cases where the repo was.

Note the practical constraint: Notion SQL reads work for single data sources on this plan but
multi-source queries are gated, so query each catalog separately.

## Acceptance criteria

- [ ] Checker reports drift across artefacts, items, pieces and tariffs
- [ ] Report-only; never writes to either side
- [ ] Runs clean against current `main`, or lists exactly what is out of sync
- [ ] Documented in `CLAUDE.md` as the thing to run before an audit

## Blocked by

- nothing

## Outcome

Shipped in `786579b` (PR #149). `tools/check-notion-drift.mjs` (216 lines) diffs the
Notion GDD catalogs against their repo mirrors (`data/artefacts.js`, `game/data/items.gd`,
`data/pieces-codex.js`, `game/data/tariffs.gd`) and prints every disagreement. It is
**report-only** and never writes to either side — which side is stale is a judgement call
each time, and both directions have happened.

It takes a Notion snapshot as input, because a plain Node script cannot call the Notion
MCP tools; the file header carries the exact SQL to run and the JSON shape to save.

**First run found 59 real drift findings on `main`** — Demote's grammar differing in
Notion, ~30 stale `(needs: …)` notes left in catalog rows, and Silk Road Coupon /
Mar-a-Lago Deed saying "Shop restock" in Notion where the repo implements "5-Wave
Milestone". Those are recorded as findings, not auto-fixed. Usage is documented in
`CLAUDE.md`.
