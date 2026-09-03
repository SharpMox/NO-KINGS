# 86 — Google Play Games backend (Android)

Status: in progress — Console **published** and plugin installed (2026-09-03); design resolved and sliced into T1-T6 below; NEXT is implementation, then device verification

## Parent

`.scratch/gdd-gaps/issues/72-accounts-and-offline.md` (split (b), Android half)

## Scope

Fill in `game/scripts/cloud/cloud_backend_play_games.gd`, today a stub. Sign-in, cloud save
read/write, leaderboard submit — against the interface slices 83-85 already exercise via
`cloud_backend_memory.gd`.

The seam exists and is already proven by the memory backend, so this slice is the SDK
plumbing, not the architecture.

## Read this before starting

**This slice cannot be tested by the existing suite, and cannot be verified on this machine.**
72 says so plainly: headless Godot has no Play Games. It additionally needs:

- the official Godot Play Games plugin **or** a custom Android export template,
- an Android device or emulator with Play services,
- a Play Console entry for the app (leaderboard ids come from there).

None of that is reachable from the desktop dev loop that every other slice in this backlog
has been verified against. So this slice lands **written but unverified** unless it is done on
a machine with the toolchain and a device.

**Do not let `run_all.sh` ALL GREEN stand in as verification here.** Green means the desktop
build still works with the backend absent — which is exactly what it meant before this slice
was written. That is the trap this note exists to prevent.

## Acceptance

- Desktop build unaffected: the backend stays unselected, `run_all.sh` ALL GREEN.
- **Device-verified** sign-in, save round-trip and leaderboard submit — or the slice is
  explicitly recorded as unverified, with what was not tested named.

## Blocked by

- 83 (login screen calls into it)
- an Android toolchain + device — **environmental, not a code dependency**


## Toolchain: INSTALLED AND PROVEN (2026-09-01)

The environmental blocker in "Blocked by" is **half cleared**. A debug APK now builds from this
machine — 29.7 MB, 435 files — so the *build* half of this slice is no longer hypothetical.

### What was installed

| Piece | Where |
| --- | --- |
| JDK 17 | `/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home` (brew formula, no sudo) |
| Android cmdline-tools + SDK | `/opt/homebrew/share/android-commandlinetools` |
| SDK packages | `platform-tools`, `build-tools;34.0.0`, `platforms;android-34`, licences accepted |
| Godot 4.7 export templates | `~/Library/Application Support/Godot/export_templates/4.7.stable` (1.28 GB) |

**Godot's editor settings were pointing at `~/Library/Android/sdk`, which does not exist on
this machine.** That is why the first export failed with *"Missing 'platform-tools'
directory"* despite the SDK being installed. `editor_settings-4.7.tres` now points at the brew
paths above; the original is backed up beside it as `.bak-preandroid`.

Reproduce the build with:

```sh
cd game && godot --headless --path . --export-debug "Android" ../build/nokings.apk
```

`build/` is already gitignored, so the APK never enters the repo.

### One cosmetic gap found

*"No project icon specified"* — `Application -> Config -> Icon` is unset. It does not block the
export and the APK is valid, but a store build will want one.

### What is still blocked, and why it cannot be worked around

Play Games sign-in needs an **OAuth client tied to the package name AND the signing
certificate fingerprint**, both of which are issued by the Play Console. So:

1. A Play Console entry for `com.sharpunk.nokings` (one-time $25 developer account).
2. Leaderboard IDs created in that console.
3. An Android device with USB debugging.

Also note `export_presets.cfg` has `gradle_build/use_gradle_build=false`. **The Play Games
plugin requires a Gradle build**, because Godot Android plugins are Android libraries — so
that flag flips as part of wiring the plugin, not before. The plain APK proven above does not
exercise that path.

## The Gradle path is PROVEN, and the plugin is chosen (2026-09-02)

### Gradle builds work — the second half of the environmental blocker is cleared

The note above said the Play Games plugin needs `gradle_build/use_gradle_build=true` and that
"the plain APK proven above does not exercise that path". It does now:

```sh
godot --headless --path game --install-android-build-template \
      --export-debug "Android" build/nokings-gradle.apk
```

produces a valid **77.8 MB / 474-file APK** (the non-Gradle one is 28.4 MB) with the Kotlin
runtime inside it — a real Gradle build, not the prebuilt template.

**The flag is deliberately left at `false`.** This file's own earlier note is right: it flips
*as part of wiring the plugin, not before*. Turning it on now would add a hard prerequisite
(the 1 GB `game/android/` template) to every export for zero present benefit. What has changed
is that the flip is now known-good rather than hypothetical.

`game/android/` is **gitignored** — it is ~1 GB of regenerated SDK scaffolding, and the
regeneration command is recorded in `.gitignore` beside the rule.

### A store requirement this slice had not recorded

`gradle_build/export_format=0` is **APK**. Google Play requires an **AAB** (`=1`) for new
applications, so the store build needs that flag as well as a release keystore. Neither is
needed for device testing, which is what unblocks the rest of this slice.

### The plugin: `godot-sdk-integrations/godot-play-game-services`

MIT, Godot 4.3+, and it lives in the **Godot Foundation's GitHub organisation** (moved there
October 2024) — community-built rather than engine-official, but under the Foundation's
umbrella, which is as close to endorsed as an Android plugin gets.

It covers **exactly the three things this slice needs and nothing more**: sign-in,
leaderboards, and **Snapshots** (cloud saves). Play Games SDK v21.0.0, Android API 35,
node-based rather than autoload-based, and it **requires the custom Gradle build** — the path
proven above.

Mapping onto the existing seam is genuinely drop-in: `cloud_backend_play_games.gd` already
declares `is_available()` / `push()` / `pull()` / `account_id()`, and Snapshots is a
named-blob store, which is the same shape as `push(key, envelope)`.

### What is STILL blocked, unchanged

Sign-in needs an OAuth client tied to the package name **and the signing certificate
fingerprint**, both issued by the Play Console. No amount of local work produces those. Still
required from the user:

1. A Play Console entry for `com.sharpunk.nokings` (one-time $25 developer account).
2. Leaderboard IDs created there.
3. An Android device with USB debugging.

**The SDK calls are deliberately not written yet.** Writing them blind against a plugin that
is not installed would be guessing an API surface — the exact thing this repo's conventions
forbid ("ambiguity goes back as a question, not into code as a guess"), and it could not be
compiled, let alone verified.

## Fit analysis (2026-09-02): the scope matches, the CONTRACT does not

### Our contract is synchronous, and callers depend on that

`cloud_save.gd` declares:

```
is_available() -> bool
push(key, envelope) -> bool     # returns success NOW
pull(key) -> Variant            # returns the envelope NOW
account_id() -> String
```

and its callers consume the return value immediately — `resolve(local_ts, local, pull(key))`,
and `SyncQueue.drain()` takes a `Callable` that must return `bool` per entry.

### The plugin is async

`SnapshotClient.save_game()` / `load_game()` **emit signals** (`game_saved` / `game_loaded`);
they do not return the snapshot. So a literal drop-in is impossible: `pull()` cannot return an
envelope the SDK has not fetched yet.

### Health check — good, and better than the iOS side

| | |
| --- | --- |
| licence | MIT |
| latest release | **v3.4.0, 2026-07-20** (v3.3.0 2026-07-09, v3.2.0 2025-11-22) |
| stars / open issues | 271 / 11 |
| org | `godot-sdk-integrations` — the Godot **Foundation's** org |
| scope | sign-in, leaderboards, Snapshots — exactly this slice, nothing more |

Actively released, correctly scoped, permissively licensed. The choice is sound.

### The resolution: our OWN offline-first design already absorbs async

This is not a rewrite of the seam. `cloud_save.gd` already states that **local is the source of
truth and the cloud is only a mirror**, and `SyncQueue` already exists for "accepted now,
delivered later". So:

- **`push()` = enqueue + return true.** That is what it already does when the backend is
  unavailable (issue 84: *"unreachable is not a failure, it is deferred"*). The async SDK
  simply becomes another deferred delivery, and `game_saved` drains the entry.
- **`pull()` = return the last cached snapshot**, and kick an async refresh for next time. Safe
  precisely because resolution is *highest-wave-wins, else last-write-wins* — a stale mirror
  loses to local, which is the intended outcome.
- **`account_id()` = the cached id from the last completed sign-in**, "" before that.

So the contract stays synchronous and honest, and nothing in `cloud_save.gd`, `SyncQueue` or
their tests has to change shape. **This is worth an ADR** before it is built — it is the
decision that keeps the seam sync in a world of async SDKs, and a future reader will otherwise
wonder why `pull()` does not await.

## OPEN RISK: the 100-login cap on sensitive scopes (2026-09-02)

Creating the Android OAuth client surfaced: *"OAuth is limited to 100 sensitive scope logins
until the OAuth consent screen is verified. This may require a verification process that can
take several days."*

That sits oddly beside the Auth Platform's own Data Access status, which reads *"Verification
is not required since your app is not requesting any sensitive or restricted scopes."* Both can
be true at once — the second only reflects scopes CONFIGURED on the consent screen, and ours
are requested at runtime instead.

**The unresolved question: does `drive.appdata`, requested by Play Games Saved Games, count
toward that cap?** Google's sensitive-scope verification page lists five exceptions (personal
use, testing, service-owned data, internal-only, domain-wide delegation) and **none mention
Play Games**. A secondary source states the PGS scopes need no verification; that could not be
confirmed against Google's own docs.

**Not blocking now.** Device testing involves a handful of accounts. It would be fatal at
launch, where 100 sign-ins is nothing.

**How to settle it, empirically rather than by reading:** after the first successful on-device
sign-in, the Cloud console's Data Access page shows which scopes were actually requested and
how they are classified. Check it then. There is also a structural reason to expect no problem:
PGS sign-in on Android uses the native Play Games flow, not a browser consent screen, which is
where the unverified-app cap normally applies.

**If it does apply**, the fix is submitting the consent screen for verification — days, not
weeks, and it can run in the background well before launch. Do not discover this in the week of
release.

### The client, for the record

Client ID `292256536070-r8mmdpv4m3prpppa714792n908mtofgm.apps.googleusercontent.com`. Android
OAuth clients carry **no client secret**, so this is not a credential to protect — the security
boundary is the package name plus the signing fingerprint, which is why the pair is what the
client binds to. The downloaded JSON is not needed by the plugin, which reads its app id from
the Play Console configuration.

## Shipping size, measured (2026-09-02)

The 78 MB debug APK is **not** what anyone downloads. Built as an AAB — the format Google
Play requires for new apps:

| Artefact | Size | Why |
| --- | --- | --- |
| Non-Gradle APK | 28.4 MB | native libs deflated |
| Gradle APK (debug) | 78.5 MB | Gradle stores native libs UNCOMPRESSED (`method 01:01`) so the OS can mmap them; install size unchanged |
| **AAB (debug)** | **28.9 MB** | libs stored compressed again (`24.3 MB` from `72.7 MB` raw) |

So the plugin's real cost is **~0.7 MB**, and the scary 78 MB was packaging, not payload.

**A release build will be smaller still.** The engine templates differ:

```
android_debug.apk    121.2 MB   (libgodot_android.so, arm64: 72.7 MB raw)
android_release.apk   99.8 MB   (libgodot_android.so, arm64: 67.9 MB raw)
```

That is ~4.8 MB less engine before compression, plus no debug symbols and R8 on the dex — so
a release AAB should land comfortably under the debug 28.9 MB. Only one ABI is built
(`arm64-v8a`), so Play's per-device split has little left to strip; the download will be close
to the AAB size.

`export_format` is left at **0 (APK)** for now: an AAB cannot be `adb install`ed, and device
testing needs an APK. Flip it to 1 for store submission — see the publishing checklist.

## Play Console: DONE (2026-09-03)

Verified in the Console: **Properties → Published**, **Saved games enabled**, project
`NO KINGS` / id `292256536070` — which matches the `APP_ID` constant already committed in
`cloud_backend_play_games.gd`. Testers added (A8) and the configuration published (A9).

The setup checklist's remaining open item, *"Add the Play Games Services SDK to your APK to use
the APIs"*, is **this slice's code**, not a Console step. Installing the plugin (commit
`3281bba`) put the AAR in the build; the checklist wants the APIs actually *called*. Nothing in
`game/scripts/` calls them yet, so the checklist is accurate rather than stuck.

**The only remaining non-code blocker is an Android device** (section B of `MANUAL-STEPS.md`).

## Design resolved (grilled 2026-09-03)

Eight decisions, taken against the plugin source rather than its docs. The contract decision is
recorded as **`docs/adr/0003-synchronous-cloud-contract-over-async-sdk.md`** — the ADR this
issue said was owed.

| # | Question | Ruling |
| --- | --- | --- |
| 1 | Where does the plugin's Node live? | **One autoload of ours**, `PlayGamesBridge`, owning the three clients; no-ops off Android |
| 2 | Does the login button trigger native sign-in? | **Yes** — `sign_in()` then `user_authenticated`; accepts a `menu.gd` edit this issue had not scoped |
| 3 | Who resolves snapshot conflicts? | **We do, silently.** Google's picker is never shown |
| 4 | How does a fresh device get its progress? | **Sign-in completion re-syncs** `run`/`scores`/`history`; not deferred to the next run |
| 5 | What does `is_available()` mean? | **Signed-in session state.** Platform capability becomes a separate method |
| 6 | Does `push()` enqueue into `SyncQueue`? | **No** — overturns this file's earlier ruling; see the ADR for why |
| 7 | How much is tested? | **The codec only.** No fake plugin double |
| 8 | Desktop / web login? | **Parked** as its own slice — see issue 105. `menu.gd`'s buttons are left as they are |

### Two facts the earlier notes had wrong

**The plugin's clients are Nodes, not autoloads.** Their doc comments say *"This autoload
exposes…"*, but `export_plugin.gd:25` registers exactly one autoload — `GodotPlayGameServices` —
holding only `android_plugin` and the JSON marshaller. `PlayGamesSignInClient`,
`PlayGamesSnapshotsClient` and `PlayGamesPlayersClient` are `class_name … extends Node` wiring
their signals in `_ready()`. `GodotPlayGameServices.initialize()` must also be called manually.
This is what forces the bridge autoload; a static-func script cannot receive a signal.

**`account_id()` is a second async hop, not a property read.** It arrives via
`PlayGamesPlayersClient.load_current_player()` → `current_player_loaded(player)` →
`player.player_id`. So sign-in is a *chain*: `user_authenticated(true)` → `load_current_player()`
→ `current_player_loaded` → only then bind the account and re-sync. Binding on
`user_authenticated` alone would stamp an empty owner id into `account.json`, silently.

### Slices

Vertical, in dependency order. T1 and T2 are the seam; T3-T5 are behaviour; T6 is proof.

| Ticket | What | Blocked by |
| --- | --- | --- |
| **T1** | `PlayGamesBridge` autoload: `initialize()`, owns the three clients, Android-guarded. Plus the envelope↔`PackedByteArray` codec **and its desktop test** (the one thing here that is testable and silently corrupting if wrong) | — |
| **T2** | `cloud_backend_play_games.gd`: `is_available()` / `push()` / `pull()` / `account_id()` reading the bridge's cache, plus the new platform-capability method | T1 |
| **T3** | Sign-in flow: `menu.gd` button → `sign_in()` → `user_authenticated` → `load_current_player()` → bind `Account` on `player_id`. Failure path reuses the existing "isn't available on this device yet" message | T2 |
| **T4** | Post-sign-in re-sync: fetch `run`/`scores`/`history`; each `game_loaded` caches and re-runs that key's `sync_file` | T3 |
| **T5** | `conflict_emitted` → resolve with `CloudSave.resolve()` / `Leaderboard.merge()` → re-save. No UI | T2 |
| **T6** | Flip `gradle_build/use_gradle_build=true`, build, `adb install`, **device-verify** sign-in + save round-trip | T3-T5, **an Android device** |

`run_all.sh` must stay ALL GREEN throughout — but per this file's own warning, green verifies
only that the desktop build still works with the backend absent. **T6 is the only verification
that counts**, and it cannot happen on this machine.
