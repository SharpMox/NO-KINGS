# Manual steps only you can do — the blockers on 86 / 87

Everything in this file needs an account, a payment, a device or a GUI login. Nothing here can
be done from the dev loop, which is why these two slices are stalled while the rest of the
backlog is merged.

Ordered so that **section A unblocks Android entirely**. iOS is deliberately last — see
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

### A3. Find Play Games Services — it is NOT top-level
Everything below lives under one collapsed menu:

> **Grow users -> Play Games Services -> Setup and management**

If the sidebar only shows *Dashboard / Statistics / Publishing overview / Protected with Play /
Test and release / Monitor and improve / Grow users / Monetize with Play*, then **Grow users**
is collapsed — expand it. There is no top-level "Play Games Services" entry.

### A4. Create the Games Services project
**Setup and management -> Configuration** asks *"Which Play Games Services project do you want
to use?"* with exactly two radio options:

- **Create new Play Game Services project**  <- pick this
- Use an existing Play Games Services project

It then asks for a **Google Cloud project** to link ("Choose a cloud project to link with your
PGS project"). Let it create one unless this game already has a Cloud/Firebase project.

> Google's own docs (developer.android.com/games/pgs/console/setup) still describe an older
> three-option screen with *"No, my game doesn't use Google APIs"*. That wording is gone —
> verified against the live console 2026-09-02. Trust the console, not the doc.

#### A4a. The Cloud project it asks for

The dialog will not proceed without one ("Cloud project is a required field"). Click
**Create new cloud project** — it opens the Google Cloud console in a new tab.

- **Organisation: choose "No organization".** A GCP organisation is not a name you type — it
  is created by claiming a domain (sharpunk.com) in Cloud Identity or Workspace, which mints
  new identities like `max@sharpunk.com`. The Play Console developer account here is
  `charp.max@gmail.com`, and the PGS dialog requires you to be an **owner** of the Cloud
  project for it to even appear in the list. Creating the project under a different identity is
  a fast route to an ownership mismatch that looks like a bug.
  **Keep everything on the single Google account that owns the Play Console entry.**
  Cloud Identity Free does exist if sharpunk ever becomes a multi-person company, and projects
  can be migrated into an organisation later — so this is deferral, not a closed door.
- Name it something obvious, e.g. `no-kings`. The project ID is generated from it.
- **Do NOT attach a billing account.** Creating a project is free, and the Games API is not a
  billable service. Google's own PGS docs only mention billing under *viewing and managing
  quota* (developer.android.com/games/pgs/quota), not under using PGS. If something genuinely
  blocks on billing, stop and say so rather than entering a card — that would be a finding, not
  a normal step.
- Back in the Play Console, click **Refresh cloud projects**, select it, then **Use**.

Two constraints the dialog states, worth not tripping over:

- **A Cloud project can be linked to only ONE PGS project.** Do not reuse a project that
  already backs another game.
- **You must be an "owner" of the Cloud project** for it to appear in the list. Creating it
  yourself satisfies that.

Then **Properties -> Edit properties** and set a display name — required before testing.

### A5. Create the OAuth credential — **the actual blocker**
Still in **Configuration**, the **Credentials** section -> **Add credential** -> type
**Android**. It asks for the package name and the **SHA-1** from the table above. This is the
one thing that cannot be produced locally: the credential binds to *both* the package name
*and* the signing certificate.

You may be asked to configure the OAuth consent screen first. The scopes involved are
`games`, `games_lite` and **`drive.appdata`** — the last is what Saved Games uses.

> **Give it the DEBUG SHA-1 for now.** A release build is signed with a different key and needs
> its own credential later. That is expected, not a mistake.

### A6. ENABLE SAVED GAMES — do not skip this
This is the feature slice 86 actually needs: Play Games **Snapshots** is what
`cloud_backend_play_games.gd` mirrors saves through. **Sign-in can work perfectly while every
save silently fails** if it is left off.

**It is not its own nav item.** The Setup and management list is *Configuration / Achievements /
Game Stats / Events / Leaderboards / Publishing / Testers* — no "Saved Games" entry. It is a
per-game setting inside **Configuration** (alongside the other game properties), and it may
only appear once the PGS project from A4 exists.

If you cannot find the toggle after A4, say so — the fallback is that Saved Games is implied by
the `drive.appdata` OAuth scope from A5, and we confirm it works on device instead.

### A7. Create the leaderboard
**Setup and management -> Leaderboards -> Create leaderboard.**

- Name: `High Score`
- Format: **Integer**, higher is better
- **Copy the leaderboard ID** it generates (looks like `CgkI...`) and send it to me. The code
  needs it as a constant and there is no way to guess it.

### A8. Add yourself as a tester
**Setup and management -> Testers.** Add your own Google account, or on-device sign-in fails
with an unhelpful error. This step is skipped constantly and costs an hour of confusion.

### A9. Publish the Games Services configuration
PGS settings have their own **Publish Game** action, separate from publishing the app. The
configuration must be published before it takes effect on a device — the app itself does not
need to be published.

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
3. App Store Connect -> create the app with bundle id **`com.sharpunk.nokings`** (user
   ruling 2026-09-02: match Android). Bundle ids are as permanent as Android's.
4. Enable the **iCloud key-value store** capability, entitlement
   `com.apple.developer.ubiquitous-key-value-store`.
5. Create the leaderboard in App Store Connect and copy its id back to me.
6. A real iPhone — Game Center does not fully work in the simulator.
7. **Build the plugins from source.** `godotengine/godot-ios-plugins` has no Godot 4 release —
   every published artifact is Godot 3 — so `gamecenter` and `icloud` must be compiled from
   master with Xcode.

---

## What I do the moment A1-A9 are done

1. Install `godot-sdk-integrations/godot-play-game-services` into `addons/`.
2. Flip `gradle_build/use_gradle_build=true` — **already proven to build** (77.8 MB APK).
3. Fill in `cloud_backend_play_games.gd` against the cache-and-defer shape in issue 86's fit
   analysis, so the synchronous contract survives the async SDK.
4. Wire the leaderboard id from A7.
5. Build, install to the device from B, and verify sign-in, a save round-trip and a
   leaderboard submit **on the device** — the only verification that counts here.
