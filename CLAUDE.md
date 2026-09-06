# NO-KINGS

NO KINGS — *An explosive Chess riot* (the tagline; the game is described as a Chess riot, never by a variant-genre label — user ruling 2026-09-06). A project in two parts:

1. **The reference site** — what lives in this repo right now: a static HTML/CSS/JS
   site documenting every piece in NO-KINGS (a filterable codex, a relationship
   graph + merge matrix, promotion/fusion/inversion references, a Betza-notation
   sandbox, and a 100-piece encyclopedia).
2. **The game** *(in progress)* — a Godot 4 mobile game (Android + iOS) of the same
   piece system, bootstrapped in `game/` (Godot 4.7, portrait 480×800). The MVP
   is being built desktop-first from the plan-file spec; the Notion GDD is the design
   source of truth.

> ## ⚠️ Always ship changes via a pull request — never push to `main`
> **Every change goes on a branch off `main` and lands through a PR.** No direct
> commits or pushes to `main` — not for one-line fixes, content edits, follow-ups,
> or "tiny" tweaks. The flow is always: branch → commit → rebase on `main` → push the
> branch → `gh pr create`. Do not run `git push origin main` or fast-forward `main` locally.
> If the user explicitly asks to push to `main`, confirm that's what they want first.

---

## The reference site (current work)

Pure static **HTML + vanilla JS** — no build step, no framework, no bundler, no
tests, no servers. Deployed as plain static files (note the `.nojekyll`).

**Pages** — each is a self-contained HTML file with inline `<style>` + `<script>`:

- `index.html` — redirects to the codex.
- `codex.html` — the 38 curated pieces; card + list views, filters, piece relations.
- `graph.html` — two tabs: a force-directed relationship **Graph** and a merge/fusion **Matrix**.
- `promotion.html` · `fusion.html` · `inversion.html` — the 8 Families (promotion chains), the fusions, and the inversion pairs.
- `betza.html` — Betza "funny notation" reference + a live sandbox that renders any string.
- `encyclopedia/index.html` — 100-piece visual reference, grouped by family/origin.
- `artefacts.html` — the 180 artefacts as a **density map wired to a ledger**: a sticky
  rail of contribution-calendar grids (one square per artefact, shaded by bonus-tag
  count) beside a one-line-per-artefact list, with an SVG thread from every on-screen row
  back to its own square. The map groups by rarity or by bonus, and the filter chips
  always show whichever axis the map is *not* grouped by. **Design pilot for the
  site-wide redesign**: it deliberately does *not* link `assets/site.css` (that file
  styles `footer` as a bare element and forces `min-height:44px` onto
  `.badge`/`.filter-input` on phones, both of which fight this layout). It carries its
  own tokens, nav and footer markup, and still shares `assets/theme.js` so the light/dark
  choice stays in sync. When the look is settled, this file is the seed of the new
  `site.css`.

Two things about `artefacts.html` that are easy to break:

- **Chrome heights are measured, never assumed.** The header collapses to a burger on
  phones and the filter bar carries 4 or 9 chips, so `--nav-h` and `--bar-h` are written
  from `offsetHeight` at runtime. Hardcoding them leaves the rail tucked underneath.
- **`fitRail()` solves the column count** so the rail always fits `100dvh` minus that
  chrome without scrolling. It measures cell size with `offsetWidth`, *not*
  `getBoundingClientRect()`, because the dense dot mode applies `scale(.62)` and a
  transformed rect would latch the page into dots forever.

**Artefact artwork** has no home in this design yet: the ledger is deliberately one line
per artefact and carries no image slot. When art arrives, the expanded row is the place
for it. Whatever renders it, never emit an `<img>` for a file that does not exist — 180
missing files would be 180 console 404s and the verification rule below is *zero*
console errors.

**Shared code** lives in `assets/`: `site.css` (palette, sticky nav, footer, base +
shared a11y), `board.js` (SVG board / movement-diagram renderer), `theme.js` (light/dark
toggle, `fp-theme` in localStorage), `tabs.js` (per-page tab persistence).

**Data is the single source of truth** in `data/`: `pieces-codex.js` (38 pieces),
`pieces-encyclopedia.js` (100), `promotions.js` (8 Families), `fusions.js` (additive +
synergistic), `inversions.js` (14 pairs). Pages load these via `<script src>` and derive
everything (graph edges, matrix cells, card relations, counts) from them. **Do not keep
inline copies of this data** — past bugs came from pages duplicating `PIECES`/`FUSIONS`
inline and drifting; load the shared file instead.

A `data/` edit therefore reaches every page with **no rebuild** — the pages hardcode
nothing and read it at load time. Two exporters carry the same data to the Godot side:

- `node tools/export-game-pieces.mjs` -> `game/data/pieces.json` + `fusions.json`
- `node tools/export-game-artefacts.mjs` -> `game/data/artefacts.json`

> **`data/artefacts.js` feeds BOTH the game and the public reference site.** This is easy to
> forget, because game work touches it constantly (every Artefact slice edits it and re-runs
> the exporter) while `artefacts.html` reads the very same file directly, at load time, with
> no build step in between. A malformed entry, a missing `bonus` array or a renamed field
> breaks a public page that no Godot test covers.
>
> So after editing `data/artefacts.js`, the Godot suite passing is **not** sufficient. Check
> the site too: `python3 -m http.server`, load `artefacts.html`, confirm zero console errors.
> A quick structural check catches most of it:
> ```sh
> node -e 'eval(require("fs").readFileSync("data/artefacts.js","utf8"));
>   console.log(ARTEFACTS.length, ARTEFACTS.filter(a=>!a.name||!a.effect||!Array.isArray(a.bonus)).length)'
> ```

### Conventions

- **Mobile-friendly without breaking desktop.** Put phone-only CSS behind
  `@media (max-width: 560px)` (the established breakpoint). Prove desktop is untouched
  with a before/after pixel-diff at 1280px (target **0px**); anything intentionally
  site-wide is the exception and should be called out.
- **Verify in a real browser, with `agent-browser`.** Serve with `python3 -m http.server`,
  then drive `agent-browser` (on PATH) to check: every page returns 200, zero
  console errors in light + dark, no horizontal overflow on mobile, plus visual spot-checks.
  Run `node --check` on extracted inline scripts after editing JS.

  ```sh
  agent-browser open "http://localhost:8899/privacy.html" --viewport 390x844
  agent-browser console --level error
  agent-browser eval "document.documentElement.scrollWidth - window.innerWidth"   # expect 0
  agent-browser screenshot /path/out.png
  ```

  **Not Playwright.** This file used to say Playwright was installed under
  `/tmp/node_modules`; that install is broken (the `playwright` package there has no
  `package.json`, so both `require` and ESM import fail) and it is a temp directory that
  will not survive. `agent-browser` is on PATH, needs no project dependency, and drove the
  whole check first time. Verified 2026-09-02 while adding privacy.html/terms.html.
- **Match the surrounding page.** Styles/scripts are inline per page — keep edits in the
  same idiom and density as the file you're touching.

---

## The game (Godot 4.7 — built, and the larger half of this repo)

Portrait 480×800, desktop-first. The MVP shipped and then some: ~30 merged slices, a
5-tier difficulty system, 12 Piece Buffs, a 16-King cast, 141 of 180 Artefacts, cloud-save
scaffolding, and a 22-suite test harness.

### Where the work lives

- **The backlog is Linear** (user ruling 2026-09-06): the PRD as a project, one issue per
  slice (status, labels, an outcome comment on close), and non-blocking findings as issues
  labelled `flag`. Commits and PRs carry `Refs: ENG-NN`. While the Linear MCP was absent the
  backlog lived in `.scratch/gdd-gaps/` (`PRD.md`, `issues/NN-*.md` with a `Status:` line and
  an `## Outcome`, `FLAGS.md`); those files are being migrated into Linear and stay readable
  as history until then. If a session has no Linear MCP, say so rather than silently
  falling back to the files.
  `NOTION-QUESTIONS.md` stays in the repo: the open GDD questions, each blocking at least one
  Artefact — **read it before implementing any Artefact**, so an already-known ambiguity
  isn't rediscovered or, worse, guessed at.
- One slice → one branch → one PR, rebased on `main` before pushing, same as the reference site.
- **The Notion GDD is the design source of truth** for the catalogs (Pieces, Items,
  Artefacts, Tariffs, Piece Buffs). When Notion and the code disagree, that is a finding —
  see the drift checker below — and which side is stale is a judgement call each time. Both
  directions have happened.
- **Load the relevant Godot skill before writing GDScript:** `godot-best-practices`,
  `godot-gdscript-patterns`, `godot-ui`, `godot-mcp`. When in doubt, load all four.

### Architecture

`game.gd` is the live node — board state, turn flow, input, `_draw`. Everything else in
`game/scripts/` is a **pure logic module operating on `g` or on plain Dictionaries**, with no
nodes of its own: `rules.gd` (movement/legality/AI), `item_logic.gd`, `buff_logic.gd`,
`merge_logic.gd`, `wave_logic.gd`, `economy.gd`, `shop.gd`, `box.gd`, `save_config.gd`.
That split is why the headless suites can drive real game logic without a window.

**`artefact_hooks.gd` is the shared dispatch layer for BOTH Artefacts and Tariffs.** Read its
header before touching it — it documents the hook list and two rules that are load-bearing:

- **ctx contract.** Handlers return values through `ctx`; they compute percentages off the
  immutable `ctx.base`, never the running `ctx.amount`; and they never write `g.score`/
  `g.gold` mid-dispatch — cross-resource side-payments go through `ctx.gold_bonus` /
  `ctx.score_bonus`, applied exactly once by `Economy.earn`. Four handlers broke this and
  produced an order-dependent payout before it was written down.
- **Stacking is additive per held copy, and `run()` key-sorts** so a value touched by several
  artefacts never depends on acquisition order.

Gold, Score and the Clock all route through `Economy` (`earn`/`gain`/`add_clock`) — that
single choke point is the only reason hooking them was cheap. Anything new that a future
effect might want to modify should get the same treatment.

**ADR-0002** (`docs/adr/`): a Stock entry is a bare id String or a Dictionary carrying the
piece's opaque state. Stock never interprets that state, so per-piece additions (buffs,
capture ledgers, peak rank) ride through save/load and Extraction for free.

### Conventions learned the hard way

- **Generated data is generated.** `data/*.js` are the source; `tools/export-game-*.mjs`
  write `game/data/*.json`. **Never hand-edit the JSON** — re-run the exporter, including
  after a merge conflict in it.
- **Tests pin their RNG seed.** `_boot()` defaults to a fixed seed in every suite; opt out
  explicitly and say why. Before this, 170 of 171 fixtures ran on `randomize()` and the
  suite produced false failures that made every "ALL GREEN" claim unfalsifiable.
- **Verify independently.** Do not take a green claim — including your own subagents' — at
  face value on a branch you are about to merge. Re-run it. That has caught real
  discrepancies more than once.
- **Saves are versioned.** `save_config.gd` carries `save_version`; its header explains
  which changes are additive (default and carry on) and which need a migration. An additive
  field read with a default is safe forever; a *reshaped* field read with a default is a
  silent corruption.
- **Ambiguity goes back to Notion as a question, not into code as a guess.** Half this
  backlog existed to undo guesses. If a catalog entry cannot be implemented faithfully,
  leave it `implemented: false` and write down why.
- **Scope discipline.** No defensive code, speculative features, or backwards-compat
  shims. Out-of-scope discoveries open a follow-up Linear issue — don't expand the change.
- **UI first, bypasses second.** Any change touching UI runs the click probes BEFORE the
  headless sweeps: `godot --path game -s tests/test_menu_clicks.gd` and
  `-s tests/test_game_clicks.gd` (windowed — Godot headless still drops GUI picking, re-verified on 4.7).
  The CLI bypasses (`--scenario`, `--autoplay`, `--screenshot`) skip the interactive
  layer entirely; they once green-lit a fully dead main menu. Extend the probes when
  adding buttons/flows.
- **Run the suite in the foreground WITH AN EXPLICIT TIMEOUT: `timeout: 600000`.** This is
  the single most-repeated mistake in this repo — **four** agents have now lost their turn
  to it, with work uncommitted and unpushed. The mechanism is not carelessness: `run_all.sh`
  takes several minutes, the Bash tool's default timeout is **120s**, and on hitting that
  the harness *auto-backgrounds* the command. So "run it in the foreground" is not
  achievable by intent alone — without the explicit timeout it gets backgrounded no matter
  what you meant, and then the agent sits waiting on a task that has already ended.
  Pass `timeout: 600000` (10 minutes, the maximum) and let it block until it prints its
  verdict.
- **A/B a suspected flake by INTERLEAVING runs, not by batching them.** Running 15 on a
  branch, then 20 on `main`, and comparing the rates is invalid when the flake is
  load-sensitive: the two batches ran under different machine load, so the comparison
  measures the load, not the branch. This produced a confident and **wrong** conclusion on
  2026-08-29 — 3/15 on a branch against 0/20 on `main` "proved" the branch broke it, the PR
  was blocked, and an interleaved 20-and-20 in the same window then came back 0 and 0.
  Alternate the two in a single loop so both see identical conditions, using a second
  `git worktree` rather than checking branches out back and forth. And weigh a
  *reachability* argument ("that code cannot execute at the failure site") above a rate
  comparison — it is the stronger evidence.
- **Never run two suites at once.** The click probes are *windowed* — they open a real
  Godot window and drive real input. Two concurrent runs fight over window focus and the
  probes fail for no reason in the code. This has already produced one false failure
  (2026-08-29: three `game-clicks` cases failed while four suites ran in parallel across
  worktrees; all three passed on every one of three sequential re-runs). It matters most
  with parallel agents, where each worktree is a separate checkout but they all share one
  display: **serialise the suite runs**, don't parallelise them. A probe failure during a
  concurrent run is not evidence of a bug, and — just as important — a *pass* during one
  is not evidence of correctness either. Re-run alone before believing either result.
- **Non-regression suite after every change:** `game/tests/run_all.sh` — click probes
  first, then the headless suites, `tests/test_scenarios.gd` (boots + bot-plays every
  TEST scenario), and a full autoplay run. It must be ALL GREEN before a commit.
  New interaction or edge case ⇒ add a scenario to `game/data/scenarios.gd` (manual
  sandbox + swept automatically) and, if it's clickable UI, a probe check too.

### Piece art

Tokens live in `game/assets/pieces/` and are keyed by **codex id**, never by the
fantasy display name (`chancellor-light.png`, not `dragonlord-light.png` — see the
id convention below). Two files per piece:

- `<id>-light.png` — the **player** token · `<id>-dark.png` — the **enemy** token.

The art carries its own side colour, so `_draw_piece` passes `Color.WHITE` and only
multiplies in state tints (spent grey, drag-ghost alpha). A piece with no painted
pair falls back to a single monochrome `<id>.svg`, which *is* given the blue/red
side shift (`COL_SIDE_PLAYER`/`COL_SIDE_ENEMY`) — tracked in `mono_art`. The King is
the only one on that path today; dropping `king-light.png` + `king-dark.png` in
switches it over with no code change. Read tokens through `piece_tex(id, owner)` —
never index `textures[id]` directly, it holds a `{PLAYER, ENEMY}` dictionary.

PNGs import with **mipmaps on**: source art is 192×192 and the board tile is ~51px,
so without them the tokens shimmer during slide animations.

`test_assets.gd` fails a piece that has only one side of the pair, or that has both
painted art *and* a leftover svg.

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
- **Prioritise trusted sources**, highest first (order ruled by the user 2026-09-06):
  1. Explicit user instructions in this conversation.
  2. The Notion GDD (the design source of truth).
  3. This `CLAUDE.md`.
  4. Project docs: ADRs, `CONTEXT.md`, `.agents/skills/*/SKILL.md`.
  5. The codebase itself (`git log`, current file contents).
  6. General knowledge — official upstream docs, locked external skills
     (`skills-lock.json`), training data, blogs, Stack Overflow — a hypothesis to verify;
     upstream docs and locked skills have no explicit tier of their own yet.
  Never let a lower tier override a higher one without flagging the conflict.
- **Before an audit of the GDD catalogs, run the Notion drift checker.** The Notion
  GDD (Artefacts, Items, Pieces, Tariffs) and the repo mirrors (`data/artefacts.js`,
  `game/data/items.gd`, `data/pieces-codex.js`, `game/data/tariffs.gd`) have drifted
  apart unnoticed before and been hand-fixed twice — the second fix still missed a
  row. `tools/check-notion-drift.mjs` diffs them and prints every disagreement; it
  never writes to either side. It needs a Notion snapshot as input (a plain script
  can't call the Notion MCP tools) — see the header of that file for the exact SQL
  to run and the JSON shape to save, then:
  ```sh
  node tools/check-notion-drift.mjs <snapshot.json>
  ```

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
