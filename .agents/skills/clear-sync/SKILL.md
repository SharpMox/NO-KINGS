---
name: clear-sync
description: >-
  Run before a session is compacted or cleared, at a work boundary (PRs merged, device
  session done, bug fixed, ruling made, silo finished), or on "sync the docs" /
  "write this down". Writes what only this context knows to its durable home, reads it
  back, states what clearing would still lose. Never clears the session itself.
---

# clear-sync: sync, then clear

One-way, context out to its homes, never reconciling the homes with each other. Done when
you can say, honestly: **"everything durable is written down and cited, so clearing this
session loses nothing"** — or name exactly what it still loses.

Autonomy is split by destination (user ruling 2026-09-13): write freely to memory,
`docs/device-verification.md`, Linear and the handoff; **ask before touching `CLAUDE.md`
or `docs/MANUAL-STEPS.md`**, which every agent reads on every task. Reach is repo docs,
memory, Linear, Notion (same ruling; Notion on a condition, see Write).

## When to run

**Context pressure.** clear-sync then `/clear` replaces compaction (user ruling
2026-09-13): compaction summarises and drops detail nobody can audit; clear-sync writes
the facts to homes that persist. Run while the session still holds the raw material. An
agent cannot read its own token count, so go by the signs: a long session with many tool
results, work spanning several tasks, a compaction that already happened, the user
mentioning context, compacting or clearing. Mid-task, write now; the clear itself still
waits for a task boundary (`silo-cycle`).

**A work boundary, unasked.** Propose it whether or not the user has mentioned clearing:
the context is fattest exactly when the close-out gets forgotten.

Either way it **clears nothing**: the last act is stating what would still be lost, and
the user performs the clear. **An empty run is a success**: `nothing to record` and a
one-line reason; the triage default is already NOWHERE, do not manufacture findings.

## 1. Inventory

Sweep by category, answering every one, "none" included; the output is a flat candidate
list, nothing written yet.

- Rules or conventions **earned from a failure**.
- **User rulings** and decisions, with the date and the words used.
- **Traps**: a tool, a layout, an API that does not do what it says.
- **Verified on hardware**, and what was NOT verified.
- **Defects in our own tooling**: a script, a probe, a skill that failed or lied.
- Work **open, blocked, or deliberately not done**.
- **Corrections**: something already written down that this session found stale or wrong.

## 2. Triage: the default is NOWHERE

Each candidate ends in exactly one home or in the bin, the bin by default. Two tests, in
order. **Already recorded?** Check `git log`, `CLAUDE.md`, the `.scratch/gdd-gaps/`
archive, the memory directory, the open Linear issues; recorded means update that home in
place, a near-duplicate is worse than the stale original. **Would the next agent make a
WORSE DECISION without it?** No means bin; what was done, in what order, how long it took,
`git log` holds. A survivor takes its home from the table, at its shortest useful length.

### Routing table: NO-KINGS

The one project-specific part; swap this whole section for another project.

| Candidate | Home | Autonomy |
|---|---|---|
| A durable rule or convention, incident named | `CLAUDE.md`, the matching section | **ask first** |
| Something only the user can do; a device, account or tooling trap | `docs/MANUAL-STEPS.md` | **ask first** |
| Confirmed on hardware, and what was not | `docs/device-verification.md`: a new block at the top, append-only; a correction is a new entry, never an edit of an old one | write |
| An architectural decision with alternatives considered | a new ADR under `docs/adr/`, next number, the shape of `0002` | write |
| Open or blocked work; a non-blocking finding | Linear, team `NO`: an issue, with the `flag` label for a finding (the `linear-web` skill) | write |
| How the user wants to be worked with; a fact about the user or the project the code cannot yield | a memory file in `~/.claude/projects/-Users-sharpmax-NO-KINGS/memory/` with frontmatter `name`, `description`, `metadata: {node_type: memory, type: feedback\|reference}`, plus its one-line entry in `MEMORY.md` | write |
| Enough to resume cold | the handoff, `silo-cycle` skill section 1 | write |

Not a home: `.scratch/gdd-gaps/` (read-only archive, ruling 2026-09-06) and the
`.<tool>/skills/` symlink farms that `tools/refresh-agent-skill-links.sh` overwrites.
A CLAUDE.md addition names the incident that earned it; a single unrecurred incident goes
in the ask, and the user's yes makes it a rule. Declined: a dated memory line, or the bin.

## 3. Write

The fact, its source, and what to do about it; nothing else (user ruling 2026-09-13: what
we write is re-read every session). Source in house style: `User ruling <date>`, a commit,
a PR, an issue id, the incident; the story is in git.

- **Free homes**: write now.
- **Ask-first homes**: batch every `CLAUDE.md` and `MANUAL-STEPS.md` candidate into ONE
  consolidated ask with, for each, the target section and the proposed exact wording.
  Nothing lands before the answer; an ask still open at the close goes into the handoff
  verbatim, under open threads.

**Notion, on a condition.** Run the drift check only when this session touched catalog
data: `data/artefacts.js`, `game/data/items.gd`, `data/pieces-codex.js`,
`game/data/king_abilities.gd` (the Tariffs), or the matching Notion databases. The
snapshot is hand-gathered through the browser (recipe in the header of
`tools/check-notion-drift.mjs`), so it never runs by default. Touched: gather, run, file
each disagreement as a `flag` issue (which side is stale is a judgement each time).
Untouched: report `drift check skipped: no catalog data touched`.

**Who writes.** Inventory and triage stay with the agent that holds the context: what is
being delegated is exactly what is about to disappear. The writes may be delegated (the
coordinator session must, per memory `coordinator-dispatch-only`); the dispatcher still
owns the read-back.

## 4. Read back

Read every write back from its home, not from your own buffer: a file, grep the lines; a
memory, the file and its `MEMORY.md` line; Linear, reopen the issue and read the title,
status or comment through the clipboard path; Notion, re-read the property. An unverified
write is worse than none, because it will be trusted.

## 5. Close

1. Write the handoff (`silo-cycle`, section 1); its "rediscovered conventions" section
   holds the CLAUDE.md candidates still awaiting the user's answer.
2. State what clearing would still lose, item by item: a decision not made, a question
   outstanding, a write that failed its read-back. "Nothing" only when it is true.
3. Stop. A session cannot clear itself (`silo-cycle`, section 2).

## Report

```
clear-sync: <session>, <date>
Written, read back:
  <fact> -> CLAUDE.md, section <name>           (approved: <the user's words>)
  <fact> -> docs/device-verification.md, block <commit>
  <fact> -> NO-<n> <title>                      (issue | flag)
  <fact> -> memory/<file>.md (+ MEMORY.md line)
Asked, awaiting answer: <the consolidated ask> | none
Binned: <n> (already recorded <n>, no decision changed <n>)
Drift check: run, <n> disagreements filed | skipped: no catalog data touched
Handoff: ~/Documents/handoff-<silo>.md
Clearing still loses: <each item> | nothing
```
