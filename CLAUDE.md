# NO-KINGS

Godot 4 mobile game (Android + iOS), built by autonomous agents under [Noodle](https://poteto.github.io/noodle).

## Repo state

Pre-bootstrap. Noodle framework is configured but no Godot project exists yet — no `project.godot`, no `.gd` scripts. The first backlog item in `todos.md` covers initializing the mobile project.

## How work flows

1. Backlog lives in `todos.md` (managed via `adapters/backlog-*` — don't hand-edit IDs).
2. `noodle start` runs the loop: scheduler reads state → writes `.noodle/orders-next.json` → loop dispatches agents in worktrees → work merges back to `main`.
3. Skills live in `.agents/skills/` and are surfaced to every agent CLI via symlinks under each `.<tool>/skills/` directory. Don't duplicate skill content — edit the canonical copy in `.agents/skills/`.

## Non-negotiables for any agent touching this repo

- **Worktree-first.** Never edit files on `main`. Use `noodle worktree create <name>` and either absolute paths or `noodle worktree exec`. Never `cd` into a worktree — if it's pruned mid-session, the shell dies.
- **Load the relevant Godot skill before writing GDScript.** `godot-best-practices`, `godot-gdscript-patterns`, `godot-ui`, `godot-mcp`. When in doubt, load all four.
- **Autonomous execution.** The `execute` skill operates without user prompts. Track work with Tasks; emit `stage_yield` when the deliverable is done.
- **Scope discipline.** No defensive code, no speculative features, no backwards-compat shims. Out-of-scope discoveries go in quality review notes.

## Working method

- **Grill before building — almost always.** For any new feature, refactor, design change, or non-trivial decision, start with the `grill-with-docs` skill (or `grill-me` for non-code planning). Skip only when the task is mechanical (renames, formatting, applying an already-grilled plan) or when the user explicitly says "just do it" / "skip the grilling". When in doubt, grill.
- **Always cite sources.** Every factual claim, recommendation, or design decision must name where it came from: a specific file + line, a skill name, a doc URL, a commit, an issue, or a direct user instruction in this conversation. "I think" / "usually" / "in general" without a pointer is not acceptable. If you don't have a source, say "no source — assumption" so the user can challenge it.
- **Prioritise trusted sources.** When sources disagree, rank them in this order:
  1. **Explicit user instructions in this conversation** — highest.
  2. **This `CLAUDE.md`, project docs, ADRs, and `.agents/skills/*/SKILL.md`** — the repo's codified intent.
  3. **The codebase itself** — `git log`, current file contents, tests.
  4. **Official upstream docs** — Godot, Noodle, language/runtime docs from their canonical domains.
  5. **Locked external skills** (`skills-lock.json`) — vetted but third-party.
  6. **General training-data knowledge / blog posts / Stack Overflow** — lowest; treat as a hypothesis to verify, not a fact.
  Never let a lower-tier source override a higher-tier one without flagging the conflict to the user.

## Commits

```
<type>(<scope>): <description>

Refs: #<backlog-id>
```

Types: `feat`, `fix`, `refactor`, `test`, `docs`, `chore`. One commit per logical change. `Refs:` only when a backlog item drives the work.

## Key files

- `.noodle.toml` — runtime config (mode, routing defaults, skills paths, adapter scripts).
- `todos.md` — backlog (next-id tracked in an HTML comment).
- `skills-lock.json` — installed external skills with content hashes.
- `.agents/skills/` — canonical skill location. `noodle`, `schedule`, `execute`, plus the four `godot-*` domain skills.
- `adapters/backlog-{add,sync,done,edit}` — POSIX-sh shims Noodle calls to read/write `todos.md`.
- `tools/refresh-agent-skill-links.sh` — regenerates the `.<tool>/skills/` symlink farms (one proxy per agent CLI) pointing at `.agents/skills/`. Run after fresh clone or after adding a tool/skill.

## Godot agent tools (MCP)

Agents drive the live Godot editor via the [Godot AI](https://github.com/hi-godot/godot-ai) MCP server (MIT, ~120 ops / 39 tools). Load the `godot-mcp` skill before any task that touches scenes, nodes, signals, materials, animations, particles, UI containers, cameras, or environments. Hand-edit `.tscn`/`.gd` files only for pure GDScript function bodies; everything structural goes through the MCP.

**Status:** the addon is **not yet installed** — `project.godot` doesn't exist (see `todos.md` #1). Once the Godot project is bootstrapped:

```sh
# 1. Install uv if missing: https://docs.astral.sh/uv/getting-started/installation/
# 2. Vendor the addon
git clone https://github.com/hi-godot/godot-ai.git /tmp/godot-ai
cp -r /tmp/godot-ai/plugin/addons/godot_ai addons/
# 3. Enable in Project Settings > Plugins
# 4. Open the Godot AI dock and press "Configure all" to wire every detected MCP client
```

Until then, the `godot-mcp` skill loads cleanly but reports "tools unavailable — bootstrap first" and falls back to file edits only when explicitly authorized.

Deferred (not now): GitNexus (no GDScript support), GodotIQ Pro (paid), Coding-Solo/godot-mcp (subsumed by Godot AI).

## Agent-tool proxies

The repo exposes the canonical Godot skills to ~29 agent CLIs via `.<tool>/skills/` symlinks (`.claude/`, `.roo/`, `.continue/`, `.goose/`, etc.). These directories are **gitignored and generated** — never hand-edit them. To regenerate:

```sh
./tools/refresh-agent-skill-links.sh
```

To add a tool, append its name to `TOOLS` in that script. To expose a new skill across all tools, append its directory name to `SKILLS`. `noodle`, `execute`, `schedule` stay internal to `.agents/skills/` and are not exposed via proxies.

## Pointers

- Noodle CLI + scheduling: see `.agents/skills/noodle/SKILL.md`.
- Writing scheduled skills: `.agents/skills/noodle/references/skill-authoring.md`.
- Implementation methodology: `.agents/skills/execute/SKILL.md`.
- Scheduling rules (one-plan-at-a-time, model routing): `.agents/skills/schedule/SKILL.md`.
