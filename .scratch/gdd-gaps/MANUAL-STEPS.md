# Manual steps only you can do — the blockers on 86 / 87

Everything in this file needs an account, a payment, a device or a GUI login. Nothing here can
be done from the dev loop, which is why these two slices are stalled while the rest of the
backlog is merged.

Ordered so that **the first three unblock Android entirely**. iOS is deliberately last — see
issue 87 for why it is the harder half.

---

## A. Google Play Console — unblocks slice 86

### The exact values you will be asked for

| Field | Value | Where it came from |
| --- | --- | --- |
| Package / application ID | `com.sharpunk.nokings` | `export_presets.cfg:33` |
| App name | `No Kings` | `project.godot`, `package/name` |
| **Debug signing SHA-1** | `BE:78:92:BD:40:CF:62:CC:3A:F1:95:38:C1:1A:0E:C0:04:18:FF:FE` | read from the keystore below |
| Debug keystore | `~/Library/Application Support/Godot/keystores/debug.keystore` (alias `androiddebugkey`, password `android`) | Godot's generated debug key |

Re-read that fingerprint at any time with:

```sh
JAVA_HOME=/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home
"$JAVA_HOME/bin/keytool" -list -v -storepass android \
  -keystore ~/Library/Application\ Support/Godot/keystores/debug.keystore | grep SHA1
```

### A1. Create the developer account — **$25, one time**
<https://play.google.com/console/signup>. This is the only spend required for Android.

### A2. Create the app entry
Console -> **Create app**. Name `No Kings`, type **Game**, free. Nothing needs uploading yet —
the entry alone is what issues the credentials.

### A3. Create the Play Games Services project and link it
Console -> **Play Games Services -> Setup and management -> Configuration**. Create a new
Games Services project and link it to the `No Kings` app.

### A4. Create the OAuth client — **this is the actual blocker**
Games Services -> **Credentials -> Add credential -> Android**. It will ask for the package
name and the **SHA-1** above. This is what cannot be produced locally: the credential is bound
to *both* the package name *and* the signing certificate.

> **Give it the DEBUG SHA-1 above for now.** A release build is signed with a different key and
> needs its own credential added later — that is normal and expected, not a mistake.

### A5. Create the leaderboard(s)
Games Services -> **Leaderboards -> Create leaderboard**.

- Name: `High Score`
- Format: **Integer**, higher is better
- **Copy the leaderboard ID** it generates (looks like `CgkI...`). Paste it back to me — the
  code needs it as a constant, and there is no way to guess it.

### A6. Add yourself as a tester
Games Services -> **Testers**. Add your own Google account, or sign-in fails on device with an
unhelpful error. This step is skipped constantly and costs an hour of confusion.

### A7. Download the plugin config
Games Services -> **Configuration** offers a resources/config block. Save it — the plugin needs
the app id from it.

---

## B. An Android device — unblocks *verifying* slice 86

A phone with **Developer options -> USB debugging** on, plugged in. Then `adb devices` should
list it (`adb` is at `/opt/homebrew/share/android-commandlinetools/platform-tools/adb`).

An emulator with **Google Play services** also works, but a real device is less trouble.

This is what turns 86 from "written" into "verified" — and issue 86 is explicit that
`run_all.sh` ALL GREEN does **not** verify this slice.

---

## C. Only when you actually publish — not needed for any of the above

- **A release keystore**, kept somewhere safe and backed up. Losing it means never being able
  to update the app. Its SHA-1 needs its own credential (step A4 again).
- **`gradle_build/export_format=1`** — Google Play requires an **AAB**, not an APK, for new
  apps. Currently `0`.
- Store listing copy, screenshots, a privacy policy URL, and the content questionnaires.

---

## D. iOS — do this last, or not at all for now

Recommendation from issue 87: **ship Android first and leave iOS stubbed.** The seam is
designed for exactly that split. If you do want it:

1. **Install Xcode** (not just Command Line Tools — `xcodebuild` currently reports the CLT
   instance, so no iOS build can be produced here at all).
2. **Apple Developer Program — $99/year.** Needed for the iCloud entitlement *and* for device
   installs.
3. App Store Connect -> create the app with a bundle id (suggest `com.sharpunk.nokings` to
   match Android).
4. Enable the **iCloud key-value store** capability, entitlement
   `com.apple.developer.ubiquitous-key-value-store`.
5. Create the leaderboard in App Store Connect and copy its id back to me.
6. A real iPhone — Game Center does not fully work in the simulator.
7. **Build the plugins from source.** `godotengine/godot-ios-plugins` has no Godot 4 release —
   every published artifact is Godot 3 — so `gamecenter` and `icloud` must be compiled from
   master with Xcode.

---

## What I do the moment A1-A7 are done

1. Install `godot-sdk-integrations/godot-play-game-services` into `addons/`.
2. Flip `gradle_build/use_gradle_build=true` — **already proven to build** (77.8 MB APK).
3. Fill in `cloud_backend_play_games.gd` against the cache-and-defer shape in issue 86's fit
   analysis, so the synchronous contract survives the async SDK.
4. Wire the leaderboard id from A5.
5. Build, install to the device from B, and verify sign-in, a save round-trip and a
   leaderboard submit **on the device** — the only verification that counts here.
