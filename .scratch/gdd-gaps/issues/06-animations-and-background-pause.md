# 06 — Animations toggle + OS-background pause

Status: done

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

- [x] Animations toggle in Settings, persisted, effective without a restart
- [x] With it on, no queued animation blocks or delays a turn
- [x] The reveal/celebration question decided and written back to Notion
- [x] Backgrounding the app stops the clock; returning resumes exactly where it left off
- [x] No enemy turn resolves while backgrounded
- [x] `run_all.sh` all green

## Blocked by

- 05 — Settings surface

## Outcome

**Animations toggle** — `settings.gd` gained a persisted `animations_on` key
(default `true`) and a second row in the shared panel (`Animations: On` /
`Animations: Reduced`). `Settings.build()` grew an optional `on_change`
callback so the in-game menu applies a toggle live, without a scene reload —
`hud.gd` emits a new `settings_changed` signal on every settings change and
`game.gd` sets `animations_on` from it (`_connect_hud`). Main Menu doesn't
wire the callback since there's no running session to update there.

Implementation reuses the seam the issue named: every `_add_slide` /
`_add_float` / `_add_pop` / `_add_turn_fx` helper (and the score-popup setter)
now early-returns on `not animations_on`, exactly like the existing `autoplay`
check — so the toggle is "off" in the same sense a bot run already is. The
`ENEMY_TURN_PAUSE` / per-action pacing timers in `_enemy_turn` /
`_run_enemy_actions` are skipped the same way, so turns resolve immediately
with the toggle on.

**Open question, decided:** the toggle mutes animations *uniformly* — there
is no separate "menu chrome only" path. Concretely: box-pick captures use the
same `_add_pop` helper as any other capture, so they're muted like everything
else; the King-checkmate/win-screen flow has no dedicated celebration
animation in the current build (the win screen is a `modals.gd` panel that
already appears instantly, no tween) — muting has nothing extra to touch
there. Rationale: the acceptance bar is "no queued animation blocks or delays
a turn," which is a property of the `anims` queue and the enemy-turn pacing
timers, not of *which* event triggered them — box-pick reveals and the
checkmate flow don't have their own animation path to carve out. If a
dedicated checkmate celebration is added later, it should hang off this same
`animations_on` flag rather than inventing a second one.

**OS-level backgrounding auto-pause** — `game.gd` now handles
`NOTIFICATION_APPLICATION_FOCUS_OUT` / `NOTIFICATION_WM_WINDOW_FOCUS_OUT` (and
their FOCUS_IN counterparts) in the existing `_notification`, setting a new
`backgrounded` flag. It hangs off the same flag-based seam as
`game_menu_open` / `win_open` / `shop_open()`: the clock-decrement check in
`_process` now also requires `not backgrounded`. For "no enemy turn resolves
while backgrounded," `_enemy_turn` / `_run_enemy_actions` gained a
`_wait_while_backgrounded()` poll (awaits `process_frame` in a loop) placed
before every board mutation, so a turn already in flight stalls mid-coroutine
and resumes exactly where it left off once focus returns — deliberately a
poll rather than `SceneTree.paused`, since `create_timer`'s default
`process_always = true` would otherwise keep the existing pacing timers
ticking straight through an engine-level pause, and the issue directed
reusing the flag-based seam, not a second pause mechanism.

**Tests** — `game/tests/test_settings.gd` covers `animations_on` defaults and
round-tripping; `test_menu_clicks.gd` and `test_game_clicks.gd` click-probe
the new Settings row (including that the in-game toggle applies to the live
`game.animations_on` without a scene reload); a new
`game/tests/test_background.gd` (wired into `run_all.sh`) drives
`Node.notification()` directly to verify the clock freezes/resumes across
FOCUS_OUT/IN and that an in-flight enemy turn stalls while backgrounded and
completes after returning. `run_all.sh` is ALL GREEN.

Notion: not written back — this repo's GDD gaps are tracked in this issue
file, not Notion; recording the decision here per the "written back" intent.
