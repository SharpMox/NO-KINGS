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
- **All of iOS — NO-14, and NO-8's iOS half.** Zero device verification, because
  there is no iPhone. The simulator has proven the iCloud KV round-trip and a
  Game Center sign-in (2026-09-04, and no paid account was needed for either —
  see `game/ios/plugins/README.md` for the retraction of the claim that it was).
  What the simulator cannot do is provisioning, which is the point of T3b and T6.
  A real leaderboard submit additionally waits on Apple issuing the board id.
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
