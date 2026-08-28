# 07 — Difficulty Ranks

Status: todo

## Parent

`.scratch/gdd-gaps/PRD.md`

## What to build

[Difficulty Ranks](https://app.notion.com/p/390f1559c99b81788e8bc6434751239c) is a
pre-run difficulty selection. Nothing exists — not the picker, not a single lever.

⚠️ **The page deliberately leaves the tuning open** and carries four unanswered questions.
Only one lever is resolved: higher ranks disable the Shop's clock-pause, so shopping costs
real time. **This slice cannot be built from the page as it stands** — it needs a grilling
pass first (`grill-with-docs`) to answer:

- What does difficulty modulate? Candidates on the page: tariff severity, King
  strength/timing, starting Stock/Items, enemy density.
- How many ranks, and how are they named in the Main Menu?
- Does difficulty weight the leaderboard score, or is it purely comfort?
- Locked at run start, or changeable on Continue into endless?

Build after those are answered. The shipped half is then: the picker in the Main Menu,
the rank stored in run state and the save, and the Shop-pause lever wired to it.

## Acceptance criteria

- [ ] The four open questions answered and written back to the Notion page
- [ ] Rank chosen pre-run, stored in run state, survives save/load
- [ ] Higher ranks leave the Clock running while the Shop panel is open
- [ ] Whatever other levers the grilling settles on
- [ ] `run_all.sh` all green

## Decisions taken (2026-08-28)

The page's four open questions, answered so the slice can be built. Each is deliberately
the smallest defensible option — difficulty is a frame around the game, not a second game.

1. **What it modulates:** three levers only — the Shop clock-pause (the one already
   resolved on the page), tariff severity (shift the tier draw one step harsher), and
   starting Stock size. Explicitly NOT King strength or wave density: both are tuned
   against the wave catalog, and moving them invalidates the balance work.
2. **How many ranks:** three, named for the game's own fiction — **Citizen / Officer /
   Autocrat**. Three is enough to be meaningful and few enough to tune.
3. **Leaderboard weighting:** none. Difficulty is a comfort setting; Score is unweighted.
   Weighting opens a fairness question the local-only leaderboard cannot answer, and it
   can be added later without migrating anything.
4. **Locked at run start:** yes. Continuing into endless keeps the rank — otherwise a
   player could clear wave 50 on Citizen and bank an endless run on easy footing.

Write all four back to the Notion page when implementing.


## Blocked by

- 05 — Settings surface
- a grilling pass on the Notion page
