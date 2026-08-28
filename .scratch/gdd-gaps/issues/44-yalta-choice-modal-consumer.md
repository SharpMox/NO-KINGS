# 44 — Yalta Cocktail Napkin, the first consumer of the choice-modal seam

Status: todo — INDEPENDENT (no design decision needed)

## Parent

`.scratch/gdd-gaps/PRD.md`

## Why this slice exists

Slice 41 built `game.gd._open_choice_pick(header, offers, cancel_text, on_chosen,
on_cancelled)` and deliberately shipped it with **one** consumer (the Buff Box, migrated
onto it to prove the seam was behaviour-preserving). Six Artefacts were waiting on it and
41 implemented none of them, by design.

Of those six, this is the only one that needs **nothing but** the seam. The other five
each still want something that does not exist or that the user has parked — see
"Not in scope" below, which is the useful half of this issue.

## Scope — Yalta Cocktail Napkin (Rare)

> On 5-Wave Milestone: choose one — +100 Gold / +1 Item / +15s Clock

Its catalog note reads `(needs: choice UI)`; that note is now **stale** and should be
cleared as part of this slice.

- Fires on the per-artefact milestone cadence (issue 28): `_milestone5_hit(wave,
  acquired_wave)`, each held copy counting its own 5 waves from acquisition — not
  `g.wave % 5`.
- Presents three offers through `_open_choice_pick`. Gold goes through `Economy.earn`,
  Clock through `Economy.add_clock` (the choke point slice 35 built — do not touch
  `clock_ms` directly), and "+1 Item" appends a random entry from `Items.ITEMS`, the
  same pool a Box's item roll draws from.
- **The Clock keeps ticking while the modal is open.** This is the user's explicit ruling
  (2026-08-29): the UI hangs until the player chooses, but the timer runs. `buff_pick_open`
  is already absent from `_process`'s `tier_pauses` at every tier, so a caller through the
  seam inherits this for free — assert it rather than add code.
- Held twice = two independent picks. They will not fire on the same wave unless both
  copies were acquired on the same wave, which is the intended consequence of the
  per-artefact cadence.
- Cancelling: the seam requires an `on_cancelled` continuation. A milestone reward is not
  a spend and has nothing to refund, so cancelling should simply forfeit the reward and
  close. Give the cancel button text that says so rather than implying a refund.

**Bot/headless:** `autoplay` must not deadlock on the modal. `_open_box_pick` already
shows the pattern — under `autoplay` it resolves the choice itself with `rng` instead of
calling `modals.show_*`. Do the same here, or `test_scenarios.gd` and the autoplay run
will hang instead of failing, which is worse.

## Not in scope — the other five, and why

Recording these so the next pass does not re-derive them:

| Artefact | Why it is still parked |
| --- | --- |
| Exhibit 399 | "When a Tariff would be applied" — the user removed in-run Tariffs on 2026-08-29 (`TARIFFS_SCHEDULED := false`) pending the King-mechanics pass. Its trigger cannot fire, so it cannot be verified in game. |
| All-Seeing Eye Contact Lens | "Box Picks show all 3 box types' contents at once" — a combined Box UI, which is issue 32, still blocked on design. |
| Cicada Rejection Letter | "+Gold equal to the Shop value of the **offered pieces**" — but `Box.roll_options` offers Item / Artefact / Score and **never a piece**. That is a real GDD↔code mismatch, so it is a question for Notion, not a guess. (The decline path itself is fine — `_on_box_skipped` already exists and pays `BOX_SKIP_CONSOLATION`.) |
| Inflatable Vietcong Torpedo | "when one of your pieces would be captured: pay 15 Gold and it survives" — the capture happens inside `_enemy_turn`'s action loop, so offering a choice there means **suspending an enemy turn mid-resolution**, a capability the seam does not have. This is issue 33's decision #2 and wants that ruling first. |
| Nostradamus Mad Libs | "+1 extra pick" on a Box. Buildable, but it is Box-flow work rather than choice-modal work — file it with the Box cluster instead of smuggling it in here. |

## Acceptance

- `implemented: true` set in `data/artefacts.js` and exported with
  `node tools/export-game-artefacts.mjs` — never hand-edit `game/data/artefacts.json`.
- The stale `(needs: choice UI)` note removed from the effect text.
- Tests in the split suites (issue 37): all three branches taken, the per-copy cadence,
  the cancel path, and an assertion that the Clock advanced while the modal was open.
- `game/tests/run_all.sh` ALL GREEN, click probes included — this touches a modal.

## Blocked by

- nothing
