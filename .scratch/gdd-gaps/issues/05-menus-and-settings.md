# 05 — Menus & Settings shell

Status: done

## Parent

`.scratch/gdd-gaps/PRD.md`

## What to build

[Menus & Options](https://app.notion.com/p/367f1559c99b81cd85d1f6143b93acef) specs a Main
Menu of Play/Continue · Highscores · Games History · Guide · About · Settings · Quit, and
an In-Game Menu of Resume · Guide · Settings · Main Menu.

Today the Main Menu has Play, Continue, TEST scenarios, army select and High scores; the
In-Game Menu has Resume and Main Menu. Missing: **Games History, Guide, About, Settings,
Quit** and the in-game **Guide** + **Settings**.

1. **Settings surface + persisted store.** The shell other slices hang off — 06 needs an
   animations toggle, 07 needs a difficulty picker, 12 needs an account row. Persist to
   `user://` alongside the existing scores/save files.
2. **Games History** — per-run records, distinct from the top-10 Highscores. The run
   summary already computed for the end screen (score, deepest wave, kings, tariffs seen,
   pieces lost) is what to store.
3. **Guide** — in-game rules reference, reachable from both menus.
4. **About** — credits/version.
5. **Quit Game** — clean exit from the Main Menu.

Keep the click probes ahead of the sweeps: every new button gets a probe check, per repo
CLAUDE.md. Godot headless drops GUI picking.

## Acceptance criteria

- [x] Main Menu carries all seven entries
- [x] In-Game Menu carries Resume · Guide · Settings · Main Menu
- [x] Settings persist across a relaunch
- [x] Games History records a run and is distinct from Highscores
- [x] Every new button has a click-probe check
- [x] `run_all.sh` all green

## Blocked by

- nothing

## Outcome

Shipped on `feat/menus-and-settings`.

- **Settings** (`scripts/settings.gd`): persists to `user://settings.json`
  alongside `save.json`/`scores.json`/`history.json`. Ships one real, wired
  toggle — **Sound** (mutes the Master audio bus) — since there's no
  animations system or difficulty system yet for 06/07 to have real content;
  a dead toggle for either would be speculative. `load_settings()` merges
  onto defaults so future keys (06's `animations_on`, 07's difficulty, 12's
  account row) round-trip untouched. `apply()` runs at both Menu and Game
  boot so a relaunch (or a CLI bypass that skips the Menu) still respects it.
  Panel is a single shared `Settings.build()` embedded by both the Main Menu
  and the in-game menu — one copy, no drift.
- **Guide** (`data/guide_text.gd` + `scripts/guide.gd`): a plain-language
  rules reference sourced from the actually-implemented mechanics (board,
  turns/actions, merging, Shop, Tariffs, Kings, clock) rather than the GDD,
  which this agent had no access to. Shared scrollable panel, reachable from
  both menus, one copy.
- **Games History** (`Economy.record_history` / `GameScript.load_history`,
  `user://history.json`): every real run's summary (score, deepest wave,
  kings, tariffs seen, pieces lost — the exact fields already computed for
  the end screen — plus `won`, added because a bare stat line is ambiguous
  without knowing if the run ended in victory or defeat) appends newest-first
  on `_game_over`, capped at 50 so the log can't grow forever. Distinct from
  the ranked top-10 Highscores.
- **About**: static credits/version screen (no version file exists in the
  repo, so it just names the game and "Built with Godot 4").
- **Quit**: already existed on the Main Menu — untouched.
- Main Menu now carries all seven GDD entries (Continue/Play, Highscores,
  Games History, Guide, About, Settings, Quit); the existing dev-only TEST
  scenario launcher was kept alongside them, not removed. In-game menu now
  carries Resume · Guide · Settings · Main Menu.
- Every new button has a click-probe check in `test_menu_clicks.gd` and
  `test_game_clicks.gd`, plus two new headless suites (`test_settings.gd`,
  `test_history.gd`) wired into `run_all.sh`.
- Fixed two latent test-harness bugs surfaced by the new probes (not
  production bugs): `test_menu_clicks.gd` left an orphaned `Game.tscn`
  instance (from an earlier deferred `change_scene_to_file`) as a sibling of
  the fresh Menu reload, whose full-rect HUD could intercept clicks landing
  near the screen bottom; and `test_game_clicks.gd`'s `_click_button_in`
  didn't scroll a target into view before clicking, so a button below the
  fold (the Guide panel's own Back, once its long text pushed it off-screen)
  got a synthetic click at a coordinate outside the window. Both fixed at
  the test-harness level, matching `test_menu_clicks.gd`'s existing
  scroll-into-view pattern.
