# Capture paths: screenshots and short videos for review

Debug tooling for showing Max UI he has never seen. Everything here is behind CLI flags, so a normal boot never reaches it. The screenshot seam's rules are in `CLAUDE.md` ("The `--screenshot` seam is windowed"): run windowed, never `--headless`; flags go after the bare `--`; each capture gets its own directory; don't hash `game.png`.

## Pick scenarios by name

`--scenario-name NAME` boots the scenario with that exact `"name"` from `game/data/scenarios.gd`. It is gated the same way as `--scenario N` (it sets `is_scenario`, so a run never autosaves). Use it instead of `--scenario N`: the indices shift every time a scenario is inserted. If no scenario has that name, the run prints `UNKNOWN SCENARIO` and exits 2. It never falls back to a default board.

`tests/test_capture_paths.gd` (part of `run_all.sh`) checks that every scenario name quoted after `--scenario-name` in this file still resolves. If you rename a scenario, update this file too.

## Running a command

Locally:

```sh
tools/godot-lock.sh godot --path game -- <flags>
```

On Aux, check out and capture inside one locked command (`ROLE.md`, `CLAUDE.md`). The `\"` escapes survive both shells:

```sh
ssh aux 'cd ~/NO-KINGS && caffeinate -i tools/godot-lock.sh sh -c "git fetch --prune -q && git checkout --detach -q origin/<ref> && $HOME/bin/godot --path game -- --scenario-name \"Loss: clock-out (10s)\" --screenshot /tmp/cap/gameover --show-screen gameover"'
```

## Screens (`--screenshot DIR --show-screen NAME`)

Game-scene screens need a scenario and write `DIR/game.png`:

| Screen | What it shows | Flags after `--` |
|---|---|---|
| `board` | the scenario exactly as booted (a bare `--screenshot` places the Stock and passes first) | `--scenario-name "Header: King Wave — Donald Trump, Tariffs in force" --screenshot /tmp/cap/kchip --show-screen board` |
| `pause` | in-game pause menu | `--scenario-name "Movement & drag" --screenshot /tmp/cap/pause --show-screen pause` |
| `king-abilities` | King Abilities overview | `--scenario-name "Header: King Wave — Donald Trump, Tariffs in force" --screenshot /tmp/cap/ka --show-screen king-abilities` |
| `box` | a random Box pick | `--scenario-name "Movement & drag" --screenshot /tmp/cap/box --show-screen box` |
| `banner` | the pinned turn banner (NO-234) | `--scenario-name "Banner: frozen (NO-234)" --screenshot /tmp/cap/banner --show-screen banner` |
| `tip` / `preview` | long-press tip / preview for the tile at `--anchor` | `--scenario-name "Movement & drag" --screenshot /tmp/cap/preview --show-screen preview --anchor 2,1` |
| `gameover` | loss screen ("Clock out"), no ad-retry offer | `--scenario-name "Loss: clock-out (10s)" --screenshot /tmp/cap/gameover --show-screen gameover` |
| `gameover-retry` | NO-241/NO-100 "Retry wave N?" prompt, forced on | `--scenario-name "Loss: clock-out (10s)" --screenshot /tmp/cap/retry --show-screen gameover-retry` |
| `ad` | the AD placeholder overlay | `--scenario-name "Movement & drag" --screenshot /tmp/cap/ad --show-screen ad` |
| `win` | wave-50 win screen (Continue / End Run) | `--scenario-name "Win screen: wave 50 (capture King)" --screenshot /tmp/cap/win --show-screen win` |
| `setup` | SETUP placement zone: empty board, full Army Stock, Stock drawer open | `--scenario-name "Movement & drag" --screenshot /tmp/cap/setup --show-screen setup` |
| `stock-return` | SETUP, a placed piece mid-drag over the open Stock drawer: its first empty slot highlighted as the drop target, the Army's Stock one cell per piece | `--scenario-name "Movement & drag" --screenshot /tmp/cap/return --show-screen stock-return` |
| `feed` | kill feed with three lines: a capture gain, a sale, an Artefact trigger | `--scenario-name "Movement & drag" --screenshot /tmp/cap/feed --show-screen feed` |
| `pick` | the shared choice modal, as a Sell confirm | `--scenario-name "Capture: selling sandbox" --screenshot /tmp/cap/pick --show-screen pick` |

| `turn-start` | the player-turn-start Artefact dispatch alone (NO-250 Pincer: the Stunned enemy with its "Stunned!" float; `stunned` has no board badge) | `--scenario-name "NO-250: Pincer" --screenshot /tmp/cap/pincer --show-screen turn-start` |

Other seam flags work with `--scenario-name` too: `--select X,Y[;X,Y]`, `--arm-item KEY [--anchor X,Y]`, `--open-shop`, `--open-drawer stock|inventory` (only one of them per run).

NO-250 Artefact mechanics, through `--select` (a real tap):

| State | Flags after `--` |
|---|---|
| Magic bullet preview: the Rook's shot at the Knight through your own Pawn (linked dots through the blocker, red ring on the target) | `--scenario-name "NO-250: Magic bullet" --screenshot /tmp/cap/bullet --select 0,1` |
| Oligarch: the enemy Pawn's recon preview, with no capture on your Queen | `--scenario-name "NO-250: Oligarch" --screenshot /tmp/cap/oligarch --select 2,4` |
| Oligarch control: the same preview without the Artefact, with the capture shown | `--scenario-name "NO-250: Oligarch (control, no Artefact)" --screenshot /tmp/cap/oligarch-ctrl --select 2,4` |

Menu screens need no scenario and write `DIR/menu.png`. The run then boots a default game and also writes a `game.png`; ignore that file.

| Screen | Flags after `--` |
|---|---|
| Guide hub | `--screenshot /tmp/cap/guide --show-screen guide` |
| Guide sub-page | `--screenshot /tmp/cap/guide-rules --show-screen guide:rules` (pages: `rules`, `pieces`, `promotions`, `fusions`, `artefacts`, `items`, `indicators`) |
| Guide detail panel | `--screenshot /tmp/cap/guide-pieces-0 --show-screen guide:pieces:0` — the page with its slide-over detail open on row `<index>` (0-based, list order), settled. Pages with rows: `pieces`, `promotions`, `fusions`, `artefacts`, `items` |
| Guide list, scrolled to a row | `--screenshot /tmp/cap/guide-pieces-row --show-screen guide:pieces:row:25` — no detail panel, just the list scrolled so row `<index>` (0-based, list order) sits at the top (the default view only shows the top of the list) |
| Others | `tests`, `armies`, `rank`, `scores`, `history`, `about`, `settings`, `device-info`, `login` |

## Videos of the selling flows (`--ui-demo FLOW`)

`--ui-demo` boots "Capture: selling sandbox" by itself and plays one flow. It takes a step every 0.8 s, holds the end for 1.6 s, then quits. Each step triggers what a tap triggers: the HUD signal that a long press emits, then the modal's own button, which is focused briefly and then pressed. The video therefore shows the real preview and the real confirm. If a step can't find its button, the run prints `UI-DEMO FAIL` and exits 1.

Record with Movie Maker, windowed. The engine flags go before `--`:

```sh
tools/godot-lock.sh godot --path game --write-movie /tmp/cap/sell-stock.avi --fixed-fps 30 -- --ui-demo sell-stock
```

| Flow | Steps |
|---|---|
| `sell-stock` | Stock drawer → long-press Rook → preview → Sell → confirm |
| `convert` | Stock drawer → long-press Captured Bishop → Convert → long-press it in Stock → Sell → confirm |
| `sell-item` | Inventory drawer → long-press Blitz → preview (Use / Sell) → Sell → confirm |
| `sell-artefact` | Inventory drawer → long-press Jet Fuel Vial → preview → Sell → confirm |
| `box-sell` | small Item Box on a full inventory (at the Item cap) → Sell row → confirm → select an offer → Pick |

On Aux, record one at a time:

```sh
ssh aux 'cd ~/NO-KINGS && caffeinate -i tools/godot-lock.sh sh -c "git fetch --prune -q && git checkout --detach -q origin/<ref> && mkdir -p /tmp/cap && $HOME/bin/godot --path game --write-movie /tmp/cap/sell-stock.avi --fixed-fps 30 -- --ui-demo sell-stock"'
```

## NO-100 top 10 (`~/Documents/nokings-NO-100-review-candidates.md`)

| # | Surface | Flags after `--` |
|---|---|---|
| 1 | Game-over, loss | `--scenario-name "Loss: clock-out (10s)" --screenshot /tmp/cap/gameover --show-screen gameover` |
| 1 | Game-over, full clear (existing path, never verified) | `--scenario-name "Win screen: full clear @ wave 201 (capture Larry)" --screenshot /tmp/cap/fullclear --select "3,8;3,10"` |
| 2 | Win screen | `--scenario-name "Win screen: wave 50 (capture King)" --screenshot /tmp/cap/win --show-screen win` |
| 3 | SETUP placement zone | `--scenario-name "Movement & drag" --screenshot /tmp/cap/setup --show-screen setup` |
| 4 | Pause menu | `--scenario-name "Movement & drag" --screenshot /tmp/cap/pause --show-screen pause` |
| 5 | Kill feed | `--scenario-name "Movement & drag" --screenshot /tmp/cap/feed --show-screen feed` |
| 6 | Choice-pick modal | `--scenario-name "Capture: selling sandbox" --screenshot /tmp/cap/pick --show-screen pick` |
| 7 | Ad-retry prompt | `--scenario-name "Loss: clock-out (10s)" --screenshot /tmp/cap/retry --show-screen gameover-retry` |
| 7 | AD overlay | `--scenario-name "Movement & drag" --screenshot /tmp/cap/ad --show-screen ad` |
| 8 | Guide sub-pages | `--screenshot /tmp/cap/guide-<page> --show-screen guide:<page>` (menu.png) |
| 8 | Guide detail panel | `--screenshot /tmp/cap/guide-<page>-<index> --show-screen guide:<page>:<index>` (menu.png) |
| 9 | King Ability chip | `--scenario-name "Header: King Wave — Donald Trump, Tariffs in force" --screenshot /tmp/cap/kchip --show-screen board` |
| 9 | King Abilities overview | `--scenario-name "Header: King Wave — Donald Trump, Tariffs in force" --screenshot /tmp/cap/ka --show-screen king-abilities` |
| 10 | Stock drawer, one cell per piece (no stacks, no Promote badge) | `--scenario-name "Combo Army: Crown — free merges, Stock pieces onto board partners" --screenshot /tmp/cap/stock --open-drawer stock` |
| 10 | Stock return drop preview | `--scenario-name "Movement & drag" --screenshot /tmp/cap/return --show-screen stock-return` |
