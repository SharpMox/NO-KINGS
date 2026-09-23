# NO-243 animation variants: recording the demos

Throwaway probe branch `probe/no-243-anim-variants`. Not for merge.

Two flags, both after the bare `--`:

- `--anim-variant A|B` picks a proposal. Without it the game runs the shipping animations unchanged.
- `--anim-demo arrive|capture|merge|score` boots a fixed board as a scenario (it never autosaves). It fires the case 4 times, 1.5 s apart, then quits. A run lasts about 7.5 s.

| Case | A | B |
|---|---|---|
| arrive (fires 1-2: 3 enemies each, 60 ms stagger; fires 3-4: the King) | Drops in from above and squashes on landing. The King drops from higher, squashes harder, and the board edge glows. | Fades in and scales up from 0, with a white outline flash. The King overshoots to 1.25x before settling, and the board edge glows. |
| capture (queen takes rook, bishop, knight, pawn) | The victim shrinks to 0 with a slight spin while fading (0.3 s). | The victim flashes white, then bursts into 10 squares. The capture ring runs for the same 0.4 s. |
| merge (pawn + pawn promotion, through the real `commit_merge`) | The result pops 1 → 1.25 → 1 inside a merge-colour ring (0.35 s). | The input slides into the target tile, then the result fades in with a cyan glow (0.5 s). |
| score (Score and Gold gains) | The digits count from the old value to the new one over 0.4 s. | The value snaps, the row flashes gold, and a "+N" beside it fades out. |

## Recording (Aux)

Godot Movie Maker records a windowed run. Do not use `--headless`. The recording ends when the demo calls `quit()`. **The local Settings "animations" toggle must be on**, because every variant respects `animations_on`. With it off the video shows pieces snapping.

Check out the branch inside the lock first:

```sh
ssh aux 'cd ~/NO-KINGS && caffeinate -i tools/godot-lock.sh sh -c "git fetch --prune -q && git checkout --detach -q origin/probe/no-243-anim-variants && mkdir -p /tmp/no243"'
```

Then make the 8 recordings. Run one at a time, and keep each one inside the lock:

```sh
ssh aux 'cd ~/NO-KINGS && caffeinate -i tools/godot-lock.sh $HOME/bin/godot --path game --write-movie /tmp/no243/arrive-A.avi --fixed-fps 30 -- --anim-demo arrive --anim-variant A'
ssh aux 'cd ~/NO-KINGS && caffeinate -i tools/godot-lock.sh $HOME/bin/godot --path game --write-movie /tmp/no243/arrive-B.avi --fixed-fps 30 -- --anim-demo arrive --anim-variant B'
ssh aux 'cd ~/NO-KINGS && caffeinate -i tools/godot-lock.sh $HOME/bin/godot --path game --write-movie /tmp/no243/capture-A.avi --fixed-fps 30 -- --anim-demo capture --anim-variant A'
ssh aux 'cd ~/NO-KINGS && caffeinate -i tools/godot-lock.sh $HOME/bin/godot --path game --write-movie /tmp/no243/capture-B.avi --fixed-fps 30 -- --anim-demo capture --anim-variant B'
ssh aux 'cd ~/NO-KINGS && caffeinate -i tools/godot-lock.sh $HOME/bin/godot --path game --write-movie /tmp/no243/merge-A.avi --fixed-fps 30 -- --anim-demo merge --anim-variant A'
ssh aux 'cd ~/NO-KINGS && caffeinate -i tools/godot-lock.sh $HOME/bin/godot --path game --write-movie /tmp/no243/merge-B.avi --fixed-fps 30 -- --anim-demo merge --anim-variant B'
ssh aux 'cd ~/NO-KINGS && caffeinate -i tools/godot-lock.sh $HOME/bin/godot --path game --write-movie /tmp/no243/score-A.avi --fixed-fps 30 -- --anim-demo score --anim-variant A'
ssh aux 'cd ~/NO-KINGS && caffeinate -i tools/godot-lock.sh $HOME/bin/godot --path game --write-movie /tmp/no243/score-B.avi --fixed-fps 30 -- --anim-demo score --anim-variant B'
```

Leaving out `--anim-variant` records the current behaviour, which is a useful third clip for comparison.

To compare two clips side by side, if ffmpeg is installed:

```sh
ffmpeg -i /tmp/no243/capture-A.avi -i /tmp/no243/capture-B.avi -filter_complex hstack /tmp/no243/capture-AB.mp4
```

## Where the code lives

- `game.gd`: `anim_variant` (a static var), `_add_pop` (death snapshot), `_add_arrive`, `_add_merge_fx`, `_draw_variant_anim`, and the demo driver (`ANIM_DEMO_CFG`, `_run_anim_demo`).
- `wave_logic.gd` `spawn_pending` → `_add_arrive`. `merge_logic.gd` `commit_merge` → `_add_merge_fx`.
- `hud.gd` `_counter_variant` / `_flash_delta` (case 4).
