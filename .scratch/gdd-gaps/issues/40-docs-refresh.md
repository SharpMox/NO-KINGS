# 40 — Repo docs refresh

Status: todo — INDEPENDENT

## Parent

`.scratch/gdd-gaps/PRD.md`

## Problem

`CLAUDE.md` still says, at line 95:

> ## The game (planned — Godot)
> Not started yet. When it is, this is the intended setup:

The game now has ~30 merged slices, 141 implemented artefacts, 12 Piece Buffs, a 5-tier
difficulty system, a King cast, cloud-save scaffolding and a 22-suite test harness. The
section below that heading describes intentions that have all since been decided differently
— it names Linear as the backlog (there is no Linear; the backlog is `.scratch/gdd-gaps/`).

An agent reading `CLAUDE.md` to orient itself is being actively misled, and several agents
this session had to discover the real state by reading code.

## What to build

Rewrite the game section to describe what exists: the architecture (`game.gd` + the pure
logic modules, `ArtefactHooks` as the shared dispatch for artefacts and tariffs, ADR-0002's
opaque piece state), where the backlog actually lives, the test discipline that has emerged
(windowed probes first, full suite blocking, verify independently), and the conventions that
were learned the hard way — the ctx contract, the exporter as the only writer of
`artefacts.json`, seeds for determinism.

Also refresh `CONTEXT.md` if its glossary has drifted.

Keep it the same density as the rest of the file. This is documentation of what is, not a
plan for what might be.

## Acceptance criteria

- [ ] No section of `CLAUDE.md` describes the game as unstarted or planned
- [ ] The backlog's real location is named
- [ ] The hard-won conventions are written down where an agent will read them
- [ ] `CONTEXT.md` checked and refreshed if drifted

## Blocked by

- nothing
