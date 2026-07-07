# NO-KINGS

A fairy-chess project in two parts:

1. **The reference site** — what lives in this repo right now: a static HTML/CSS/JS
   site documenting every piece in NO-KINGS (a filterable codex, a relationship
   graph + merge matrix, promotion/fusion/inversion references, a Betza-notation
   sandbox, and a 100-piece encyclopedia).
2. **The game** *(in progress)* — a Godot 4 mobile game (Android + iOS) of the same
   fairy-chess system, bootstrapped in `game/` (Godot 4.6, portrait 480×800). The MVP
   is being built desktop-first from the plan-file spec; the Notion GDD is the design
   source of truth.

> ## ⚠️ Always ship changes via a pull request — never push to `main`
> **Every change goes on a branch off `main` and lands through a PR.** No direct
> commits or pushes to `main` — not for one-line fixes, content edits, follow-ups,
> or "tiny" tweaks. The flow is always: branch → commit → push the branch →
> `gh pr create`. Do not run `git push origin main` or fast-forward `main` locally.
> If the user explicitly asks to push to `main`, confirm that's what they want first.

---

## The reference site (current work)

Pure static **HTML + vanilla JS** — no build step, no framework, no bundler, no
tests, no servers. Deployed as plain static files (note the `.nojekyll`).

**Pages** — each is a self-contained HTML file with inline `<style>` + `<script>`:

- `index.html` — redirects to the codex.
- `codex.html` — the 38 curated pieces; card + list views, filters, piece relations.
- `graph.html` — two tabs: a force-directed relationship **Graph** and a merge/fusion **Matrix**.
- `promotion.html` · `fusion.html` · `inversion.html` — the 8 promotion chains, the fusions, and the inversion pairs.
- `betza.html` — Betza "funny notation" reference + a live sandbox that renders any string.
- `encyclopedia/index.html` — 100-piece visual reference, grouped by family/origin.

**Shared code** lives in `assets/`: `site.css` (palette, sticky nav, footer, base +
shared a11y), `board.js` (SVG board / movement-diagram renderer), `theme.js` (light/dark
toggle, `fp-theme` in localStorage), `tabs.js` (per-page tab persistence).

**Data is the single source of truth** in `data/`: `pieces-codex.js` (38 pieces),
`pieces-encyclopedia.js` (100), `promotions.js` (8 chains), `fusions.js` (additive +
synergistic). Pages load these via `<script src>` and derive everything (graph edges,
matrix cells, card relations, counts) from them. **Do not keep inline copies of this
data** — past bugs came from pages duplicating `PIECES`/`FUSIONS` inline and drifting;
load the shared file instead.

### Conventions

- **Mobile-friendly without breaking desktop.** Put phone-only CSS behind
  `@media (max-width: 560px)` (the established breakpoint). Prove desktop is untouched
  with a before/after pixel-diff at 1280px (target **0px**); anything intentionally
  site-wide is the exception and should be called out.
- **Verify in a real browser.** Serve with `python3 -m http.server` and drive Playwright
  (installed under `/tmp/node_modules`) to check: every page returns 200, zero console
  errors in light + dark, no horizontal overflow on mobile, plus visual spot-checks.
  Run `node --check` on extracted inline scripts after editing JS.
- **Match the surrounding page.** Styles/scripts are inline per page — keep edits in the
  same idiom and density as the file you're touching.

---

## The game (planned — Godot)

Not started yet. When it is, this is the intended setup:

- **Backlog lives in Linear.** Use the `mcp__linear__*` tools (`list_issues`, `get_issue`,
  `save_issue`, `save_comment`, …). Each issue is one unit of work; one issue → one branch → one PR.
- **Load the relevant Godot skill before writing GDScript:** `godot-best-practices`,
  `godot-gdscript-patterns`, `godot-ui`, `godot-mcp`. When in doubt, load all four.
- **Scope discipline.** No defensive code, speculative features, or backwards-compat
  shims. Out-of-scope discoveries open a follow-up Linear issue — don't expand the change.
- **UI first, bypasses second.** Any change touching UI runs the click probes BEFORE the
  headless sweeps: `godot --path game -s tests/test_menu_clicks.gd` and
  `-s tests/test_game_clicks.gd` (windowed — Godot 4.6 headless drops GUI picking).
  The CLI bypasses (`--scenario`, `--autoplay`, `--screenshot`) skip the interactive
  layer entirely; they once green-lit a fully dead main menu. Extend the probes when
  adding buttons/flows.
- **Non-regression suite after every change:** `game/tests/run_all.sh` — click probes
  first, then the headless suites, `tests/test_scenarios.gd` (boots + bot-plays every
  TEST scenario), and a full autoplay run. It must be ALL GREEN before a commit.
  New interaction or edge case ⇒ add a scenario to `game/data/scenarios.gd` (manual
  sandbox + swept automatically) and, if it's clickable UI, a probe check too.

### Godot agent tools (MCP)

Agents drive the live Godot editor via the [Godot AI](https://github.com/hi-godot/godot-ai)
MCP server (MIT, ~120 ops / 39 tools). Load the `godot-mcp` skill before any task that
touches scenes, nodes, signals, materials, animations, particles, UI, cameras, or
environments. Hand-edit `.tscn`/`.gd` only for pure GDScript function bodies; everything
structural goes through the MCP.

**Status: vendored** — the addon lives at `game/addons/godot_ai/` and is enabled in
`game/project.godot` (it self-disables in headless runs). Remaining one-time setup, in
the editor: open the Godot AI dock and press "Configure all" to wire every detected MCP
client (requires `uv`: https://docs.astral.sh/uv/getting-started/installation/).
Deferred: GitNexus (no GDScript support), GodotIQ Pro (paid), Coding-Solo/godot-mcp
(subsumed by Godot AI).

---

## Working method (both parts)

- **Grill before building — almost always.** For any new feature, refactor, design
  change, or non-trivial decision, start with `grill-with-docs` (or `grill-me` for
  non-code planning). Skip only for mechanical work (renames, formatting, applying an
  already-grilled plan) or when the user says "just do it" / "skip the grilling".
- **Always cite sources.** Every factual claim or design decision names where it came
  from: a file + line, a skill, a doc URL, a commit, an issue, or a direct user
  instruction. No "I think" / "usually" without a pointer — say "no source — assumption"
  so it can be challenged.
- **Prioritise trusted sources**, highest first:
  1. Explicit user instructions in this conversation.
  2. This `CLAUDE.md`, project docs, ADRs, `.agents/skills/*/SKILL.md`.
  3. The codebase itself (`git log`, current file contents).
  4. Official upstream docs (Godot, Linear API, MDN/web platform from canonical domains).
  5. Locked external skills (`skills-lock.json`).
  6. General training-data knowledge / blogs / Stack Overflow — lowest; a hypothesis to verify.
  Never let a lower tier override a higher one without flagging the conflict.

## Commits

```
<type>(<scope>): <description>
```

Types: `feat`, `fix`, `refactor`, `style`, `docs`, `chore`. One commit per logical
change. When a Linear issue drives the work (the game), add a `Refs: <issue-id>` trailer
(e.g. `Refs: ENG-42`); reference-site changes don't need one.

## Agent tooling

Skills live in `.agents/skills/` (the canonical copy — edit there, never duplicate) and
are surfaced to ~29 agent CLIs via generated `.<tool>/skills/` symlinks (`.claude/`,
`.roo/`, `.continue/`, `.goose/`, …). Those `.<tool>/` dirs are **gitignored and
generated — never hand-edit them**. Regenerate with:

```sh
./tools/refresh-agent-skill-links.sh
```

Add a tool by appending to `TOOLS` in that script; expose a new skill by appending its
directory to `SKILLS`.

## Pointers

- `data/` — the canonical piece / promotion / fusion data for the reference site.
- `CONTEXT.md` — domain glossary (Godot + GitNexus-fork terms, for the game).
- `docs/adr/` — architecture decision records.
- `skills-lock.json` — installed external skills with content hashes.
- Godot skills: `.agents/skills/godot-{best-practices,gdscript-patterns,ui,mcp}/SKILL.md`.
