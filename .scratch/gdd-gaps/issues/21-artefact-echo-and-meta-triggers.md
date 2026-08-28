# 21 — Artefacts: echo, duplication and cross-artefact meta-triggers

Status: todo

## Parent

`.scratch/gdd-gaps/PRD.md`

## Split out of

19 — during that slice's triage, this group turned out to be one real system
(a meta-layer over `ArtefactHooks.run()` itself), not a scatter of one-offs —
see issue 19's Outcome for the full accounting of what shipped there instead.

## What to build

Every artefact here reads or reacts to *another artefact's own trigger*, not
to a game event directly. `ArtefactHooks.run(g, hook, ctx)` today just walks
`REGISTRY` and calls `_dispatch` per held key — it has no concept of "an
artefact fired," "twice," or "the last one bought," so none of these can be
expressed as an ordinary REGISTRY line + `match` case. The real work is
deciding what `run()` itself needs to expose (a fired-this-call list? a
trigger log?) before any of these can be REGISTRY entries.

| Artefact | Needs | Note |
| --- | --- | --- |
| 100% Genuine Original Mona Lisa | artefact echo | "your first Artefact trigger [any hook] is copied and triggers again," including enemy turns |
| Red Diary's Missing Pages | artefact echo | same idea, scoped to "on losing a piece" Artefacts only (on_piece_lost, issue 19) |
| Polybius Cartridge | (no needs-note, Special) | "When a 'Capture' Artefact triggers: it triggers an additional time" — same shape, scoped to on_capture |
| Max Headroom Mask | (no needs-note, Special) | same shape, scoped to "Wave" Artefacts (on_wave_clear/on_wave_spawn) |
| CERN Ctrl+Z Shortcut | duplicate detection | "your duplicate Artefacts trigger one extra time" — needs run() to know a key is held 2+ times, which REGISTRY already implies but no handler currently reads |
| Bilderberg Hotel Slippers | trigger tracking | "+15 Gold whenever two or more of your Artefacts trigger on the same event" — needs run() to report how many handlers actually fired this call, not just how many are held |
| Déjà Vu Glitch | gain multiplier | "your first Score gain and first Gold gain each Turn: they trigger again" — re-running Economy.earn's own ctx a second time without double-charging the reason-tagged early-clear/etc. gates |
| Troll Farm Employee of the Month | dual-trigger dispatch | "your 'Wave' Artefacts also trigger on Wave start" — cross-wires on_wave_spawn to also run the on_wave_clear handlers, artefact-by-artefact |
| Ecdysis Sheddings | artefact-copy dispatch | "copies the effect of the last other Artefact you bought" — needs a purchase-order log and a way to invoke an arbitrary key's handler by name |
| Illuminati: NWO Booster Pack | artefact-trigger event | "+2 Gold/+20 Score whenever a 'Capture' Artefact triggers" — same shape as Polybius but additive, not multiplicative |
| Illuminati Fridge Magnet | rarity threading | "own Artefacts of every rarity" — `Items.ARTEFACT_EFFECTS` carries `rarity` per-entry (issue 18) but the 7 core keys have none at all, so "every rarity" can never be literally true while they're held — a design question, not just plumbing (issue 16's held-back note) |
| Capstone Polish | acquisition-path ambiguity | "on acquiring an Artefact" only reaches on_purchase today; box-granted artefacts are a different call site (issue 16's held-back note, repeated in issue 17/18) |
| Deep State Yearbook / New World Order Gerrymandering | cross-artefact modification | both artefacts modify *other* artefacts' own payouts — real design work on what "modifies" means before any hook shape follows (issue 16's held-back note) |

## Acceptance criteria

- [ ] Decide `run()`'s new contract: does it return which keys actually fired
      (not just which are held), and is a "trigger log" (last N hook fires,
      with key + hook) worth adding as a small `g` field the way
      `wave_capture_count` etc. already are?
- [ ] Illuminati Fridge Magnet and the two Yearbook/Gerrymandering artefacts
      need a design ruling before they're triaged further — Notion question,
      not a guess
- [ ] Scenario coverage, `run_all.sh` all green

## Blocked by

- 15 — trigger engine
- 19 — Special + prereq triage (this file is one of its splits)
