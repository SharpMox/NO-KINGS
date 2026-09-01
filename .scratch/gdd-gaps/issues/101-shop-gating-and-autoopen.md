# 101 — Shop gated to wave 5+, and auto-opens on restock

Status: todo (planned 2026-09-01) — the gating half contradicts a shipped GDD decision

## Parent

`.scratch/gdd-gaps/PRD.md`

## Two halves, very different risk

### (a) Auto-open on restock — additive, low risk

`SHOP_RESTOCK_WAVES` is **5** (`tuning.gd:181`), and `wave_logic.gd:51` already fires Lane A's
guaranteed restock every 5th wave. Opening the panel automatically at that moment is a small,
well-defined change on an event that already exists.

Care needed: the Shop must not auto-open **over** another modal. `_open_shop` already refuses
while `box_open`/`buff_pick_open`/`preview_open`/`win_open` (one modal at a time), and a wave
clear can produce a Box pick. So auto-open has to queue behind those rather than be dropped —
otherwise the restock wave silently doesn't open, which is worse than never auto-opening.

Also: **Kim Jong Un's Juche Power closes the Shop entirely** (`game.gd:3492`). Auto-open must
respect it, or the King's Power announces itself by opening the thing it forbids.

### (b) Gate to wave 5+ — contradicts a documented decision

`game.gd:3487-3490`, verbatim:

> *Shop entry: player's turn only, never over another modal.*
> ***Always openable, in any state — the GDD makes the Shop the one surface the player can
> reach at will.*** *Buying is still turn-gated (`Shop.can_buy`), so outside your turn it is a
> readable catalog with dead Buy buttons.*

"Always openable" is a deliberate, GDD-sourced property, and the Shop is *already* the one
place a player can look things up mid-run — descriptions, prices, what exists. Gating it to
wave 5 removes the **catalog** as well as the **purchasing**, which is probably not the
intent.

The likely real goal — "no buying in the opening" — is achievable without closing the surface:
keep the Shop readable from wave 1 and gate **`Shop.can_buy`** until wave 5. Same economic
effect, keeps the reference function, and matches how the Shop already behaves outside your
turn (readable catalog, dead Buy buttons — the pattern exists).

**Recommendation**: (a) as asked; for (b), gate buying rather than opening.

## Acceptance

- The Shop opens by itself on a Lane A restock wave, queued behind any modal already open,
  and never under Juche.
- Purchasing unavailable before wave 5 (or the panel closed entirely, if that is the ruling),
  with a readable reason in the UI rather than a dead button with no explanation.
- Scenario boards at wave 4 and wave 5 showing the boundary.
- Click probes extended; `run_all.sh` ALL GREEN, foreground, alone.

## Blocked by

A ruling on (b): gate **buying** (recommended) or gate **opening** (as literally asked, and a
reversal of a GDD decision).
