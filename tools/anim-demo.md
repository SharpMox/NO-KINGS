# NO-243 board animations: recording the demos

Throwaway branch `probe/no-243-demo` (PR #557's head plus this driver). Not for merge.

`--anim-demo arrive|capture|merge` (after the bare `--`) boots a fixed board as a scenario, which never autosaves. It fires the case 4 times, 1.5 s apart, then quits. Each run lasts about 7.5 s. The Settings "animations" toggle must be on, or the pieces just snap.

Record on Aux with Godot Movie Maker, windowed (not `--headless`). Check out inside the lock, then record one at a time:

```sh
ssh aux 'cd ~/NO-KINGS && caffeinate -i env GODOT=$HOME/bin/godot tools/godot-lock.sh sh -c "git fetch --prune -q && git checkout --detach -q origin/probe/no-243-demo && mkdir -p /tmp/no243"'
ssh aux 'cd ~/NO-KINGS && caffeinate -i tools/godot-lock.sh $HOME/bin/godot --path game --write-movie /tmp/no243/arrive.avi --fixed-fps 30 -- --anim-demo arrive'
ssh aux 'cd ~/NO-KINGS && caffeinate -i tools/godot-lock.sh $HOME/bin/godot --path game --write-movie /tmp/no243/capture.avi --fixed-fps 30 -- --anim-demo capture'
ssh aux 'cd ~/NO-KINGS && caffeinate -i tools/godot-lock.sh $HOME/bin/godot --path game --write-movie /tmp/no243/merge.avi --fixed-fps 30 -- --anim-demo merge'
```
