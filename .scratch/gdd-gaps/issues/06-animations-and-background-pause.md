# 06 — Animations toggle + OS-background pause

Status: todo

## Parent

`.scratch/gdd-gaps/PRD.md`

## What to build

Two Menus & Options requirements with no code today.

1. **Reduce/Disable Animations toggle** in Settings, for motion sensitivity and low-end
   devices. The GDD's design principle is that UI transitions are animated by default;
   this makes them instant or minimal. The prototype's animation queue (`anims` in
   `game.gd` — slides, pops, banners, outlines) is the thing to short-circuit.
   The GDD leaves one question open: does the toggle also mute box-pick reveals and the
   King-checkmate celebration, or only menu chrome? Decide and record it.
2. **OS-level backgrounding auto-pause.** App switch, phone call or notification must
   trigger the same pause state as the in-game menu — clock stopped, wave timer stopped,
   no enemy turns processing. Nothing handles
   `NOTIFICATION_APPLICATION_FOCUS_OUT` / `NOTIFICATION_WM_WINDOW_FOCUS_OUT` today, so a
   backgrounded phone silently burns the run clock.

The pause plumbing already exists — `game.gd` stops the clock for the game menu, the win
screen and the open shop. This hangs off the same seam.

## Acceptance criteria

- [ ] Animations toggle in Settings, persisted, effective without a restart
- [ ] With it on, no queued animation blocks or delays a turn
- [ ] The reveal/celebration question decided and written back to Notion
- [ ] Backgrounding the app stops the clock; returning resumes exactly where it left off
- [ ] No enemy turn resolves while backgrounded
- [ ] `run_all.sh` all green

## Blocked by

- 05 — Settings surface
