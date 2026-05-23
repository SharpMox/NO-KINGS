# NO-KINGS

A Godot 4 mobile game built by AI agents driven from Linear (issues are the unit of work). The agent stack includes a fork of GitNexus extended to understand Godot files; the fork-specific terms live in their own subsection below.

## Language

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
