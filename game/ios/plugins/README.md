# Vendored iOS plugin binaries (issue 87)

`gamecenter` and `icloud` from godotengine/godot-ios-plugins, compiled from
master (no Godot 4 release exists — every published artifact is Godot 3) against
the engine tag matching this project's editor. Vendored so a fresh checkout
builds without a 12-minute engine compile.

## Rebuild recipe (needed on every Godot version bump)

```sh
git clone --recursive https://github.com/godotengine/godot-ios-plugins.git ~/godot-ios-plugins
cd ~/godot-ios-plugins/godot
git fetch --tags --depth 1 origin tag <GODOT_TAG e.g. 4.7-stable> && git checkout <GODOT_TAG>
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
scons platform=ios target=editor -j$(sysctl -n hw.ncpu)          # headers, ~7 min
cd .. && for p in gamecenter icloud; do for t in debug release; do
  ./scripts/generate_xcframework.sh $p $t 4.0
done; done
cp -R bin/{gamecenter,icloud}.{debug,release}.xcframework <this dir>/
```

## APPLY THE PATCHES IN THIS DIRECTORY BEFORE BUILDING

The vendored binaries are **not** pristine upstream. Three patches, applied
with `patch -p1` from `~/godot-ios-plugins`, in any order — they touch
different lines of `plugins/gamecenter/game_center.mm`:

| Patch | What it fixes |
|---|---|
| `gamecenter-godot47-window.patch` | Godot 4.7 leaves the app delegate's `window` nil, so `authenticate()` could never present its view controller. |
| `gamecenter-utf8-strings.patch` | The plugin handed Godot a UTF-8 `const char *`, whose `String` constructor parses **Latin-1** (`core/string/ustring.h`), mangling every non-Latin player name (NO-52). |
| `gamecenter-scoped-ids.patch` | Reports `scopedIDsArePersistent`, Apple's documented way to tell whether `teamPlayerID` is stable or unique per app launch (NO-53). |

**A rebuild that skips them silently reintroduces all three**, and two of the
three are invisible on an English-language account with a persistent id. Verify
after applying:

```sh
grep -c 'String::utf8(\[player' plugins/gamecenter/game_center.mm   # expect 2
grep -c 'scopedIDsArePersistent'  plugins/gamecenter/game_center.mm   # expect 2
grep -c 'nk_root_controller'      plugins/gamecenter/game_center.mm   # expect 3
```

All three are candidates for upstream PRs; none is specific to this project.

## The trap this recipe also fixes

The OFFICIAL Godot iOS export template ships its simulator library x86_64-only
inside a directory named `ios-arm64_x86_64-simulator` — on an Apple Silicon
simulator the link fails on a missing arm64 `_main`. Build the missing slice and
fatten the installed template once per Godot version (original kept as .orig):

```sh
cd ~/godot-ios-plugins/godot
scons platform=ios target=template_debug arch=arm64 ios_simulator=yes -j$(sysctl -n hw.ncpu)
T=~/Library/Application\ Support/Godot/export_templates/<VER>; W=$(mktemp -d); cd "$W"
unzip -q "$T/ios.zip" "libgodot.ios.debug.xcframework/ios-arm64_x86_64-simulator/libgodot.a"
cp "$T/ios.zip" "$T/ios.zip.orig"
lipo -create libgodot.ios.debug.xcframework/ios-arm64_x86_64-simulator/libgodot.a \
  ~/godot-ios-plugins/godot/bin/libgodot.ios.template_debug.arm64.simulator.a \
  -output libgodot.ios.debug.xcframework/ios-arm64_x86_64-simulator/libgodot.a
zip -q "$T/ios.zip" "libgodot.ios.debug.xcframework/ios-arm64_x86_64-simulator/libgodot.a"
```

DONE FOR RELEASE TOO (2026-09-10). Confirmed the defect rather than trusting
this note: the installed 4.7.stable `libgodot.ios.release.xcframework/
ios-arm64_x86_64-simulator/libgodot.a` was `lipo -archs` **x86_64 only**, same
mislabelling as the debug slice. Built `target=template_release arch=arm64
ios_simulator=yes` (3m50s) and fattened it; both slices now read
`x86_64 arm64`, re-read out of the installed zip. Device builds were never
affected — the device slices were always correct.

**Do NOT re-run the `cp "$T/ios.zip" "$T/ios.zip.orig"` line above.**
`ios.zip.orig` already holds the PRISTINE upstream zip from before the debug
patch. The live `ios.zip` is patched, so copying it over the backup destroys
the only way back to an unmodified template.

## Simulator builds (no paid account needed)

Ad-hoc signing carries entitlements on the simulator, which is what lets the
iCloud store initialize. Build the exported project with:

```sh
xcodebuild -project nokings.xcodeproj -scheme nokings -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' -configuration Debug \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=YES CODE_SIGNING_ALLOWED=YES \
  CODE_SIGN_ENTITLEMENTS=path/to/nokings.entitlements build
```

with an entitlements plist carrying `com.apple.developer.ubiquity-kvstore-identifier`
(= the bundle id) and `com.apple.developer.game-center`. Verified on the
simulator 2026-09-04: the iCloud store registers, syncs with a signed-in
iCloud account, and values survive relaunches.

**GAME CENTER WORKS HERE TOO** — and the sentence that used to sit in this spot
saying it could not, "GameKit refuses to load its services without a real
provisioning profile, that wall is exactly where the paid developer account
starts being necessary", is RETRACTED. Archive issue 87 retracted it on
2026-09-04 and this file was never updated (found 2026-09-10). It came from a
log line — *"Could not load services... missing the
com.apple.developer.game-center entitlement"* — captured BEFORE that
entitlement was added and never re-tested after; the message named its own fix
and was read as a verdict. With the entitlement present (ad-hoc simulator
signing carries it, which is the whole reason the two `CODE_SIGN_*` flags above
are set the way they are) `authenticate()` returns `result: "ok"` with a real
player id and an alias, on the free simulator, with no paid account.

What the paid membership actually buys is a **signed build on a physical device
and the store** — not a first login. What the simulator still cannot do is
device provisioning itself, which is the point of the remaining iOS gates
(docs/MANUAL-STEPS.md section D3).

### The exporter writes the entitlements file EMPTY (found 2026-09-10)

`export_project_only` produces `nokings/nokings.entitlements` containing an
**empty dict**, even with `plugins/GameCenter=true` and `plugins/iCloud=true` in
the preset — the Godot 4.7 iOS exporter emits neither
`com.apple.developer.game-center` nor
`com.apple.developer.ubiquitous-key-value-store`. The generated project
hardcodes `CODE_SIGN_ENTITLEMENTS = "nokings/nokings.entitlements"` in both
configurations, which is why the entitlements plist above has to be supplied by
hand at all. Worth knowing before concluding anything from a run: an app signed
with empty entitlements produces exactly the *"Could not load services...
missing the com.apple.developer.game-center entitlement"* log line that the
retraction above is about, so a careless re-test re-derives the wrong answer.

**Unresolved for RELEASE simulator builds, flagged not fixed.** Two ways of
supplying them left the SIGNED app's embedded entitlements still `{}`
(`codesign -d --entitlements`): passing
`CODE_SIGN_ENTITLEMENTS=<abs path>` to `xcodebuild` — which
`-showBuildSettings` confirmed resolved to that path — and writing the two keys
into the exported `nokings/nokings.entitlements` before building. No cause
established, so none is claimed here. The 2026-09-04 verification that DOES
stand was a **Debug** build via the recipe above, and nothing here contradicts
it; only the Release simulator path is unproven. Do not read this note as
"entitlements are broken".
