# Open questions for the Notion GDD

Every one of these blocks at least one Artefact, and every one is a question **for the
GDD**, not something to settle in code. They are collected here because they were found
one at a time, in different slices, and were about to rot in separate `## Outcome`
sections.

House rule they all follow (`CLAUDE.md`): *ambiguity goes back to Notion as a question,
not into code as a guess.* Half this backlog exists to undo guesses.

Compiled 2026-08-29, against catalog state **152 / 180 implemented**.
Revised the same day: questions 1 and 4 resolved in a design session; see issues 47-50.

---

## 1. ~~What is in a Box?~~ — ANSWERED 2026-08-29

The user specced the Box system **upward** rather than re-texting the rows down to the
prototype. Nine Boxes: three sizes (Small 3/1, Big 5/1, Huge 7/2 choices/picks) x three
themes (Pieces / Artefacts / Items). Score Boxes and the mixed Box are removed, as is the
box-carrier enemy. Contents roll at stock time so a Box is a concrete object.

Full spec in **issue 47**; the four dependent Artefacts in **issue 49**; the replacement
for loot-on-capture is the new Bounty Piece Buff in **issue 48**.
---

## 2. Two Artefacts have the same effect — still open, low priority

**Bible Gag Reel Scroll** (Uncommon) — "On Box Pick: you may reject the contents once and
reroll them" — and **Snowden's Rubik's Cube** (Uncommon) — "Once per Box: you may reroll
the offered Picks" — are functionally identical.

Both shipped in slice 46, implemented the same way with a shared reroll budget so they
stack additively. The question stands but answering it is now a small edit to one handler,
not a rebuild.

**Question:** is one meant to differ, or is this a duplicate to retire?
---

## 3. Spare Organ Receipt — which piece is "the consumed piece"?

> On Fuse: refund 50% of the consumed piece's value as Gold

A Fuse consumes **two** pieces (`merge_logic.gd` `commit_merge`: both entries are erased,
one result is produced). The effect text is singular.

**Question:** 50% of the *combined* value of both consumed pieces, or 50% of one — and if
one, which (the higher, the lower, the second selected)?

Everything else about this one is ready: `commit_merge` has both ids in scope and
`g.defs[id].value` gives the value, so it is a small hook away once the reading is fixed.

---

## 4. ~~Winchester Salt Lined Doors~~ — WITHDRAWN 2026-08-29

Raised as a balance blocker; it was neither. "Enemy pieces cannot move onto your back row"
plainly means enemies never occupy it, so immunity to the back-row breach loss is the card
working as written, not a side effect. And balance tuning was already ruled to wait until
every lever is coded, so this re-litigated a settled decision.

**Winchester and Cheyenne Mountain Doorbell are cleared to build** — see issue 33's
addendum, where the go-ahead is now recorded in writing rather than living only in the
conversation.
---

## 5. 'Definitely Not Russia' Patch — what exactly does it mask?

> The first piece you lose each Wave doesn't count as a loss for your Artefacts and
> penalties

The piece **is** still lost — this is different from Fireproof Pajamas, which sets
`ctx.cancel` and the piece survives. This one needs a *second* flag meaning "lost, but
uncounted", and the open part is what that suppresses.

**Question:** does "your Artefacts and penalties" mean every effect that reads
`on_piece_lost` (e.g. Nibiru Hide-and-Seek Trophy's streak collapse, Frog Pride Flag's
arming), or only *scoring* penalties? An explicit list is best — this is exactly the kind
of scope that silently drifts.

---

## 6. Alien Pet Rocks — what counts as "did not move"?

> At Wave end: +2 Gold per allied piece that did not move this Wave

**Question:** does a piece count as having moved when it was **Deployed** this Wave, or
when it was moved by an effect rather than by the player (Royal Fiat's forced retreat,
Tactical Reposition, Decoy Swap, Rapid Deployment)?

The natural reading is "the player did not spend a move on it", but the forced-move cases
genuinely could go either way, and the answer changes the payout every Wave.

---

## 7. Abduction Probe — implementing it means inventing a base rule

> Your pieces can carry 2 Piece Buffs at once

There is **no 1-buff cap anywhere in the code today** — `buff_logic.gd` appends freely to
a piece's `buffs` array. So this Artefact currently does nothing, and making it do
something means first introducing a base-game restriction nothing else asks for.

**Question:** is a 1-buff-per-piece cap intended as a base rule (with this Artefact
lifting it to 2), or should this row be re-texted / retired?

---

## 8. "5-Wave Milestone" vs the hook named `on_milestone` — naming, not behaviour

Not blocking, but it has now caused one real spec error and will cause more.

- `on_milestone` is the **global 10-Wave** clock-refill trigger
  (`Tuning.MILESTONE_WAVES == 10`), used only by "timer" and the Recession tariff.
- Every per-artefact **"5-Wave Milestone"** effect hooks `on_wave_clear` and calls
  `_milestone5_hit(g.wave, acquired_wave)` — each held copy counting its own 5 Waves from
  acquisition (user ruling 2026-08-29).

**Question:** should the GDD use two distinct names for these, so "Milestone" stops
meaning two different cadences? Renaming the hook in code is cheap; the catalog wording is
the part that needs the ruling.

---

## 9. Item held capacity — blocks 2 Artefacts (this is issue 34)

Area 51 Parking Permit ("+3 Item held capacity") and Denver Bunker Timeshare ("While all
your Item slots are full: +30% Gold gain") both presuppose an Item cap. There is none.

**Question:** what is the base Item capacity? Both rows are one number away from shipping.

---

## Not questions — recorded so they are not re-raised

- **Exhibit 399** and **SETI's Red Marker** depend on Tariffs, which you removed from runs
  on 2026-08-29 (`TARIFFS_SCHEDULED := false`) pending the King-mechanics pass. Parked by
  your decision, not blocked by a gap.
- **All-Seeing Eye Contact Lens**, **Oak Island Wishing Well**, **FIFA Complimentary
  Yacht**, **Zapruder's Director's Cut**, **Roanoke Hex Kit**, **Bovine Tractor Beam** all
  need new interactive UI — issue 32, blocked on design, not on the GDD.
- **Pegasus Free Trial**, **Zeta Reticuli Souvenir Map**, **UAP Breath Mint**,
  **Inflatable Vietcong Torpedo**, **Hellfire Club Discord Invite** are issue 33's parked
  group (decisions #2/#3/#4).
- **Ecdysis Sheddings** and **Troll Farm Employee of the Month** are meta-dispatch — they
  change how `run()` itself behaves and want their own design pass.
