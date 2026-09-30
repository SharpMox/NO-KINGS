/* Items + Piece Buffs catalog — the canonical source. tools/export-game-items.mjs
   writes game/data/items.json, which game/data/items.gd loads (moved out of
   items.gd's GDScript consts 2026-09-28, keys and values unchanged). Run
   `node tools/gen-all.mjs` after editing; CI fails if the JSON is stale.

   From the Notion GDD catalogs (STATUS triage synced 2026-07-14: only KEEP items
   ship; REWORK/REMOVE entries deleted — the Notion Items DB is the source of
   truth for their return). The Notion Items DB is the source of truth for names,
   tiers and effects — when it disagrees with this file, Notion wins and this
   file changes (user call 2026-08-27; last name+effect audit 2026-08-27, Blitz
   and Demote resynced).

   Item fields: key, name, tier, description, target, action_cost (default 1
     if omitted — the Actions it costs to USE the item itself; separate from
     whatever effect it grants on its target). target:
     "" (instant) · "tile" (pick one tile) · "pair" (pick a piece, then a
     destination) · "multi" · "area"

   `fires` / `suppresses` (issue 94) — the PRODUCER half of the hook graph.
   `ArtefactHooks.REGISTRY` records what each Artefact LISTENS to; these record
   what an Item or Piece Buff CAUSES, in the same 34-name vocabulary, so
   "using this reaches that Artefact" is answerable instead of remembered.
     fires      — hooks this effect makes fire. Every Item carries
                  on_item_consume (game.gd's _consume_item is the single choke
                  point every Item leaves through) plus whatever its own effect
                  reaches: Air Strike's _destroy, Promote's on_rank_up.
     suppresses — hooks this effect DENIES to everything listening on them.
                  Shield repels the capture attempt before the capture branch
                  is reached, so the 22 on_capture Artefacts see nothing.
   Every entry was traced to a real ArtefactHooks.run() call site, not inferred
   from the description text. NOTE (FLAGS): `suppresses` has no consumer yet and
   no test asserts it — a wrong entry there is invisible by construction.
   Two hooks can never appear here: `on_box_open` and `on_shop_restock` are
   declared in HOOKS but fired nowhere in game/scripts, and nothing listens on
   them either. Dead vocabulary, found while deriving this.

   Key order inside each entry is kept as it was in items.gd: the game's
   snapshot test (test_items.gd) compares var_to_str of the loaded catalog. */

var ITEMS = [
  { key: "blitz", name: "Blitz", tier: "Tactical", target: "tile", action_cost: 0,
    fires: ["on_item_consume"],
    description: "One of your pieces: its next move or capture this Turn is free, even if it already moved." },
  { key: "asset_recovery", name: "Asset Recovery", tier: "Tactical", target: "tile",
    fires: ["on_item_consume"],
    description: "Copy any piece on the board, ally or enemy, into your Stock." },
  { key: "demote", name: "Demote", tier: "Tactical", target: "tile",
    fires: ["on_item_consume", "on_demote", "on_piece_demoted"],
    description: "Turn any piece, ally or enemy, into the base piece of its chain." },
  { key: "promote", name: "Promote", tier: "Tactical", target: "tile",
    fires: ["on_item_consume", "on_rank_up"],
    description: "Promote one of your pieces to its next tier." },
  { key: "invert", name: "Inversion", tier: "Tactical", target: "tile",
    fires: ["on_item_consume"],
    description: "Turn any piece into its paired inverse (Bishop ↔ Rook, Pawn ↔ Void Pawn, …), either way." },
  { key: "extraction", name: "Extraction", tier: "Tactical", target: "multi",
    fires: ["on_item_consume"],
    description: "Return any number of your pieces from the board to your Stock." },
  { key: "tactical_reposition", name: "Tactical Reposition", tier: "Tactical", target: "pair",
    fires: ["on_item_consume"],
    description: "Move any piece, ally or enemy, 1 square to an empty tile." },
  { key: "air_strike", name: "Air Strike", tier: "Strategic", target: "tile",
    fires: ["on_item_consume", "on_destroy"],
    description: "Destroy an enemy piece. No Score or Gold. Not the King." },
  { key: "sniper", name: "Sniper", tier: "Strategic", target: "tile",
    fires: ["on_item_consume", "on_destroy"],
    description: "Destroy an enemy piece that one of your pieces could capture. No Score or Gold. Not the King." },
  { key: "radar_jamming", name: "Radar Jamming", tier: "Strategic", target: "tile",
    fires: ["on_item_consume", "on_buff_removal"],
    description: "Remove every Piece Buff and Debuff from a piece." },
  { key: "rapid_deployment", name: "Rapid Deployment", tier: "Strategic", target: "pair",
    fires: ["on_item_consume"],
    description: "Move one of your pieces to any Deploy tile." },
  { key: "decoy_swap", name: "Decoy Swap", tier: "Strategic", target: "pair",
    fires: ["on_item_consume"],
    description: "Swap any two pieces on the board, ally or enemy." },
  { key: "counter_intel", name: "Counter-Intel", tier: "Strategic", target: "",
    fires: ["on_item_consume"], suppresses: ["on_king_ability_apply", "on_king_ability_charge", "on_charge"],
    description: "Tariffs stop applying until the next Wave." },
  { key: "drone_strike", name: "Drone Strike", tier: "Decisive", target: "area",
    fires: ["on_item_consume", "on_destroy", "on_piece_lost"],
    description: "Destroy every piece, ally and enemy, in a 3x3 area. Not the King." },
  { key: "surprise_attack", name: "Surprise Attack", tier: "Decisive", target: "",
    fires: ["on_item_consume"], suppresses: ["on_enemy_turn_start"],
    description: "Take another turn right after this one. The enemy skips its turn." },
  { key: "buff_box", name: "Buff Box", tier: "Strategic", target: "tile",
    fires: ["on_item_consume", "on_buff_apply"],
    description: "Pick 1 of 3 random Piece Buffs, then apply it to any piece, ally or enemy." },
];

/* Piece Buffs — one-shot effects that ride on a single board piece, delivered
   by the Buff Box item (GDD Piece Buffs DB). Two models:
     dormant — sits on the piece until its trigger fires, then resolves and is
               consumed. No expiry: it can wait forever.
     timed   — activates on application and runs for a fixed window.
   "Reduced movement range" (Slow, Smog) means the piece moves and captures
   exactly like a Pawn — ruled 2026-08-28, see the Notion Piece Buffs pages.
   `turns` on a timed buff is its life in player turns. */
var PIECE_BUFFS = [
  { key: "shield", name: "Shield", tier: "Tactical", model: "dormant",
    fires: ["on_buff_consume"], suppresses: ["on_capture"],
    description: "Blocks the next capture attempt on this piece. Both pieces stay put." },
  { key: "critical", name: "Critical", tier: "Tactical", model: "dormant",
    fires: ["on_buff_consume"],
    description: "This piece's next capture scores double." },
  { key: "multicapture", name: "Multicapture", tier: "Strategic", model: "dormant",
    fires: ["on_buff_consume", "on_capture", "on_score_change", "on_gold_change"],
    description: "This piece's next capture also takes one enemy beside the captured piece." },
  { key: "taunt", name: "Taunt", tier: "Tactical", model: "dormant",
    fires: [],
    description: "Enemies that can capture this piece always take it first." },
  { key: "stun", name: "Stun", tier: "Tactical", model: "dormant",
    fires: [],
    description: "The piece that captures this one loses its next 2 turns." },
  { key: "bomb", name: "Bomb", tier: "Decisive", model: "dormant",
    fires: ["on_buff_consume", "on_destroy", "on_piece_lost"],
    description: "When this piece captures or is captured, it explodes: both pieces and everything within 1 square are destroyed." },
  { key: "trap", name: "Trap", tier: "Decisive", model: "dormant",
    fires: ["on_buff_consume", "on_piece_lost"],
    description: "When this piece is captured, the attacker is captured too." },
  { key: "range", name: "Range", tier: "Tactical", model: "dormant",
    fires: ["on_buff_consume"],
    description: "Until its next capture, this piece can also capture any enemy beside an enemy it could already take." },
  { key: "reflect", name: "Reflect", tier: "Decisive", model: "dormant",
    fires: ["on_buff_consume", "on_piece_lost"], suppresses: ["on_capture"],
    description: "Stops the next capture attempt, then captures the attacker and takes its tile." },
  { key: "slow", name: "Slow", tier: "Tactical", model: "timed", turns: 1,
    // A DEBUFF on its own holder (ruled 2026-08-28) — a RANDOM artefact grant
    // must never hand a piece this by accident (see artefact_hooks.gd's
    // _random_buff_key); the player's own Buff Box pick still offers it
    // (game.gd _open_buff_pick reads PIECE_BUFFS directly), since choosing Slow
    // deliberately (e.g. onto an enemy) is legitimate. Smog debuffs *adjacent
    // enemies*, not its holder, so it stays a genuine buff and carries no flag.
    self_harming: true,
    fires: [],
    description: "This piece moves and captures like a Pawn until the end of the next enemy turn." },
  { key: "aura", name: "Aura", tier: "Strategic", model: "timed", turns: 2,
    fires: [],
    description: "For 2 player turns, adjacent allies score double on their captures." },
  { key: "smog", name: "Smog", tier: "Strategic", model: "timed", turns: 2,
    fires: [],
    description: "For 2 player turns, adjacent enemies move and capture like a Pawn." },
  // Keyed "piece_bounty", NOT "bounty" — historically a legacy core Artefact
  // held that key. User ruling (issue 48, 2026-08-29): the Buff takes the NAME
  // "Bounty". Issue 69 removed that Artefact entirely; "piece_bounty" stays
  // as-is regardless, a rename now would be pure save-format churn.
  { key: "piece_bounty", name: "Bounty", tier: "Decisive", model: "dormant",
    fires: ["on_buff_consume"],
    description: "When this piece is captured, by either side, pick 1 of 3 random Boxes and open it." },
];

if (typeof module !== "undefined" && module.exports) module.exports = { ITEMS, PIECE_BUFFS };
