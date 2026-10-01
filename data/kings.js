/* The 16-King cast + Larry — the canonical source. tools/export-game-kings.mjs writes
   game/data/kings.json (ROSTER, LARRY, KITS), which game/data/kings.gd loads (moved out of
   kings.gd's GDScript consts 2026-09-29, keys and values unchanged). Selection, Powers and
   Abilities — all LOGIC — stay in kings.gd. Run `node tools/gen-all.mjs` after editing; CI
   fails if the JSON is stale.

   From the Notion GDD "Kings" page (fetched 2026-08-27), four per costume tier.

   NAMES (Max's ruling, 2026-09-27): `name` is the King's ONLY player-facing name,
   everywhere — game and site. The 16 are Demon Kings ("Demon King Trumpus"); Larry is
   "King of Tyrants Larry". The real figures each King is drawn from live in Notion only
   (Max, 2026-09-29: "keep real names in Notion as the inspiration, but remove all mentions
   outside Notion"). `id` is the Demon name in snake_case (Max, 2026-09-29: "migrate the
   keys"; save_config.gd's v3 -> v4 step moved saves off the old ids). Ids are saved and
   keyed on, so never rename one without a save migration. The game
   uppercases names at display (Kings.name_of); the data stays title case. */

/* ROSTER — keyed by costume tier, in kings.gd's TIER_ORDER (laurel, hat, uniform, suit).
   ONE costume tier per run (issue 89): a run rolls one tier at start and meets its four
   Kings in shuffled order at the waves in WAVES.kings. */
const ROSTER = {
  laurel: [
    { id: "nebuchadnezzebub", name: "Demon King Nebuchadnezzebub" },
    { id: "xerxius", name: "Demon King Xerxius" },
    { id: "qinshizuzu", name: "Demon King QinShiZuzu" },
    { id: "neroth", name: "Demon King Neroth" },
  ],
  hat: [
    { id: "khandrax", name: "Demon King Khandrax" },
    { id: "tamerzazel", name: "Demon King Tamerzazel" },
    { id: "ivanilith", name: "Demon King Ivanilith" },
    { id: "napolemon", name: "Demon King Napolemon" },
  ],
  uniform: [
    { id: "maoloch", name: "Demon King Maoloch" },
    { id: "stalinox", name: "Demon King Stalinox" },
    { id: "hitleroth", name: "Demon King Hitleroth" },
    { id: "tojodeus", name: "Demon King Tojodeus" },
  ],
  suit: [
    { id: "trumpus", name: "Demon King Trumpus" },
    { id: "netanhyael", name: "Demon King Netanhyael" },
    { id: "putinazar", name: "Demon King Putinazar" },
    { id: "kimmerius", name: "Demon King Kimmerius" },
  ],
};

/* LARRY — the 17th boss, at wave 201 (NO-7). DELIBERATELY OUTSIDE ROSTER: roll_run
   shuffles all four entries of the tier it draws, so a Larry inside it could turn up at
   wave 50. He is selected BY WAVE NUMBER, never by the tier draw. */
const LARRY = { id: "larry", name: "King of Tyrants Larry" };

/* Which wave each King fights at. NOT exported to the game — game/data/waves.gd is the
   source there (its "king" rows and LARRY_WAVE); tools/validate-data.mjs checks this
   against it. Kept here for the site. Wave 50 is the win condition; 51-200 are Endless,
   so Kings 2-4 are post-win content. */
const WAVES = { kings: [50, 100, 150, 200], larry: 201 };

/* KING KITS (issue 91) — one Power and one Ability each, mirroring the Army structure
   (user ruling, 2026-09-01: "32, a power and an ability for each king").
     POWER   — static, live for the WHOLE King wave (both segments, ruling 6).
     ABILITY — once per Wave, costs the King one of its Actions (ruling 4).
   The Notion GDD page still describes "2-3 King Abilities" each — an open question for
   Max rather than a bug: the shipped cast is 16 x (1 Power + 1 Ability).

   Fields: power_name, power_desc, and either power_key (a bespoke Power, dispatched in
   kings.gd's power_hook / branch reads) or power_catalog_escalation (King Ability keys,
   data/king_abilities.js); ability_name, ability_desc, and either ability_key (bespoke,
   kings.gd _bespoke_ability) or ability_catalog_key (a King Ability key).
   enters_at_start: optional, true skips the issue-90 segment (read by WaveLogic.queue). */
const KITS = {
  // ---- LAUREL (issue 92) --------------------------------------------------
  nebuchadnezzebub: {
    power_name: "The Babylonian Exile",
    power_desc: "Pieces you capture this wave never reach your Captured Stock.",
    power_key: "exile",
    ability_name: "The Dream of the Statue",
    ability_desc: "Your most valuable piece crumbles to its base form.",
    ability_key: "crumble",
  },
  xerxius: {
    power_name: "The Countless Host",
    power_desc: "The enemy takes 1 extra Action per turn this wave.",
    power_key: "host",
    ability_name: "Whip the Hellespont",
    ability_desc: "Pushes each of your pieces back one row, if the square behind it is free.",
    ability_key: "whip",
  },
  qinshizuzu: {
    power_name: "The Great Wall",
    power_desc: "Deploys cost double this wave.",
    power_key: "wall",
    ability_name: "The Terracotta Army",
    ability_desc: "3 more enemies arrive, copied from the wave's own pieces.",
    ability_key: "terracotta",
  },
  neroth: {
    power_name: "Rome Burns",
    power_desc: "Your $ gains are halved this wave.",
    power_key: "burns",
    ability_name: "The Fire of Rome",
    ability_desc: "Destroys every Item you hold.",
    ability_key: "fire",
  },

  // ---- HAT (issue 93) -----------------------------------------------------
  khandrax: {
    power_name: "No Fixed Cities",
    power_desc: "You cannot merge this wave.",
    power_key: "nomerge",
    ability_name: "The Silent Steppe",
    ability_desc: "Removes every Piece Buff from your pieces.",
    ability_key: "strip",
  },
  tamerzazel: {
    power_name: "Scorched Earth",
    power_desc: "Your Score gains are halved this wave.",
    power_key: "scorched",
    ability_name: "The Pyramid of Skulls",
    ability_desc: "Destroys your 2 least valuable pieces.",
    ability_key: "pyramid",
  },
  ivanilith: {
    power_name: "The Oprichnina",
    power_desc: "You cannot use Items this wave.",
    power_key: "noitems",
    ability_name: "Kill the Tsarevich",
    ability_desc: "A random piece of yours switches to the King's side.",
    ability_key: "turncoat",
  },
  napolemon: {
    power_name: "La Grande Armée",
    power_desc: "Enemies arriving this wave carry 1 extra Piece Buff.",
    power_key: "grande",
    ability_name: "Artillery Barrage",
    ability_desc: "Destroys all your pieces in the column holding the most of them.",
    ability_key: "barrage",
  },

  // ---- UNIFORM (issue 93) -------------------------------------------------
  maoloch: {
    power_name: "Backyard Furnaces",
    power_desc: "Pieces you deploy this wave arrive in their base form.",
    power_key: "furnaces",
    ability_name: "The Long March",
    ability_desc: "Every enemy piece but the King advances one row toward you, if the square is free.",
    ability_key: "longmarch",
  },
  stalinox: {
    power_name: "The Purge",
    power_desc: "You cannot apply Piece Buffs this wave.",
    power_key: "purge",
    ability_name: "Order No. 227",
    ability_desc: "Not one step back. Destroys your pieces on your back row.",
    ability_key: "order227",
  },
  hitleroth: {
    power_name: "Total War",
    power_desc: "Each piece you lose this wave costs $10.",
    power_key: "totalwar",
    ability_name: "Total Mobilisation",
    ability_desc: "The enemy takes 1 extra Action per turn for the rest of this wave.",
    ability_key: "mobilise",
  },
  tojodeus: {
    power_name: "Kamikaze",
    power_desc: "Each capture you make also destroys one of your pieces next to the capturing piece.",
    power_key: "kamikaze",
    ability_name: "Total Attrition",
    ability_desc: "Halves your remaining Clock.",
    ability_key: "attrition",
  },

  // ---- SUIT (ruled in slice 66 + the design session) ----------------------
  trumpus: {
    power_name: "Tariff",
    // "10" is Tuning.KING_TARIFF_STACK_TURNS, spelled out: test_kings.gd and
    // tools/validate-data.mjs both fail if the two disagree.
    power_desc: "Every 10 turns, another Tariff comes into force for the rest of this wave.",
    // ESCALATING (design 2026-09-09). Ordered by tier so the wave tightens rather than
    // opening at full strength: the six Mild Tariffs first, then the two Moderate ones.
    // Tariff on Gold Gain second (NO-95), so it lands at turn 10. Trumpus is the only King
    // whose Power is a catalog entry at all, so this field is his alone.
    power_catalog_escalation: ["move_cost", "inflation", "capture_cost", "pass_cost",
      "long_range_cost", "ability_cost", "deploy_cost", "fuse_cost"],
    ability_name: "Diplomatic Visit",
    ability_desc: "Destroys your most valuable piece.",
    ability_catalog_key: "diplomatic_visit",
    // NO-80 (user ruling 2026-09-13): he skips the issue-90 segment and is on the board
    // from turn 0 of his wave — his Tariffs charge from turn 0 and are read off his
    // piece's info panel, which needs him there. His alone.
    enters_at_start: true,
  },
  netanhyael: {
    power_name: "Iron Dome",
    power_desc: "The King cannot be captured while any other enemy piece stands.",
    power_key: "dome",
    ability_name: "Targeted Strike",
    ability_desc: "Destroys your piece closest to the King.",
    ability_key: "strike",
  },
  putinazar: {
    power_name: "Annexation",
    power_desc: "At the end of your turn, your pieces in the enemy half switch sides.",
    power_key: "annex",
    ability_name: "Disinformation",
    ability_desc: "Shuffles your pieces among the squares they stand on.",
    ability_key: "disinfo",
  },
  kimmerius: {
    power_name: "Juche",
    power_desc: "The Shop is closed this wave.",
    power_key: "juche",
    ability_name: "The Parade",
    ability_desc: "Destroys all your pieces in the 3x3 block holding the most of them.",
    ability_key: "parade",
  },
  // ---- LARRY, the 17th boss at wave 201 (NO-7) ----------------------------
  // Outside the 4x4 cast and outside ROSTER, but the KIT contract is the same.
  larry: {
    power_name: "Borrowed Time",
    power_desc: "Your Clock drains twice as fast this wave.",
    power_key: "borrowedtime",
    ability_name: "The Bill Comes Due",
    ability_desc: "Destroys your most valuable piece once per King you have defeated (up to 4).",
    ability_key: "bill",
  },
};

if (typeof module !== "undefined" && module.exports) module.exports = { ROSTER, LARRY, WAVES, KITS };
