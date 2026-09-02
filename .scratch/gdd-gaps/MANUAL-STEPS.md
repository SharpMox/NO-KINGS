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

- **Organisation: take `sharpunk.com` if the dropdown offers it, otherwise "No organization".**
  A GCP organisation is not a name you type — it exists only if the domain is already claimed
  in Google Workspace or Cloud Identity, in which case it appears in this dropdown for free and
  is the tidier choice. If only "No organization" is offered, take it: it is fully functional
  and projects can be migrated into an organisation later. **Do not set up Cloud Identity just
  to satisfy this field.**

  The PGS dialog requires you to be an **owner** of the Cloud project for it to appear in its
  list at all, so create it under the same Google account that owns the Play Console developer
  account — an ownership mismatch here presents as "my project isn't in the dropdown" rather
  than as a permissions error.
  **Keep everything on the single Google account that owns the Play Console developer
  account** — whichever that is; check the avatar in both tabs rather than assuming.
  Cloud Identity Free exists if Sharpunk ever becomes a multi-person company, and projects can
  be migrated into an organisation later — so this is deferral, not a closed door.

  > This file previously named a specific Gmail address here as the Play Console owner. That
  > was inferred from the local dev environment, not from the Console, and was wrong. The
  > developer account is **Sharpunk**, ID `5660342400699971142`, type **Personal**.
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

### A5a. Configure the OAuth consent screen FIRST

**Add credential is greyed out until this exists.** The Credentials page offers a **Configure**
link that sends you to the Cloud console — recent versions call this **Google Auth Platform**
(tabs: Branding / Audience / Clients) rather than "OAuth consent screen".

| Field | Value |
| --- | --- |
| User type / Audience | **External** (a public game) |
| App name | `No Kings` |
| User support email | a Sharpunk address |
| Developer contact email | same |
| Scopes | `games`, `games_lite`, `drive.appdata` |

**`drive.appdata` is what Saved Games uses** — it is why A6 and this step are connected.

**No verification review is required.** All three PGS scopes are exempt from Google's app
verification when used with Play Games Services, so there is no security assessment standing
between this and launch. Worth knowing because `drive.appdata` looks like a sensitive Drive
scope and would normally imply one.

**Publish the consent screen rather than leaving it in Testing.** Google recommends publishing
immediately for PGS, and Testing caps you at 100 test users with tokens that expire after 7
days — which surfaces later as a device sign-in that mysteriously stops working.

If the page says *"Google Auth Platform not configured yet"*, click **Get started** — it is a
four-step wizard: app name + support email, **Audience: External**, contact email, agree and
create. Internal is only selectable for Workspace users inside your own organisation.

Afterwards, on the same left nav:

- **Audience -> Publish app.** It lands in *Testing*, which caps at 100 test users and expires
  tokens after 7 days. That later presents as "sign-in randomly stopped working on my phone".
- **Data Access ->** add `games`, `games_lite`, `drive.appdata` if the Play Console asks. If
  the UI warns about sensitive scopes, proceed — those three are exempt under PGS.

Check the **project selector** reads `NO KINGS` before touching anything; the Cloud console
silently remembers whichever project you last used.

Then return to Play Console -> Credentials and **Refresh**.

### A5. Create the OAuth credential — **the actual blocker**
Still in **Configuration**, the **Credentials** section -> **Add credential** -> type
**Android**. It asks for the package name and the **SHA-1** from the table above. This is the
one thing that cannot be produced locally: the credential binds to *both* the package name
*and* the signing certificate.

You may be asked to configure the OAuth consent screen first. The scopes involved are
`games`, `games_lite` and **`drive.appdata`** — the last is what Saved Games uses.

> **Give it the DEBUG SHA-1 for now.** A release build is signed with a different key and needs
> its own credential later. That is expected, not a mistake.

### A6. Saved Games ON, Recall OFF — both live in **Properties**

Not in Configuration and not a nav item of their own (an earlier version of this file said
both). **Setup and management -> Configuration -> Properties -> Edit properties**, scroll to:

**Saved games -> `On`.** This is the feature slice 86 needs: Play Games **Snapshots** is what
`cloud_backend_play_games.gd` mirrors saves through. Sign-in can work perfectly while every
save silently fails if it is off. The console warns **"Can't be turned off after publishing"** —
that is a one-way door, and it is the direction we want.

**Recall -> leave `Off`** ("Turn off storage of recall tokens without a Play Games Services
profile", the default).

Recall is *not* Saved Games. It stores per-player **recall tokens** so a game can restore
progress for players who have **no PGS profile**, and it exists for games that run their own
account system and want to bridge to it. We have none: the design is local-first with Snapshots
as the mirror, keyed to the signed-in player. Turning it on would mean accepting Supplemental
Terms of Service and holding per-player tokens on Google's side — new data-retention and GDPR
surface for a capability nothing in this codebase would ever call.

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

## A-bis. Play Console account type: Personal vs Organisation

Separate decision from the GCP organisation above, and easy to conflate. The existing
developer account is **Sharpunk / Personal account / ID 5660342400699971142**.

**Switching to an Organisation account requires, per Play Console Help:**

| Requirement | Cost |
| --- | --- |
| **D-U-N-S number** (mandatory) | free from Dun & Bradstreet, **up to 30 days** if you do not have one |
| Official organisation documents | you must be a **real registered legal entity** |
| Identity document for the account owner | — |
| Website verified in Google Search Console | sharpunk.com is already owned, so cheap |
| Google fee | **none** — no second $25 |

The conversion does not require abandoning the account: you create a new **payments profile**
of the organisation type, verify it, and link it to the existing developer account. Account
type cannot be edited on an existing payments profile, which is why a new one is needed.

**RESOLVED 2026-09-02: Sharpunk is a registered French company.** So the Organisation account
is available, and is the right call — Google displays developer contact details on
consumer-facing listings, and a Personal account shows **an individual's name and address**
where an Organisation account shows the company's. For anything shipped publicly that alone
justifies it.

### The signing-in email does NOT set the account type

Easy to misread, and it costs money to act on: the Console shows
**"Sharpunk · Personal account"** even when a **company email** signs in. Account type is a
stored classification chosen once at signup (*"Who are you creating an account for?"* ->
*Yourself* vs *An organisation*); the email on the account is unrelated to it. Changing which
address logs in does not convert anything.

> **Do NOT create a second developer account to "fix" this.** The `play.google.com/console/signup`
> flow is a NEW account: another $25, a separate developer ID, and the existing `No Kings` app
> plus everything built in section A would be stranded on the old one. The conversion path
> keeps developer ID `5660342400699971142` and everything attached to it.

### Do it in parallel, not first

**D-U-N-S is the long pole (up to 30 days) and nothing else waits on it.** So:

1. **Request the D-U-N-S now** — dnb.com, free. A registered French company is already in the
   Sirene registry and often already has a D&B record, so this can come back far faster than
   the 30-day worst case. You will need the SIREN/SIRET and the registered address.
2. **Meanwhile continue section A on the existing Personal account.** Sign-in, Saved Games,
   leaderboards and device testing do not care about account type.
3. **Convert when the D-U-N-S arrives**: new payments profile of the organisation type ->
   verify -> link to the existing developer account.

The developer account **ID stays the same** through that conversion (`5660342400699971142`),
so the PGS project, the OAuth credential and the leaderboard ids created in section A are
expected to survive it — they are bound to the app and the PGS project, not to the payments
profile. Worth confirming rather than assuming at conversion time, but it is not a reason to
delay section A.

One thing to check before filing: the address that becomes public is the company's **siège
social**. If Sharpunk is registered at a home address, an Organisation account does not hide it
— a domiciliation service would.

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
