# Device verification log

What has actually been confirmed on real hardware, and by whom.

**This file exists because a PR body cannot be updated.** Four fixes shipped in
`770db2d` with "UNVERIFIED ON DEVICE" written into their PR descriptions. Those
descriptions are merged and immutable, so the caveat outlives the fact — and a
stale "unverified" is worse than an accurate one, because the next reader either
re-does the work or stops trusting the label anywhere. This is the single
forward pointer those PRs do not have.

**Newest build first. Append only.** Add a new block at the top; never
reorganise, never edit an old block to reflect later knowledge — add the later
knowledge as its own entry. A record you can rewrite is not a record.

**The "still unverified" section is half the point, not an afterthought.** A log
that only collects wins reads as a claim that everything else is fine, which is
a worse lie than having no log at all. Anything genuinely untested on hardware
belongs there, including the things nobody has got to yet.

Not a substitute for the suite. `game/tests/run_all.sh` carries the regression
protection; a human tapping a phone once does not, and cannot be re-run. What a
device verification establishes is the thing a desktop probe genuinely cannot:
that the probes were telling the truth about hardware.

---

## `8657977` — 2026-09-10, iOS — FIRST EVER RUN ON iOS HARDWARE

**iPhone 11 (iPhone12,1), iOS 26.6.1 (23G83)**, UDID `00008030-001160D01486402E`,
over cable with Trust accepted and Developer Mode already enabled. Built and run
by **Max** from Xcode.app; the reads below are mine, from the built artifact and
the device.

**The iPhone was BORROWED and is not Max's**, and it is signed into its owner's
Apple ID and Game Center account. So anything account-shaped verified here was
verified against a third party's identity, not his — a real limit on what these
results mean, and why the account-touching steps were held until he authorised
them ("No worries about the iphone account… Do everything we can now on this
iphone").

**Do not assume any iPhone would have done as well.** This one arrived with
Developer Mode already enabled, which is normally a detour, and it is signed into
a **non-Latin-script Game Center account** — which is the only reason the mojibake
defect below was found at all. Every account this project owns is Latin, so that
bug would have shipped invisibly.

Confirmed:

| | |
| --- | --- |
| **It builds for a device** | arm64, TeamIdentifier `DGT6GH7583`, signed |
| **It installs** | `com.sharpunk.nokings`, "No Kings", version 0.1.0 |
| **It runs** | process alive on device, pid 29973, from the app bundle |
| **Entitlements survive signing** | see NO-47 below — this is the night's real finding |

### It needs Xcode.app. `xcodebuild` cannot do it, and this is the hour-saver

The command-line build fails with exactly two errors:

```
error: Device "iPhone …" isn't registered in your developer account. The device
       must be registered in order to be included in a provisioning profile.
error: No profiles for 'com.sharpunk.nokings' were found.
```

`-allowProvisioningUpdates` does **not** rescue it. Registering a device and
creating a provisioning profile need an authenticated App Store Connect session,
and **Xcode.app being signed in does not extend to `xcodebuild`** — the CLI needs
its own credential, i.e. an App Store Connect API key (`.p8`), which we do not
have. Xcode.app does both silently and then builds, installs and launches.

So: export headlessly, then `open -a Xcode build/ios/nokings.xcodeproj`, select the
device, ⌘R. Until an ASC API key exists, the GUI step is not avoidable.

### NO-47, answered — entitlements are NOT stripped

The exporter writes `nokings/nokings.entitlements` as an **empty dict** even with
`plugins/GameCenter=true` and `plugins/iCloud=true` in the preset. Reproduced here
on the device path, not just the simulator. Written in by hand before building:
`com.apple.developer.game-center` and
`com.apple.developer.ubiquity-kvstore-identifier` = `$(TeamIdentifierPrefix)com.sharpunk.nokings`.

`codesign -d --entitlements` on the SIGNED device binary:

```
application-identifier                          => DGT6GH7583.com.sharpunk.nokings
com.apple.developer.game-center                 => true
com.apple.developer.team-identifier             => DGT6GH7583
com.apple.developer.ubiquity-kvstore-identifier => DGT6GH7583.com.sharpunk.nokings
get-task-allow                                  => true
```

Both present, `$(TeamIdentifierPrefix)` expanded correctly, and the provisioning
profile Xcode generated carries the same capabilities (`game-center` true,
`ubiquity-kvstore-identifier` `DGT6GH7583.*`). Portal, profile and binary all
agree. **So "entitlements do not survive signing" is dead as a hypothesis** — the
defect is the exporter's silence, and the rule is: fill that file in after every
export, or you get a signed app with no Game Center and no iCloud, which produces
the log line that misled this project in September.

### Game Center authentication SUCCEEDS on real hardware

Read off Xcode's console, from the plugin's own event:

```
[ic-bridge] gc event: {"result":"ok","type":"authentication","player_id":"DE23264F…","alias":"…","displayName":"…"}
```

`result: "ok"` with a real `teamPlayerID`. This had never been proven on hardware
— only on the simulator. The sign-in fires automatically at launch (see the
lifecycle note below), so it needs no interaction.

**The same line exposed a defect no account we own could have found:** the
borrowed account's name is non-Latin, and `alias`/`displayName` came back as
mojibake while `player_id` came back perfect. Mechanism, from source:
`plugins/gamecenter/game_center.mm:130-131` assigns `[player.alias UTF8String]`
— valid UTF-8 bytes as a `const char*` — into a Godot `String`, and Godot's
`const char*` path parses **Latin-1**. `player_id` at `:134` takes the identical
path and survives only because it is hex ASCII, where the two encodings agree.
Fix is `String::utf8(...)` per site, in the vendored patch. Our code reads only
`player_id` (grep: `alias`/`displayName` appear nowhere in `game/scripts/`), so
it is log-only today and player-facing the moment anyone displays a Game Center
name.

### The four Android-verified fixes, re-checked on iOS

Verified on Android against build `770db2d`; this file's own rule is that a build
inherits nothing automatically, so they were re-run here. Max played one run on
the device.

| | On iOS |
| --- | --- |
| **#379** TEST-menu list drag-scroll | **WORKS.** "1 works" — the fix holds on iOS's input stack too |
| **#375** resume mid-turn after backgrounding | **WORKS.** "resume works fine" |
| **#373** artefact art in the Shop | **WORKS.** "looks good too" — second platform confirmed |
| **#381** captured stock convert/sell | **NOT VERIFIED — deliberately dropped.** See below |

**#375 is worth recording as a PREDICTION THAT WAS WRONG, not just a pass.** Both
the coordinating session and I expected it to be the one that differed: iOS
suspends rather than backgrounds, and `game.gd`'s resume path was written against
Android's lifecycle. It behaved identically. The reasoning was sound and the
conclusion was wrong, which is worth more in a record than a bare tick — the next
person should not re-derive that worry from scratch, and should also not trust it.

**#381 was dropped by user ruling, not left as an outstanding test.** Max: "So
lets not verify this implementation we will just change it later." He dislikes the
convert-badge UI and intends to redesign it. The scenario also carries $0 gold, so
convert could not have been exercised without editing it. **A future reader should
not treat this as a gap to close** — the implementation it would test is expected
to change first.

**NO-45 (artefact drawer drag-scroll) could not be tested**: the captured-stock
scenario carries no inventory, so the drawer had nothing to scroll. Still open,
still unverified on any device.

### NEW DEFECT: the iOS safe area is not respected anywhere

Max, on the running game: "the score and money are being hidden by the notch right
now". Confirmed from source, and it is not handled wrongly — **it is not handled
at all**.

`grep` for `safe_area`, `get_display_safe_area` and `SafeArea` across
`game/scripts/*.gd` and `game/project.godot` returns **nothing**. Godot exposes
`DisplayServer.get_display_safe_area()`; the project never calls it.

The top strip positions itself from the viewport, at a hardcoded 4px inset
(`hud.gd:178-180`):

```gdscript
var top := HBoxContainer.new()
top.position = Vector2(10, 4)
top.custom_minimum_size = Vector2(vp.x - 56, 0)
```

On an iPhone 11 the portrait status/notch region is roughly 44pt tall, so the
clock, score and gold sit underneath it. `menu_btn.position = Vector2(vp.x - 34, 3)`
(`hud.gd:196`) has the same shape, and takes its x from the viewport width rather
than from any right inset.

**A fix is layout-wide, not a nudge to one label.** `game.gd`'s `_layout_board`
takes the board's y from the top strip's height, so the strip's position feeds the
board's position; moving the strip without threading the inset through that
calculation just moves the collision. The bottom edge (home indicator, under the
Stock/Inventory/Shop row and PASS) was NOT reported as broken and is untested
rather than proven fine — the deck absorbs slack there, which may be why.

### Also found: the scenarios built for hand-testing are the hardest to reach

Not a bug, a real cost — it slowed tonight down. `menu.gd:693-721` groups TEST
scenarios by the text before the first `:` or `(`, then folds every
single-member section into a catch-all **"Other"**, which is sorted last however
large it grows. The generated per-artefact scenarios form 34 big sections; the
hand-written scenarios — the ones that exist *for* hand-testing, with distinct
names and therefore usually a section of one — all end up in "Other", at the
bottom, behind everything. Both scenarios needed tonight were there.

### THE HEADLINE FINDING: the Game Center player id CHANGES ON EVERY LAUNCH

Two consecutive ⌘R launches of the same unmodified install, both `"result":"ok"`,
captured from Xcode's own console:

```
launch 1: player_id 27CB0CEA034A5C064F9A3E2AC5DF5B6D991C466C5A7B39A83C44F1C0D7B47996
launch 2: player_id C474E39F1D1EA86008DF4153706E8A4E16D6541344D57065259B5D621DFBC6E1
```

**It is definitely the same account.** `alias` and `displayName` are byte-identical
in both events — the same (mojibake) string — so no account switch happened
between them. Same human, same account, a different 64-hex id each time. Five
distinct ids were observed across five launches this evening, including the value
stored in `account.json` at bind time, which matches none of the later ones.

Transcription error is ruled out: these two came from screenshots of Xcode's
console rather than retyping, and the identical alias is the control.

**The consequence chain, all of it now fact rather than suspicion:**

- `cloud_backend_ios.gd:is_available()` is `Bridge.signed_in and Account.owner()
  == Bridge.player_id`. With the live id changing every launch it is
  **permanently false on iOS**. `push` is never reached, so **nothing is ever
  written to iCloud** — cloud save cannot engage at all on this platform.
- `menu.gd:211` raises the account-switch prompt whenever `Account.owner() != id`,
  so that prompt fires on **every launch**. Which makes the whole-menu layout
  defect below the *permanent* state of the iOS main menu, not an occasional one.
- **The iCloud KV round trip is therefore BLOCKED, not untested.** It was the
  night's third priority and it cannot succeed while this holds; recorded as
  blocked with a proven cause, which is worth more than a failed attempt.

**No cause claimed.** Apple documents `teamPlayerID` as stable per player per
team, so something is not behaving as documented. Candidates, none tested:
`plugins/gamecenter/game_center.mm:133-137` picks `teamPlayerID` under
`@available(iOS 13, *)` and falls back to `playerID`; and a development-signed
build may scope the id differently. That is a source investigation and it needs
no phone — which is exactly why the reproduction was banked tonight and the
theory was not.

### The app's own files CAN be read from the Mac

`xcrun devicectl device copy from --device <id> --domain-type appDataContainer
--domain-identifier com.sharpunk.nokings --source Documents --destination <dir>`
pulls Godot's `user://` off the device. That is how the local half of any
cloud-save claim gets checked — `account.json` for the binding, the save file for
the write — without touching the phone.

Baseline immediately after first run, before any account binding: the container
held **only `shader_cache/`** — no `account.json`, no save, no settings. Two
things follow. The clean baseline makes any later state a diff rather than an
assertion. And the caches present were `CanvasShaderGLES3`, `SceneShaderGLES3`,
`PostShaderGLES3`, `CopyShaderGLES3` and `FeedShaderGLES3` — the app compiled
canvas AND scene shaders, so it got as far as really rendering, not just creating
a GL context.

### What could NOT be observed from the Mac, and the traps that cost time

**No screenshot.** `xcrun devicectl device` has no screenshot verb (only info /
install / process / uninstall), libimobiledevice is not installed
(`idevicescreenshot` absent), and `log stream` rejects a device UDID on this
macOS. So "it reaches the menu" cannot be established from the Mac at all —
whoever holds the phone is the instrument. Plan the session around that rather
than discovering it with the hardware already in hand.

**The log route exists but is thin.** `xcrun devicectl device process launch
--console --terminate-existing <bundle-id>` does attach and stream the app's
output. It produced **7 lines in 45 seconds** and no `[ic-bridge]` output, so
either Godot's `printerr` does not reach that stream or no event arrived — and
the two are indistinguishable from the Mac, which makes the absence of a line
there **not** evidence of anything. What it did prove: `Setting up an OpenGL ES
3.0 context`, i.e. the renderer initialises on real hardware. **Use Xcode's
console for anything that matters.**

Two lifecycle facts from using it: `--console` **owns the app's lifetime** — killing
the devicectl process terminates the app on the device (`App terminated due to
signal 15`), so launch WITHOUT `--console` if the app should stay up. And launched
without it, the app was **still running 25 s later**, which is how "does not crash
on startup" was established.

Also worth knowing: **the app authenticates Game Center BY ITSELF at launch.**
`ios_cloud_bridge.gd`'s `_ready()` starts a 0.5s timer whose `_poll()` calls
`authenticate()` until the call is accepted. There is no way to run the iOS build
without attempting a Game Center sign-in against whatever account the device holds
— which matters when the device is borrowed.

## `770db2d` — 2026-09-10

**Nothing Phone 2a (A142), Android 16.** Installed over wireless debugging from
`nokings-universal.apks` (bundletool `--mode=universal` over the debug AAB,
signed with the debug keystore — SHA-1 verified against the documented key
rather than assumed, because without `--ks` bundletool only warns and the
install then fails silently).
Verified by **Max**, on his own device and his own live save. His words: *"The 4
things you asked to check in game are working."*

Device and OS are recorded deliberately: what was learned is that these four
work on **this** phone and **this** Android version, not that they "work on
Android".

Confirmed by Max:

| Shipped in | What was confirmed |
| --- | --- |
| **#379** | TEST-menu scenario list drag-scrolls under a finger, and the row under the finger does **not** launch. A plain tap still does. |
| **#375** | Switching away mid-turn and back resumes the **same** turn — pause menu up, no actions redone or refunded. |
| **#373** | Artefact art renders: painted artefacts show their art in the drawer and the Shop, the other 142 and all 9 Boxes show the shared placeholder at the same size. No blank tiles, no reflow. Never once seen on a phone before this. |
| **#381** | Captured stock lists one row per captured piece, most recent first; Convert works with a duplicate of that piece held; no deploy dots are painted while dragging a captured piece. |

Also established by the install itself, separately from Max's taps: the build
launches to the intro title card and reaches the main menu, runs at a steady
60 fps, logs no `FATAL` and no `AndroidRuntime` crash, and Play Games sign-in
completes on device (`[pgs] player loaded: a_2378…` in logcat).

Scope of that evidence, stated plainly: a user confirming four features work,
against the descriptions above. It is not a per-case inspection — #373 was not
checked row by row across all 180 artefacts — and it is not an automated
assertion.

Artefacts, logs and the two screenshots (title card, main menu):
`~/Documents/nokings-builds/770db2d-2026-09-10/`.

## `8534eeaa` — 2026-09-10 (superseded by the above)

Same phone. Installed and launched to the intro title card; **the menu was never
reached** because the wireless transport dropped. So this build verified that it
installs and starts, and nothing about gameplay. Recorded because "it launched"
and "it works" are different claims and the distinction is the whole reason this
file exists.

---

# Still unverified on hardware

Everything below has never run on a physical device. Ordered by how likely it is
to matter.

- **The artefact drawer's own drag-scroll — NO-45.** Diagnosed only, from engine
  source: drawer rows are `MOUSE_FILTER_STOP` inside their `ScrollContainer`, so
  the press never reaches the container and its touch drag never starts. Same
  mechanism as #379, which IS now verified above — so the diagnosis is
  confirmed real on hardware and the fix shape is confirmed to work there. The
  ruling was not to start NO-45 until #379 was hardware-verified; that
  precondition is now satisfied, so it is unblocked.
- **Larry, the wave-201 finale — NO-7, #380.** Merged the same day as this
  build and not among the four Max checked, so no human has met him on a device.
  Reaching wave 201 by hand is impractical, so this needs a scenario rather than
  a play-through.
- **iOS beyond "it runs" — NO-14's T6, and NO-8's iOS half.** As of 2026-09-10 the
  game builds, installs and runs on a physical iPhone (see the `8657977` entry),
  which retires T3b. What is still unverified: whether it reaches the menu and
  renders correctly at iPhone 11's 1792x828 with a notch and home indicator; the
  iCloud KV round trip, which is **blocked** rather than untested — see the
  player-id finding; and T6's remaining script — relaunch reconnect, tombstone,
  wipe-and-restore. Account binding itself is confirmed (`account.json` on
  device).
  Everything account-shaped was additionally limited by the iPhone being borrowed
  and signed into someone else's Apple ID. A real leaderboard submit is blocked
  further back, on NO-51: there is no App Store Connect app record, so no
  leaderboard id exists to submit to.
- **A full cloud-save round trip on Android.** Play Games *sign-in* is confirmed
  on device (above). Push, pull and conflict resolution against real Play Games
  Saved Games are not — the account-switch and stale-snapshot defect family this
  code was written against was diagnosed on device, but the current code has not
  been re-exercised there.
- **Tablet sizing — NO-25, NO-26.** Built and asserted for the iPad half of
  `targeted_device_family=2`, never opened on a tablet.

## How to add to this file

Verify, then write the block. Not the other way round. One block per BUILD, not
per fix: a fix verified on a build is a fact about that build, and the next
build inherits nothing automatically — that is the assumption this file is here
to stop.

The install recipe, its traps, and what only Max can do live in
`docs/MANUAL-STEPS.md` section B. Those are steps; this is a record.
