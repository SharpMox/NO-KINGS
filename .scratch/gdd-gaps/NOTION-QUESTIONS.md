# Open questions for the Notion GDD

Every one of these blocks at least one Artefact, and every one is a question **for the
GDD**, not something to settle in code. They are collected here because they were found
one at a time, in different slices, and were about to rot in separate `## Outcome`
sections.

House rule they all follow (`CLAUDE.md`): *ambiguity goes back to Notion as a question,
not into code as a guess.* Half this backlog exists to undo guesses.

Compiled 2026-08-29, against catalog state **152 / 180 implemented**.
Revised the same day: **questions 1 and 3-7 and 9 all resolved** across two design sessions.
Only question 2 (the duplicate reroll pair) and question 8 (the `on_milestone` naming
collision) remain, and neither blocks any Artefact. See issues 47-55.

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

## 3. ~~Spare Organ Receipt~~ — ANSWERED 2026-08-29

**50% of both consumed pieces combined.** See issue 53.
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

## 5. ~~'Definitely Not Russia' Patch~~ — ANSWERED 2026-08-29

Masks the loss from **everything** that reads `on_piece_lost` — one flag, no carve-outs.
The piece is still lost, so this needs a flag distinct from Fireproof Pajamas' `cancel`
(which saves the piece). See issue 53.
---

## 6. ~~Alien Pet Rocks~~ — ANSWERED 2026-08-29

**Only moves you spent an Action on count.** A Deploy does not count as moving, and neither
does being shoved by an effect — both still pay. See issue 53.
---

## 7. ~~Abduction Probe~~ — ANSWERED 2026-08-29

**Base Piece Buff capacity is 2; Abduction Probe gives +1 (to 3).** This introduces a base
cap where none existed, so it nerfs the current game — every grant path must refuse a 3rd
buff cleanly. The Artefact's text needs rewriting, since "can carry 2" now describes the
base game. See issue 53.
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

## 9. ~~Item held capacity~~ — ANSWERED 2026-08-29

**Base capacity 3.** Area 51 Parking Permit takes it to 6; Denver Bunker Timeshare's
"slots full" condition becomes reachable. See issue 53.
---

## 10. SETI's Red Marker — what is a Tariff's "equivalent bonus"?

> On acquiring this Artefact: one random active Tariff is inverted into its equivalent bonus

**The only Artefact left unimplemented for a design reason** (issue 54 declined to guess).
`data/tariffs.gd` has no inverse for anything, and the 13 Tariffs split into two groups that
behave very differently under "invert":

**The 8 `action`-kind Tariffs invert cleanly** — they all read "X costs extra gold", so the
inverse is "X *pays* gold". No design needed, it falls straight out of the existing
`Economy.charge` seam:

`move_cost` · `ability_cost` · `capture_cost` · `pass_cost` · `long_range_cost` ·
`box_cost` · `deploy_cost` · `fuse_cost`

**The `persistent` ones mostly have no inverse at all:**

| Tariff | Effect | Natural inverse? |
| --- | --- | --- |
| Inflation | All Gold gains reduced 10% (stacks) | **Yes** — +10% Gold gains |
| Sanctions | One random piece type can no longer be placed | **No** — the un-sanctioned state is just the base game |
| Regulation | Pawns can no longer be merged | **No** — same problem |

So "invert Sanctions" has no meaning unless a bonus is *invented* for it, which is exactly
the kind of guess the house rule forbids.

**Options:**

1. **Scope it to cost Tariffs.** "One random active **cost** Tariff is inverted — it pays
   instead of charging." Fully derivable, needs no new design, ships immediately. Inflation
   can come along too, since it inverts cleanly.
2. **Author an explicit inverse per Tariff**, inventing bonuses for Sanctions and Regulation
   (e.g. "one piece type deploys free", "Pawns merge at no Action cost").
3. **Retire or re-text** the Artefact.

I'd take **1** — it needs nothing invented and the excluded Tariffs are exactly the two
that have no coherent opposite. But it does mean SETI reads as weaker than its text implies,
so it is your call.

Note this is moot in live play until Tariffs return: `TARIFFS_SCHEDULED` is `false`, so
SETI cannot fire in a real run today either way.

---

## Not questions — recorded so they are not re-raised

- **Exhibit 399** and **SETI's Red Marker** depend on Tariffs, which you removed from runs
  on 2026-08-29 (`TARIFFS_SCHEDULED := false`) pending the King-mechanics pass — issue 54
  built both anyway (dormant, tested directly). Exhibit 399 shipped `implemented: true`;
  SETI's Red Marker stays `implemented: false` — "equivalent bonus" needs a per-Tariff table
  that doesn't exist in `data/tariffs.gd`, a genuine open GDD question issue 54 didn't
  resolve either, not attempted.
- **All-Seeing Eye Contact Lens**, **Oak Island Wishing Well**, **FIFA Complimentary
  Yacht**, **Zapruder's Director's Cut**, **Roanoke Hex Kit**, **Bovine Tractor Beam** all
  need new interactive UI — issue 32, blocked on design, not on the GDD.
- **Pegasus Free Trial**, **UAP Breath Mint**, **Inflatable Vietcong Torpedo**, **Hellfire
  Club Discord Invite** were issue 33's parked group (decisions #2/#3/#4) — all 4 resolved
  and shipped in issue 54. **Zeta Reticuli Souvenir Map** remains parked (out of issue 54's
  scope).
- **Ecdysis Sheddings** and **Troll Farm Employee of the Month** are meta-dispatch — they
  change how `run()` itself behaves and want their own design pass.
