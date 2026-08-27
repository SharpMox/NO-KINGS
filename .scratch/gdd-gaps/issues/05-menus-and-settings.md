# 05 — Menus & Settings shell

Status: todo

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

- [ ] Main Menu carries all seven entries
- [ ] In-Game Menu carries Resume · Guide · Settings · Main Menu
- [ ] Settings persist across a relaunch
- [ ] Games History records a run and is distinct from Highscores
- [ ] Every new button has a click-probe check
- [ ] `run_all.sh` all green

## Blocked by

- nothing
