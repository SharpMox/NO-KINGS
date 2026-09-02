# 100 — Surface the Army POWER in-run (the Ability button already exists)

Status: done (2026-09-02) — rescoped: the Ability button already existed

## Parent

`.scratch/gdd-gaps/PRD.md`

## Half of this already shipped

**The Ability button exists.** `hud.gd:452`, `_add_army_ability_chip()` — a chip reading
`★<ability_name>`, disabled when unavailable, wired to `army_ability_pressed`, added to the
HUD at `hud.gd:443` since issue 67. Autoplay presses it (15% roll per turn).

So "we need a button for the ability" is done. What is genuinely missing is the **Power**.

## The Power is effectively invisible on the target platform

The static Power is displayed in exactly two places:

- `hud.gd:459` — inside the **tooltip** of the Ability chip
- `menu.gd:289` — on the **army-select screen**, before the run starts

This game is **portrait 480x800, Android + iOS**. Hover tooltips do not exist on touch. So
once the run begins, the player's always-on Power — "Merges cost no Action", "your Piece Buff
cap is 3", "Shop buy prices -25%" — is unreachable. They chose it on one screen and then have
no way to re-read it.

That is worse than a missing nicety: several Powers change what is *legal* (Close Ranks makes
merges free, Endless Ranks makes pawn deploys free), so a player who has forgotten it is
misreading the rules of their own run.

## Scope

Put the Power somewhere persistent and touch-reachable. The **inventory drawer** is the
natural home — it already has sections and is the "what do I have" surface — but a compact
always-visible HUD badge is worth considering, since the Power is always on and a drawer is
a tap away.

Include the Ability's cost (1 Action) in the same place: it is the deliberate contrast with
Artefact activation and the Shop, both 0, and that contrast is currently only in a tooltip too.

## Constraints

- Portrait 480x800, touch-first, no hover-only affordances.
- Load `godot-ui` before writing UI code; **click probes first**, windowed, per CLAUDE.md.
- Extend the probes to cover the new surface — the bypasses once green-lit a dead main menu.

## Acceptance

- The active Army's Power name and description are readable in-run without hover.
- The Ability's 1-Action cost is stated where the Ability is.
- Click probes extended; `run_all.sh` ALL GREEN, foreground, alone.

## Blocked by

Nothing.

## Outcome (2026-09-02)

A wrapped line at the top of the Inventory drawer, above the Item/Activate/Artefact strips —
it is the standing rule the rest of the drawer operates under, so it reads first:

```
The Muster — Close Ranks: Merges cost no Action.   ·   ★Call the Banners (1 Action):
Duplicate a target piece from your Stock into your Stock.
```

The Ability's **1-Action cost** is stated with it. That cost is the deliberate contrast with
Artefact activation and the Shop (both 0), and it was tooltip-only too.

`INV_H_ACTIVATE` grew by 48px for two wrapped rows at 13px on a 480-wide portrait screen.

### Why this was worth a slice at all

Half the original ask was already built — the Ability **button** has existed since issue 67
(`hud.gd`'s `_add_army_ability_chip`). What was missing was the **Power**, and it was missing
in a way that only matters on the real platform: it lived in the Ability chip's `tooltip_text`
and on the army-select screen. **This is a portrait touch game, and hover tooltips do not
exist on a phone**, so from the moment a run started the player's always-on Power was
unreadable.

That is not cosmetic. Several Powers change what is *legal* — Close Ranks makes merges cost no
Action, Endless Ranks makes pawn deploys cost no Gold — so a player who had forgotten theirs
was misreading the rules of their own run.

Asserted in `test_game_clicks.gd` (windowed, per the UI-first rule): the drawer text contains
the active Army's Power name and description, and the Ability's Action cost, **without any
hover**. Verified across The Muster, The Cult and The Horde.

`run_all.sh` ALL GREEN, foreground, alone.
