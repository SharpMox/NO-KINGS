# Driving an iPhone from the Mac

How to get a build onto a physical iPhone, screenshot it, and read its files —
without a human touching the phone. Established 2026-09-10 on a borrowed
iPhone 11 (iOS 26.6.1); see `docs/device-verification.md` for what that session
actually verified.

**This is the RECIPE. `docs/device-verification.md` is the RECORD, and
`docs/MANUAL-STEPS.md` is the list of things only Max can do.** Three files, three
jobs; this one is the only one an agent executes.

**What works: build, install, launch-with-arguments, screenshot, read the app's
files.** What does NOT work yet: sending a tap. See *Input injection* at the end —
the route is known and cheap, it just was not built on the night this was written.

---

## The one-time GUI step, and why it cannot be avoided

**`xcodebuild` cannot register a device or create a provisioning profile.** It
fails with:

```
error: Device "iPhone …" isn't registered in your developer account. The device
       must be registered in order to be included in a provisioning profile.
error: No profiles for 'com.sharpunk.nokings' were found.
```

`-allowProvisioningUpdates` does not rescue it: that flag needs its own
authenticated App Store Connect session (an API key `.p8`), and **Xcode.app being
signed in does not extend to `xcodebuild`.**

So, **once per device**, a human does:

```sh
open -a Xcode <worktree>/build/ios/nokings.xcodeproj
# select the iPhone in the scheme dropdown, press ⌘R
```

Xcode registers the device, creates the profile, builds, installs and launches.

**After that, everything below is headless.** The profile lands in
`~/Library/Developer/Xcode/UserData/Provisioning Profiles/` (NOT the legacy
`~/Library/MobileDevice/Provisioning Profiles/`, which Xcode 26 leaves empty) and
`xcodebuild` reuses it — verified by a second, CLI-only build that reported
`Provisioning Profile: "iOS Team Provisioning Profile: com.sharpunk.nokings"` and
`** BUILD SUCCEEDED **`. The GUI step is per-device, not per-build.

---

## The loop

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
DEV=<the identifier from `xcrun devicectl list devices`>   # a UUID, not the UDID
TEAM=DGT6GH7583

# 1. export the Xcode project (headless, no signing involved)
godot --headless --path game --export-debug "iOS" ../build/ios/nokings.zip

# 2. WRITE THE ENTITLEMENTS. The exporter emits an EMPTY dict even with both
#    plugins enabled in the preset, and a signed app without these has no Game
#    Center and no iCloud (NO-47). Do this after EVERY export.
cat > build/ios/nokings/nokings.entitlements <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
	<key>com.apple.developer.ubiquity-kvstore-identifier</key>
	<string>$(TeamIdentifierPrefix)com.sharpunk.nokings</string>
	<key>com.apple.developer.game-center</key>
	<true/>
</dict></plist>
PLIST

# 3. build and sign (headless, reuses the profile from the one-time step)
cd build/ios
xcodebuild -project nokings.xcodeproj -scheme nokings \
  -destination "id=$DEV" -configuration Debug -allowProvisioningUpdates \
  CODE_SIGN_STYLE=Automatic DEVELOPMENT_TEAM="$TEAM" build

# 4. install
APP=~/Library/Developer/Xcode/DerivedData/nokings-*/Build/Products/Debug-iphoneos/nokings.app
xcrun devicectl device install app --device "$DEV" "$APP"

# 5. launch — NOTE THE BARE `--`, see below
xcrun devicectl device process launch --device "$DEV" --terminate-existing \
  com.sharpunk.nokings -- --screenshot "user://"

# 6. pull whatever the app wrote
xcrun devicectl device copy from --device "$DEV" \
  --domain-type appDataContainer --domain-identifier com.sharpunk.nokings \
  --source Documents --destination ./pulled
```

Step 5 + 6 together are the screenshot pipeline: the game's existing
`--screenshot <dir>` bypass writes `menu.png` and `game.png` into `user://`, and
step 6 brings them back. **No human, no WebDriverAgent, no Appium.**

`--scenario N` works the same way, so any TEST scenario can be booted and
screenshotted from the Mac.

---

## Traps, each of which cost time

**THE BARE `--` IS LOAD-BEARING.** The flags are read with
`OS.get_cmdline_user_args()` (`intro.gd:60`, `menu.gd:443`, `game.gd`), which
returns only what follows a `--` separator — that is why `run_all.sh` writes
`godot --path . -- --autoplay`. `devicectl` passes arguments straight through, so
without the separator Godot sees an empty user-arg list and **silently ignores
every flag**. First attempt produced no screenshot and no error; adding `--`
produced both PNGs immediately.

**A SCREENSHOT CANNOT SHOW THE NOTCH.** `--screenshot` captures the framebuffer;
the OS composites the notch, rounded corners and home indicator *over* it. So a
safe-area defect looks perfectly fine in a captured PNG — the top bar in
`game.png` reads cleanly while on the physical screen the notch covers it (see
`device-verification.md`). **Never verify a safe-area fix from a screenshot.**
That needs eyes, or a simulator with the device bezel.

**`devicectl … launch --console` OWNS the app's lifetime.** Killing the console
process terminates the app on the device (`App terminated due to signal 15`).
Launch without `--console` when the app should stay up.

**`--console` relays `NSLog`/`os_log` ONLY — not Godot's `print` or `printerr`.**
This was first written down as "`--console` is a poor log transport" after it
yielded 7 lines in 45 seconds with no `[ic-bridge]` output while Xcode's console
had it. The mechanism, established 2026-09-10: the one Godot-side line it *does*
relay is `platform/ios/display_layer_ios.mm`'s literal `NSLog(@"Setting up an
OpenGL ES 3.0 context.")`. Godot's own output goes to stdout/stderr, which Xcode
captures because it attaches a debugger and `devicectl` does not. Ruled out along
the way: it is not buffering — the app was exited cleanly by driving the menu's
own Quit button and the missing lines still never appeared.

So **an absence through `--console` is not evidence**, but the positive path is
cheap and needs no Xcode and no human: anything that must be readable from the
host should be `NSLog`ed. That is how `scopedIDsArePersistent` was read off the
device for NO-53 — one `NSLog` in the vendored plugin, then
`devicectl … launch --console` and a `grep`. Log a boolean or a shape, never an
identifier.

`log stream` is not an alternative: this macOS build has no `--device` option, so
there is no host-side iOS `os_log` stream at all.

**There is no CLI screenshot verb.** `xcrun devicectl device` offers only info,
install, process and uninstall; libimobiledevice is not installed. The pipeline
above works because the *app* takes the screenshot, not the host.

**`devicectl list devices` shows two different identifiers.** The `Identifier`
column is a CoreDevice UUID and is what `--device` wants; the UDID
(`xcrun devicectl device info details`) is what the developer portal wants.

**Do not add a UI test target to the game's Xcode project.** Godot regenerates
`build/ios/nokings.xcodeproj` on every export, so anything added there is
destroyed by the next build. Nothing device-side belongs in that project.

---

## Input injection — BUILT

The route recommended here (a debug input path in the game rather than
WebDriverAgent) was taken. WDA was rejected and stays rejected: a second app to
build, sign and keep installed, its own provisioning profile, its own one-time
GUI step, re-signed whenever the certificate rolls, and nothing about it in this
repo for anyone to maintain.

`game/scripts/drive.gd`, active only under `--drive <dir>`. Read its header
before using it; the essentials:

```sh
# launch it (note the bare `--`, as above)
xcrun devicectl device process launch --device "$DEV" --terminate-existing \
  com.sharpunk.nokings -- --drive "user://drive"

# then, per batch: write cmd.txt, wait, read ack.txt
xcrun devicectl device copy to   --device "$DEV" --domain-type appDataContainer \
  --domain-identifier com.sharpunk.nokings --source cmd.txt --destination Documents/drive/cmd.txt
xcrun devicectl device copy from --device "$DEV" --domain-type appDataContainer \
  --domain-identifier com.sharpunk.nokings --source Documents/drive/ack.txt --destination ack.txt
```

`cmd.txt` is a `seq <n>` header then one command per line; `ack.txt` is
`seq <n> ms <elapsed>` then one `ok`/`fail <verb> <reason>` line per command.
**Sequence numbers must increase** — a batch numbered below the last one is
correctly ignored, and reading the previous ack back then looks like a pass.

**COORDINATES ARE WINDOW PIXELS, NOT CANVAS PIXELS.** This cost two device
sessions. `Input.parse_input_event` is read as window-space and transformed
*into* canvas space, so on desktop (480x800 window, 480x800 canvas) the
transform is identity and the bug is invisible, while on an iPhone 11
(828x1792 window, ~480 canvas) every tap lands ~370 canvas px off and actuates
nothing. `drive.gd` scales canvas→window itself and `probe` reports both sizes.
Full mechanism in the file's header.

**BATCH EVERYTHING; DO NOT TIGHTEN THE POLL.** Measured on an iPhone 11: one
host round trip (`copy to` + `copy from`) is **0.43s** and is paid **once per
batch**, so a 42-command batch cost **0.73s** of host overhead in total and ran
at roughly 19 commands/sec excluding deliberate waits. The 0.25s in-app poll is
also once per batch and is therefore irrelevant to throughput — lowering it
burns battery and frames to shave a cost nobody pays. One command per file is
the slow way to use this.

**Prefer `wait_text` over `wait_settled`.** `wait_settled` md5s the framebuffer
each iteration, which is ~5.9MB per pass at 828x1792. And keep timeouts tight:
in one 42-command tour, four 6000ms `wait_text` timeouts were 24 of the 26
seconds, which read as "the driver is slow" when it was the script's own waits.

The loop above already delivered the expensive half — a build on the device and
a screenshot back, no human in it. With the driver, a device check that needs a
tap no longer needs one either.

---

## A DISTRIBUTION archive (TestFlight) — three things that block it

Attempted 2026-09-10 and **not completed**; recorded because all three are
reproducible and cost nothing to know in advance. The loop above builds
*development*-signed apps, which is a different thing.

**1. Godot's exported Release config cannot be signed as generated.** The
exporter writes both `CODE_SIGN_IDENTITY = "Apple Distribution"` *and*
`CODE_SIGN_STYLE = Automatic` into `build/<dir>/nokings.xcodeproj`, and Xcode
treats an explicit identity under automatic signing as a manual override:

```
error: nokings has conflicting provisioning settings. nokings is automatically
signed for development, but a conflicting code signing identity Apple
Distribution has been manually specified.
```

Clearing the identity in the **generated** project lets automatic signing pick
one. It belongs in the build script, not the repo — Godot rewrites that file on
every export:

```sh
sed -i '' 's/CODE_SIGN_IDENTITY = "Apple Distribution";/CODE_SIGN_IDENTITY = "";/g' \
  build/tf/nokings.xcodeproj/project.pbxproj
```

Do **not** "fix" it by setting the identity to `Apple Development`, which is
what the error message suggests: that produces a development-signed archive,
which is not uploadable and silently defeats the purpose.

**2. There is no distribution certificate.** `security find-identity -v -p
codesigning` returns exactly one identity, `Apple Development`. Whether
`xcodebuild -allowProvisioningUpdates` can mint a distribution certificate
headlessly is **untested** — assume it may need a GUI step or an account action
and budget for it.

**3. Declare export compliance in the build, not in the web UI.** Otherwise the
first upload parks waiting on a form. This game has no non-exempt encryption, and
the preset carries the answer:

```
application/additional_plist_content="<key>ITSAppUsesNonExemptEncryption</key>\n<false/>"
```

Verified present in the generated `nokings-Info.plist` after export.

Also worth knowing: **the build number must be its own value.** The preset had
`application/version` equal to `application/short_version` ("0.1.0"), which
leaves no room to upload a second build of the same marketing version;
`application/version` is now `1`. `CFBundleVersion` reads back as
`$(CURRENT_PROJECT_VERSION)` in the plist because it is a build setting — check
`project.pbxproj`, not `plutil`, to confirm it took.
