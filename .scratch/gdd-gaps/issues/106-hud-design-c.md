# 106 — In-run HUD for tall screens (design C)

Status: **SHIPPED** (2026-09-05, PR #308; main verified ALL GREEN after the merge).
Army-select follow-up in PR #310.

> Commits for this work carry `Refs: 100`, which is wrong — issue 100 (surface the Army
> Power in-run) closed on 2026-09-02. This file is the real home; 100 is only its ancestor
> in the sense that the Power/Ability surfacing question started there.

## Parent

`.scratch/gdd-gaps/PRD.md`

## Why

Removing the letterboxing (PR #305) gave the game the whole phone and immediately exposed
what the black bars had been hiding: the board was centred in its span, so the leftover
height split into a gap above AND below it, and the top bar carried status that did not
need to be glanceable.

## What shipped

- **Top strip: clock, score, gold, menu. Nothing else.** Wave, tariffs and Arrows moved
  into the deck; they are status and controls, not glance material.
- **Board pulled up flush** under that strip rather than centred, so every spare pixel
  arrives in ONE place, under the board, where the deck expands into it.
- **One deck**, fixed order: stock strip, status pills, drawers, passive Power badge, then
  **Ability beside PASS** on the last row, inside the thumb arc.
- **The Army Ability left the Inventory drawer.** It was a chip with its cost in a tooltip,
  in a touch game where tooltips are unreachable once a run starts. It now wears its state
  on the main view: `1 Action`, `next wave` when spent, `no Action` when there is nothing
  to spend. Those are three different problems for the player and a greyed-out button
  cannot tell them apart.
- **One `ICON` constant (52px)** sizes every icon, deliberately just under the 59px board
  tile. Items were clamped to 30, stock stacks to 46, the new strip to 52.
- **The stock strip absorbs leftover height** (`flex:1` in the prototype, `EXPAND_FILL`
  here), which is what makes a dead band structurally impossible rather than merely absent
  on the one screen that was measured.

## Method worth repeating

Three HTML prototypes (deleted 2026-09-06 — they had served their purpose; the method below
is the part worth keeping), rendered at **three real screen formats**
(9:20 Nothing Phone, 19.5:9 iPhone, 16:9 older Android) with a **self-audit printed on the
page**: canvas overflow, biggest gap between rows, and whether Stock stays reachable. Six
rounds. The audit caught things reading could not: a 316px dead gap, a mid-row clip, one
variant quietly using 42px icons, and — only on the 16:9 render — the stock strip
collapsing and taking the ONLY route to Stock with it.

## Still open

- **Drawers row is three text buttons**, not the prototype's icon dock. The click probes
  identify those buttons by text (`"Stock 2"`, `"Inventory 1"`), so converting them changes
  what the tests assert. Deliberate slice, not an oversight.
- **PR #310 (army select) is not device-checked.** The phone dropped off wireless debugging
  mid-verification, and this is a screen the desktop cannot show honestly, because
  `menu.gd` forces the window back to 480x800 on real boots — exactly the shape where the
  problem does not appear.
- The **empty band inside the strip** on very tall screens is ~37px and deliberate: the
  strip is the slack absorber, so its own leftover is where slack ends up.
