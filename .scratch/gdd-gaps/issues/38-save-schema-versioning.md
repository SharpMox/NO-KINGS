# 38 — Save schema versioning

Status: todo — INDEPENDENT

## Parent

`.scratch/gdd-gaps/PRD.md`

## Problem

The save config carries **20 top-level fields and no version stamp**. It has grown a lot in a
short time — this session alone added `seed`, `rng_state`, `rank`/tier, `king_ids_defeated`,
`turn_number`, per-piece `captures`/`wave_captures`, artefact entries with `acquired_wave`
and `rarity`, and `shop_restocks`.

Every one of those was added with an ad-hoc backward-compatibility guard (`cfg.get(...)` with
a default, or a catalog fallback). Those guards work, but there is no way to answer "what
shape is this save?" — so each new field means auditing every reader by hand, and a genuinely
breaking change would have no safe path at all.

## What to build

A `save_version` field, written on every save and read on load. Then a documented policy:
which changes are additive (default-and-carry-on) and which need a migration step, plus one
place migrations live.

This is not speculative: the shape of a save has changed roughly ten times in two days.

Keep it small — a version int, a migration table that is currently empty, and a test that
loads a pre-versioning save and succeeds.

## Acceptance criteria

- [ ] `save_version` written and read; a save without one is treated as version 0
- [ ] A pre-versioning save still loads — covered by a test with a fixture, not a live save
- [ ] Policy documented in the file header: additive vs migrating
- [ ] `run_all.sh` all green

## Blocked by

- nothing
