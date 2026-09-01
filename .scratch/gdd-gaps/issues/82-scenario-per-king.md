# 82 — A sandbox per King (16)

Status: done (2026-09-01) — unblocked and built the same day, once slice 93 shipped all 16 kits

## Parent

`.scratch/gdd-gaps/issues/73-scenario-coverage.md` (the King set)

## Scope

One board per King: that King as the boss, reachable immediately rather than at wave 50, with
its Power active and its Abilities triggerable — so the kit can be seen without playing a
50-wave run to get there.

This is the highest-value part of 73 and the only part that is blocked. Kings appear at waves
50 / 100 / 150; before slice 78 no run had ever reached one. A sandbox is the only practical
way to look at a King's kit at all.

## Why it WAS blocked (resolved)

`game/data/kings.gd` was identity and selection only — *"no per-King mechanics are specced
anywhere, so none are invented here."* There was nothing to build a sandbox around until the
design session assigned Powers and Abilities, and only one was assigned: Tariff, Donald
Trump's King Power (slice 66).

**Resolved by slices 91-93**: the Power/Ability engine plus all 16 kits, 32 effects. That is
what unblocked this, and it is why the sandbox needed no new mechanics of its own.

## Acceptance

- One entry per King, boss present from the first turn, Power visibly active.
- Each Ability reachable — whatever trigger the design session settles on, the board must be
  able to produce it on demand.
- Boots under `test_scenarios.gd`.
- `run_all.sh` ALL GREEN, foreground, alone.

## Blocked by

- ~~the Kings design session~~ (`.scratch/gdd-gaps/KINGS-DESIGN-WORKSHEET.md`) — held, 2026-09-01
- ~~the slices that session produces~~ — 91 (engine), 92 (Laurel), 93 (the other 12)
- ~~79 (menu grouping)~~ — done

## Outcome (2026-09-01)

**16 generated sandboxes in `game/data/scenarios_kings.gd`, appended by `Scenarios.all()`
beside 79's and 80's generators. 317 scenarios total** (301 + 16), one menu section `King`.

### It needed no engine change at all

The seams from 90-93 already covered every requirement, which is the whole reason this came
in small:

- **Boss from turn one** — `save_config.gd:157-167` merges a board entry's slot-4 Dictionary
  into the piece, so `["king", 1, 3, 10, {"king_id": "nero"}]` places an *identified* King.
- **Power live from turn one** — every Power branch reads `g.king_power_id` (`power_hook`,
  `power_is`, `deports_captures`), and `save_config.gd:134` restores that field straight from
  the config. No wave has to turn over to call `apply_power()`; setting the field stands in
  for it.
- **Ability on demand** — `game.gd:966` already spends one enemy Action on
  `Kings.fire_ability` whenever the King is on the board. Ending a turn fires it. Once per
  Wave and no wave turns over here, so it fires once per load.

**Donald Trump is the only special case**: his Power is tariff-backed (`inflation`), the
other 15 are bespoke keys. The config lists the tariff, which activates it exactly as
`apply_power()` would.

### One template, not sixteen

The kits bite different things, so the single board carries one of each rather than 16
bespoke setups that would drift the first time a kit changed: a queen (Nebuchadnezzar
crumbles the highest-value piece), two pawns (Tamerlane's pyramid takes the two least
valuable), a rook carrying two Buffs at the cap (Genghis strips them), a knight past
`BOARD_H / 2` (Putin's annex reaches it), 3 Items at the cap (Nero burns them), Stock to
deploy from (Qin Shi Huang doubles the cost), and takeable enemies (Nero's halved Gold,
Tamerlane's halved Score, Nebuchadnezzar's deported captures).

### Verified by consequence, not by field read-back

`test_kings.gd` boots three sandboxes and asserts one per dispatch shape — a ctx value, a
`blocked` gate, and a branch read at its call site — because `king_power_id` is exactly what
the generator sets, so reading it back would pass even if nothing downstream honoured it:

- The Great Wall: `deploy_cost` is **40** against a `PLACEMENT_COST` of 20.
- No Fixed Cities: `merge_ok` is **false**.
- The Babylonian Exile: `deports_captures` is **true**.
- The Ability fires on demand, and a second call returns false.

Also measured while building: Xerxes' Countless Host puts `enemy_actions` at **2** against a
baseline of 1.
