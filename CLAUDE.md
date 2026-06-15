# NO-KINGS

Godot 4 mobile game (Android + iOS), driven by AI agents working from Linear issues.

> ## ⚠️ Always ship changes via a pull request — never push to `main`
> **Every change goes on a branch off `main` and lands through a PR.** No direct
> commits or pushes to `main` — not for one-line fixes, content edits, follow-ups,
> or "tiny" tweaks. The flow is always: branch → commit → push the branch →
> `gh pr create`. Do not run `git push origin main` or fast-forward `main` locally.
> If the user explicitly asks to push to `main`, confirm that's what they want first.

## Repo state

Pre-bootstrap. No Godot project exists yet — no `project.godot`, no `.gd` scripts. The first Linear issue covers initializing the mobile project.

## How work flows

1. **Backlog lives in Linear.** Use the `mcp__linear__*` tools (`list_issues`, `get_issue`, `save_issue`, `save_comment`, etc.) to read, update, and close work. Each issue is one unit of work.
2. **One issue, one branch, one PR.** Branch off `main`, implement against the issue, open a PR that closes it. No local scheduler dispatches agents — the user (or an AFK / cloud agent) picks up an issue and works it.
3. **Skills live in `.agents/skills/`** and are surfaced to every agent CLI via symlinks under each `.<tool>/skills/` directory. Don't duplicate skill content — edit the canonical copy in `.agents/skills/`.

## Non-negotiables for any agent touching this repo

- **Worktree-first.** Never edit files on `main`. Use `git worktree add ../no-kings-<slug> <branch>` for isolation — keeps experimental work and parallel investigations from polluting the main checkout, and lets you switch contexts without stashing. Never `cd` into a worktree from your primary shell — if it's pruned while the shell is inside, the session dies. Use absolute paths or `git -C <worktree>` instead.
- **Load the relevant Godot skill before writing GDScript.** `godot-best-practices`, `godot-gdscript-patterns`, `godot-ui`, `godot-mcp`. When in doubt, load all four.
- **Scope discipline.** No defensive code, no speculative features, no backwards-compat shims. Out-of-scope discoveries open a follow-up Linear issue — don't expand the current change.

## Working method

- **Grill before building — almost always.** For any new feature, refactor, design change, or non-trivial decision, start with the `grill-with-docs` skill (or `grill-me` for non-code planning). Skip only when the task is mechanical (renames, formatting, applying an already-grilled plan) or when the user explicitly says "just do it" / "skip the grilling". When in doubt, grill.
- **Always cite sources.** Every factual claim, recommendation, or design decision must name where it came from: a specific file + line, a skill name, a doc URL, a commit, an issue, or a direct user instruction in this conversation. "I think" / "usually" / "in general" without a pointer is not acceptable. If you don't have a source, say "no source — assumption" so the user can challenge it.
- **Prioritise trusted sources.** When sources disagree, rank them in this order:
  1. **Explicit user instructions in this conversation** — highest.
  2. **This `CLAUDE.md`, project docs, ADRs, and `.agents/skills/*/SKILL.md`** — the repo's codified intent.
  3. **The codebase itself** — `git log`, current file contents, tests.
  4. **Official upstream docs** — Godot, Linear API, language/runtime docs from their canonical domains.
  5. **Locked external skills** (`skills-lock.json`) — vetted but third-party.
  6. **General training-data knowledge / blog posts / Stack Overflow** — lowest; treat as a hypothesis to verify, not a fact.
  Never let a lower-tier source override a higher-tier one without flagging the conflict to the user.

## Commits

```
<type>(<scope>): <description>

Refs: <linear-issue-id>
```

Types: `feat`, `fix`, `refactor`, `test`, `docs`, `chore`. One commit per logical change. `Refs:` carries the Linear issue identifier (e.g., `Refs: ENG-42`) when an issue drives the work.

## Key files

- `skills-lock.json` — installed external skills with content hashes.
- `.agents/skills/` — canonical skill location. The four `godot-*` domain skills (best-practices, gdscript-patterns, ui, mcp).
- `tools/refresh-agent-skill-links.sh` — regenerates the `.<tool>/skills/` symlink farms (one proxy per agent CLI) pointing at `.agents/skills/`. Run after fresh clone or after adding a tool/skill.
- `CONTEXT.md` — domain glossary (Godot terms + GitNexus-fork terms).
- `docs/adr/` — architecture decision records.

## Godot agent tools (MCP)

Agents drive the live Godot editor via the [Godot AI](https://github.com/hi-godot/godot-ai) MCP server (MIT, ~120 ops / 39 tools). Load the `godot-mcp` skill before any task that touches scenes, nodes, signals, materials, animations, particles, UI containers, cameras, or environments. Hand-edit `.tscn`/`.gd` files only for pure GDScript function bodies; everything structural goes through the MCP.

**Status:** the addon is **not yet installed** — `project.godot` doesn't exist (see the Linear issue for initializing the Godot mobile project). Once the Godot project is bootstrapped:

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

To add a tool, append its name to `TOOLS` in that script. To expose a new skill across all tools, append its directory name to `SKILLS`.

## Pointers

- Godot AI MCP usage: `.agents/skills/godot-mcp/SKILL.md`.
- Godot best practices: `.agents/skills/godot-best-practices/SKILL.md`.
- GDScript architecture patterns: `.agents/skills/godot-gdscript-patterns/SKILL.md`.
- Godot UI system: `.agents/skills/godot-ui/SKILL.md`.
- Domain glossary: `CONTEXT.md`.
- Architecture decisions: `docs/adr/`.
