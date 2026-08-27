# 03 — Piece Buffs: the delivery path + 3 buffs

Status: done (2 of 3 buffs; Slow deferred — see Outcome)

## Parent

`.scratch/gdd-gaps/PRD.md`

## What to build

The largest unbuilt system in the GDD. The
[Piece Buffs](https://app.notion.com/p/dde9fd8c3cc545368f9160ab174a06e7) database holds 12
one-shot effects attached to a single piece, delivered by a **Buff Box** Item that does
not exist. `box.gd` only rolls item/artefact/score.

This slice is the tracer bullet — the whole path end to end, with 3 buffs rather than 12.

1. **The Buff Box Item.** A new entry in the Items catalog. Picking it fires a follow-up
   instead of granting a normal item.
2. **The sub-pick.** 3 random Piece Buffs shown, player picks 1.
3. **Targeting.** The player then targets a piece on the board — **ally or enemy**, per
   the GDD; the strategic choice is the point. Reuse the existing item-targeting stage
   machinery (`item_logic.gd`) rather than inventing a second targeting flow.
4. **Buff state on the piece.** Board pieces are Dictionaries and already carry an opaque
   `buff` flag for box carriers — that name is taken and means something else. Use a
   distinct key, and make sure it rides through ADR-0002 stock round-trips the way other
   piece state does.
5. **The clock keeps ticking** through both pick steps and the targeting (GDD Box Pick).
6. **Three buffs to prove both persistence models:**
   - **Shield** (Tactical, dormant) — prevents the next capture attempt on this piece;
     consumed; both pieces stay put. **This is also the first carrier of the general
     capture-repulsion rule** confirmed in slice 02 and now written on
     [Pieces & Movement](https://app.notion.com/p/367f1559c99b81b394b8faa429cf8151): a
     stopped capture returns the attacker to its starting tile. Build the repulsion as a
     rule the buff triggers, not as Shield-specific code — Reflect needs the same seam.
   - **Critical** (Tactical, dormant) — next capture by this piece scores double.
   - **Slow** (Tactical, immediate + timed) — applied piece loses 1 movement range,
     consumed at the end of the next enemy turn.

Shield and Critical prove dormant-until-trigger; Slow proves activate-immediately-and-
expire. Those two models are what slice 04 then fills in against.

## Acceptance criteria

- [ ] Buff Box is offerable and opens the 3-buff sub-pick
- [ ] Picking a buff enters targeting; ally and enemy pieces are both valid
- [ ] Cancelling before the target is chosen leaves the item unspent
- [ ] Shield absorbs exactly one capture attempt, then is gone
- [ ] Critical doubles exactly one capture's score, then is gone
- [ ] Slow expires on its own at the end of the next enemy turn
- [ ] A buffed piece extracted to Stock and replaced keeps its buff
- [ ] Radar Jamming strips these buffs (its description already promises it)
- [ ] The clock does not pause during pick or targeting
- [ ] Scenario added for the buff flow; `run_all.sh` all green

## Outcome (2026-08-27)

The delivery path and both **dormant** buffs shipped. The **timed** model did not —
see below.

**Buff Box added to the Notion Items DB.** It was referenced by name on both Reward
Economy and Game Flow — Box Pick but had no row in the catalog, so nothing could roll or
price it. Created as **Strategic** (60 Gold) on the reasoning that it is a lottery over
three buffs and can hit a Decisive one. Revisit after playtesting.

**Divergence from the GDD, recorded on the item's Notes:** the GDD fires the buff
sub-pick *immediately* when Buff Box is picked from the Item Box's 5 options. The
prototype has no two-step box (divergence #10) and every other Item resolves on use, so
Buff Box enters the inventory like any Item and fires its sub-pick + targeting when used.
One acquisition path serves boxes, Shop purchases and scenarios, and the player keeps the
tactical choice of *when*.

**Shipped:** `buff_logic.gd` (buffs as `{"key": …}` Dictionaries on the piece, so
ADR-0002 carries them through Stock and the save untouched); the 3-of-N sub-pick modal
with cancel-keeps-the-item; ally-or-enemy targeting through the existing `item_logic`
stage machinery; the **capture-repulsion rule** as a shared seam
(`BuffLogic.repels_capture`) hooked into both the player and AI capture paths, so Reflect
drops in beside Shield; Radar Jamming widened to strip piece buffs as its description
already promised; board rows in the save now carry a state Dictionary while still
accepting the legacy `"buff"` string.

### Deferred: the timed model (Slow / Aura / Smog)

Slow was meant to prove activate-immediately-and-expire. It could not ship honestly:
**"movement range is reduced by 1" has no defined meaning for most pieces.** `moves_for`
has a `range` limit only for *rides*, and an unbounded rider (Rook, `range = 0`) has no
"range − 1". Read as Chebyshev distance instead, a Knight's max is 2, so −1 leaves it
with no legal move at all — a freeze, not a slow.

Aura and Smog have the same hole: the catalog says *bonus movement and/or score gain* and
*reduced movement range and capture power* with no numbers anywhere.

Rather than invent an interpretation and create exactly the drift slices 01–02 spent
their time removing, all three timed buffs move to **slice 04**, which now has to settle
the magnitudes with the user first.

## Blocked by

- nothing
