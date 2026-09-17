# 03 — Always-openable Shop that pauses the Clock

Status: done — shipped 2026-08-27 in `41deeb0`; the pause is now a difficulty lever

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

## Outcome

Shipped 2026-08-27 in `41deeb0` *feat(shop): open the Shop in any state and pause the clock
while it is up* (touched `game.gd`, `test_game_clicks.gd`, `test_shop.gd` and this slice
file). The `Status: todo` line above was never updated, which made an instruction audit on
2026-09-17 read it as unstarted work.

**The pause is no longer unconditional.** This file says "the prototype has no difficulty
system, so the pause is unconditional here and the lever lands with difficulty ranks" — the
lever has since landed. `game.gd:969` now reads
`var tier_pauses := not Tuning.clock_never_pauses(next_tier) and (game_menu_open or
shop_open() or ...)`, so higher tiers leave the Clock running exactly as the GDD specifies.
The OS-backgrounded pause (slice 06) always wins and is not a difficulty lever; `win_open`
is deliberately excluded from the tier-gated list.

The known gap above still stands as written: the Clock stops, but the enemy-turn coroutine
keeps resolving behind the panel. Still accepted, still worth revisiting only if the enemy
turn grows long enough to matter.
