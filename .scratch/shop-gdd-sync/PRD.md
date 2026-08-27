# PRD: Shop — GDD sync

Status: in progress

## Problem Statement

The Shop shipped before it was ever specced (`money-and-shop`, PRs #48–#54). The Notion GDD has now caught up: the in-run Shop was grilled and written on 2026-08-27 (<https://app.notion.com/p/3c9f1559c99b8153b127ea8c079c02cd>), and it disagrees with the prototype in seven places — two of them naming, five behavioural. Left alone, the design doc and the game drift further apart with every artefact written against the doc's vocabulary.

## Solution

Port the prototype to the GDD page. **Gold** replaces `money` and **Artefact** replaces `trinket` throughout, the stock reshapes (typed boxes, slot counts as base + modifiers), the reroll trigger moves from a 10-wave cadence to cumulative-Score thresholds, and the Shop becomes always-openable with the Clock paused while it is up. **All UI work is deferred** — the shop stays a full-screen modal this round; the GDD's right-edge drawer is a separate follow-up.

## Scope

Seven divergences, from the GDD page's own table:

| | Prototype | GDD | Slice |
| --- | --- | --- | --- |
| Currency name | `money` | **Gold** | 01 |
| Passive pickups | `trinket` | **Artefact** | 01 |
| Restock trigger | every 10 waves | cumulative Score thresholds (1000, +500 each) | 02 |
| Boxes | 3 identical lootboxes | 6, typed 2 Item / 2 Artefact / 2 Score | 02 |
| Pieces | 8 fixed | 8 base, up to 10 via effects | 02 |
| Access | player's turn only | always openable | 03 |
| Pause | none | Clock stops while open | 03 |
| Surface | full-screen scrolling modal | right-edge drawer, ~90%, no scroll | **deferred** |

## Implementation Decisions

- **Rename is mechanical and total** (01): identifiers, save keys, UI labels, test names, comments. Save keys change too — `money` → `gold`, `trinkets` → `artefacts` — with **no back-compat shim**, per the repo's no-defensive-code rule; an old save loses those two fields and starts them empty, which is acceptable for a pre-release prototype.
- **Slot counts stay literals for now** (02): the GDD defines the rows as base + modifiers ("Pieces 8, up to 10 via effects"), but every slot-adding Artefact (Chocolate Key Cake, Alleged Weather Balloon, Sub-Antarctic Visa) lives in Notion, not in the game. Building the modifier pass now would be a seam with no caller — the same reason the per-Artefact milestone counter is deferred. `ROWS` keeps plain base counts; the modifier path lands with the first Artefact that needs it.
- **Boxes become typed** (02): a box slot carries its type (`item` / `artefact` / `score`), and buying it opens the roll modal restricted to that type. Price stays flat 50 for all three; per-type pricing is an open question on the GDD page.
- **Restock is score-driven** (02): the next threshold is tracked as run state (`shop_next_restock`, starting at 1000, stepping +500 after each restock). Crossing it rerolls all four areas and clears SOLD. The wave hook in `wave_logic.gd` is removed. The threshold marker persists in the save so reloading cannot reroll-scum.
- **Pause reuses the existing seam** (03): the Clock already stops for `game_menu_open` and `win_open` (`game.gd:362`). The Shop joins that condition — no new pause system.
- **Buying stays turn-gated and costs 1 action** (03): `can_buy` keeps its `PLAYER_TURN` + `actions_left >= 1` checks. Only *opening* becomes unconditional; outside your turn the shop is a readable catalog with dead Buy buttons.
- **The Difficulty-Ranks pause lever is not built** (03): the GDD makes the pause a difficulty lever, but the prototype has no difficulty system at all. Pause is unconditional here; the lever lands with difficulty ranks.

## Testing Decisions

- Test-first per slice; assert external behaviour (balances, slot states, what a purchase grants, whether the clock moved), never internals.
- **01**: the rename must be provably behaviour-neutral — the existing suites pass unchanged apart from renamed identifiers. `test_money.gd` becomes `test_gold.gd`.
- **02**: new cases in `test_shop.gd` — restock fires on crossing a threshold and not before, thresholds step +500, SOLD clears on restock, stock shape is 8/4/4/6 with the box row typed 2/2/2, slot modifiers change the counts, save/load preserves the next-threshold marker.
- **03**: the shop opens outside `PLAYER_TURN`; the Clock does not advance while it is open; Buy is refused outside the player's turn. Click probe extended for opening the shop during the enemy turn.
- Full `game/tests/run_all.sh` green before each commit; click probes first per repo policy.

## Out of Scope

- **All Shop UI** — the right-edge ~90% drawer, icon tiles with price badges, expand-on-tap, the four-area layout. Separate issue, needs the Godot MCP and click probes.
- **Porting the Artefacts catalog** (7 trinkets in code vs 180 in Notion) — its own project.
- **The per-Artefact 5-Wave Milestone counter** — ruled on in the GDD (each Artefact counts its own 5 waves from acquisition) but no artefact in the prototype uses milestones, so there is nothing to hook. Lands with the first milestone artefact.
- Selling goods back for Gold; wager betting; per-type box pricing.

## Further Notes

- The GDD's restock threshold (1000, +500) is flagged in the doc as probably unreachable: fleet data has a median Crown run ending near Score 300. Ship the rule, tune the numbers after a playtest sweep.
- Global 10-wave milestones (tariffs, score chunk, clock refill, stock drip) are **unchanged** — only the shop reroll leaves that cadence.
