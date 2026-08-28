# 29 — Runtime artefact metadata

Status: todo — INDEPENDENT (no design decision needed)

## Parent

`.scratch/gdd-gaps/PRD.md`

## Problem

A held artefact entry carries its `key` and (since the milestone fix) an `acquired_wave`.
It does **not** carry its **rarity**, so any effect that reasons about rarity cannot be
written. `Illuminati Fridge Magnet` — *"While you own Artefacts of every rarity: +50% Gold
gain"* — was skipped for exactly this reason.

Rarity already exists in `game/data/artefacts.json`; it simply is not threaded onto the
runtime instance the way `acquired_wave` now is.

## What to build

Thread the catalog row's `rarity` onto held artefact entries at every acquisition path
(Shop buy, Box pick, scenario/save config, CLI flag) — the same places the milestone fix
already stamps `acquired_wave`, so this is one more field on an existing stamp rather than
a new mechanism. Round-trip it through `save_config.gd`, and fall back to the catalog
lookup for older saves that predate the field.

Then implement **Illuminati Fridge Magnet**.

While in there, add a small `ArtefactHooks` helper for "do I hold one of each rarity" so
the next rarity-reading artefact is a one-liner.

## Acceptance criteria

- [ ] Held entries carry `rarity`; old saves degrade to a catalog lookup, not a crash
- [ ] Illuminati Fridge Magnet implemented and flagged
- [ ] `run_all.sh` all green

## Blocked by

- nothing
