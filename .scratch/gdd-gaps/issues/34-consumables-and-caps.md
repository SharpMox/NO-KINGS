# 34 — Consumable artefacts & caps

Status: superseded (2026-08-29) — all three decisions answered

## Parent

`.scratch/gdd-gaps/PRD.md`

## Why this is parked

Two small groups that each break a stated invariant, so neither is a plumbing job.

**Consumable artefacts** — *Epstein's Black Book*, *Moscovium Glow Stick*. Artefacts are
defined as **run-long passives** (Reward Economy: *"a passive bonus that applies for the
rest of the run"*). A consumable artefact is a new category sitting between an Item and an
Artefact. Decide whether that category exists before building one — if it does, it needs a
name, a UI affordance, and a rule for what happens when it is spent.

**Item capacity** — *Area 51 Parking Permit* (+3 Item capacity), *Denver Bunker Timeshare*.
There is **no item cap today**; held Items are an unbounded Array. So "+3 capacity" has
nothing to raise. Note the precedent: the same question came up for Stock and the ruling
was **no cap** (see `Stock` in Notion, reconciled 2026-08-28) — but Items are a different
resource and the answer need not match.

Also here: *Loch Ness Stool Sample* references a **"Piece Box"**, which is not one of the
three Box kinds (Item / Artefact / Score). Either it is a fourth kind or the text is wrong.

## The decisions needed first

1. Do consumable artefacts exist as a category?
2. Is there an Item cap, and if so what is the base number?
3. Is "Piece Box" a real fourth Box kind?

## Blocked by

- the three decisions above

## Superseded 2026-08-29

All three decisions answered by the user:

1. **Do consumable Artefacts exist as a category?** **Yes.** Moscovium Glow Stick (issue 52)
   and Epstein's Black Book (issue 49) are the first two. Note Black Book's rule is the
   subtle one: it is consumed *only* when you take more than you were already entitled to.
2. **Is there an Item cap, and what is the base?** **Yes, base 3** (issue 53). A Piece Buff
   cap of **2** was introduced alongside it — neither existed before, so both nerf the
   current game and must refuse cleanly on every path.
3. **Is "Piece Box" a real Box kind?** **Yes.** Slice 47's rework gives 9 Boxes — 3 sizes x
   3 themes (Pieces / Artefacts / Items) — so Loch Ness Stool Sample's text was right and
   the prototype was behind.

Nothing left here. Kept for the decision record.
