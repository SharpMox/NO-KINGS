# Manual steps only you can do — the blockers on NO-10, NO-12 and NO-13 (archive issues 86 / 87)

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

### "Publish" means THREE different things here — only one is the store

A real trap in Google's model. None of the steps in this file put the game on the Play Store.

| Action | What it does | Store impact |
| --- | --- | --- |
| Auth Platform -> **Publish app** | moves the OAuth CONSENT SCREEN from Testing to In production, so any Google account can consent rather than only listed testers | none |
| PGS -> **Publish Game** (A9) | publishes the Games Services CONFIGURATION (leaderboards, Saved Games) so it takes effect on a device | none |
| Play Console -> production track | puts the actual game on the store | **this is the real one, and it is not in this file** |

Publishing the consent screen exposes nothing: it is the "NO KINGS wants access to your Play
Games profile" dialog. It lists or announces nothing, and no one can discover the game from it.

**Publish it rather than leaving it in Testing**: Testing caps at 100 test users and expires
refresh tokens after **7 days**, so sign-in works on device and then mysteriously stops a week
later. The three PGS scopes are verification-exempt, so publishing triggers no review.

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

### A6-bis. Target audience: 13+, ruled 2026-09-02

**Play Console -> Policy -> App content -> Target audience and content.** Select **13-15,
16-17 and 18 and over**. Do NOT select 9-12 or below.

Google treats 9-12 and under as "children in most locales", which triggers the full **Families
policy**: content review against an age-appropriateness standard, and certified-ads SDKs only.
This game cannot pass that review — the King roster is Hitler, Stalin, Mao and Kim Jong Un with
abilities called The Purge and The Pyramid of Skulls — and the ads restriction would constrain
the (parked) AdMob decision before it is made.

The game is *marketed* at roughly 12-45, which is not the same question: Google asks whether
the app is CHILD-DIRECTED in theme, characters and framing. A strategy game about twentieth
century autocrats is not, so 13+ is the honest declaration rather than a convenient one.

's Children section states exactly this and must keep matching the Console.
Note the IARC content-rating questionnaire is SEPARATE and will land at PEGI 12 or 16 on the
historical-violence questions.

### Values produced by A5 (record — the backend needs them)

| Value | |
| --- | --- |
| **Play Games Application ID** | **`292256536070`** |
| OAuth client ID | `292256536070-r8mmdpv4m3prpppa714792n908mtofgm.apps.googleusercontent.com` |
| Bound to | `com.sharpunk.nokings` + SHA-1 `BE:78:…:FF:FE` |

The **Application ID** is the one the game itself needs: it goes into the Android manifest as
`com.google.android.gms.games.APP_ID`, and the plugin reads it from there. It is the numeric
prefix of the OAuth client id, not a separate secret.

Neither value is a credential — an Android OAuth client has no secret, and the security
boundary is package name + signing fingerprint.

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

### The D-U-N-S is ALREADY IN HAND — Apple's enrolment proves it (2026-09-10)

**The long pole is already spent.** The Apple Developer Program enrolment is type
**Organization**, and Apple's own requirement is that *"Companies and educational institutions
must provide a D‑U‑N‑S Number registered to their legal entity"*
(developer.apple.com/help/account/membership/D-U-N-S/). An Organization enrolment cannot
complete without one, so Sharpunk holds one.

**It is the same number.** A D-U-N-S is issued and maintained by **Dun & Bradstreet** and
belongs to the legal entity — neither Apple nor Google issues one, and neither has a
vendor-specific variant. Play's own Help page says so from the other side: *"Many organizations
already have a D-U-N-S number as part of doing business. You should check whether your
organization has one before applying for a new one."* So the number that satisfied Apple is
the number Play Console asks for, and step 1 below is done rather than pending.

Two conditions on that, and both are worth checking rather than assuming:

- **Same legal entity.** This holds only if the Apple enrolment was completed under the entity
  Play would show — Sharpunk, the registered French company. A different entity means a
  different number. Play warns about exactly this: *"Large organizations may have multiple
  D-U-N-S numbers for the different entities... you must make sure that the one that you use to
  create your developer account contains the organization details that you'd like to be
  associated with your developer account."*
- **Having the number is not the same as passing Play's verification**, which matches the D&B
  record's name and address against the documents supplied. That is a verification step, not a
  30-day wait for an identifier.

So the revised order:

1. ~~Request the D-U-N-S~~ — **done, via Apple.** Read it off the Apple Developer account
   (Membership details) or the D&B record; it is the same nine digits either way.
2. **Continue section A on the existing Personal account** whenever you like. Sign-in, Saved
   Games, leaderboards and device testing do not care about account type.
3. **Convert whenever you want to**: new payments profile of the organisation type -> verify
   -> link to the existing developer account. What is still needed for that, and none of it is
   a wait: the official organisation documents, an identity document for the account owner,
   sharpunk.com verified in Search Console (the domain is already owned), and no second $25.

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
list it (`adb` is at `/opt/homebrew/share/android-commandlinetools/platform-tools/adb`, not
on PATH). Wireless debugging works too and needs no cable once the phone is paired.

An emulator with **Google Play services** also works, but a real device is less trouble.

### `ADB_LIBUSB=1` is REQUIRED, or adb hangs forever

```sh
export ADB_LIBUSB=1
```

Without it every adb command hangs. The symptom is a lie: `adb devices` prints
`* daemon not running; starting now at tcp:5037` and never returns, and a server process
exists while **nothing is listening on 5037**, so every client waits forever.

`sample` on the stuck process says exactly why (2026-09-09):

```
adb_server_main() -> usb_init() -> std::this_thread::sleep_for()   2332 of 2359 samples
```

It hangs inside USB init and never reaches the TCP bind. Tested back to back in one shell:
`ADB_LIBUSB=0` -> refused, `ADB_LIBUSB=1` -> LISTENING.

**Three wrong diagnoses, all checked and all false** — written down because each one costs an
hour and the next reader will reach for them in this order:

- **Not mDNS.** `ADB_MDNS=0` changes nothing. The mDNS sockets you see in `lsof` are opened
  before the hang, not the cause of it.
- **Not Gatekeeper or quarantine.** The binary is Developer-ID signed by Google LLC with no
  `com.apple.quarantine` xattr. `spctl` says "rejected … does not seem to be an app", which
  is normal for any CLI binary and is not a block.
- **NOT "it needs an interactive shell"** — the most tempting one, because running it by hand
  appears to fix it. It does not; the environment differs, not the interactivity.

### Getting a build onto the device

The export preset has been **AAB-only since PR #342**, so `--export-debug ...apk` is refused
outright ("Android App Bundle requires the *.aab extension"). The path that works:

```sh
export ADB_LIBUSB=1
godot --headless --path game --export-debug "Android" ../build/nokings-debug.aab
bundletool build-apks --bundle=build/nokings-debug.aab --output=build/nokings.apks \
  --connected-device --adb="$(which adb)" \
  --ks="$HOME/Library/Application Support/Godot/keystores/debug.keystore" \
  --ks-pass=pass:android --ks-key-alias=androiddebugkey --key-pass=pass:android
bundletool install-apks --apks=build/nokings.apks --adb="$(which adb)"
```

**Pass the keystore.** Without `--ks` the APKs build fine, bundletool only *warns*, and the
install then fails — a silent trap, because the build looked successful. Re-confirmed
2026-09-11 by following this recipe.

**`--mode=universal` instead of `--connected-device` when there is no phone yet.** The two
differ only in whether bundletool asks a device what splits it needs, so the universal set is
larger (80.8 MB against the AAB's 31.3 MB) and installs anywhere. That matters because it
decouples the BUILD from the device: a build made while the phone is unreachable is ready the
moment it appears, and the install is then one command. Use `--connected-device` only when
the phone is already there and the smaller set is worth having.

### The build template does not exist in a git worktree — COPY it, do not wait

`game/android/build` is 1.2 GB of generated scaffolding and `.gitignore` excludes all of
`game/android/`, so a fresh `git worktree` has none of it and the export refuses outright:

```
ERROR: Cannot export project with preset "Android" due to configuration errors:
Android build template not installed in the project. Install it from the Project menu.
```

**`godot --headless --path game --install-android-build-template` produced NOTHING here**
(2026-09-11): it ran past 600 s with no output and without creating the directory. Do not
wait on it. Copy the template from a checkout that already has one — seconds, and it leaves
that checkout untouched:

```sh
mkdir -p <worktree>/game/android
cp -a <primary-checkout>/game/android/build <worktree>/game/android/build
cp -a <primary-checkout>/game/android/.build_version <worktree>/game/android/
```

### Launching it: the activity is `GodotAppLauncher`, and `monkey` is better anyway

`am start -n com.sharpunk.nokings/com.godot.game.GodotApp` **fails** — a Binder exception,
no app. Measured on the device 2026-09-11:

```sh
adb shell cmd package resolve-activity --brief -c android.intent.category.LAUNCHER com.sharpunk.nokings
# -> com.sharpunk.nokings/com.godot.game.GodotAppLauncher
```

`GodotApp` is the activity name every recipe reaches for and it is the wrong one. Use the
form that needs no activity name at all, which is also immune to Godot renaming it on the
next template bump:

```sh
adb shell monkey -p com.sharpunk.nokings -c android.intent.category.LAUNCHER 1
```

**`scripts/drive.gd` has never run on Android**, and this is why it was not tried further:
passing `--drive <dir>` needs `OS.get_cmdline_user_args()` to be populated at launch, and
`--esa command_line_args` on top of the already-wrong activity produced nothing. It is not
needed here — **Android has `adb shell input`**, which iOS does not, and that absence is the
entire reason `drive.gd` exists. `input tap`, `input swipe`, `input keyevent 4` for Back,
`input text` for typing (the driver has no typing verb at all) and `exec-out screencap -p`
cover the whole verification surface.

**Coordinates for `input tap` are DEVICE pixels.** `project.godot` is 480x800 with
`stretch/aspect = expand`, which scales by `min(screen.x/480, screen.y/800)` and never
letterboxes. On a 1084x2412 screen that is `2.258`, so `device_px = canvas_px x 2.258` and
the canvas is 480 x ~1068 logical. This is the same trap that cost two iOS sessions,
arriving on the other platform.

This is what turns 86 from "written" into "verified" — and issue 86 is explicit that
`run_all.sh` ALL GREEN does **not** verify this slice.

**What has actually been verified on a device, and what has not, is recorded in
`docs/device-verification.md`** — newest build first. This file is the STEPS; that one is
the RECORD. Check it before re-doing a device test, and add to it after doing one: a PR body
saying "UNVERIFIED ON DEVICE" cannot update itself once merged.

---

## C. Only when you actually publish — not needed for any of the above

- **A release keystore**, kept somewhere safe and backed up. Losing it means never being able
  to update the app. Its SHA-1 needs its own credential (step A4 again).
- **`gradle_build/export_format=1`** — Google Play requires an **AAB**, not an APK, for new
  apps. Currently `0`.
- Store listing copy, screenshots, a privacy policy URL, and the content questionnaires.

---

## D. iOS — the account half is bought; what is left is records and a device

**Two things this section used to say are wrong, and both were verified wrong before this
rewrite** (2026-09-10):

- **Xcode IS installed** — `xcodebuild -version` = Xcode 26.6 (17F113). The old step 1 said
  only Command Line Tools were present. Both plugins were compiled against 4.7-stable on
  2026-09-04 and are vendored under `game/ios/plugins`, so the old step 7 is done too.
- **The $99 membership was never the wall it was described as.** The simulator proved BOTH
  halves without any paid account: the iCloud KV round-trip (write, synchronous read, real
  sync, survives relaunch) *and* a Game Center sign-in returning `result: "ok"` with a real
  player id. The earlier claim came from a log line captured *before* the
  `com.apple.developer.game-center` entitlement was added and never re-tested after; ad-hoc
  simulator signing carries entitlements, which is what makes it work. See archive issue 87's
  own CORRECTION note. The membership buys a **device and the store**, not a first login.

**Membership: enrolled.** Team ID `DGT6GH7583`, **Organization**. The Team ID is public and is
already in `game/export_presets.cfg` — no placeholder left.

### The exact values you will be asked for

Same shape as section A's Android table. **All four are PUBLIC identifiers** — they belong in
the repo. The secrets in this area are the Apple ID password, 2FA codes, an App Store Connect
API key's `.p8` and any exported `.p12`; none of those go in a file.

| Field | Value | Where it came from |
| --- | --- | --- |
| Bundle identifier | `com.sharpunk.nokings` | user ruling 2026-09-02: match Android |
| Team ID | `DGT6GH7583` | Apple Developer -> Membership details |
| Enrolment type | **Organization** (Sharpunk) | decides that a D-U-N-S applies — see A-bis |
| **App Store listing name** | **`NO KINGS: Chess Riot`** | App Store Connect app record |
| **ASC app Apple ID** | **`6810748568`** | App Store Connect, after the record propagated |

> **The App Store listing name is NOT the in-game title.** The game is `NO KINGS`; the store
> listing had to be `NO KINGS: Chess Riot` because `NO KINGS` alone was already taken by
> another app. Expect them to differ, and do not "fix" one to match the other.

The ASC app Apple ID is the number App Store Connect issues for the app record itself — needed
for uploads and for ASC URLs. It is **not** the Game Center Leaderboard ID (still outstanding,
D1 step 3) and **not** the bundle id.

### D1. Records only you can create (App Store Connect / developer.apple.com, GUI)

1. ~~**The app record.**~~ **DONE 2026-09-10.** `NO KINGS: Chess Riot`, iOS 1.0, status
   *Prepare for Submission*, Apple ID `6810748568` — in the table above.
   Worth keeping the one lesson: **the record did not appear for ~90 minutes.** App Store
   Connect's Apps page rendered blank, the bundle id vanished from the New App dropdown, and
   `/iris/v1/apps` returned an authenticated `200` with **zero** records — which was the truth,
   not a false negative. It propagated on its own with no Support ticket (NO-51). So if a
   freshly created record is missing: **trust the API and wait**, do not distrust the
   instrument.
2. **Capabilities on the identifier.** developer.apple.com -> Identifiers -> that bundle id ->
   enable **Game Center** and **iCloud (Key-Value storage)**. KV needs no container; the
   entitlement is `com.apple.developer.ubiquitous-key-value-store`.
3. **The leaderboard.** App Store Connect -> the app -> Game Center -> a leaderboard named
   **High Score**, classic, integer, best score, high to low. Send its **Leaderboard ID**
   (public). It drops into `LEADERBOARD_HIGH_SCORE` in
   `game/scripts/cloud/cloud_backend_ios.gd` — one string, no other change: the bridge calls,
   the backend methods and the `global_board.gd` seam are all already wired and tested against
   the empty id.
4. **The Program License Agreement**, if App Store Connect prompts. It blocks builds silently
   until accepted. The Paid Apps agreement is not needed; the game is free.

### D2. Signing — your choice of two, one is a SECRET

5. Either:
   - **a.** Xcode -> Settings -> Accounts -> sign in with the Apple ID, once, at this Mac.
     Certificates and profiles then handle themselves. Nothing to hand over.
   - **b.** An **App Store Connect API key** (Users and Access -> Integrations): the `.p8`
     file, its **Key ID** and the **Issuer ID**. **The .p8 is a secret.** Never paste it in
     chat and never commit it: drop the file in `~/keystores/` (same home as the Android
     keystore, outside the repo) and put the two ids in the macOS Keychain — then tell me the
     Keychain service name only. A leaked ASC key signs and uploads as you.

### D3. The device gate — the only genuinely blocked thing left

6. **An iPhone.** The earlier one was borrowed and left on 2026-09-04. Needed for: the first
   signed build reaching a device, and the device script (sign-in consent, account binding,
   relaunch reconnect, tombstone, wipe-and-restore). Say **which model and iOS**, and whether
   it is yours to keep or borrowed — the verification plan differs. If a specific device must
   be registered, its **UDID** (Settings -> General -> About, or Xcode). UDID is public but
   keep it out of the repo.

Not needed from you: the Apple ID password or 2FA codes, ever.

### What is already done and needs nothing

- iOS export preset: bundle id, both plugins, `export_project_only`, and the Team ID.
- Both plugin xcframeworks, debug and release, vendored with a rebuild recipe.
- The vendored window patch without which `authenticate()` and `show_game_center()` return nil
  forever on Godot 4.7.
- Both simulator slices of the installed export template fattened to arm64 (debug 2026-09-04,
  release 2026-09-10) — see `game/ios/plugins/README.md`.

---

## What I do the moment A1-A9 are done

1. Install `godot-sdk-integrations/godot-play-game-services` into `addons/`.
2. Flip `gradle_build/use_gradle_build=true` — **already proven to build** (77.8 MB APK).
3. Fill in `cloud_backend_play_games.gd` against the cache-and-defer shape in issue 86's fit
   analysis, so the synchronous contract survives the async SDK.
4. Wire the leaderboard id from A7.
5. Build, install to the device from B, and verify sign-in, a save round-trip and a
   leaderboard submit **on the device** — the only verification that counts here.

---

## E. The release keystore — NO-12, and the one secret in the whole build

`gradle_build/export_format` is now **1 (AAB)**, which is what Google Play requires for a new
app. Issue 86 measured the difference: **28.9 MB as an AAB against 78 MB as an APK**, because
the native libs are stored compressed again.

That leaves exactly one blocker, and it is the one thing an agent must not create for you.

### What the key IS

Not something you download. You **generate** it, once, with `keytool` from the JDK already
installed for the Android build:

```sh
mkdir -p ~/keystores
JAVA_HOME=/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home
"$JAVA_HOME/bin/keytool" -genkey -v -keystore ~/keystores/nokings-upload.keystore \
  -alias nokings -keyalg RSA -keysize 2048 -validity 10000
```

**Call keytool through `$JAVA_HOME`, not by bare name.** macOS ships a stub at
`/usr/bin/keytool` that is first on `PATH` and is not a real tool — it answers every
invocation with *"The operation couldn't be completed. Unable to locate a Java Runtime."*
`which keytool` finds the stub and tells you nothing, which is how this was hit for real on
2026-09-09. The JDK installed for the Android build is the working one, same as the debug
fingerprint command further up already assumes.

It asks for a keystore password, a key password and some identity fields. The file plus those
two passwords and the alias are the whole credential.

### Why it is handled differently from every other config

**Losing it is unrecoverable in the ordinary case.** An Android app's identity IS its signing
key: Play refuses an update signed by a different one, and the only remedy is shipping a new
listing and abandoning the install base.

Two consequences, both non-negotiable:

- **It never goes in the repo.** See "How the key reaches the build" below — this is the
  part with a real, specific leak path, not a general caution.
- **Back it up somewhere that is not this machine.** A password manager or an encrypted
  archive. The file, BOTH passwords and the alias — all four, or none of it works. Not
  `~/Downloads`.

### How the key reaches the build — environment variables, never the editor UI

**Do not fill the keystore fields in Godot's export dialog.** Doing so writes
`keystore/release`, `keystore/release_user` and `keystore/release_password` into
`game/export_presets.cfg` **in plaintext** — and that file is TRACKED. One `git add -A`
puts the signing password in the history, pushed to GitHub, permanently. Those three empty
fields are sitting in the preset right now waiting for exactly that.

Use the environment variables instead. Godot reads them at export time and persists
nothing.

**Verified 2026-09-07** against the installed binary rather than assumed —
`strings /Applications/Godot.app/Contents/MacOS/Godot | grep GODOT_ANDROID_KEYSTORE`
lists all three RELEASE variables (plus the DEBUG trio). This build honours them.

Env vars have their own leak: `export FOO=secret` lands in `~/.zsh_history`, and anything
in a dotfile is plaintext on disk. So take the password from the Keychain at invocation and
prefix it onto the command, scoping it to that one process:

```sh
# once — prompts for the password, never echoes it
security add-generic-password -a nokings -s nokings-keystore -U -w

# every export
GODOT_ANDROID_KEYSTORE_RELEASE_PATH="$HOME/keystores/nokings-upload.keystore" \
GODOT_ANDROID_KEYSTORE_RELEASE_USER=nokings \
GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD="$(security find-generic-password -s nokings-keystore -w)" \
godot --headless --path game --export-release "Android" build/nokings.aab
```

Prefixed, not exported: the password never reaches argv, shell history, or any file. Same
pattern as the sharpunk SFTP password (see the global `CLAUDE.md`); broad Keychain searches
get blocked by the permission classifier, so always look the service up by its exact `-s`
name.

**What this does NOT protect.** The keystore FILE still sits on disk at `~/keystores/`.
Environment variables guard the password, not the file — which is why the backup point
above is separate and independent.

### Play App Signing softens exactly one of those risks

Google's default for new apps: you upload an **upload key**, Google holds the actual app
signing key. If the upload key is lost, support can reset it — the app survives. The app
signing key never leaves Google, so it cannot be lost by you at all.

**It is automatic for new apps now** (verified against Google's own docs 2026-09-09, which
say new apps are "automatically enrolled in quantum-ready, hybrid signing with Google-generated
keys"). There is no opt-in step to remember at app-entry creation — this page used to say there
was. What it means for the key above is unchanged: it is an **upload** key, not the final
signing key.

Google does NOT generate the upload key for you. You still run the `keytool` command above:
Play needs your first AAB signed with something, and registers that as your upload key. What
enrolment buys is recovery — a lost upload key is reset by generating a new one, exporting its
certificate to PEM, and submitting a reset request in the Play Console. A lost key on an app
that was NOT enrolled is terminal.

### What I can do once the key exists

Everything else is already prepared. Build:

```sh
cd game && godot --headless --path . --export-release "Android" ../build/nokings.aab
```

The preset is otherwise complete — `arm64-v8a` only, `com.sharpunk.nokings`, launcher icons
wired, Play Games app id `292256536070` set, `package/signed=true`.

**Corrected 2026-09-07:** issue 86 recorded *"No project icon specified — a store build will
want one."* That is stale. `project.godot` carries `config/icon="res://icon.png"` and the
file exists. Nothing owed there.
