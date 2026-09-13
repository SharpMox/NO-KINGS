---
name: clear-sync
description: >-
  Run when the context is getting large, before compaction and instead of it, or when
  the user mentions context, compacting or clearing. Also at a work boundary: PRs
  merged, a device session finished, a bug fixed, a user ruling made, a silo reporting
  done, the user moving to an unrelated thread. And on "clear the session", "before I
  clear", "sync the docs", "write this down", "/clear-sync". Writes what only this
  context knows to its durable home, reads it back, states what clearing would still
  lose. Never clears the session itself.
---

# clear-sync: sync, then clear

At the end of a session the context holds things that exist nowhere else: a rule earned
from a failure, a decision the user ruled on, a trap, a fact verified on a phone, work
left open. `/clear` destroys them. This skill runs first and leaves nothing behind that
only the context knows. It is one-way, context out to its homes; it never reconciles the
homes with each other.

Done when you can say, honestly: **"everything durable is written down and cited, so
clearing this session loses nothing"** — or name exactly what it still loses.

Two user rulings (2026-09-13), settled:

- **Autonomy is split by destination.** Write freely to memory,
  `docs/device-verification.md`, Linear and the handoff. **Ask before touching `CLAUDE.md`
  or `docs/MANUAL-STEPS.md`**: every agent reads those on every task, so a bad line there
  costs more than a forgotten fact.
- **Reach is everything**: repo docs, memory, Linear, Notion. Notion is on a condition
  (see Write).

## When to run

Two triggers, both first-class. In each case the agent proposes the run; the user does not
have to remember.

**Context pressure: before compaction, as the alternative to it** (user ruling 2026-09-13,
"instead of compacting mostly"). Compaction and clear-sync both shrink the context, but
only one keeps the knowledge. Compaction summarises: lossy in a way nobody can audit, it
drops the detail that later turns out to have mattered, and the loss stays invisible until
an agent confidently asserts what the summary mangled. clear-sync writes the durable facts
out to homes that persist, a doc, an issue, a memory, the handoff, and then the context can
be cleared outright. After a clear-sync a `/clear` costs less than a compaction did:
what mattered is on disk and citable, not paraphrased.

- The moment is **while the session still holds the raw material**. A run after a
  compaction is worth much less: the details it exists to capture have already been
  through the lossy step.
- An agent cannot read its own token count, so go by the signs: a long session with many
  tool results, work spanning several tasks, a compaction that has already happened once,
  the user mentioning context, compacting or clearing.
- "Mostly" is the user's word: clear-sync is the preferred path for a long working
  session, not the only one. Compaction stays available when nothing durable is at stake.

**A work boundary, unasked.** A batch of PRs merged, a device session finished, a bug
root-caused and fixed, a ruling made, a silo reporting completion, the user calling a
thread done or moving to an unrelated one. Propose it whether or not the user has mentioned
clearing: the agent cannot see a clear coming, and the context is fattest exactly when the
close-out gets forgotten.

In either case:

- **It clears nothing.** It prepares for a clear the user performs. The last act is
  stating what would still be lost, and the user decides whether that is acceptable.
- **An empty run is a success.** At a boundary where nothing durable was learned, the
  output is `nothing to record` and a one-line reason. A close-out that always finds
  something to write manufactures findings to justify itself; the triage default is
  already NOWHERE.

## 1. Inventory

Sweep the session by category; an open "what did we learn" produces mush. Answer every
category, "none" included:

- Rules or conventions **earned from a failure**: something broke, and now we know why.
- **User rulings** and decisions, with the date and the words used.
- **Traps** discovered: a tool, a layout, an API that does not do what it says.
- **Verified on hardware**, and, as important, what was NOT verified.
- **Defects in our own tooling**: a script, a probe, a skill that failed or lied.
- Work **open, blocked, or deliberately not done**.
- **Corrections**: something already written down that this session found stale or wrong.

Output: a flat candidate list. Nothing is written yet.

## 2. Triage: the default is NOWHERE

The load-bearing phase. Each candidate ends in exactly one home or in the bin, and the bin
is the default. Two tests, in this order:

1. **Already recorded?** Check `git log`, `CLAUDE.md`, the `.scratch/gdd-gaps/` archive,
   the memory directory, the open Linear issues. Recorded means update that home in place;
   a near-duplicate file or a second issue is worse than the stale original.
2. **Would the next agent make a WORSE DECISION without it?** No means bin. What was done,
   in what order, how long it took: `git log` holds that, and a second telling anywhere
   else is sediment.

A survivor takes its home from the routing table and is written at its shortest useful
length: a long entry makes its file less likely to be read at all, the same outcome as
not writing it.

### Routing table: NO-KINGS

The one project-specific part of this skill; swap this whole section for another project.

| Candidate | Home | Autonomy |
|---|---|---|
| A durable rule or convention, incident named | `CLAUDE.md`, the matching section | **ask first** |
| Something only the user can do; a device, account or tooling trap | `docs/MANUAL-STEPS.md` | **ask first** |
| Confirmed on hardware, and what was not | `docs/device-verification.md`: a new block at the top, append-only; a correction is a new entry, never an edit of an old one | write |
| An architectural decision with alternatives considered | a new ADR under `docs/adr/`, next number, the shape of `0002` | write |
| Open or blocked work; a non-blocking finding | Linear, team `NO`: an issue, with the `flag` label for a finding (the `linear-web` skill) | write |
| How the user wants to be worked with; a fact about the user or the project the code cannot yield | a memory file in `~/.claude/projects/-Users-sharpmax-NO-KINGS/memory/`, frontmatter matching its neighbours, plus its one-line entry in `MEMORY.md` | write |
| Enough to resume cold | the handoff, `silo-cycle` skill section 1 | write |

Not a home: `.scratch/gdd-gaps/` is a read-only archive (ruling 2026-09-06), and the
`.<tool>/skills/` directories are symlink farms that `tools/refresh-agent-skill-links.sh`
overwrites.

**The CLAUDE.md filter: every addition names the incident that earned it.** That is the
house style of the file (read any convention there; each cites a failure), and a candidate
that cannot name one is speculation dressed as a lesson. A single incident that has not
recurred and the user has not ruled on is not a rule yet: it goes into the ask with its
date, and the user's yes is what makes it a ruling; on the agent's own judgement it does
not enter, because there the next agent cannot tell speculation from experience. Declined,
it is a dated observation for a memory file, or the bin.

## 3. Write

Write the fact, its source, and what to do about it; nothing else (user ruling
2026-09-13: what we write is re-read every session, so length is a cost paid forever).
The source is house style: `User ruling <date>`, a commit, a PR, an issue id, the
incident. The date and the PR number are the citation; the story is in git. A memory or a
doc line is a fact with a hook, not an essay.

- **Free homes**: write now.
- **Ask-first homes**: batch every `CLAUDE.md` and `MANUAL-STEPS.md` candidate into ONE
  consolidated ask carrying, for each, the target section and the proposed exact wording.
  The user's standing instruction is one consolidated ask, never a trickle. Nothing lands
  there before the answer; an ask still unanswered at the close goes into the handoff
  verbatim, under open threads.

**Notion, on a condition.** Run the drift check only when this session touched catalog
data: `data/artefacts.js`, `game/data/items.gd`, `data/pieces-codex.js`,
`game/data/tariffs.gd`, or the matching Notion databases. The checker needs a snapshot
hand-gathered through the browser (recipe in the header of
`tools/check-notion-drift.mjs`), which turns a short close-out into a long one, so it runs
on this condition and not by default. Touched: gather, run, file each disagreement as a
`flag` issue (which side is stale is a judgement each time; both directions have
happened). Untouched: skip, and the report says `drift check skipped: no catalog data
touched`.

**Who writes.** Inventory and triage stay with the agent that holds the context: the
thing being delegated is precisely what is about to disappear, so nobody else can do them.
The writes can be delegated, and in this project usually are (memory
`coordinator-dispatch-only`): dispatch each with complete, verbatim-executable
instructions. The dispatcher still owns the read-back; a delegated write verified only by
the delegate's own report is exactly the failure the next phase exists to prevent.

## 4. Read back

Verify every write by reading it back from the home, not from your own buffer. A file:
grep the lines back. A memory: the file and its `MEMORY.md` line. A Linear write: reopen
the issue and read the title, status or comment back through the clipboard path. Notion:
re-read the property. An unverified write is worse than none, because it will be trusted:
on 2026-09-13 a session reported a Linear title rename as done when the field had never
taken focus, and the read-back is what caught it.

## 5. Close

1. Write the handoff (`silo-cycle`, section 1). Its "rediscovered conventions" section is
   where the CLAUDE.md candidates still awaiting the user's answer live.
2. State plainly and specifically what clearing would still lose: a decision the user has
   not made, a question outstanding, a write that failed its read-back. Name each one.
   "Nothing" only when it is true; implying a clean session when it is not defeats the
   skill.
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

