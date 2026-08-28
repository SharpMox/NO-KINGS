# 19 — Artefacts: Special, and the prerequisite backlog

Status: todo

## Parent

`.scratch/gdd-gaps/PRD.md`

## What to build

The long tail: the **Special (41)** tag, plus the **86 artefacts whose text carries an
explicit `(needs: …)` note** — the catalog authors flagging a system that does not exist.

Grouped, the missing systems are roughly:

| Needed | Artefacts | Notes |
| --- | --- | --- |
| spawn modifier | 3 | change what a wave spawns |
| item cap | 2 | held-item capacity is currently unbounded |
| zone check | 2 | "while in your zone" positional predicate |
| purchase counter | 2 | per-run purchase tally |
| shop layout change | 2 | needs slice 08 |
| box reroll | 2 | re-roll an open Box Pick |
| enemy auto-debuff | 2 | slice 04's buffs, applied by the game |
| chain lookup | 2 | promotion-chain queries — `ItemLogic.chain_base` is the seed |
| capture conversion | 2 | turn a captured piece into an ally |
| artefact echo | 2 | re-trigger another artefact |
| streak / loss / gold-threshold / rank / deploy hooks | 1 each | mostly slice 15 hooks |

**Do not build these blind.** Each row is a small system, and several are one line of
catalog text away from being a slice of their own. The work here is:

1. Triage the 86 by prerequisite, using the table above.
2. Implement the cheap shared ones — most of the "hooks" collapse into slice 15's
   registry once it exists.
3. For anything that is genuinely a new system (capture conversion, artefact echo, spawn
   modifier), **split it out** rather than smuggling it in.
4. Anything still undefined after that goes back to Notion as a question, the way Slow and
   Range did — not into code as a guess.

## Acceptance criteria

- [ ] All 86 prerequisite artefacts triaged by system, with the table kept current
- [ ] Shared hooks implemented once, in slice 15's registry
- [ ] Genuinely new systems split into their own slices rather than absorbed
- [ ] Every remaining ambiguity asked on Notion, not guessed
- [ ] Scenario coverage, `run_all.sh` all green

## Blocked by

- 15 — trigger engine
- 16 / 17 / 18 — the straightforward tags first
