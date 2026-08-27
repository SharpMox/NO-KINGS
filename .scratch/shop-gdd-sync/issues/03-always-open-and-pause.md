# 03 — Always-openable Shop that pauses the Clock

Status: todo

## Parent

`.scratch/shop-gdd-sync/PRD.md`

## What to build

Opening the Shop becomes unconditional — the button works in any state, including during the enemy turn — and **the run-long Clock stops while the panel is open**, reusing the existing pause condition at `game.gd:362` (`game_menu_open` / `win_open`).

Buying stays exactly as it is: `PLAYER_TURN` only, 1 action plus the Gold price. Outside your turn the Shop is a readable catalog with dead Buy buttons.

The GDD makes the pause a Difficulty-Ranks lever (higher ranks leave the Clock running). The prototype has no difficulty system, so the pause is unconditional here and the lever lands with difficulty ranks.

**Known gap:** "pauses the game" is implemented as *the Clock stops*. The enemy turn is a coroutine driven by `await create_timer(ENEMY_TURN_PAUSE)` and `_run_enemy_actions()`, so opening the Shop mid-enemy-turn does not freeze enemy moves or their animations — they keep resolving behind the panel. Since the Clock is the only real-time pressure in the game and the enemy turn is a short scripted sequence, this is left as-is rather than threading a pause check through the coroutine. Revisit if the enemy turn ever gets long enough to matter.

## Acceptance criteria

- [ ] The Shop opens outside `PLAYER_TURN`
- [ ] `clock_ms` does not advance while the Shop is open
- [ ] Buy is refused outside `PLAYER_TURN`, and Buy buttons render disabled there
- [ ] Closing the Shop resumes the Clock
- [ ] Click probe covers opening the Shop during the enemy turn
- [ ] `game/tests/run_all.sh` all green

## Blocked by

- 01 — rename
