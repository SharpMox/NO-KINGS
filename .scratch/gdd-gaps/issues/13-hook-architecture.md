# 13 — Hook architecture

Status: todo

## Parent

`.scratch/gdd-gaps/PRD.md`

## What to build

[Architecture / Systems Loop](https://app.notion.com/p/390f1559c99b81969429ee421bb8acaf)
wants subsystems attached to the main loop via **hooks** — `on_wave_start`, `on_turn_end`,
`on_capture` — rather than the loop calling into each subsystem directly, so new
subsystems (and mods, per Future Ideas) register without editing the loop.

The prototype calls subsystems directly from `game.gd`. That page is also mostly TODO and
was written before the Godot project existed ("treat as architecture intent, not an
as-built doc"), so it describes an intent the code has since diverged from by default.

**Deliberately last.** This is a refactor with no player-facing value, and every slice
above it adds call sites that would have to be migrated. Doing it early means doing it
twice. Revisit once Piece Buffs (03/04) has landed — that system is the first real test of
whether direct calls actually hurt, because buffs need to observe captures, turn ends and
wave starts from outside the loop.

The page's other requirement — **headless testing at volume** — is already met and then
some by `run_all.sh` plus the autoplay sweep.

## Acceptance criteria

- [ ] Hook list and signal/method contract defined
- [ ] At least Piece Buffs and the tariff system registered through hooks rather than
      direct calls
- [ ] The Global Systems Loop diagram drawn and added to the Notion page
- [ ] No behaviour change — pure refactor, `run_all.sh` green before and after

## Blocked by

- 03 / 04 — Piece Buffs (the first real consumer)
