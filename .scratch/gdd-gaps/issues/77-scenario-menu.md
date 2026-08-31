# 77 — Scenario menu: fit the screen, vertical scroll, subsections

Status: todo — SPECCED (user ruling 2026-08-31) · ready

## Parent

`.scratch/gdd-gaps/PRD.md`

## The problem

**53 scenarios in a flat list** at 480x800. It is already inside a `ScrollContainer`
(`menu.gd`'s `test_scroll`), so it scrolls — but it is one undifferentiated column of
17px buttons, and finding anything means reading all 53.

## What to build

- **Vertical scrolling only.** Constrain horizontally so nothing can scroll sideways —
  `test_scroll` is currently a full-rect ScrollContainer with no axis constraint. Set
  `horizontal_scroll_mode = SCROLL_MODE_DISABLED` and make the inner box fill the width.
- **Subsections**, so the list is scannable.

## The grouping is already in the data — use it, do not invent one

Scenario names are mostly `"Prefix: detail"`:

```
Promote: %s
Shop: browse & buy (gold, SOLD, reroll at 10s)
Economy: Blitz + First-Capture bonus actions
Win screen: wave 50 (capture King)
Captured stock: deploy (gold cost) & merge
Spawn overflow: full top row (friendly capture + spillover)
```

**Derive sections from the text before the first `":"`**, falling back to a "General" section
for names with no prefix ("Movement & drag", "Captures & highlights", "Waves & cadence").

That means **no data migration** — `scenarios.gd` is untouched, and any scenario added later
is grouped automatically by how it is named. If a future scenario wants a section, it gets one
by being named `"Section: thing"`.

If the derived sections come out lopsided (one giant "General", or fifteen sections of one),
say so and propose a grouping rather than shipping something unusable — the point is
scannability, and a bad grouping is worse than none.

## Presentation

- Section headers visually distinct from entries (smaller, uppercase, dimmed — the Activate
  section header in the inventory drawer is the in-repo precedent).
- Collapsible sections are **optional** — nice at 53 entries, necessary at 150. If the sandbox
  work in issue 73 lands, this list grows a lot, so build it so collapsing can be added later
  without restructuring.
- Keep the "← Back" button reachable — it is the last child today, and a long list already
  pushes it off-screen without scrolling.

## Acceptance

- All 53 reachable at 480x800; no horizontal scroll possible.
- Sections derived from names, "General" fallback, `scenarios.gd` unmodified.
- **Extend the windowed click probe**: assert a scenario deep in the list is reachable and
  launches — the existing probe only proves the TEST menu opens. This is exactly the class of
  bug the six-Army menu overflow was (a real player could not reach the Back button), caught by
  a probe rather than a headless test.
- `run_all.sh` ALL GREEN (`timeout: 600000`, blocking, alone).

## Blocked by

- nothing
