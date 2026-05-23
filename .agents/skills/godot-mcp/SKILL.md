---
name: godot-mcp
description: >-
  Use the Godot AI MCP server (hi-godot/godot-ai) to drive the live Godot 4 editor
  instead of hand-editing scenes, nodes, signals, materials, animations, particles,
  UI, cameras, or environments. Load this skill before any task that touches Godot
  project files. Skip only for pure GDScript text edits where no editor state is
  involved (algorithms, math, utility functions inside an existing class).
---

# Godot MCP

Source: [hi-godot/godot-ai](https://github.com/hi-godot/godot-ai) — MIT-licensed, ~120 ops across ~39 MCP tools. Live editor control via a Godot addon + Python MCP server (`uv`-based).

## When to use vs. write files

Prefer Godot AI tools whenever the change is **structural** — anything Godot's editor would normally own:

| Task | Use MCP tool | Acceptable to edit by hand |
|------|--------------|----------------------------|
| Create/rename a scene | ✓ | — |
| Add/move/delete a node in a scene | ✓ | — |
| Wire a signal (connect/disconnect) | ✓ | — |
| Set node properties (position, anchors, modulate, etc.) | ✓ | — |
| Configure UI containers, themes, anchors | ✓ | — |
| Materials, shaders, animations, particles, cameras, environments | ✓ | — |
| Pure GDScript function bodies, math, algorithms | — | ✓ (edit `.gd` directly) |
| Project-wide `project.godot` settings | ✓ (when a tool exists) | ✓ (otherwise) |
| Asset imports (sprites, audio, models) | — | ✓ (filesystem) |

**Rule of thumb:** if Godot's editor would refuse to save a hand-edited `.tscn` due to UID/format drift, prefer the MCP path.

## Tool families (per Godot AI docs)

- **Scenes** — create, open, save, instance, change root.
- **Nodes** — add, remove, rename, reparent, set type, query tree.
- **Scripts** — attach, detach, edit, query exports.
- **Signals** — list, connect, disconnect, query connections.
- **UI** — Control nodes, anchors, containers, themes, fonts.
- **Materials / Shaders** — create, assign, configure.
- **Animations** — AnimationPlayer/Tree setup, tracks, keys.
- **Particles** — GPUParticles2D/3D, process material params.
- **Cameras** — Camera2D/3D positioning, follow targets, limits.
- **Environments** — WorldEnvironment, sky, fog, GI.
- **Project / Editor** — run scene, capture output, screenshot, query state.

Run `mcp__godot_ai__list_tools` (or the equivalent listing in your CLI) on a live session to enumerate exact tool names — they evolve with addon versions.

## Workflow

1. **Confirm connection.** Before structural work, list the MCP tools. If no `godot-ai` server is connected, the addon isn't enabled or the MCP client isn't configured — flag in output and fall back to file edits only if explicitly authorized.
2. **Read before writing.** Use a `get_scene_tree` / `list_nodes` style tool to learn current state before issuing mutations. Don't blind-apply.
3. **Mutate via tools.** Each structural change is one tool call. Reflect the resulting state back into the conversation so the agent's mental model stays in sync with the editor.
4. **Save and verify.** After a batch of mutations, save the scene via the tool, then run the scene (or capture a screenshot) to confirm visual/behavioral expectations.
5. **Commit.** The `.tscn` diff will be tool-authored — clean and minimal. Hand-edited `.tscn` diffs are a smell; investigate before committing.

## Guardrails

- **Never invent a tool name.** If a tool you expect isn't in the live listing, stop and report — don't fabricate.
- **One scene at a time.** Don't issue cross-scene mutations in parallel; the editor serializes state and you'll lose changes.
- **Worktree-first still applies.** All editor mutations happen against the worktree's project copy, not main. Never edit on main (see `CLAUDE.md` non-negotiables).
- **Stale index after merges.** Godot AI doesn't (currently) re-index on `git merge`. After merging a feature branch back to `main`, re-open the project on the integration branch if you intend to verify visually.
- **Don't commit `addons/godot_ai/`** unless explicitly decided — the user should choose whether the plugin vendors into the repo or stays an out-of-band install.

## Setup status (project-level)

- **Pre-bootstrap state** (current): no `project.godot` yet. Tools unavailable until the Godot mobile project is initialized (see the Linear issue for the mobile bootstrap).
- **Post-bootstrap**: install the addon per the [Godot AI Quick Start](https://github.com/hi-godot/godot-ai#quick-start), enable it in Project Settings, then use the Godot AI dock's "Configure all" to wire MCP across every detected agent CLI.

If you load this skill and the MCP tools don't exist, the project hasn't been bootstrapped yet — say so and exit cleanly. Don't fabricate scene work.

## Related skills

- `[[godot-best-practices]]` — Godot 4.x coding standards, scene organization.
- `[[godot-gdscript-patterns]]` — GDScript architecture (loaded for `.gd` text edits).
- `[[godot-ui]]` — Control nodes, themes, responsive layouts (loaded for UI structural work).
