# 23 — Artefacts: Buff lifecycle hooks (apply / consume / transfer / protect)

Status: todo

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

- [ ] A single `_apply_buff(piece, key, turns)` choke point in game.gd (or
      BuffLogic itself) replacing `BuffLogic.add`'s scattered call sites,
      firing `on_buff_apply`
- [ ] A single `on_buff_consume` hook at BuffLogic.consume's call sites
- [ ] Numbers Station Sudoku / Bohemian Grove Friendship Bracelet are a UI
      change (`_open_buff_pick`), triaged separately from the hook work
- [ ] Abduction Probe needs a codebase audit (every "the piece's buff"
      singular assumption) before it's safe — call this out explicitly if
      any are found
- [ ] Scenario coverage, `run_all.sh` all green

## Blocked by

- 15 — trigger engine
- 19 — Special + prereq triage (this file is one of its splits)
