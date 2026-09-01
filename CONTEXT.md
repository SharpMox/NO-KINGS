# NO-KINGS

A Godot 4 mobile game built by AI agents. The backlog lives in `.scratch/gdd-gaps/` (a PRD plus one file per slice) and the Notion GDD is the design source of truth for the catalogs — **not Linear**, which earlier revisions of this file named but which was never actually used.

> ⚠️ The GitNexus-fork subsection below documents an agent-tooling experiment that is **not part of the shipped game**. It is kept for reference; nothing in `game/` depends on it.

## Language

### Game domain (No Kings rules)

**Endless mode**:
The post-win phase of a run, entered via **Continue** on the Win screen after the wave-50 King checkmate. Waves 51–150 come from the designed Wave Catalog; the run ends at the wave-150 full clear (grilled 2026-07-03: no procedural generator — diverges from the GDD's TBD sketch).
_Avoid_: "new game+", "second loop"

**Recurring King**:
The wave-100 King wave. Checkmate awards a score bonus + clock refill and the run continues — no Win screen (that shows once, at wave 50).

**Full clear**:
Checkmating the wave-150 King. Ends the run immediately with a win-flavored end screen; the score is locked.

**Army**:
One of six preset starting kits chosen on the army-select screen before a run: **The Muster** (classic, signature rook), **Wild Hunt** (leapers, signature kirin), **Old Guard** (fairy walkers, signature ferz/wazir), **The Syndicate**, **The Cult**, **The Horde**. An Army sets Starting Stock, Starting Gold and Starting Items, plus a static **Power** (always on) and a once-per-Wave **Ability** costing 1 Action — a deliberate contrast with Artefact activation and the Shop, both 0 (issues 67, 68). Called "Family" before issue 76.
_Avoid_: "team", "deck", "loadout", "family"
_Note_: ids stay the original keys (`Crown`/`Wild Hunt`/`Old Guard`) — load-bearing in the save's `army` field, so display name ≠ id.

**Family**:
A piece's promotion chain — base → mid → end, plus its fusion-only relatives. Reassigned to this meaning by issue 76, which simultaneously renamed the old "Family" (the starting kit) to **Army**. A piece that promotes into nothing and is promoted into by nothing has no Family.
_Avoid_: using it for the starting kit — that is an Army.

**Signature piece**:
The piece (and its Family) that gives an Army its identity — the GDD's "unique Queen" reinterpreted after dropping queen-grade centerpieces as too strong. Team special abilities and Piece Cases from the GDD are deferred, not implemented.

**Tariff**:
A player penalty activated on every 10th wave per the Wave Catalog. Three kinds: **action** (Gold surcharge when the taxed action happens), **persistent** (rule modifier for the rest of the run, e.g. Inflation), **oneoff** (applies instantly on activation).
_Avoid_: "debuff", "curse"

**Tariff suppression**:
What Counter-Intel does (grilled 2026-07-17): action and persistent tariffs stop applying for the rest of the current wave, ending when the next wave spawns. Oneoff tariffs are untouched — they already fired. Replaces the deleted turn-counted version (`counter_intel_turns`).

**Stock entry**:
One element of the player's Stock: a bare piece id, or `{id + opaque piece state}` for a piece returned from the board carrying state (e.g. a future buff). Stock never interprets the state — see ADR-0002. Distinct-state copies stack separately in the HUD.
_Avoid_: "inventory" (that's the Items/Artefacts drawer), "pool"

**Destruction**:
An item effect removing a piece from the board outright (Air Strike, Sniper, Drone Strike). Not a capture (grilled 2026-07-17): awards no Score or Gold and fires no per-capture Artefact effects; a destroyed ally is gone, not returned to Stock.
_Avoid_: conflating with "capture" — captures are board moves and feed the economy; destruction never does.

**Artefact**:
A held, persistent effect from the 180-entry catalog (`data/artefacts.js` → `game/data/artefacts.json`), listening at named hook points. Cap 5. Activation costs 0 Actions. Called "Trinket" in earlier revisions of this file and in the pre-rename GDD.
_Avoid_: "trinket", "relic", "item" (an Item is a separate, consumable catalog).

**Combo**:
A **directed** relation between two effects (Artefact, Item, Piece Buff, Army Power or Army Ability): one side **fires or gates** a hook the other side **listens** on, so using X measurably changes what Y does. Not "two effects that touch the same resource" and not "two effects that share a hook" — 39 Artefacts listen on `on_wave_clear` and almost none of them interact (grilled 2026-09-01).
_Avoid_: "synergy", "interaction" (too broad — those cover the undirected case this term deliberately excludes).

**Anti-combo**:
The inverse relation: X **suppresses** a hook Y listens on, so holding both makes Y silently do nothing. Shield stopping a capture attempt is the reference case — it denies `on_capture` to the 22 Artefacts listening there. Named separately because the failure is invisible by construction: nothing happens, and nothing reports that nothing happened.
_Avoid_: "conflict", "negative synergy".

### Godot domain

**Scene**:
A `.tscn` file containing a serialized tree of scene Nodes plus signal wiring, script attachments, and external resource references. Composable — one Scene can instance another.
_Avoid_: "level", "screen", "stage"

**Node** (scene Node):
An entry in a Scene's tree (e.g., `Sprite2D`, `Button`). Has a name, a type, optional Script, and child Nodes.
_Avoid_: "object", "element"

**Script**:
A `.gd` (GDScript) file attached to a scene Node, defining its runtime behavior. May declare `signal`s, register a `class_name` in the global script registry, and inherit via `extends`.

**Signal**:
A typed runtime event a scene Node can emit (declared via `signal foo(arg: int)`) and other scene Nodes can subscribe to.
_Avoid_: "event", "callback"

**Signal connection**:
A `[connection]` entry in a `.tscn` that declaratively wires `signal X` on Node A to method `Y` on Node B. Runtime-deferred — not a lexical call.
_Avoid_: "binding", "subscription"

**Scene instance**:
A scene Node whose contents are loaded from another `.tscn` via `PackedScene` reference. Lets Scenes nest Scenes.
_Avoid_: "child scene", "nested scene"

**Autoload**:
A Script registered in `project.godot` under `[autoload]` that loads at startup as a singleton accessible by its registered name from any Script (e.g., `GameManager.save()`).
_Avoid_: "singleton", "global"

**Script attachment**:
The relation between a scene Node and a Script — the Node's `script` property points at the Script's `res://` path.

**Resource**:
A `.tres` file containing a serialized non-Node data object (materials, themes, custom `Resource` subclasses). Out of v1 scope for the fork.

### GitNexus fork (Godot-specific additions)

**GDScript LanguageProvider**:
The `LanguageProvider` implementation under `src/core/ingestion/languages/gdscript/` mapping `tree-sitter-gdscript` captures to GitNexus's unified semantic tags (`@definition.class`, `@call.name`, …).

**`scenes` phase**:
A new pipeline phase between `structure` and `parse` that reads `.tscn` and `project.godot` files via `tree-sitter-godot-resource` and indexes scene trees, Autoload registrations, and external resource references.

**`godot-crossref` phase**:
A new pipeline phase after `parse` that joins indexed scene data with parsed GDScript symbols and emits the Godot-specific edges.

**`CONNECTS_SIGNAL` edge**:
The one new edge type added to GitNexus's schema. Represents a Signal connection from an emitter scene Node's Signal to a target scene Node's method.

## Relationships

- A **Scene** contains many **scene Node**s organized in a tree.
- A **scene Node** has zero or one **Script** (via Script attachment).
- A **Script** declares zero or more **Signal**s.
- A **Signal connection** wires a Signal on a scene Node to a method on another scene Node (the target method lives in the target Node's attached Script).
- A **Scene** may instance other **Scene**s, producing a Scene instance Node.
- An **Autoload** is a Script registered globally; any Script may reference it by its registered name.

## Example dialogue

> **Agent:** "Where is `enemy_died` handled in the codebase?"
> **Graph:** "Two **Signal connection**s in `level_1.tscn` and `boss_arena.tscn` wire `Enemy.enemy_died` to `Player._on_enemy_died`. Also one runtime `connect()` call in `wave_manager.gd`."
> **Agent:** "So I need to model both declarative and imperative wiring?"
> **Domain expert:** "v1 covers declarative `[connection]` entries via `CONNECTS_SIGNAL` edges. Runtime `connect()` calls show up as ordinary `CALLS` edges from the GDScript LanguageProvider — they're in the graph but not typed as Signal connections."

## Flagged ambiguities

- **"Scene"** was used for both a Godot `.tscn` file and a high-level game stage ("menu scene", "gameplay scene"). Resolved: only the file-level meaning belongs here. Game stages are an emergent property of the Scene graph, not a distinct concept.
- **"Node"** is overloaded: Godot's scene-tree Node vs. graph-database node (GitNexus). When ambiguity matters use "scene Node" vs "graph node".
- **"Signal"** spans the `signal` keyword (declaration), Signal connection (declarative wiring), and `connect()` (runtime wiring). Use the precise term per context.
