# 40 — Repo docs refresh

Status: done (2026-08-29)

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

## Outcome (2026-08-29)

Rewrote `CLAUDE.md`'s game section from "planned — not started yet" to what the game
actually is, and pointed the backlog at `.scratch/gdd-gaps/` instead of the Linear that was
never used. Kept the parts that were already accurate and hard-won — the UI-probes-first
rule, the non-regression discipline, the piece-art conventions — and added:

- **Architecture**: `game.gd` as the live node, everything else a pure logic module on `g`
  or plain Dictionaries, which is why the headless suites can drive real logic.
- **`artefact_hooks.gd` as the shared dispatch for Artefacts AND Tariffs**, with the ctx
  contract and the stacking/ordering rules spelled out — the two things four handlers broke
  before they were written down anywhere.
- **ADR-0002** and why opaque piece state keeps paying off.
- **Conventions learned the hard way**: generated data is generated (never hand-edit the
  JSON); tests pin their seed; verify independently rather than trusting a green claim,
  including your own subagents'; saves are versioned and additive vs reshaped is the
  distinction that matters; ambiguity goes back to Notion as a question, not into code as a
  guess.

`CONTEXT.md` also corrected — it opened by describing the project as "driven from Linear",
and its GitNexus-fork glossary is now explicitly marked as an agent-tooling experiment that
nothing in `game/` depends on, rather than reading as shipped architecture.

## Blocked by

- nothing
