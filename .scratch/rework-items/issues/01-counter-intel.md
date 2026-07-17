# 01 — Counter-Intel: tariff suppression for the wave

Status: done
Type: AFK

## Parent

`.scratch/rework-items/PRD.md`

## What to build

Counter-Intel as an instant item (Strategic tier): using it suppresses action
and persistent tariffs — Inflation included — for the rest of the current
wave; the suppression ends the moment the next wave spawns. Oneoff tariffs are
untouched. The HUD tariff overlay shows a suppressed marker while active. The
flag survives the mid-run save/load round-trip. The item enters the catalog
(and thus lootbox + Shop pools) with its Notion description.

## Acceptance criteria

- [ ] With an action tariff active, using Counter-Intel makes tariffed actions cost no extra money for the rest of the wave
- [ ] With Inflation active, money gains during suppression are untaxed; score is unchanged either way
- [ ] The next wave's spawn ends the suppression (subsequent tariffed actions pay again; Inflation resumes)
- [ ] A oneoff tariff already applied is not reverted
- [ ] Save/load mid-suppression preserves it; save/load after expiry does not resurrect it
- [ ] HUD tariff display marks tariffs as suppressed while the flag is on
- [ ] Item costs 1 action; the ability tariff on the use itself is charged before suppression starts (grilled: suppression covers subsequent actions, and cancelling nothing — instant item)
- [ ] Headless items suite covers the above; a Counter-Intel scenario joins the catalog; full suite ALL GREEN

## Blocked by

None - can start immediately
