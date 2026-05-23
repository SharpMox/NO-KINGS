# Godot graph schema: hybrid extension with one new edge type

The GitNexus fork must represent Godot-specific relationships (Signal connections, Scene instancing, Script attachment, Autoload references) in a graph whose existing 44-node / 21-edge vocabulary was built around code-only languages. We reuse existing types where the semantics are defensible and add exactly one new edge type — `CONNECTS_SIGNAL` — for declarative Signal wiring, because conflating Signal connections with `CALLS` would pollute every existing call-graph query.

## Considered Options

- **Conservative — reuse only.** Encode Signal connections as `CALLS` with `reason='signal'`. Rejected: pollutes call-graph queries, every consumer needs to filter, and the encoding is easy to forget.
- **Hybrid — chosen.** Reuse: Scene ≈ `Class`, scene Node ≈ `Property`, Scene instance ≈ `USES`, Script attachment ≈ `MEMBER_OF`, Autoload ≈ `Module` + `IMPORTS`. Add `CONNECTS_SIGNAL` only. One new edge type is small enough to defend in an upstream PR.
- **Additive — first-class Scene/Signal/Autoload nodes + 3-4 new edge types.** Cleanest semantics. Rejected: touches `gitnexus-shared/types.ts`, the LadybugDB schema, and the MCP tool surface — much harder to upstream and much more rebase pain on every fork sync.

## Consequences

- Signal wiring queries use a dedicated edge type; existing `CALLS`-based agent queries stay untouched.
- Scene instancing and Script attachment appear in the graph as generic `USES` / `MEMBER_OF` edges. To preserve queryability without new types, the `godot-crossref` phase sets `reason` (e.g. `'scene-instance'`, `'script-attached'`) and `source_file_kind` (`'tscn'`) on each emitted edge.
- Upstream PR diff stays small: one new edge type in shared schema + the GDScript `LanguageProvider` + two new pipeline phases.
- If real-world use reveals that the muddy `USES`/`MEMBER_OF` semantics cost more than the schema-cleanliness saves, we revisit by promoting `INSTANCES_SCENE` and `ATTACHES_SCRIPT` to first-class edges in a follow-up ADR.
