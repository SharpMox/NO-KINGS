## Run-state serialization: the config Dictionary a save restores from and a
## scenario boots from — over the live game node `g` (split out of game.gd;
## the shape is documented in data/scenarios.gd).
##
## SCHEMA VERSIONING (issue 38). Every save carries `save_version`; a save
## without one is version 0, which is every save written before 2026-08-28.
##
## The policy, so the next field does not need this reasoned out again:
##
##   ADDITIVE — a new field with a sensible default. Read it with
##   `cfg.get("field", default)` and DO NOT bump the version. Old saves keep
##   loading because the default is correct for them. Almost every field this
##   file has gained works this way (seed, rank, turn_number, per-artefact
##   acquired_wave/rarity, the per-piece capture ledger).
##
##   MIGRATING — a field whose MEANING or SHAPE changed, so an old value would
##   be silently misread. That needs a bump plus an entry in `_MIGRATIONS`,
##   because a default cannot repair it. The table's first entry (1 -> 2,
##   issue 69) is exactly this: removing the 7 game-native core Artefacts
##   (first_capture_extra/greed/move/lifesteal/score/timer/bounty) is NOT
##   additive — a v1 save can hold copies of those keys in `artefacts`, which
##   would load as held effects with no REGISTRY/dispatch entry: inert
##   entries silently occupying Artefact-cap slots (base 5, see
##   artefact_hooks.gd's cap()). A default can't repair that; the entries
##   have to be filtered out.
##
## The distinction matters: an additive field that is read with a default is
## safe forever, but a reshaped field read with a default is a silent
## corruption. If unsure which you have, it is migrating.

const Tuning := preload("res://scripts/tuning.gd")
const Waves := preload("res://data/waves.gd")
const Items := preload("res://data/items.gd")
const Economy := preload("res://scripts/economy.gd")
const ArtefactHooks := preload("res://scripts/artefact_hooks.gd")
## issue 83: every save carries the account that owns it. Additive — a save
## written before this has no `owner`, reads back as "", and needs no migration.
const Account := preload("res://scripts/account.gd")


## Bumped ONLY for a migrating change (see the header). Additive fields do not
## bump it.
const SAVE_VERSION := 2

## issue 69: the 7 game-native core Artefacts, removed — see items.gd's
## header (the old ARTEFACT_EFFECTS_CORE) and .scratch/gdd-gaps/issues/69.
const _REMOVED_ARTEFACT_KEYS_69 := [
	"first_capture_extra", "greed", "move", "lifesteal", "score", "timer", "bounty",
]

## 1 -> 2 (issue 69): drop any held copy of a removed core Artefact key from
## `artefacts`, and clear `ecdysis_copy_key` if it names one — an un-migrated
## save would otherwise load the removed key as a held effect with no
## REGISTRY/dispatch entry (inert, but still occupying an Artefact-cap slot),
## or have Ecdysis Sheddings mirror a key nothing dispatches. Handles both
## `artefacts` entry shapes apply() already reads (a bare key String, or a
## `{key, acquired_wave, rarity}` Dictionary).
static func _migrate_1_to_2(cfg: Dictionary) -> Dictionary:
	var kept := []
	for entry in cfg.get("artefacts", []):
		var key: String = entry if entry is String else str(entry.key)
		if not _REMOVED_ARTEFACT_KEYS_69.has(key):
			kept.append(entry)
	cfg.artefacts = kept
	if _REMOVED_ARTEFACT_KEYS_69.has(str(cfg.get("ecdysis_copy_key", ""))):
		cfg.ecdysis_copy_key = ""
	return cfg


## Walk a loaded config up to SAVE_VERSION, one version at a time. A config
## with no `save_version` is version 0 — every save written before the field
## existed. Each step that reshapes something gets its own `match` case here;
## a version with nothing to reshape just falls through untouched.
static func migrate(cfg: Dictionary) -> Dictionary:
	var v: int = int(cfg.get("save_version", 0))
	while v < SAVE_VERSION:
		match v:
			1: cfg = _migrate_1_to_2(cfg)
		v += 1
	# Only claim the current version when we actually walked up to it. A save
	# from a NEWER build falls straight through the loop above, and stamping it
	# as current would relabel a version we cannot read as one we can — losing
	# the only evidence that it is unreadable. Callers refuse it via
	# is_loadable(); this makes a stray one fail honestly rather than silently.
	if v <= SAVE_VERSION:
		cfg["save_version"] = SAVE_VERSION
	return cfg


## True when THIS build can load `cfg` at all.
##
## Two ways a save arrives unloadable, and cloud sync (issue 86) is what made
## the second one reachable — before it, saves never crossed devices:
##
##   * corrupt or truncated, so JSON.parse_string returned null;
##   * written by a NEWER build, carrying a save_version this one has no
##     migration for. migrate() only walks versions UP.
##
## Callers check this BEFORE offering to continue a run. A save that fails here
## is left untouched on disk rather than deleted: the build that wrote it can
## still read it, and deleting another version's progress to tidy up our own
## menu would be the worst possible answer.
static func is_loadable(cfg: Variant) -> bool:
	return cfg is Dictionary and int(cfg.get("save_version", 0)) <= SAVE_VERSION


## Start the game from a config Dictionary instead of the normal SETUP flow.
## Every field of run state is settable — the same mechanism a saved game
## will restore from.
static func apply(g, cfg: Dictionary) -> void:
	cfg = migrate(cfg)
	g.stock = cfg.get("stock", []).duplicate()
	g.captured = cfg.get("captured", []).duplicate()
	g.score = int(cfg.get("score", 0)) # int(): JSON numbers arrive as floats
	g.gold = int(cfg.get("gold", 0))
	g.score_gained_total = int(cfg.get("score_gained_total", 0)) # issue 49,
		# Loch Ness Stool Sample — additive, defaults to 0 for any older save
	g.run_capture_count = int(cfg.get("run_capture_count", 0)) # issue 55, Zeta
		# Reticuli Souvenir Map — run-long, so it MUST survive a resume or the
		# "every 3rd Capture" cadence silently restarts at 0 on load. Same shape
		# and reasoning as turn_number (35) and score_gained_total (49);
		# additive, so no migration.
	g.shop_stock = cfg.get("shop_stock", []).duplicate(true)
	g.shop_restocks = int(cfg.get("shop_restocks", 0)) # no reroll-scumming
	g.shop_lane_b_progress = int(cfg.get("shop_lane_b_progress", 0)) # issue 64:
		# Score banked toward the next Lane-B restock — run-long and
		# resettable (Shop.lane_a_restock), so it MUST survive a resume the
		# same way run_capture_count (55) and score_gained_total (49) do, or a
		# resumed run silently loses progress toward its next restock.
		# Additive: a save from before this field existed has no restock
		# progress banked either, so 0 is the correct default, not a guess.
	# GDD Game Flow — Run: restore the run's RNG so a resumed save rolls what an
	# uninterrupted run would have. Seed first — assigning it resets the state.
	# Both travel as strings: they are int64 and JSON numbers are doubles.
	if cfg.has("seed"):
		g.rng.seed = int(cfg.seed)
	if cfg.has("rng_state"): # mid-stream, not back at the top of it
		g.rng.state = int(cfg.rng_state)
	# default: all designed waves done, so nothing spawns into the sandbox
	g.wave = int(cfg.get("wave", Waves.WAVES.size()))
	g.turns_since_wave = int(cfg.get("turns_since_wave", 0))
	g.early_clear_awarded = bool(cfg.get("early_clear_awarded", false))
	g.pending_reinforce = bool(cfg.get("pending_reinforce", false))
	g.pending_shop_open = bool(cfg.get("pending_shop_open", false)) # issue 101:
		# additive — a save from before this field existed had no queued Shop
		# open either, so false is the correct default, not a guess
	g.kings_defeated = int(cfg.get("kings_defeated", 0))
	g.king_ids_defeated = cfg.get("king_ids_defeated", []).duplicate()
	# issue 89: additive. A pre-89 save has no line-up and gets an empty one;
	# Kings.select() rolls a fresh line-up in that case rather than leaving a
	# King wave with no King, which would be a softlock and not a cosmetic gap.
	g.king_tier = str(cfg.get("king_tier", ""))
	g.king_order = cfg.get("king_order", []).duplicate()
	# issue 90: a save taken mid-segment-1 must still produce its King. Additive
	# — a pre-90 save has none, and a King wave restored without one would be
	# unwinnable rather than merely different.
	g.pending_king = cfg.get("pending_king", {}).duplicate()
	g.king_ability_used_this_wave = bool(cfg.get("king_ability_used_this_wave", false))
	g.king_power_tariff = str(cfg.get("king_power_tariff", "")) # issue 91
	g.king_power_id = str(cfg.get("king_power_id", "")) # issue 92
	g.next_army = str(cfg.get("army", g.next_army)) # milestone drip draws from it
	# issue 76: the SAVE KEY stays "family_ability_used_this_wave" while the
	# in-memory symbol became army_*. Renaming a persisted key is not additive
	# and would need a migration; SAVE_VERSION 2's first entry was just spent
	# on issue 69's real removal, and a cosmetic rename does not earn a second.
	g.army_ability_used_this_wave = bool(cfg.get("family_ability_used_this_wave", false))
		# issue 67: additive — an old save predates the Army Ability, so
		# "not used yet" is the correct default, not a guess (same shape
		# every other *_used_this_wave field would need if it were persisted)
	# "rank" key kept for save compat (07-difficulty-ranks rework: 3 named
	# ranks -> 5 numbered tiers). An old save's rank name ("Citizen" etc.) or
	# any other unrecognized value falls back to Tier 1 baseline everywhere
	# Tuning reads next_tier (tier_index() returns 0 for an unknown string).
	g.next_tier = str(cfg.get("rank", g.next_tier)) # locked at run start, Continue keeps it
	# issue 78: the Clock fallback follows the tier, so a config with no clock_s
	# still gets its tier's start (15 min, or 5 at Tier 3+). MUST come after
	# next_tier is resolved just above — reading it earlier silently gave every
	# config Tier 1's 15 minutes.
	g.clock_ms = cfg.get("clock_s", Tuning.clock_start_ms(g.next_tier) / 1000.0) * 1000.0
	g.lost_player = int(cfg.get("lost_player", 0))
	g.lost_enemy = int(cfg.get("lost_enemy", 0))
	g.pending_spawn = cfg.get("pending", []).duplicate(true)
	for p in cfg.get("board", []):
		var piece := {"id": p[0], "owner": int(p[1])}
		# slot 4 is the piece's non-positional state. Legacy saves and the
		# scenario table write the bare string "buff" (box carrier); anything
		# richer — piece buffs — travels as a Dictionary merged in whole.
		if p.size() > 4:
			if typeof(p[4]) == TYPE_STRING:
				piece.buff = true
			elif typeof(p[4]) == TYPE_DICTIONARY:
				piece.merge(p[4], true)
		g.board[Vector2i(int(p[2]), int(p[3]))] = piece
	for key in cfg.get("items", []):
		for it in Items.ITEMS:
			if it.key == key:
				g.items.append(it)
	for entry in cfg.get("artefacts", []):
		# Two shapes: a bare key String (every scenario config, data/scenarios.gd,
		# and the balance-sweep --artefacts flag — "acquired this boot", so it
		# stamps g.wave, already set above) or a {key, acquired_wave, rarity}
		# Dictionary (a real save round-tripping to_config()'s own output
		# below) — the per-artefact "5-Wave Milestone" cadence (ruled
		# 2026-08-28, artefact_hooks.gd's _milestone5_hit) needs the wave each
		# held copy was actually acquired on, not just g.wave at load time.
		var key: String = entry if entry is String else str(entry.key)
		var acquired: int = g.wave if entry is String else int(entry.get("acquired_wave", g.wave))
		# `rarity` (issue 29): a bare-key entry never carried one, and a save
		# written before this field existed doesn't either — both fall back
		# to a fresh catalog lookup (ArtefactHooks.rarity_of).
		var rarity: String = str(entry.rarity) if entry is Dictionary and entry.has("rarity") \
			else ArtefactHooks.rarity_of(key)
		for t in Items.ARTEFACT_EFFECTS:
			if t.key == key:
				var inst: Dictionary = t.duplicate() # never mutate the shared
					# catalog entry (Items.ARTEFACT_EFFECTS is one Array of
					# Dictionaries reused by every lookup) with a per-copy stamp
				inst.acquired_wave = acquired
				inst.rarity = rarity
				g.artefacts.append(inst)
	for key in cfg.get("tariffs", []) + cfg.get("oneoffs", []):
		Economy.activate_tariff_by_key(g, key)
	if cfg.has("sanctioned_id"): # a save must restore the exact barred type
		g.sanctioned_id = cfg.sanctioned_id
	if cfg.has("tariffs_seen"): # activation above re-logged; restore the truth
		g.tariffs_seen = cfg.tariffs_seen.duplicate()
	g.tariffs_suppressed = cfg.get("tariffs_off", false)
	g._begin_player_turn()
	# item-effect counters restore AFTER the turn reset (a save is always taken
	# at a turn start, so move/place/merge budgets are simply fresh)
	g.skip_enemy_turns = int(cfg.get("skip_enemy_turns", 0))
	# turn_number (issue 35): _begin_player_turn's own += 1 just above doesn't
	# know this call is a resume, not a fresh Turn — override with the saved
	# value (falling back to whatever it just computed, for older configs/
	# scenarios written before this field existed) so a resumed save doesn't
	# double-count the Turn it was saved on.
	g.turn_number = int(cfg.get("turn_number", g.turn_number))
	g.ecdysis_copy_key = str(cfg.get("ecdysis_copy_key", "")) # issue 55, additive


## The inverse of apply(): the live run as a JSON-safe config Dictionary.
static func to_config(g) -> Dictionary:
	var b := []
	for pos in g.board:
		var row := [g.board[pos].id, g.board[pos].owner, pos.x, pos.y]
		var extra: Dictionary = g.board[pos].duplicate(true)
		extra.erase("id")
		extra.erase("owner")
		if not extra.is_empty(): # box-carrier flag and/or piece buffs
			row.append(extra)
		b.append(row)
	var keys_of := func(arr: Array) -> Array:
		var out := []
		for e in arr:
			out.append(e.key)
		return out
	var artefacts_out := []
	for t in g.artefacts: # {key, acquired_wave, rarity} per copy — apply()'s
		artefacts_out.append({"key": t.key, "acquired_wave": int(t.get("acquired_wave", g.wave)),
			"rarity": str(t.get("rarity", ArtefactHooks.rarity_of(t.key)))}) # shape, so a
			# reloaded save keeps each held copy's own "5-Wave Milestone" cadence
			# and rarity (issue 29) — the catalog fallback covers an in-memory
			# entry that predates the stamp, same as apply()'s own fallback
	return Account.stamp({
		"save_version": SAVE_VERSION,
		"board": b, "stock": g.stock.duplicate(), "captured": g.captured.duplicate(),
		"items": keys_of.call(g.items), "artefacts": artefacts_out,
		"tariffs": keys_of.call(g.tariffs_active), "tariffs_seen": g.tariffs_seen.duplicate(),
		"wave": g.wave, "turns_since_wave": g.turns_since_wave, "turn_number": g.turn_number,
		"early_clear_awarded": g.early_clear_awarded,
		"pending_reinforce": g.pending_reinforce,
		"pending_shop_open": g.pending_shop_open, # issue 101
		"kings_defeated": g.kings_defeated, "king_ids_defeated": g.king_ids_defeated.duplicate(),
		"king_tier": g.king_tier, "king_order": g.king_order.duplicate(), # issue 89
		"pending_king": g.pending_king.duplicate(), # issue 90
		"king_ability_used_this_wave": g.king_ability_used_this_wave, # issue 91
		"king_power_tariff": g.king_power_tariff,
		"king_power_id": g.king_power_id, # issue 92
		"army": g.next_army, "rank": g.next_tier,
		"family_ability_used_this_wave": g.army_ability_used_this_wave, # key kept — see load
		"lost_player": g.lost_player, "lost_enemy": g.lost_enemy,
		"pending": g.pending_spawn.duplicate(true),
		"score": g.score, "gold": g.gold, "score_gained_total": g.score_gained_total,
		"run_capture_count": g.run_capture_count, # issue 55, Zeta Reticuli
		"clock_s": g.clock_ms / 1000.0,
		"shop_stock": g.shop_stock.duplicate(true),
		"shop_restocks": g.shop_restocks,
		"shop_lane_b_progress": g.shop_lane_b_progress, # issue 64: must round-trip
			# with the save or the resumed run's Lane-B progress bar silently
			# restarts at 0 (issue 55's shipped bug, same class)
		"sanctioned_id": g.sanctioned_id,
		"skip_enemy_turns": g.skip_enemy_turns,
		"tariffs_off": g.tariffs_suppressed,
		"seed": str(g.rng.seed), "rng_state": str(g.rng.state),
		"ecdysis_copy_key": g.ecdysis_copy_key,
	})
