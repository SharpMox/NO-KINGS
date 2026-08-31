# 91 — The King Power / Ability engine

Status: done (2026-09-01)

## Parent

`.scratch/gdd-gaps/KINGS-DESIGN-WORKSHEET.md` (rulings 4, 6 and 8)

## The shape, corrected by the user

**One Power and one Ability per King — 32 effects, not 48** (user, 2026-09-01: *"Shouldnt it
be 32 with a power and an ability for each king?"*). This supersedes the worksheet's original
"2-3 Abilities".

It is the better shape for a reason worth recording: it **mirrors the Army structure exactly**,
so the engine seams already existed, and a player reads a King the same way they read their own
Army.

- **POWER** — static, live for the **whole** King wave, both segments (ruling 6).
- **ABILITY** — once per Wave, **costs the King one of its Actions** (ruling 4).

## Outcome

`Kings.KITS` carries the metadata; `apply_power()` and `fire_ability()` are the engine.

### Only Trump's kit is filled in, deliberately

His is the one that was ruled — **Tariff** as his Power (slice 66) and **Diplomatic Visit – JD
Vance** as his Ability (design session). The other 15 are absent and the engine **no-ops** on
them. That ships a working, tested engine without inventing 30 effects that are the user's to
design.

Trump's Power reuses the built-but-switched-off Tariff system (`Tuning.TARIFFS_SCHEDULED` is
false), which is the cheapest faithful reading of "Tariff is his Power": Tariffs are in force
for the duration of his wave and only his wave.

### The Ability spends an enemy Action, and that is the design

`_run_enemy_actions()` charges the Ability out of **the same budget the attacks come from**. An
Action spent on an Ability is an Action not spent attacking — the visible tradeoff the player
plays around. It also composes for free: an enemy turn zeroed by Y2K Patch Floppy Disk buys no
Ability either, because there is no Action to spend.

### Three constraints that each closed a real hole

1. **A Power must not outlive its wave.** `apply_power()` is called on *every* wave, and a
   non-King wave passes `""` — so the clearing half always runs. A Power leaking into wave 51
   would be a permanent difficulty increase nobody chose. Asserted directly: after the wave
   ends the Tariff is *removed from `tariffs_active`*, not merely un-recorded.
2. **No Ability during segment 1.** The Power is live before the King lands, but the Ability
   requires the King **on the board** — an Ability from a King the player cannot yet see or
   attack would be unanswerable. Asserted, including that the refused attempt spends nothing.
3. **A kitless King is charged no Action.** 15 of 16 have no Ability yet; they must not pay for
   one. Asserted.

### The bug this slice found in slice 90

`release_king_if_due()` **appended** the King to `pending_spawn`. With ordinary spawns still
queued and the spawn row full, `spawn_pending()` returned before ever reaching the King — and
90's landing guarantee only inspects the *head* of the queue, so a King sitting behind a
spilled spawn never got its chance to displace. It now **pushes to the front**: the King is the
event of the wave and does not queue behind rank and file.

Found by the engine test failing at "segment 2: the Ability fires", not by review.

### Save

`king_ability_used_this_wave` and `king_power_tariff` round-trip, both additive.

`test_kings.gd` — 13 new assertions. `run_all.sh` **163.2s ALL GREEN**, foreground, alone.

## Next

The 32 effects themselves, split per costume tier (four Kings per slice). Trump's is done; 15
Powers and 15 Abilities remain, and they are design decisions rather than engineering.
