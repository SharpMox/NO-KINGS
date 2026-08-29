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
