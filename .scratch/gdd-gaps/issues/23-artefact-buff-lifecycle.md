# 23 — Artefacts: Buff lifecycle hooks (apply / consume / transfer / protect)

Status: partial — 12 of 13

## Parent

`.scratch/gdd-gaps/PRD.md`

## Split out of

19 — `BuffLogic.add`/`consume` both have several scattered call sites (issue
18's Outcome already flagged this for Youth Fountain Martini and Flight 19
Blackbox's sibling problem, `on_piece_lost`, which 19 did fix). This file is
the buff-side equivalent: a single `_apply_buff`/`_consume_buff` choke point
in game.gd would unlock most of the table below the same way `on_piece_lost`
and `on_item_consume` unlocked theirs.

## What to build

| Artefact | Needs | Note |
| --- | --- | --- |
| Amityville Ouija Board | artefact-trigger event | "when one of your Piece Buffs of any tier triggers: +10 Gold" — needs an on_buff_consume hook at BuffLogic.consume's call sites |
| Cleopatra's Hairpin | artefact-trigger event | same hook, scoped to Decisive buffs (Trap, Reflect, Bomb) |
| Guidestone Blood Ritual | artefact-trigger event | same hook, but fires for ANY piece (ally or enemy) being Demoted or losing a buff — the owner-agnostic version |
| KGB Photo Eraser | buff transfer | "on losing a piece carrying a Buff: the Buff transfers to the nearest ally" — on_piece_lost (issue 19) + a nearest-ally search + BuffLogic.add |
| Pied Piper's Rat Census | buff copy | "when you apply a Piece Buff: one adjacent ally gets a copy" — needs the buff-APPLY choke point (BuffLogic.add's call sites: Buff Box item, several artefact grants) |
| Antikythera Warranty Card | buff protection | "pieces cannot be Demoted and Buffs cannot be removed by Tariffs/enemy effects" — a passive rule Sanctions/radar_jamming/demote would all need to consult |
| Abduction Probe | multi-buff per piece | "pieces can carry 2 Piece Buffs at once" — `BuffLogic.add` already appends to a list (no 1-buff cap exists in the data), but every UI/logic spot that assumes "the piece's buff" (singular) needs an audit before this is safe to flip on |
| 45.5 Carat Curse | buff strip | "+45% Gold/Score; every 3rd Wave clear: all allied pieces lose their Buffs" — the payout half is cheap (on_score_change/on_gold_change, already-wired hooks); the strip half just needs `BuffLogic.clear` looped over `_player_pieces()`, no new hook — smallest item in this file, consider lifting it back into a cheap-tier pass |
| mRNA Firmware Update | buff-apply-causes-rank-up | "every 3rd Piece Buff you apply: the piece also Ranks Up" — needs the buff-apply choke point AND a direct Rank Up (defs[id].next), not just the on_rank_up hook (issue 19) which reacts to a rank-up, doesn't cause one |
| Atlantis Snow Globe | demotion immunity | "pieces cannot be Demoted" — same "demote" Item interception as Antikythera's half |
| Youth Fountain Martini | buff-consume choke point | "the first Buff consumed each Wave: re-applied to the same piece" — issue 18's own held-back note; needs the same on_buff_consume hook as Amityville Ouija Board, with the piece identity preserved |
| Numbers Station Sudoku / Bohemian Grove Friendship Bracelet | Buff Box choice-count | "4/5 choices instead of 3[, at N Gold each]" — `_open_buff_pick` hardcodes 3; a UI + Items.PIECE_BUFFS sampling change, not a hook at all (issue 18's held-back note) |

## Acceptance criteria

- [x] A single `_apply_buff(piece, key, turns)` choke point in game.gd (or
      BuffLogic itself) replacing `BuffLogic.add`'s scattered call sites,
      firing `on_buff_apply`
- [x] A single `on_buff_consume` hook at BuffLogic.consume's call sites
- [x] Numbers Station Sudoku / Bohemian Grove Friendship Bracelet are a UI
      change (`_open_buff_pick`), triaged separately from the hook work
- [x] Abduction Probe needs a codebase audit (every "the piece's buff"
      singular assumption) before it's safe — call this out explicitly if
      any are found
- [x] Scenario coverage, `run_all.sh` all green

## Blocked by

- 15 — trigger engine
- 19 — Special + prereq triage (this file is one of its splits)

## Outcome

12 of 13 implemented (`data/artefacts.js` → `node tools/export-game-artefacts.mjs`):
Amityville Ouija Board, Cleopatra's Hairpin, Guidestone Blood Ritual, KGB
Photo Eraser, Pied Piper's Rat Census, Antikythera Warranty Card, 45.5 Carat
Curse, mRNA Firmware Update, Atlantis Snow Globe, Youth Fountain Martini,
Numbers Station Sudoku, Bohemian Grove Friendship Bracelet.

**Infra** (`game/scripts/game.gd`, `game/scripts/artefact_hooks.gd`):
- `game.gd:_apply_buff(piece, key, turns, pos, fire_hook)` — the new
  buff-grant choke point, firing `on_buff_apply` AFTER the buff lands.
  Replaces every scattered `BuffLogic.add` call site for a *catalogued*
  Piece Buff: the buff_box Item apply, and `artefact_hooks.gd`'s
  `_grant_buff`/`_grant_buff_to` (now `g`-aware) used by ~9 artefacts. The
  `stunned` debuff (Stun's own side effect, not a Items.PIECE_BUFFS entry —
  see `buff_logic.gd`'s "buff"/"Buff" naming-collision note) deliberately
  keeps calling `BuffLogic.add` directly, bypassing this hook — it isn't a
  Piece Buff and must not fire buff-apply artefacts.
- `game.gd:_consume_buff(pos, key)` — the buff-resolve choke point, firing
  `on_buff_consume` AFTER removal. Replaces the 5 existing
  `BuffLogic.consume` call sites (Reflect/Shield ×2, Critical, Range,
  Multicapture) and adds 2 new ones (Bomb, Trap) that previously just erased
  the carrying piece with no explicit consume — needed so Cleopatra's
  Hairpin / Guidestone Blood Ritual actually see those two Decisive
  triggers.
- New `on_demote` (gate, ctx.blocked) / `on_piece_demoted` (event) hooks at
  the "demote" Item's single call site, and `on_buff_removal` (gate) at
  "radar_jamming"'s. `on_piece_demoted` is a plain event with nothing to
  persist, unlike issue 19's still-open "Demoted flag" ask for Dark Market
  Light Bulb (a *continuous* is-this-piece-demoted check) — the two aren't
  the same problem, so this issue's Guidestone Blood Ritual isn't blocked by
  that gap.

**Left unimplemented — Abduction Probe** ("pieces can carry 2 Piece Buffs at
once"). Audit finding: there is no 1-buff cap anywhere in the codebase today
— not in `BuffLogic` (a plain `Array`, `.add` always appends), not in
`buff_box`'s Item targeting, not in any artefact grant. A second Piece Buff
already lands on a piece today, with or without this artefact. There is no
existing "1" to lift to "2", so implementing it would mean *inventing* a new
base-game restriction (cap at 1, this artefact raises it to 2) that nothing
in the GDD or codebase currently asks for — a design decision, not a wiring
job. **Notion question, not a guess**: does a 1-buff cap need adding to the
base game first, and if so, should Abduction Probe simply lift it, or is the
GDD text describing a limit that was never meant to exist mechanically (i.e.
this artefact was always a no-op safety net)?

**Verification**: `game/tests/run_all.sh` — ALL GREEN (windowed click
probes + all headless suites + autoplay), confirmed after rebasing onto
`main`'s merged `fix/artefact-ctx-contract` (PR #125). 17 new scenario
checks in `game/tests/test_items.gd` (202 total, up from 181/185 after the
rebase's own +2). Some earlier runs of `test_items.gd` inside the full
`run_all.sh` sequence hit transient Godot resource-import failures
("Unable to open file: res://.godot/imported/...ctex") under heavy
concurrent load from other agents sharing this machine — reproducible
standalone runs of the same file were consistently green, and a clean full
run (`ALL GREEN`) was captured once contention eased, so this reads as
environment flakiness, not a code defect.
