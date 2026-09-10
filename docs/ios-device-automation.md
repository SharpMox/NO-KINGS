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

**`--console` is also a poor log transport.** It yielded 7 lines in 45 seconds and
no `[ic-bridge]` plugin output at all, while Xcode's console had it. Use Xcode's
console for anything involving plugin logging; do not read an absence through
`--console` as evidence.

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

## Input injection — not built, route known

Sending a tap is the one missing piece. Two routes:

**WebDriverAgent / XCUITest.** The standard answer, and it fits badly here: WDA
is a second app to build, sign and keep installed, its bundle id needs its own
provisioning profile (so another one-time GUI step), and it would have to be
re-signed whenever the certificate rolls. Nothing about it is in our repo, so
nobody would maintain it.

**A debug input path in the game itself — recommended.** We own the app, so the
cheap version is a debug-only bypass in the same family as the ones that already
exist (`--scenario`, `--autoplay`, `--screenshot`): read a command list and
synthesise `InputEventScreenTouch` / `InputEventScreenDrag`. That is ordinary
GDScript, it survives Godot's project regeneration because it lives in
`game/scripts/` rather than the Xcode project, it needs no extra signing, and it
would work on **Android too** — where `adb input tap` already covers it, but a
single mechanism for both platforms is worth more than two.

Either way the loop above already delivers the expensive half: a build on the
device and a screenshot back, with no human in it.
