/* Artefacts catalog — canonical mirror of the Notion Artefacts DB; last verified in lockstep 2026-08-21
   (BASIC/REWORK redesign session applied: 19 new effects, 4 tweaks, 2 KEEP edits — all 180 KEEP;
   2026-08-23 rework: 24 renames + 3 conspiracy swaps, effects unchanged;
   2026-08-24: 4 effect reassignments among 9 artefacts, rarity follows effect;
   rarity rebalance pass 1+2: 8 Uncommon->Common, 21 Rare->Uncommon => 50/54/50/26;
   2026-08-28 (issue 16): 31 Gold/Score artefacts with no needs-note flipped to
   implemented: true, wired into game/scripts/artefact_hooks.gd; Social Credit
   Report Card re-texted, its -10 Score penalty now debits Gold (up-only Score);
   2026-08-28 (issue 17): 8 Action/Time/Piece artefacts with no needs-note
   flipped to implemented: true, same wiring);
   2026-08-28 (issue 18): 20 Shop/Item/Buff artefacts flipped to implemented: true —
   Chocolate Key Cake/Alleged Weather Balloon/Sub-Antarctic Visa's "(needs: shop
   layout change)" notes cleared now that shop.gd's base+modifiers slot pass and
   price-modifier seam exist.
   2026-08-28 (issue 19): 29 Special-tagged / (needs: ...)-flagged / issue
   16-18-held-back artefacts flipped to implemented: true, on 4 new hooks
   (on_piece_lost, on_item_consume, on_rank_up, on_tariff_apply/charge) plus
   direct ItemLogic.chain_base reads for "Ranked" — see game/scripts/
   artefact_hooks.gd's header and .scratch/gdd-gaps/issues/19's Outcome for
   the full triage of what shipped, what split into new issues, and what's
   still an open Notion question (Dark Market Light Bulb's "Demoted" clause,
   the retired "Shop visit" term on 2 still-unimplemented artefacts).
   2026-08-28 (issue 22): 4 tariff-interception artefacts flipped to
   implemented: true (Panama Papers Shredder, Amber Room Bubble Wrap, Ark
   Grounding Cable, Salvation Gift Card) on the filter/scale/cancel shapes
   added to on_charge/on_gold_gain/on_tariff_apply. Exhibit 399 (tariff
   choice) and SETI's Red Marker (tariff inversion) stay unimplemented —
   both need a design ruling first, see game/scripts/artefact_hooks.gd's
   header and .scratch/gdd-gaps/issues/22's Outcome.
   2026-08-28 (issue 30): Elvish Hard Hat flipped to implemented: true (the
   new per-turn action log + on_action hook, game/scripts/artefact_hooks.gd).
   Black Knight Morse Code stays unimplemented — its own catalog text needs a
   Turn counter and a Clock-gain hook, neither of which the action log
   provides; see artefact_hooks.gd's issue 30 header note.
   2026-08-28 (issue 26): 15 economy/Shop/Box grab-bag artefacts flipped to
   implemented: true (spawn roster modifiers, a Shop purchase counter +
   forced-free override, deploy-cost/placement rules, a Gold-floor + a
   reaching-exactly-0 hook, per-Wave first/last-lost tracking, a Score-gain
   streak, a milestone Box grant) — see .scratch/gdd-gaps/issues/26's Outcome
   for the full triage of what shipped and what stayed a Notion question
   (item cap's baseline size, "Shop visit" still retired, "Piece Box" not a
   real Box kind, Zeta Reticuli's multi-site capture redirect, every artefact
   needing brand-new player-facing UI). 27 Club Punch Card's -50 Score penalty
   re-texted to Gold, same issue-16 ruling as Social Credit Report Card.
   2026-08-28 (issue 31): 3 capture-context artefacts flipped to
   implemented: true (Curtain Rods Bag, Templar Debit Card, $2.3 Trillion
   Receipt) — see game/scripts/artefact_hooks.gd's header and
   .scratch/gdd-gaps/issues/31's Outcome. Dark Market Light Bulb stays
   unimplemented: its "Demoted" clause is undefined, a Notion question, not
   a guess.
   2026-08-28 (issue 35): Black Knight Morse Code flipped to implemented: true
   and its "(needs: turn counter)" note cleared — a Clock-gain choke point
   (Economy.add_clock/on_clock_change) and a run-long Turn counter
   (g.turn_number) now exist, so it's an ordinary two-hook artefact; see
   game/scripts/artefact_hooks.gd's header.
   2026-08-29 (issue 42): Dark Market Light Bulb flipped to implemented: true
   — "Demoted" ruled currently-below-peak-rank (option b, clears on
   re-promotion), backed by a new per-piece peak_ranked stamp; see
   game/scripts/artefact_hooks.gd's header. The 3 Tactical-restricted random-
   buff granters (MK-Ultra Sugar Cube, Obedience-Flavored Tap Water, Sleeper
   Agent Pillow) were considered for widening to the full Piece Buff pool and
   left Tactical-only — all 3 are Common/Uncommon rarity on high-frequency
   triggers (every Deploy, once per Wave, every Shop piece-buy), and a
   Decisive buff (Bomb/Trap/Reflect) that often would be a much bigger power
   swing than their catalog text asks for; see artefact_hooks.gd's own
   comments at those 3 call sites and .scratch/gdd-gaps/issues/42's Outcome.
   2026-08-29 (issue 54): 5 of the 6 remaining artefacts flipped to
   implemented: true. UAP Breath Mint / Inflatable Vietcong Torpedo both
   auto-resolve (user ruling: no targeting step, no Gold prompt) and extend
   BuffLogic's existing repel path in game.gd's _run_enemy_actions. Hellfire
   Club Discord Invite gates game.gd's _on_pass with a "no legal Action"
   escape hatch (Rules.legal_moves/_deploy_tiles/_has_usable_item) so the new
   Pass restriction can never softlock a Turn. Pegasus Free Trial was
   reworked by the user away from its old "move twice" text (which would
   have redefined moved_this_turn, the field Blitz depends on) to "first
   move/capture each Turn is free", reusing Blitz's own blitz_free_move flag
   per end-of-chain piece instead. Exhibit 399 is wired (economy.gd's
   apply_tariff now defers to game.gd's _open_choice_pick, issue 41's seam)
   but dormant — Tuning.TARIFFS_SCHEDULED is false (2026-08-29), so it is
   never exercised in a live run, only driven directly in
   game/tests/test_items_tariffs.gd. SETI's Red Marker stays unimplemented:
   "inverted into its equivalent bonus" needs a per-Tariff bonus table that
   doesn't exist in data/tariffs.gd (issue 22 already flagged this exact gap
   and declined to guess one; issue 54 didn't supply one either) — a Notion
   question, not attempted.
   2026-08-30 (issue 55): Zeta Reticuli Souvenir Map, Troll Farm Employee of
   the Month, and Ecdysis Sheddings flipped to implemented: true — a run-long
   capture counter (game.gd's run_capture_count) plus a Stock-conversion
   OUTPUT flag on on_capture (ADR-0002: the piece's state rides along, same as
   Extraction) for Zeta; a straight-to-_dispatch re-trigger of every held
   on_wave_clear Artefact from on_wave_spawn for Troll Farm; and a
   last-Artefact-bought record (g.ecdysis_copy_key, purchases only) mirrored
   as an unregistered second copy of that key's dispatch for Ecdysis — see
   game/scripts/artefact_hooks.gd's header for the full rationale of all
   three, including the two-Ecdysis and Ecdysis+Troll-Farm non-recursion
   arguments. This was issue 55's entire scope (the last 3 named in its own
   text); the other still-`implemented: false` entries in this file at the
   time of this change (Jet Fuel Vial, Oak Island Wishing Well, Roanoke Hex
   Kit, SETI's Red Marker, Moscovium Glow Stick, FIFA Complimentary Yacht,
   Zapruder's Director's Cut, Bovine Tractor Beam) belong to other,
   independently in-flight issues, not this one.
   2026-08-30 (issue 52): the last 7 flipped to implemented: true — the game's
   first player-triggered ("on use"/"you may pay") Artefacts, needing a new
   activation affordance (game/scripts/game.gd: the Artefact strip's Activate
   section, the Items-menu section it doubles as, and — Jet Fuel Vial only —
   a Restock button in the Shop). Deliberately NOT routed through
   artefact_hooks.gd's REGISTRY/run() engine, which dispatches automatically
   to every HELD copy on a hook; activation is "the player picks WHEN, for
   one use," a different shape — see game.gd's own activation block for the
   full design. Jet Fuel Vial re-texted per user ruling 2026-08-29 (the old
   text's "bring the Shop's whole stock down; it is rebuilt fresh" is just
   "restock the Shop"); "Shop visit" resolves to the existing _open_shop()
   boundary issue 45 already established for Pandemic Toilet Paper Pallet.
   Zapruder's Director's Cut's "repeat your previous Action" is scoped to
   exactly what action_log's `{kind}` (issue 30) plus a new `{from, to}` on
   the plain move/capture call site can support: the SAME piece repeating
   the SAME displacement from its new position, replayed through
   _move_player itself (bomb/trap/blocked-attack captures, Deploys, Merges
   and Items carry no replay data and so are correctly reported
   unavailable, not half-replayed) — see game.gd's _can_repeat_last_action.
   Moscovium Glow Stick's triple multiplier is the deliberate multiplicative
   exception artefact_hooks.gd's header requires being called out — applied
   directly in Economy.earn() off a standing `g.moscovium_active` flag rather
   than the REGISTRY (the effect must keep working after the artefact
   consumes itself and leaves g.artefacts, so there is no "held copy" left
   for run() to dispatch from). Verified safe with Ecdysis Sheddings (issue
   55): Moscovium has no REGISTRY entry, so Ecdysis's meta-trigger copy of it
   is an inert no-op (REGISTRY.get("moscovium-glow-stick", []) is empty) —
   no crash, no double-consume, tested in test_items_artefacts_4.gd.
   2026-08-30 (issue 56): the catalog closes at 180/180. Both re-texted, user
   redesigns: SETI's Red Marker's "one random active Tariff is inverted into
   its equivalent bonus" (unimplementable — no Tariff has a defined inverse)
   is now "remove a random active Tariff (if any), and open a Big Artefact
   Box" — the Box always opens, since TARIFFS_SCHEDULED is false and no
   Tariff is ever active in a live run today; gating the Box on the removal
   would leave this Artefact dead on arrival all over again. Zapruder's
   Director's Cut's move/capture replay (issue 52) is unchanged; the redesign
   ADDS a resource-return for the 3 kinds a replay can't express (Item use,
   Deploy, Merge — the last returning BOTH consumed pieces, user ruling),
   instead of leaving the card dead after any of them — see
   game/scripts/artefact_hooks.gd's header for the full mechanism.
   2026-08-30 (issue 61): Jet Fuel Vial and Pandemic Toilet Paper Pallet
   both re-texted off the "Shop visit" boundary onto per-Wave — the Shop
   panel can be closed and reopened at will, so "Once per Shop visit" was
   never a real limit (Jet Fuel Vial's restock was free to spam for
   unlimited reroll-scumming, defeating shop.gd's own documented intent on
   shop_restocks). User ruling: both move to the same per-Wave boundary
   already established elsewhere (Hoffa's Cement Shoes, UAP Breath Mint,
   Inflatable Vietcong Torpedo, Bovine Tractor Beam, Zapruder's Director's
   Cut) rather than tying the flag to the actual stock roll, which would
   have Jet Fuel Vial's own restock reset its own flag. The Pallet's count
   now persists across a Shop close/reopen within a Wave — a small buff, not
   just a fix, since progress toward the discount is no longer silently
   discarded. See game/scripts/game.gd/artefact_hooks.gd/wave_logic.gd.
   180 effects. Each entry: { name, rarity, type, bonus[], status, effect, conspiracy,
   url, summary, implemented? (default false; see tools/export-game-artefacts.mjs) }.
   2026-10-14 artefact rework: catalog cut to 90, effects reassigned (see .notes). */

var ARTEFACTS = [
  // ── Common ──────────────────────────────────────────────────────
  { name: "Arms Fair Goodie Bag", key: "arms-fair-goodie-bag", rarity: "Common", type: "Passive", bonus: ["Gold"], status: "KEEP", implemented: true,
    effect: "Waves spawn +1 enemy piece; Captures pay +25% $.",
    conspiracy: "War profiteering", url: "https://en.wikipedia.org/wiki/War_profiteering",
    summary: "Every war has a gift shop. The defense-expo goodie bag — lanyard, brochure, missile-shaped USB stick — is the cheerful face of the oldest accusation in politics: somebody's invoice needs this conflict to continue." },
  { name: "Bohemian Grove Friendship Bracelet", key: "bohemian-grove-friendship-bracelet", rarity: "Common", type: "Trigger", bonus: ["Gold"], status: "KEEP", implemented: true,
    effect: "On Merge: +50% of both merged pieces' value as $.",
    conspiracy: "Bohemian Grove", url: "https://en.wikipedia.org/wiki/Bohemian_Grove",
    summary: "A redwood summer camp where presidents and CEOs perform the 'Cremation of Care' before a 40-foot owl. Alex Jones snuck a camera in, in 2000, and the footage made the ritual permanently famous." },
  { name: "Capstone Polish", key: "capstone-polish", rarity: "Common", type: "Trigger", bonus: ["Time"], status: "KEEP", implemented: true,
    effect: "Per $10 gained: +5s Clock.",
    conspiracy: "Pyramidology", url: "https://en.wikipedia.org/wiki/Pyramidology",
    summary: "The Great Pyramid as prophecy in stone, power plant, or proof of lost technology — anything but a tomb built by people with ramps. The missing capstone is the mystery's crown." },
  { name: "CIA Exploding Cigar", key: "cia-exploding-cigar", rarity: "Common", type: "Trigger", bonus: ["Gold"], status: "KEEP", implemented: true,
    effect: "On capturing the highest-value enemy on the Board: +$25.",
    conspiracy: "The plots against Castro", url: "https://en.wikipedia.org/wiki/Assassination_attempts_on_Fidel_Castro",
    summary: "The CIA ran over 600 schemes against Castro — exploding cigars, poisoned wetsuits, an exploding seashell. All real, all declassified, none successful. He died at 90, in bed, undefeated by novelty items." },
  { name: "Cleopatra's Hairpin", key: "cleopatra-s-hairpin", rarity: "Common", type: "Trigger", bonus: ["Special"], status: "KEEP", implemented: true,
    effect: "When an enemy captures your piece: the capturer is Slowed.",
    conspiracy: "The death of Cleopatra", url: "https://en.wikipedia.org/wiki/Death_of_Cleopatra",
    summary: "The asp is the famous version; ancient sources also offer a poisoned hairpin, a hidden vial, and the quiet possibility that Octavian had her killed and wrote the snake. History's most elegant unsolved exit." },
  { name: "Curtain Rods Bag (Rifle-Shaped)", key: "curtain-rods-bag-rifle-shaped", rarity: "Common", type: "Trigger", bonus: ["Gold"], status: "KEEP", implemented: true,
    effect: "On Capture: +$2; +$10 more if that enemy had captured one of yours.",
    conspiracy: "JFK assassination theories", url: "https://en.wikipedia.org/wiki/John_F._Kennedy_assassination_conspiracy_theories",
    summary: "Oswald carried a long paper package into the Book Depository that morning and told his coworker it was curtain rods. The quotation marks have carried sixty years of doubt." },
  { name: "Daylight Savings Jar", key: "daylight-savings-jar", rarity: "Common", type: "Trigger", bonus: ["Time"], status: "KEEP", implemented: true,
    effect: "On Shop purchase: +25s Clock.",
    conspiracy: "The Daylight Saving racket", url: "https://en.wikipedia.org/wiki/Daylight_saving_time",
    summary: "Nobody remembers why we still do it — but the lore says Big Candy lobbied the extension (true: the industry wanted trick-or-treating in daylight) and Big Golf bought the evening sun. The jar holds the hour they keep taking; you claw it back three seconds at a time." },
  { name: "Denazification Visa", key: "denazification-visa", rarity: "Common", type: "Trigger", bonus: ["Buff"], status: "KEEP", implemented: true,
    effect: "Pieces you buy in the Shop arrive with a random Tactical Piece Buff.",
    conspiracy: "Operation Paperclip", url: "https://en.wikipedia.org/wiki/Operation_Paperclip",
    summary: "Real and documented: after 1945 the US recruited over 1,600 German scientists — von Braun included — and laundered their files clean of the war. The paperclip on the dossier marked the ones to take." },
  { name: "Denver Bunker Badge", key: "denver-bunker-timeshare", rarity: "Common", type: "Trigger", bonus: ["Gold"], status: "KEEP", implemented: true,
    effect: "On Capture: +$1 per piece in your Stock.",
    conspiracy: "Denver Airport", url: "https://en.wikipedia.org/wiki/Denver_International_Airport",
    summary: "Apocalyptic murals, a demon horse with glowing red eyes, gargoyles in the baggage claim, and a construction project so over budget that 'the bunker underneath' became the explanation. The airport now makes the jokes itself." },
  { name: "Diplomatic Migraine Ray", key: "diplomatic-migraine-ray", rarity: "Common", type: "Trigger", bonus: ["Special"], status: "KEEP", implemented: true,
    effect: "On Wave start: the strongest enemy is Slowed.",
    conspiracy: "Havana syndrome", url: "https://en.wikipedia.org/wiki/Havana_syndrome",
    summary: "Diplomats in Havana, then worldwide, reported pressure, sound and lasting symptoms; a directed-energy weapon became the leading suspect. Intelligence reviews split between adversary device and crickets-plus-stress. No emitter found." },
  { name: "Dyatlov Geiger Counter", key: "dyatlov-geiger-counter", rarity: "Common", type: "Trigger", bonus: ["Item"], status: "KEEP", implemented: true,
    effect: "On losing a piece: +1 random Tactical Item.",
    conspiracy: "The Dyatlov Pass incident", url: "https://en.wikipedia.org/wiki/Dyatlov_Pass_incident",
    summary: "1959: nine experienced hikers cut their way out of their own tent into a Urals night and none survived — and some clothing tested radioactive. The counter clicks loudest where you should not be." },
  { name: "El Dorado Body Glitter", key: "el-dorado-body-glitter", rarity: "Common", type: "Trigger", bonus: ["Gold"], status: "KEEP", implemented: true,
    effect: "On Wave clear: +5% of your current $.",
    conspiracy: "El Dorado", url: "https://en.wikipedia.org/wiki/El_Dorado",
    summary: "The gilded king who rafted onto Lake Guatavita dusted in gold — a real Muisca rite inflated by conquistadors into a golden city that swallowed expeditions for three centuries. The golden raft exists; it's in a Bogotá museum." },
  { name: "FEMA Summer Camp Flyer", key: "fema-summer-camp-flyer", rarity: "Common", type: "Trigger", bonus: ["Gold"], status: "KEEP", implemented: true,
    effect: "On Wave clear: +$2 per piece in your Captured Stock.",
    conspiracy: "FEMA camps", url: "https://en.wikipedia.org/wiki/FEMA_camps_conspiracy_theory",
    summary: "The claim that FEMA quietly maintains a network of detention camps, waiting for the day of martial law. Every fenced federal lot photographed from a car window becomes evidence." },
  { name: "FIFA Complimentary Yacht", key: "fifa-complimentary-yacht", rarity: "Common", type: "Trigger", bonus: ["Special"], status: "KEEP", implemented: true,
    effect: "On 5-Wave Milestone: open a random Box.",
    conspiracy: "The FIFA corruption case", url: "https://en.wikipedia.org/wiki/2015_FIFA_corruption_case",
    summary: "Dawn raids on a Zurich luxury hotel, 2015: football's governing body indicted for decades of bribes — World Cup votes sold for cash, watches and better. The yacht is a small token of appreciation for your continued cooperation." },
  { name: "Fort Knox IOU", key: "fort-knox-iou", rarity: "Common", type: "Passive", bonus: ["Shop"], status: "KEEP", implemented: true,
    effect: "Shop purchases can take your $ down to -$100.",
    conspiracy: "Fort Knox's missing gold", url: "https://en.wikipedia.org/wiki/United_States_Bullion_Depository",
    summary: "The claim: the US gold reserve is gone and the audits are theater. The last full audit was 1953; the 1974 press tour meant to kill the rumor only fed it — you saw one room, said the theorists." },
  { name: "Hitler's Argentinian Passport", key: "hitler-s-argentinian-passport", rarity: "Common", type: "Trigger", bonus: ["Piece"], status: "KEEP", implemented: true,
    effect: "On Wave clear: the first piece you lost this Wave returns to Stock.",
    conspiracy: "Hitler survival theories", url: "https://en.wikipedia.org/wiki/Conspiracy_theories_about_Adolf_Hitler%27s_death",
    summary: "The FBI kept a file of tips placing Hitler in Argentina for years after 1945 — because the ratlines were real for lesser Nazis, Eichmann included. The dental records say the bunker; the file says people never stopped reporting him." },
  { name: "Hollow Moon Cross-Section", key: "hollow-moon-cross-section", rarity: "Common", type: "Passive", bonus: ["Shop"], status: "KEEP", implemented: true,
    effect: "Every 2nd Shop purchase in a Wave costs 50% less.",
    conspiracy: "The Hollow Moon", url: "https://en.wikipedia.org/wiki/Hollow_Moon",
    summary: "Apollo seismometers reported the moon 'rings like a bell' — and the hollow-moon theory never recovered. Hollow things have less inside; the discount follows logically." },
  { name: "Holy Lint", key: "holy-lint", rarity: "Common", type: "Trigger", bonus: ["Buff"], status: "KEEP", implemented: true,
    effect: "On Rank Up: the piece gets +1 Piece Buff.",
    conspiracy: "The Shroud of Turin", url: "https://en.wikipedia.org/wiki/Shroud_of_Turin",
    summary: "A cloth bearing the faint image of a crucified man, venerated as the burial shroud of Christ. 1988 radiocarbon dating said medieval forgery; believers said the lab tested a repair patch. The argument is the relic now." },
  { name: "Illuminati: NWO Booster Pack", key: "illuminati-nwo-booster-pack", rarity: "Common", type: "Trigger", bonus: ["Piece"], status: "KEEP", implemented: true,
    effect: "Every 1000 Score gained: open a random Piece Box.",
    conspiracy: "The Illuminati card game", url: "https://en.wikipedia.org/wiki/Illuminati:_New_World_Order",
    summary: "A 1995 satirical card game whose 'Terrorist Nuke' card shows the twin towers exploding — printed six years early. Add the real 1990 Secret Service raid on its publisher and the deck reads itself." },
  { name: "John Titor's Crypto Wallet", key: "john-titor-s-crypto-wallet", rarity: "Common", type: "Trigger", bonus: ["Time"], status: "KEEP", implemented: true,
    effect: "Once per Wave, when the Clock drops below 30s: +25s Clock.",
    conspiracy: "John Titor", url: "https://en.wikipedia.org/wiki/John_Titor",
    summary: "In 2000 a forum poster claimed to be a soldier from 2036 with a time machine in a 1967 Chevy. The predictions flopped; the legend never did. This is where a time traveler keeps money that has not happened yet — every leftover second is billable." },
  { name: "Library of Alexandria Matchbox", key: "library-of-alexandria-matchbox", rarity: "Common", type: "Trigger", bonus: ["Gold"], status: "KEEP", implemented: true,
    effect: "Activate: triple your $ gains until end of Turn; consumed.",
    conspiracy: "The burning of the Library of Alexandria", url: "https://en.wikipedia.org/wiki/Destruction_of_the_Library_of_Alexandria",
    summary: "The ancient world's collected knowledge, gone — and two thousand years of arguing over who struck the match: Caesar's siege, a bishop's mob, a caliph's decree. History's greatest whodunnit where the victim is a building full of books." },
  { name: "Lusitania \"Hardtack\" Crate", key: "lusitania-hardtack-crate", rarity: "Common", type: "Trigger", bonus: ["Gold"], status: "KEEP", implemented: true,
    effect: "On losing a piece: refund 75% of its value in $.",
    conspiracy: "The Lusitania", url: "https://en.wikipedia.org/wiki/Sinking_of_the_RMS_Lusitania",
    summary: "Torpedoed in 1915 with 1,198 aboard, officially carrying no munitions — though the manifest's 'cheese', 'butter' and 'oysters' were suspiciously heavy and divers later found the ammunition. Aged 40 days, detonates in 18." },
  { name: "MK-Ultra Sugar Cube", key: "mk-ultra-sugar-cube", rarity: "Common", type: "Trigger", bonus: ["Piece"], status: "KEEP", implemented: true,
    effect: "On Wave clear: move 1 piece from Captured Stock to your Stock.",
    conspiracy: "Project MKUltra", url: "https://en.wikipedia.org/wiki/Project_MKUltra",
    summary: "The CIA really ran mind-control experiments on unwitting subjects for twenty years — confirmed in 1977 hearings after most files were destroyed. 'Monarch programming' is the mythology that grew where the shredded records used to be." },
  { name: "mRNA Firmware Update", key: "mrna-firmware-update", rarity: "Common", type: "Passive", bonus: ["Buff"], status: "KEEP", implemented: true,
    effect: "Buff Boxes offer +2 Piece Buff choices.",
    conspiracy: "The vaccine microchip claim", url: "https://en.wikipedia.org/wiki/COVID-19_misinformation",
    summary: "The 2020 claim that vaccines carried tracking microchips. No chip that fits a needle exists — and the people worried about being tracked carried a GPS phone into the clinic to say so." },
  { name: "Nero's Marshmallow Stick", key: "nero-s-marshmallow-stick", rarity: "Common", type: "Passive", bonus: ["Gold"], status: "KEEP", implemented: true,
    effect: "While the Clock is under 60s: +25% $ gains.",
    conspiracy: "The Great Fire of Rome", url: "https://en.wikipedia.org/wiki/Great_Fire_of_Rome",
    summary: "Rome burned in 64 AD and ancient rumor said Nero started it — and performed while it burned. The fiddle wouldn't exist for another 1,500 years, so picture the marshmallow stick instead; the rumor won't mind." },
  { name: "Pandemic Toilet Paper", key: "pandemic-toilet-paper-pallet", rarity: "Common", type: "Trigger", bonus: ["Special"], status: "KEEP", implemented: true,
    effect: "Once: You can take all content of a Box",
    conspiracy: "Panic buying", url: "https://en.wikipedia.org/wiki/Panic_buying",
    summary: "March 2020: faced with a respiratory virus, humanity bought all the toilet paper on earth. Shelves emptied because everyone believed everyone else would empty them — the rare conspiracy in which everyone was the conspirator." },
  { name: "Pigeon Charging Cable", key: "pigeon-charging-cable", rarity: "Common", type: "Trigger", bonus: ["Special"], status: "KEEP", implemented: true,
    effect: "After your first Capture each Turn: the capturer moves to your back row.",
    conspiracy: "Birds Aren't Real", url: "https://en.wikipedia.org/wiki/Birds_Aren%27t_Real",
    summary: "The parody movement claiming every bird is a government surveillance drone recharging on power lines. Built by Gen Z as satire of conspiracism — complete with billboards — and half its rally crowds can't tell." },
  { name: "Pizarro Protocol", key: "sphinx-s-booger", rarity: "Common", type: "Trigger", bonus: ["Buff"], status: "KEEP", implemented: true,
    effect: "When a lower-value piece captures a higher-value one: it gets +1 Tactical Piece Buff.",
    conspiracy: "Atahualpa's ransom", url: "https://en.wikipedia.org/wiki/Atahualpa",
    summary: "1532: Pizarro's 168 men seize the Inca emperor, who fills a room with gold to buy his freedom and is executed anyway. The protocol: a small force, a huge capture — and the legend that the last shipment never arrived, still buried in the Llanganates." },
  { name: "Scientology E-Meter", key: "scientology-e-meter", rarity: "Common", type: "Trigger", bonus: ["Buff"], status: "KEEP", implemented: true,
    effect: "On clearing a Wave without a loss: a random ally gets +1 Piece Buff.",
    conspiracy: "Scientology auditing", url: "https://en.wikipedia.org/wiki/E-meter",
    summary: "Two tin cans, a resistance needle, and a price list: the device Scientology uses to audit engrams out of members, level by costly level. The FDA once required it to carry a disclaimer that it treats nothing." },
  { name: "Silk Road Coupon", key: "silk-road-coupon", rarity: "Common", type: "Passive", bonus: ["Shop"], status: "KEEP", implemented: true,
    effect: "The Shop stocks +2 Item slots.",
    conspiracy: "Silk Road", url: "https://en.wikipedia.org/wiki/Silk_Road_(marketplace)",
    summary: "The dark-web market run by the Dread Pirate Roberts, an anonymous libertarian folk hero — until the FBI grabbed a laptop in a library and he became Ross Ulbricht, serving double life. The seized server keys unlocked it all." },
  { name: "Skull and Bones Coffin", key: "skull-and-bones-coffin", rarity: "Common", type: "Trigger", bonus: ["Buff"], status: "KEEP", implemented: true,
    effect: "On Wave clear: the ally with the most Captures this Wave gets +1 Piece Buff.",
    conspiracy: "Skull and Bones", url: "https://en.wikipedia.org/wiki/Skull_and_Bones",
    summary: "Yale's secret society initiates its members lying in a coffin in the windowless Tomb — both 2004 presidential candidates went through it and neither would discuss it on air. They also, allegedly, keep Geronimo's skull on the shelf." },
  { name: "Sleeper Agent Pillow", key: "sleeper-agent-pillow", rarity: "Common", type: "Trigger", bonus: ["Buff"], status: "KEEP", implemented: true,
    effect: "After losing a piece: your next Deploy gets +1 Piece Buff.",
    conspiracy: "The Manchurian candidate", url: "https://en.wikipedia.org/wiki/The_Manchurian_Candidate",
    summary: "The fiction that named the fear: a soldier brainwashed into a sleeper assassin, activated by the queen of diamonds. Every real programme like MKUltra chased exactly this card and never found it." },
  { name: "Tape Eraser Magnet", key: "tape-eraser-magnet", rarity: "Common", type: "Trigger", bonus: ["Gold"], status: "KEEP", implemented: true,
    effect: "On skipping a Box (not an Ad Box): +$ equal to its contents' Shop value.",
    conspiracy: "The 18½-minute gap", url: "https://en.wikipedia.org/wiki/18%C2%BD-minute_gap",
    summary: "Three days after the Watergate break-in, the Oval Office tape goes blank for 18½ minutes. Secretary Rose Mary Woods demonstrated the 'accidental' posture required to erase it — a stretch no one could hold. Still blank; greatest B-side never released." },
  { name: "Trilateral Meeting Stickers", key: "trilateral-meeting-stickers", rarity: "Common", type: "Trigger", bonus: ["Item"], status: "KEEP", implemented: true,
    effect: "On buying a Tactical Item in the Shop: +1 random Tactical Item.",
    conspiracy: "The Trilateral Commission", url: "https://en.wikipedia.org/wiki/Trilateral_Commission",
    summary: "A Rockefeller-founded discussion forum linking North America, Europe and Japan — and, in half a century of theory, the standing committee of the shadow world government. The membership roster doubles as the accusation." },
  { name: "Tungsten-Filled Gold Bar", key: "tungsten-filled-gold-bar", rarity: "Common", type: "Passive", bonus: ["Gold", "Shop"], status: "KEEP", implemented: true,
    effect: "+20% $ gains; Shop prices +10%.",
    conspiracy: "Fake gold bars", url: "https://en.wikipedia.org/wiki/Gold_bar",
    summary: "Every few years a gold bar turns out to be tungsten wrapped in a millimeter of the real thing — same weight, same ring, wrong metal. The lore says whole vaults are stacked with them, waiting for an audit that never comes." },
  // ── Uncommon ────────────────────────────────────────────────────
  { name: "$2.3 Trillion Receipt", key: "2-3-trillion-receipt", rarity: "Uncommon", type: "Passive", bonus: ["Gold"], status: "KEEP", implemented: true,
    effect: "+25% $ gains.",
    conspiracy: "The missing trillions", url: "https://en.wikipedia.org/wiki/Military_budget_of_the_United_States",
    summary: "On September 10, 2001, Rumsfeld said the Pentagon could not track $2.3 trillion in transactions. The next day buried the story — and birthed a theory that the accounting office was precisely what got hit." },
  { name: "Apocrypha", key: "bible-gag-reel-scroll", rarity: "Uncommon", type: "Passive", bonus: ["Shop"], status: "KEEP", implemented: true,
    effect: "The Shop stocks +1 Artefact slot, Uncommon or better, at +50% price.",
    conspiracy: "The Vatican Secret Archives", url: "https://en.wikipedia.org/wiki/Vatican_Apostolic_Archive",
    summary: "53 miles of shelving nobody may browse. Somewhere in there, the lore insists, is a file on everyone — and a Bishop, Cardinal or Archbishop who captures gets handed theirs: insurance against the next attempt on them." },
  { name: "Area 51 Parking Permit", key: "area-51-parking-permit", rarity: "Uncommon", type: "Passive", bonus: ["Item"], status: "KEEP", implemented: true,
    effect: "+3 Item capacity.",
    conspiracy: "Area 51", url: "https://en.wikipedia.org/wiki/Area_51",
    summary: "The Nevada test site whose existence the US denied until 2013. Lore says crashed saucers are stored and reverse-engineered there. The badge is the access nobody is supposed to have." },
  { name: "Atlantis Snow Globe", key: "atlantis-snow-globe", rarity: "Uncommon", type: "Trigger", bonus: ["Buff"], status: "KEEP", implemented: true,
    effect: "On 5-Wave Milestone: every ally on the Board gets +1 Piece Buff.",
    conspiracy: "Atlantis", url: "https://en.wikipedia.org/wiki/Atlantis",
    summary: "Plato invented a doomed island empire to make a point about hubris; the world took it as a treasure map. Under the glass the city never ages — shake it all you like, nothing degrades." },
  { name: "Bielefeld Library Card", key: "bielefeld-library-card", rarity: "Uncommon", type: "Trigger", bonus: ["Special"], status: "KEEP", implemented: true,
    effect: "Once per Wave: your piece about to be captured steps 1 square away.",
    conspiracy: "The Bielefeld Conspiracy", url: "https://en.wikipedia.org/wiki/Bielefeld_Conspiracy",
    summary: "Germany's beloved joke theory: the city of Bielefeld does not exist. Do you know anyone from Bielefeld? Have you been there? Exactly. The city ran a €1M prize for proof of its nonexistence; nobody could." },
  { name: "CIA Heart Attack Gun", key: "cia-heart-attack-gun", rarity: "Uncommon", type: "Passive", bonus: ["Gold"], status: "KEEP", implemented: true,
    effect: "Enemies destroyed by Items pay their value in $.",
    conspiracy: "The heart attack gun", url: "https://en.wikipedia.org/wiki/Church_Committee",
    summary: "Revealed in the 1975 Church Committee hearings: a dart gun firing a frozen shellfish-toxin dart that melts in the body and leaves a heart attack. The professional's weapon — untraceable, and the hit pays double." },
  { name: "Deep State Yearbook", key: "deep-state-yearbook", rarity: "Uncommon", type: "Trigger", bonus: ["Piece"], status: "KEEP", implemented: true,
    effect: "On Rank Up: add its Family's base piece to your Stock.",
    conspiracy: "The deep state", url: "https://en.wikipedia.org/wiki/Deep_state_in_the_United_States",
    summary: "The permanent, unelected government said to run things regardless of who wins — a phrase imported from Turkey's derin devlet, where the networks were real enough to surface in a car crash. The chart has no public version." },
  { name: "Dihydrogen Monoxide Battery", key: "dihydrogen-monoxide-battery", rarity: "Uncommon", type: "Trigger", bonus: ["Item"], status: "KEEP", implemented: true,
    effect: "Your first Item each Wave is not consumed.",
    conspiracy: "The water-fuelled car", url: "https://en.wikipedia.org/wiki/Water-fuelled_car",
    summary: "Stanley Meyer said his cell ran cars on water; a court said fraud. When he died mid-lunch in 1998 crying 'they poisoned me', the suppressed-invention legend acquired its martyr." },
  { name: "Doomsday Autoclicker", key: "doomsday-autoclicker", rarity: "Uncommon", type: "Trigger", bonus: ["Special", "Piece"], status: "KEEP", implemented: true,
    effect: "Once per Wave: when an enemy captures your piece, the capturer is removed too.",
    conspiracy: "Dead Hand", url: "https://en.wikipedia.org/wiki/Dead_Hand",
    summary: "The Soviet doomsday system built to fire back even if everyone who could give the order was dead — sensors, silence, then launch. Former officers say Perimeter still runs. The button that presses itself." },
  { name: "Ecdysis Sheddings", key: "ecdysis-sheddings", rarity: "Uncommon", type: "Trigger", bonus: ["Buff"], status: "KEEP", implemented: true,
    effect: "Once per Wave: Whenever a Piece Buff is consumed, reapply it to that piece. (Death effects excluded).",
    conspiracy: "The reptilian elite", url: "https://en.wikipedia.org/wiki/Reptilian_conspiracy_theory",
    summary: "David Icke's contribution: the ruling families are shapeshifting reptilians in human suits, betrayed by frame glitches in interview footage. Millions of views per 'slip'. The shed skin is the evidence that never gets bagged." },
  { name: "Exhibit 399", key: "exhibit-399", rarity: "Uncommon", type: "Trigger", bonus: ["Special"], status: "KEEP", implemented: true,
    effect: "Once per Wave: a sliding piece may capture through one blocking piece.",
    conspiracy: "The Warren Commission", url: "https://en.wikipedia.org/wiki/Warren_Commission",
    summary: "The Commission's 26 volumes concluded one man acted alone — and Exhibit 399, the 'magic bullet' recovered improbably pristine from a stretcher, became the most argued-over object in American history. Most Americans never bought it." },
  { name: "Inflatable Vietcong Torpedo", key: "inflatable-vietcong-torpedo", rarity: "Uncommon", type: "Passive", bonus: ["Buff"], status: "KEEP", implemented: true,
    effect: "Waves spawn +1 enemy piece; on Wave clear, a random ally gets +1 Piece Buff.",
    conspiracy: "The Gulf of Tonkin incident", url: "https://en.wikipedia.org/wiki/Gulf_of_Tonkin_incident",
    summary: "The second attack of August 4, 1964 — the one that authorized the Vietnam War — never happened. The NSA's own declassified history says so. Sailors shot at radar ghosts and Congress shot at the ghosts' report." },
  { name: "KGB Photo Eraser", key: "kgb-photo-eraser", rarity: "Uncommon", type: "Trigger", bonus: ["Buff"], status: "KEEP", implemented: true,
    effect: "On losing a Buffed piece: its Piece Buffs move to the nearest ally. (Death effects excluded).",
    conspiracy: "Soviet photo retouching", url: "https://en.wikipedia.org/wiki/Censorship_of_images_in_the_Soviet_Union",
    summary: "Soviet retouchers erased the purged from official photographs so thoroughly that the empty spaces became the historical record. The eraser passes along what the vanished carried to whoever stood closest." },
  { name: "Men in Black Prescription Sunglasses", key: "men-in-black-prescription-sunglasses", rarity: "Uncommon", type: "Trigger", bonus: ["Action"], status: "KEEP", implemented: true,
    effect: "If your first Action of a Turn is using an Item: +1 Action.",
    conspiracy: "The Men in Black", url: "https://en.wikipedia.org/wiki/Men_in_black",
    summary: "Since the 1950s, UFO witnesses have described identical dark-suited visitors who arrive first and advise silence. Government agents, aliens policing their own leaks — the card never has a real department on it." },
  { name: "Montauk Eggo Waffle", key: "montauk-eggo-waffle", rarity: "Uncommon", type: "Trigger", bonus: ["Special"], status: "KEEP", implemented: true,
    effect: "After your first Capture each Turn: the capturer returns to where it started.",
    conspiracy: "The Montauk Project", url: "https://en.wikipedia.org/wiki/Montauk_Project",
    summary: "Camp Hero, Long Island: lore of time tunnels, psychic boys and a chair that turned thought into reality, spun from a decommissioned radar base. It directly inspired Stranger Things — the fiction of the fiction. Stranger Things was first pitched under the title 'Montauk'." },
  { name: "Moon Landing Slate", key: "moon-landing-slate", rarity: "Uncommon", type: "Trigger", bonus: ["Special"], status: "KEEP", implemented: true,
    effect: "Once per Box: reroll its offer.",
    conspiracy: "The moon landing hoax", url: "https://en.wikipedia.org/wiki/Moon_landing_conspiracy_theories",
    summary: "The claim that Apollo was shot on a soundstage — waving flag, missing stars, Kubrick directing. Refuted by retroreflectors you can bounce a laser off tonight; believed by more people than in 1969." },
  { name: "Nigerian Prince Wire Transfer", key: "nigerian-prince-wire-transfer", rarity: "Uncommon", type: "Trigger", bonus: ["Item"], status: "KEEP", implemented: true,
    effect: "Once per Turn: pay $25 to open a Small Item Box.",
    conspiracy: "The advance-fee scam", url: "https://en.wikipedia.org/wiki/Advance-fee_scam",
    summary: "A deposed prince needs only your account details to move his fortune — a scam so old it predates email by two centuries as the 'Spanish Prisoner'. It pays out up front and collects forever, which is exactly this artefact." },
  { name: "Panama Papers Shredder", key: "panama-papers-shredder", rarity: "Uncommon", type: "Trigger", bonus: ["Gold"], status: "KEEP", implemented: true,
    effect: "On Wave clear: +10% of your current $.",
    conspiracy: "The Panama Papers", url: "https://en.wikipedia.org/wiki/Panama_Papers",
    summary: "2016: 11.5 million leaked files from one Panamanian law firm exposed the offshore shells of presidents, oligarchs and celebrities. The conspiracy that turned out to be simply, boringly, spectacularly true." },
  { name: "Pre-Scratched Lottery Ticket", key: "pre-scratched-lottery-ticket", rarity: "Uncommon", type: "Passive", bonus: ["Gold"], status: "KEEP", implemented: true,
    effect: "5% of your Score gains are also paid as $.",
    conspiracy: "The Hot Lotto fraud", url: "https://en.wikipedia.org/wiki/Hot_Lotto_fraud_scandal",
    summary: "Everyone jokes the lottery is rigged; Eddie Tipton actually did it. The lottery association's own security director planted rootkit code in the number generator and was convicted in 2017." },
  { name: "Super Soldier Multivitamins", key: "super-soldier-multivitamins", rarity: "Uncommon", type: "Trigger", bonus: ["Buff"], status: "KEEP", implemented: true,
    effect: "On Deploy: the piece gets +1 Tactical Piece Buff.",
    conspiracy: "Super soldier programs", url: "https://en.wikipedia.org/wiki/Supersoldier",
    summary: "Every superpower allegedly ran one: engineer the perfect soldier, deny the program. It ships as multivitamins now — one a day, side effects include extra turns." },
  { name: "Suspiciously Large Femur", key: "suspiciously-large-femur", rarity: "Uncommon", type: "Passive", bonus: ["Buff"], status: "KEEP", implemented: true,
    effect: "Your pieces hold +1 Piece Buff; doesn't stack.",
    conspiracy: "The hidden giant skeletons", url: "https://en.wikipedia.org/wiki/Giant_human_skeletons",
    summary: "Nineteenth-century papers reported giant skeletons dug from American mounds — and the theory says the Smithsonian quietly collected every one, filing them under 'whale.' The femur in question does not fit the drawer." },
  { name: "Tunguska Toothpicks", key: "tunguska-toothpicks", rarity: "Uncommon", type: "Trigger", bonus: ["Special"], status: "KEEP", implemented: true,
    effect: "Activate: destroy the strongest enemy (no Score or $); charges every 10 Waves.",
    conspiracy: "The Tunguska event", url: "https://en.wikipedia.org/wiki/Tunguska_event",
    summary: "1908: a blast flattened 2,000 square kilometres of Siberian forest — and left no crater. Airburst meteor is the science; a UFO that parked very badly is the folklore. The citation was never paid." },
  { name: "Walt's Ice Cube", key: "walt-s-cryonic-capsule", rarity: "Uncommon", type: "Trigger", bonus: ["Piece"], status: "KEEP", implemented: true,
    effect: "On Wave clear: the last piece you lost this Wave returns to Stock.",
    conspiracy: "The frozen Walt Disney legend", url: "https://en.wikipedia.org/wiki/Cryonics",
    summary: "The most famous cryonics story is false: Walt Disney was cremated in 1966. The rumor that he waits frozen under Pirates of the Caribbean started within years and has outlived every correction." },
  { name: "Youth Fountain Martini", key: "youth-fountain-martini", rarity: "Uncommon", type: "Trigger", bonus: ["Time"], status: "KEEP", implemented: true,
    effect: "When the Clock hits 0: turn all your $ into Clock (1s per $5); consumed.",
    conspiracy: "The Fountain of Youth", url: "https://en.wikipedia.org/wiki/Fountain_of_Youth",
    summary: "Waters that undo age, chased from Herodotus to the Caribbean — the legend fixated on Bimini in the Bahamas, whose offshore 'road' of stones doubles as an Atlantis claim on weekends. Ponce de León never even mentioned it; the quest was attached to him after death." },
  { name: "Zodiac Crossword Puzzle", key: "zodiac-crossword-puzzle", rarity: "Uncommon", type: "Passive", bonus: ["Gold"], status: "KEEP", implemented: true,
    effect: "Captures pay +25% $ for each previous Capture this Turn.",
    conspiracy: "The Zodiac ciphers", url: "https://en.wikipedia.org/wiki/Zodiac_Killer",
    summary: "The Bay Area killer who taunted papers with ciphers. The 340-character one held for 51 years until amateurs cracked it in 2020 — it named no one. The identity remains the cold case of cold cases." },
  // ── Rare ────────────────────────────────────────────────────────
  { name: "33rd Degree Fidelity Card", key: "33rd-degree-fidelity-card", rarity: "Rare", type: "Trigger", bonus: ["Piece", "Buff"], status: "KEEP", implemented: true,
    effect: "Whenever a Piece receives a second Piece Buff, it also Ranks Up",
    conspiracy: "The 33rd degree", url: "https://en.wikipedia.org/wiki/Scottish_Rite",
    summary: "Freemasonry's Scottish Rite tops out at the honorary 33rd degree, and two centuries of lore insist that's where the real handshakes happen — each degree a door, the last one unmarked. The ring is how they know each other." },
  { name: "Agartha Welcome Mat", key: "agartha-welcome-mat", rarity: "Rare", type: "Trigger", bonus: ["Piece"], status: "KEEP", implemented: true,
    effect: "On Wave clear: +1 random Army piece to your Stock.",
    conspiracy: "The Hollow Earth", url: "https://en.wikipedia.org/wiki/Hollow_Earth",
    summary: "Openings at the poles, civilizations within — Symmes petitioned Congress to fund the descent, and Agartha lore inherited the map. Admiral Byrd's polar flights were retold as the trip inside. Geology declined comment." },
  { name: "Alleged Weather Balloon", key: "alleged-weather-balloon", rarity: "Rare", type: "Trigger", bonus: ["Special"], status: "KEEP", implemented: true,
    effect: "Once per Wave: move an enemy piece to any square you could Deploy on.",
    conspiracy: "Roswell", url: "https://en.wikipedia.org/wiki/Roswell_incident",
    summary: "1947: the Army announced it had recovered a 'flying disc', then retracted to weather balloon within a day. The debris was from the classified Project Mogul — but witnesses remembered foil that unfolded itself." },
  { name: "Antikythera Warranty Card", key: "antikythera-warranty-card", rarity: "Rare", type: "Trigger", bonus: ["Special"], status: "KEEP", implemented: true,
    effect: "Your Wave clear and Wave start Artefacts trigger one extra time.",
    conspiracy: "The Antikythera mechanism", url: "https://en.wikipedia.org/wiki/Antikythera_mechanism",
    summary: "A corroded lump from a Greek shipwreck that turned out to be a 2,000-year-old geared astronomical computer — technology with no known peer for a millennium after. The favorite exhibit of every lost-knowledge theory." },
  { name: "Bilderberg Hotel Slippers", key: "bilderberg-hotel-slippers", rarity: "Rare", type: "Passive", bonus: ["Gold"], status: "KEEP", implemented: true,
    effect: "Other Artefacts' bonuses to your $ gains are 25% larger.",
    conspiracy: "The Bilderberg meeting", url: "https://en.wikipedia.org/wiki/Bilderberg_meeting",
    summary: "An invitation-only conference of politicians, bankers and industrialists held off the record since 1954. The guest list is actually published; what's said in the room never is — which is where the world-government lore lives." },
  { name: "Charlemagne Mask", key: "charlemagne-s-birth-certificate", rarity: "Rare", type: "Passive", bonus: ["Special"], status: "KEEP", implemented: true,
    effect: "Your Wave clear Artefacts also trigger on Wave start.",
    conspiracy: "The phantom time hypothesis", url: "https://en.wikipedia.org/wiki/Phantom_time_hypothesis",
    summary: "Heribert Illig's claim that the years 614–911 never happened — three centuries forged into the calendar, Charlemagne and all. It's not 2026, says the theory; it's around 1729." },
  { name: "Chupacabra Chew Toy", key: "chupacabra-chew-toy", rarity: "Rare", type: "Trigger", bonus: ["Buff"], status: "KEEP", implemented: true,
    effect: "On Capture: the capturer gets +1 Piece Buff.",
    conspiracy: "The Chupacabra", url: "https://en.wikipedia.org/wiki/Chupacabra",
    summary: "Puerto Rico, 1995: livestock found drained dry, and a spined goat-sucker entered the cryptid hall of fame. The chew toy keeps it busy — and catching a fed predator pays extra." },
  { name: "Epstein's Black Book", key: "epstein-s-black-book", rarity: "Rare", type: "Trigger", bonus: ["Special"], status: "KEEP", implemented: true,
    effect: "Your highest-value piece can't be captured by a lower-value enemy.",
    conspiracy: "The Epstein case", url: "https://en.wikipedia.org/wiki/Death_of_Jeffrey_Epstein",
    summary: "The contact book — hundreds of names, the famous ones circled, photocopied into evidence. Everyone was in it; one look takes everything, and then it disappears." },
  { name: "Frame 25", key: "frame-25", rarity: "Rare", type: "Trigger", bonus: ["Special"], status: "KEEP", implemented: true,
    effect: "Your on-Capture Artefacts trigger one extra time.",
    conspiracy: "Subliminal advertising", url: "https://en.wikipedia.org/wiki/Subliminal_stimuli",
    summary: "James Vicary claimed in 1957 that flashing EAT POPCORN for a single frame drove cinema sales up 57%. He later admitted fabricating the data — decades after the panic had written itself into law and lore." },
  { name: "Frog Pride Flag", key: "frog-pride-flag", rarity: "Rare", type: "Passive", bonus: ["Action"], status: "KEEP", implemented: true,
    effect: "While 3+ allies are Buffed: +1 Action per Turn.",
    conspiracy: "Gay frogs", url: "https://en.wikipedia.org/wiki/Gay_frogs_conspiracy_theory",
    summary: "In 2015 Alex Jones roared 'they're turning the freakin' frogs gay!' — and under the rant sat a real study: atrazine in the water really was changing male frogs' sex. The clip became the internet's favorite conspiracy anthem." },
  { name: "Jet Fuel Barrel", key: "jet-fuel-vial", rarity: "Rare", type: "Trigger", bonus: ["Special"], status: "KEEP", implemented: true,
    effect: "On your first Capture each Turn: destroy a random adjacent non-King enemy.",
    conspiracy: "Controlled demolition claims", url: "https://en.wikipedia.org/wiki/World_Trade_Center_controlled_demolition_conspiracy_theories",
    summary: "The claim that the towers were brought down by planted charges, with 'thermite traces in the dust' as its favorite exhibit. Engineering investigations answered at book length; the vial keeps being resold." },
  { name: "Loch Ness Stool Sample", key: "loch-ness-stool-sample", rarity: "Rare", type: "Passive", bonus: ["Special"], status: "KEEP", implemented: true,
    effect: "Pieces at the end of their Family get one free move or Capture per Turn.",
    conspiracy: "The Loch Ness Monster", url: "https://en.wikipedia.org/wiki/Loch_Ness_Monster",
    summary: "The 1934 'surgeon's photograph' was a confessed hoax, so the hunt went biological — expeditions now trawl the loch for DNA and, yes, droppings. Science demands a sample; the sample remains at large." },
  { name: "Mar-a-Lago Toilet Papers", key: "mar-a-lago-toilet-papers", rarity: "Rare", type: "Trigger", bonus: ["Special"], status: "KEEP", implemented: true,
    effect: "Boxes give +1 pick.",
    conspiracy: "The Mar-a-Lago documents", url: "https://en.wikipedia.org/wiki/FBI_search_of_Mar-a-Lago",
    summary: "August 2022: the FBI searched a sitting ex-president's beach club and photographed classified folders stacked in a bathroom, next to the shower. Some documents are top secret; these were toilet papers." },
  { name: "Naruto Run Manual", key: "naruto-run-manual", rarity: "Rare", type: "Trigger", bonus: ["Action"], status: "KEEP", implemented: true,
    effect: "If your first Action of a Turn is a Capture: +1 Action.",
    conspiracy: "Storm Area 51", url: "https://en.wikipedia.org/wiki/Storm_Area_51",
    summary: "2019: two million people RSVP'd to raid Area 51 because 'they can't stop all of us', Naruto-running below the radar. The Air Force issued a formal warning to a meme. About 150 showed up; nobody breached the gate." },
  { name: "Putin's Golden Toilet Brush", key: "putin-s-golden-toilet-brush", rarity: "Rare", type: "Passive", bonus: ["Gold", "Time"], status: "KEEP", implemented: true,
    effect: "Shop prices +50%; on Wave clear: +$100 and +15s Clock.",
    conspiracy: "Putin's Palace", url: "https://en.wikipedia.org/wiki/Putin%27s_Palace",
    summary: "Navalny's 2021 investigation: a $1.3 billion Black Sea estate — vineyard, casino, aquadiscotheque — held for one man through layers of proxies. A hundred million views before the Kremlin finished denying it. The itemized inventory included an $850 toilet brush; protesters marched with golden ones." },
  { name: "Stargate Divination Crystal", key: "stargate-divination-crystal", rarity: "Rare", type: "Passive", bonus: ["Special"], status: "KEEP", implemented: true,
    effect: "Boxes show their contents before you buy or choose them.",
    conspiracy: "The Stargate Project", url: "https://en.wikipedia.org/wiki/Stargate_Project_(U.S._Army_unit)",
    summary: "For twenty years the US Army and CIA paid psychics to describe distant targets from a desk. Declassified in 1995 with the verdict 'no intelligence value' — leaving the logs of two decades of government séances." },
  { name: "Sugar Free Chemtrail Can", key: "sugar-free-chemtrail-can", rarity: "Rare", type: "Trigger", bonus: ["Buff"], status: "KEEP", implemented: true,
    effect: "When one of your pieces gets a Piece Buff: an adjacent ally gets a copy.",
    conspiracy: "Chemtrails", url: "https://en.wikipedia.org/wiki/Chemtrail_conspiracy_theory",
    summary: "Ordinary contrails recast as deliberate spraying — for weather control, sterilization, or sedation, depending on the telling. The canister is the payload every diagram draws inside the plane that's really carrying passengers." },
  { name: "The Red Phone", key: "the-red-phone", rarity: "Rare", type: "Trigger", bonus: ["Special"], status: "KEEP", implemented: true,
    effect: "On Wave start: the enemy skips its first Turn.",
    conspiracy: "The Moscow–Washington hotline", url: "https://en.wikipedia.org/wiki/Moscow%E2%80%93Washington_hotline",
    summary: "The direct line between Washington and Moscow — mythologized as a red telephone on the president's desk (it was actually a teletype). It only rings when the clock is nearly dead, and then everything counts double." },
  { name: "Tinfoil Hat", key: "tinfoil-hat", rarity: "Rare", type: "Passive", bonus: ["Special"], status: "KEEP", implemented: true,
    effect: "Your pieces on your back row can't be captured.",
    conspiracy: "Tin foil hat", url: "https://en.wikipedia.org/wiki/Tin_foil_hat",
    summary: "The DIY headgear supposed to block mind-reading and mind-control rays. It became the universal shorthand for conspiracism itself — the one artefact that references all the others." },
  { name: "Zero-Point Energy Drink", key: "zero-point-energy-drink", rarity: "Rare", type: "Trigger", bonus: ["Action"], status: "KEEP", implemented: true,
    effect: "When a purchase or charge brings you to exactly $0: +2 Actions this Turn. (Stackable)",
    conspiracy: "Zero-point energy", url: "https://en.wikipedia.org/wiki/Zero-point_energy",
    summary: "The suppressed-physics dream: infinite energy extracted from empty vacuum. Bottled here — activates precisely when you have nothing. That's the zero point." },
  // ── Legendary ───────────────────────────────────────────────────
  { name: "Azimuthal Pancake Map", key: "azimuthal-pancake-map", rarity: "Legendary", type: "Passive", bonus: ["Special"], status: "KEEP", implemented: true,
    effect: "Enemy pieces can't move onto your back row.",
    conspiracy: "Modern flat Earth", url: "https://en.wikipedia.org/wiki/Modern_flat_Earth_beliefs",
    summary: "The disc, the ice wall, NASA the deceiver — revived in the internet era into a genuine movement. Its chosen 'true map' is the azimuthal equidistant projection, i.e. the UN logo, which delights everyone involved." },
  { name: "CIA Press Pass", key: "cia-press-pass", rarity: "Legendary", type: "Passive", bonus: ["Action"], status: "KEEP", implemented: true,
    effect: "Any number of times per Turn: pay $50 for +1 Action.",
    conspiracy: "Operation Mockingbird", url: "https://en.wikipedia.org/wiki/Operation_Mockingbird",
    summary: "The Church Committee era confirmed the CIA had paid relationships with journalists; 'Mockingbird' became the name for the maximal version — a wired newsroom in every city. The press pass works everywhere." },
  { name: "Guidestone Chunks", key: "guidestone-blood-ritual", rarity: "Legendary", type: "Passive", bonus: ["Special"], status: "KEEP", implemented: true,
    effect: "Artefacts you hold 2+ copies of trigger one extra time.",
    conspiracy: "The Georgia Guidestones", url: "https://en.wikipedia.org/wiki/Georgia_Guidestones",
    summary: "Granite slabs commissioned in 1980 by a pseudonymous 'R.C. Christian', engraving commandments for a post-catastrophe world — population capped at 500 million. Read as the elite's carved confession; bombed in 2022." },
  { name: "Illuminati Fridge Magnet", key: "illuminati-fridge-magnet", rarity: "Legendary", type: "Passive", bonus: ["Special"], status: "KEEP", implemented: true,
    effect: "Your first Artefact to trigger each Turn triggers an additional time.",
    conspiracy: "The Illuminati", url: "https://en.wikipedia.org/wiki/Illuminati",
    summary: "A real Bavarian society of Enlightenment radicals, founded 1776, banned 1785 — nine years of existence, two and a half centuries of afterlife as the master explanation for everything. The seal never expired." },
  { name: "Nazca Boarding Pass", key: "nazca-boarding-pass", rarity: "Legendary", type: "Passive", bonus: ["Action"], status: "KEEP", implemented: true,
    effect: "Deploying costs no Action.",
    conspiracy: "The Nazca Lines", url: "https://en.wikipedia.org/wiki/Nazca_Lines",
    summary: "Desert figures kilometres long, fully visible only from the air — ancient-astronaut writers read them as runways. With a valid boarding pass, everywhere is a landing strip." },
  { name: "Obedience-Flavored Tap Water", key: "obedience-flavored-tap-water", rarity: "Legendary", type: "Passive", bonus: ["Action"], status: "KEEP", implemented: true,
    effect: "+2 Actions per Turn; you can't Pass while Actions remain.",
    conspiracy: "Water fluoridation", url: "https://en.wikipedia.org/wiki/Water_fluoridation_controversy",
    summary: "Cold War America's homegrown panic: fluoride in the tap water as a communist plot to soften minds. Immortalized by Dr. Strangelove's General Ripper and his precious bodily fluids." },
  { name: "Snowden's Rubik's Cube", key: "snowden-s-rubik-s-cube", rarity: "Legendary", type: "Passive", bonus: ["Special"], status: "KEEP", implemented: true,
    effect: "Copies the last other Artefact you bought.",
    conspiracy: "PRISM", url: "https://en.wikipedia.org/wiki/PRISM_(surveillance_program)",
    summary: "Snowden walked the NSA's crown jewels out of a secure facility — by his own account, past the guards inside a Rubik's Cube. The slides inside proved the paranoids right, in the ugliest PowerPoint template ever made." },
  { name: "Templar Debit Card", key: "templar-debit-card", rarity: "Legendary", type: "Passive", bonus: ["Shop", "Special"], status: "KEEP", implemented: true,
    effect: "Shop costs you can't cover in $ are paid in Score, 10 Score per $1.",
    conspiracy: "The Knights Templar", url: "https://en.wikipedia.org/wiki/Knights_Templar",
    summary: "Real history: the Templars invented proto-banking — deposit in Paris, present your letter, withdraw in Jerusalem, centuries before anyone said wire transfer. The card still works, and it takes your other currency." },
  { name: "Trojan Horse Assembly Manual", key: "trojan-horse-assembly-manual", rarity: "Legendary", type: "Passive", bonus: ["Special"], status: "KEEP", implemented: true,
    effect: "You may Deploy onto any empty square.",
    conspiracy: "The Trojan Horse", url: "https://en.wikipedia.org/wiki/Trojan_Horse",
    summary: "The original hidden payload: a gift engineered to be brought inside the walls by its victims. Three thousand years later every malicious download still carries its name. Beware Greeks bearing boxes." },
  { name: "Voynich Dictionary", key: "voynich-dictionary", rarity: "Legendary", type: "Passive", bonus: ["Action"], status: "KEEP", implemented: true,
    effect: "+1 Action per Turn.",
    conspiracy: "The Voynich manuscript", url: "https://en.wikipedia.org/wiki/Voynich_manuscript",
    summary: "A 15th-century book in a script no one can read, illustrating plants that don't exist. Codebreakers who cracked Enigma bounced off it. Hoax, cipher, or lost language — 600 years without a single read sentence." },
];

if (typeof module !== "undefined" && module.exports) module.exports = ARTEFACTS;
