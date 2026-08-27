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

## Blocked by

- 05 — Settings surface
- a grilling pass on the Notion page
