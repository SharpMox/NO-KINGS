---
name: execute
description: Implementation methodology for executing tasks. Provides the how — scoping, decomposition, worktree workflow, verification, and commit conventions.
schedule: "When backlog items are ready for implementation"
---

# Execute

Implementation methodology. The order's prompt provides task context at runtime. This skill covers process — how work gets done, not what work to do.

Operate fully autonomously. Never ask the user. Don't stop until the work is fully complete.

**Track all work with Tasks** (TaskCreate, TaskUpdate, TaskList). One task per decomposed change; mark in_progress when starting, completed when done.

## Domain Skills

This is a Godot 4 mobile game project. Always load these domain skills before implementing:

- **godot-best-practices** — Godot 4.x coding standards, scene organization, signals, resources, state machines, performance
- **godot-gdscript-patterns** — GDScript architecture patterns, signals, scenes, optimization
- **godot-ui** — Godot UI system, Control nodes, themes, responsive layouts, menus, HUDs

Load the relevant domain skill(s) for the task at hand. When in doubt, load all three.

## Execution Flow

### 1. Scope

Establish what needs doing:

- **Plan phase**: Read the assigned phase from the plan files. Read the overview for scope boundaries.
- **Backlog item**: Read the todo from `todos.md`. If a linked plan exists, read it. Otherwise, scope from the description.
- **Ad-hoc request**: The prompt is the scope. Identify affected files before starting.

Output: a clear, bounded description of what changes and what doesn't.

### 2. Decompose

Break scope into discrete changes. Each change:
- One function/type + its tests, OR one bug fix
- Independently compilable
- One conventional commit

Single-change scopes skip decomposition.

### 3. Implement

#### Worktree First — Non-Negotiable

**Never edit files on main.** Multiple sessions run concurrently; editing main causes merge conflicts and lost work.

If CWD is already inside `.worktrees/`, use it. Otherwise: `noodle worktree create <descriptive-name>`

Use absolute paths or `noodle worktree exec <name> <cmd>`. **Never `cd` into a worktree** — if it gets removed while the shell is inside, the session dies permanently.

Commit inside the worktree. When done: `noodle worktree merge <name>`

Skip only when the user is interactively driving a single-agent session and explicitly chooses main.

#### Delegation

- **Self-execute**: Single change, or tightly coupled changes.
- **Sub-agents**: 2+ independent changes touching different files. Front-load context: scope, relevant code, skill name.
- **Team execution**: 2+ parallelizable phases in a plan. Lead orchestrates, teammates implement in separate worktrees.

### 4. Verify

Every change must pass before committing. Fix and re-verify on failure. Never commit failing code.

Run whatever verification is appropriate for the project's stack:
- Unit tests, linting, type checking
- Integration/E2E tests if available
- `git diff --stat` — matches expected scope

### 5. Commit

```
<type>(<scope>): <description>

Refs: #<issue-ID>
```

Types: `feat`, `fix`, `refactor`, `test`, `docs`, `chore`. Scope: package or area changed. Refs: include when linked issue exists; omit for ad-hoc work.

One commit per logical change.

### 6. Yield

After all changes are committed and verified, emit `stage_yield` to signal the deliverable is complete:

```bash
noodle event emit --session $NOODLE_SESSION_ID stage_yield --payload '{"message": "Implemented: <brief summary>"}'
```

This tells the Noodle backend the stage's work is done.

## Scope Discipline

- Only change what's in scope. No defensive code, backwards-compat shims, or speculative features.
- Out-of-scope discoveries go in the quality review notes — don't change them.
- Wrong or incomplete plan/requirements: flag it in output, don't silently deviate.
