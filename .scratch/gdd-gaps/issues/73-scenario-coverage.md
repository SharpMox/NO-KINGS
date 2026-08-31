# 73 — A test scenario per Artefact, per piece, per King

Status: todo — READY for Artefacts + pieces · Kings blocked on design

## Parent

`.scratch/gdd-gaps/PRD.md`

## What this is

`game/data/scenarios.gd` holds hand-built TEST scenarios, and `test_scenarios.gd` boots and
bot-plays every one automatically. The ask: **one scenario per Artefact (180), per piece
(39), and per King (16)**.

## Why this is worth doing, stated precisely

The suite already asserts these things in unit form. What a scenario adds is different:
it proves the thing **survives a real bot-played run** — dispatch, save/load, autoplay and
the wave loop all touching it — rather than a hand-built fixture. Several bugs this project
shipped were only visible in that integration path.

## The thing to decide before generating 235 scenarios

**Hand-written or generated?** 180 hand-written Artefact scenarios is weeks of work and will
rot the moment a card changes. A **generated** scenario per Artefact — boot with that
Artefact held, a fixed board, a pinned seed, bot-play N turns, assert no crash and no
assertion trip — is cheap, uniform, and regenerates when the catalog does.

Recommendation: **generate**, from `artefacts.json` / `pieces.json` / `kings.gd`, with a
handful of hand-written scenarios kept for genuinely tricky interactions.

**Runtime is the real constraint.** `test_scenarios.gd` already boots and plays every
scenario, and the suite takes ~6 minutes today. Adding 235 bot-played scenarios could take it
past the point where anyone runs it before committing — which would quietly destroy the
discipline that has caught most of this project's bugs. **Measure the per-scenario cost
first**, then decide: full sweep nightly, sampled subset per run, or a separate opt-in target.

## Split

- **73a — Artefacts (180).** Ready.
- **73b — pieces (39).** Ready. Cheaper and higher-value per scenario: every piece's movement
  and promotion path exercised in a real run.
- **73c — Kings (16).** **Blocked** — Kings have no mechanics yet (Powers/Abilities are the
  next design session). Nothing to test until they exist.

## Acceptance

- Generated scenarios, seeds pinned, regenerable from the catalogs.
- **A measured statement of what it does to suite runtime**, and a chosen strategy if it is
  more than ~2 minutes.
- `run_all.sh` ALL GREEN (`timeout: 600000`, alone).

## Blocked by

- the generate-vs-handwrite call and the runtime strategy (73a/73b)
- the Kings design session (73c)
