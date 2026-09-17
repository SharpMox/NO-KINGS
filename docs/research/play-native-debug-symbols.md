# Play Console native debug symbols: what the primary sources say (NO-98)

Research for the decision on whether to upload native debug symbols for the
NO-KINGS Android build. All quotes below are verbatim from the cited page,
fetched 2026-09-16. No advice, no recommendation beyond the closing section.

## 1. Size limit

Two Google pages give two different numbers for the same thing, and neither
says the limit depends on the upload path.

**developer.android.com** says 1.6 GB:

> "There is a 1.6 GB limit for the native debug symbols file. If your debug
> symbols footprint is too large, use `SYMBOL_TABLE` instead of `FULL` to
> decrease the file size."

Source: [Include native symbols in your release build](https://developer.android.com/build/include-native-symbols), fetched 2026-09-16.

**support.google.com** says 800 MB, in the same sentence structure:

> "The limit for the debug symbols file is 800 MB. If your debug symbols
> footprint is too large, use `SYMBOL_TABLE` instead of `FULL` to decrease the
> file size."

Source: [Deobfuscate or symbolicate crash stack traces](https://support.google.com/googleplay/android-developer/answer/9848633?hl=en), fetched 2026-09-16.

Neither page ties the number to a specific upload path (App Bundle Explorer
UI, the Play Developer Publishing API, or symbols embedded in the AAB via
`debugSymbolLevel`). The Play Developer Publishing API reference for
`edits.deobfuscationfiles.upload` documents the request shape but states no
size limit at all:

Source: [Method: edits.deobfuscationfiles.upload](https://developers.google.com/android-publisher/api-ref/rest/v3/edits.deobfuscationfiles/upload), fetched 2026-09-16.

Either way, both numbers are far above the 182 MB our current full zip
measures, so the limit itself is not a constraint for NO-KINGS at 0.1.0. This
is a genuine disagreement between two Google sources, not a gap to fill by
guessing which one is right.

## 2. What Play accepts

The file uploads through **Test and release > App bundle explorer**, picking
the artifact in the top-right picker, then **Downloads > Assets**:

> "On the left menu, select Test and release > App bundle explorer. Using the
> picker in the top-right-hand corner, choose the relevant artifact. Select
> the Downloads tab, and scroll down to the 'Assets' section."

Source: [Deobfuscate or symbolicate crash stack traces](https://support.google.com/googleplay/android-developer/answer/9848633?hl=en), fetched 2026-09-16.

It is per artifact (per version code), not per app: the Publishing API
confirms this at the endpoint level, since `apkVersionCode` is a required
path segment:

> `POST https://androidpublisher.googleapis.com/upload/androidpublisher/v3/applications/{packageName}/edits/{editId}/apks/{apkVersionCode}/deobfuscationFiles/{deobfuscationFileType}`

Source: [Method: edits.deobfuscationfiles.upload](https://developers.google.com/android-publisher/api-ref/rest/v3/edits.deobfuscationfiles/upload), fetched 2026-09-16.

Expected zip layout is architecture folders at the root, holding the `.so`
files directly:

> "app/build/intermediates/cmake/universal/release/obj/" containing
> "armeabi-v7a/", "arm64-v8a/", "x86/", "x86_64/" folders each holding
> `libgameengine.so`, `libothercode.so`, `libvideocodec.so`.

Source: [Include native symbols in your release build](https://developer.android.com/build/include-native-symbols), fetched 2026-09-16.

This matches what Godot's own export already produces: our real
`native-debug-symbols-nokings-0.1.0.zip` contains exactly `arm64-v8a/libc++_shared.so`
and `arm64-v8a/libgodot_android.so` at the top of the `arm64-v8a/` folder,
nothing more.

Neither developer.android.com nor the support.google.com page says anything
about what happens on a build-ID mismatch between the uploaded symbols and
the shipped library. Both were checked directly and neither mentions it.
Undocumented.

## 3. SYMBOL_TABLE vs FULL

From the AGP documentation:

> "Use `SYMBOL_TABLE` to get function names in the Play Console's
> symbolicated stack traces. This level supports tombstones."

> "Use `FULL` to get function names, files, and line numbers in the Play
> Console's symbolicated stack traces."

Source: [Include native symbols in your release build](https://developer.android.com/build/include-native-symbols), fetched 2026-09-16.

So `SYMBOL_TABLE` gets you a symbolicated function name per crash frame.
`FULL` adds the file name and line number. What's lost going from `FULL` to
`SYMBOL_TABLE` is exactly that: no file/line in the crash trace, just the
function it happened in. Neither value is described with a size number on
this page beyond the shared 1.6 GB / 800 MB figure already covered in
Question 1 — the page's only size guidance is "if your footprint is too
large, use SYMBOL_TABLE instead of FULL."

## 4. Producing a symbol-table-only file

Google's own instructions for AGP 4.0 and earlier point at objcopy:

> "If your file is too big, it's likely because your `.so` files contain a
> symbol table and also DWARF debugging info, which isn't needed to
> symbolicate your code. On AGP 4.0 or lower, you can remove the DWARF
> debugging info by running the following command:
> `$OBJCOPY --strip-debug lib.so lib.so.sym`"

Source: [Include native symbols in your release build](https://developer.android.com/build/include-native-symbols), fetched 2026-09-16.

LLVM's own docs for the equivalent flag on `llvm-objcopy`:

> "`--strip-debug`, `-g`: Remove all debug sections from the output."

Source: [llvm-objcopy Command Guide](https://llvm.org/docs/CommandGuide/llvm-objcopy.html), fetched 2026-09-16. The page does not itself spell out what survives; that's confirmed empirically below.

**Measured, on a throwaway copy in `/tmp`, never on the repo or the AAB:**

Ran `llvm-objcopy --strip-debug` (Homebrew LLVM 23.1.1, GNU-objcopy-compatible)
on the actual `libgodot_android.so` from Godot's own
`Godot_native_debug_symbols.4.7.stable.template_release.android.zip`:

- `libgodot_android.so`: 750,768,672 bytes to 92,229,104 bytes (removed
  `.debug_info`, `.debug_abbrev`, `.debug_line`, `.debug_loc`,
  `.debug_ranges`, `.debug_str`, `.debug_macinfo` — 657.6 MB of DWARF).
  `.symtab` (8.6 MB) and `.strtab` (13.4 MB) survived untouched;
  `llvm-nm` still resolved 177,837 symbols on the stripped file.
- `libc++_shared.so`: 9,290,184 bytes to 1,813,976 bytes.
- Rebuilt the zip in the same `arm64-v8a/lib*.so` layout as our real
  debug-symbols zip: 190,610,407 bytes (full, matches the reported 182 MB)
  down to 28,061,407 bytes (symbol-table-only) — an 85.3% reduction.

`build-id` was preserved on the stripped file (`BuildID[sha1]=1715f0f...`,
same as the source), which is what Play would need to match it to a crash.

Note: I first tried this with the Python `lief` library. `Binary.remove_section(name, clear=True)` zeroed the section content but did not shrink the file (LIEF's ELF writer does not repack segments on section removal by default), so that path gave a false negative before `llvm-objcopy` gave a real one. Flagging this so nobody re-tries LIEF expecting it to reproduce `--strip-debug`'s behavior without extra work.

## 5. Godot-specific documentation

Godot's own docs cover this directly:

> "Your exported template and its native debug symbols must come from the
> same build, so you can use the official symbols only if you are using the
> official export templates."

> For custom export templates: "add `debug_symbols=yes
> separate_debug_symbols=yes` to your scons build command," which produces
> a file named `android-template-release-native-debug-symbols.zip`.

> "Users can upload symbols either when creating a release or afterward" via
> the bundle's Downloads tab, Native debug symbols section.

Source: [Resolving crashes on Android](https://docs.godotengine.org/en/stable/tutorials/platform/android/resolving_crashes_on_android.html), fetched 2026-09-16.

This is the page that matters for NO-KINGS: we use the official export
templates, so the official `Godot_native_debug_symbols.4.7.stable.template_release.android.zip`
published on Godot's GitHub release page is the right, matching artifact for
0.1.0 — not something we would need to build ourselves with custom scons
flags.

## 6. Retention and timing

Symbols can be uploaded after a release is already live. Godot's docs say
so directly (quoted above: "either when creating a release or afterward").
But uploading later does not symbolicate crashes that already happened:

> "After you've uploaded a ProGuard mapping file or debug symbols file for a
> version of your app, only crashes and ANRs that occur afterward will be
> deobfuscated."

Source: [Deobfuscate or symbolicate crash stack traces](https://support.google.com/googleplay/android-developer/answer/9848633?hl=en), fetched 2026-09-16.

So the upload does not need to accompany the release, but it is not
retroactive either. Crashes before the upload stay unsymbolicated forever.

## What this means for NO-98

- The 182 MB full-debug zip is already well under either size figure Google
  publishes (800 MB or 1.6 GB), so size is not what's blocking the upload
  decision. Both Google pages agree the file is nowhere near either limit.
- A symbol-table-only version is real and works: `llvm-objcopy --strip-debug`
  on the actual engine `.so` measured at 92.2 MB (from 750.8 MB), and the zip
  in the real `arm64-v8a/` layout came to 28.1 MB (from 190.6 MB). The
  build-id survived the strip.
- The cost of going symbol-table-only, per Google's own description, is file
  and line numbers in the crash trace. `SYMBOL_TABLE` still gets a function
  name per frame; `FULL` also says which line in that function.
- Whichever is picked, it can be uploaded any time after the release goes
  live, but only covers crashes from that point forward — not the internal
  testing crashes already collected.
- Two things stayed undocumented after checking the primary sources directly:
  build-ID mismatch behavior (neither Google page addresses it), and whether
  the size limit differs by upload path (neither page ties its number to UI
  vs. API vs. Gradle-embedded upload; each states one number with no
  qualification).

## DONE — uploaded 2026-09-17

`native-debug-symbols-nokings-0.1.0-symtab.zip`, 28061251 bytes, SHA256
`90d83611b7f98c971c15a8eb167ab68643d50556da584ebb67b7f7c90eb0038d`, attached to
**version code 1 / 0.1.0** (artifact `4860230669253486127`). Play renames it to
`native-debug-symbols.zip` on its side and lists it at 28.1 MB.

The symbol-table build was chosen over the 182 MB full-debug zip. **arm64-v8a
only is correct, not a gap**: `game/export_presets.cfg` ships `arm64-v8a=true`
with `armeabi-v7a`, `x86` and `x86_64` all false, so there is no second ABI whose
symbols could be missing. Worth re-checking that if the export ever gains an
architecture — symbols are not retroactive, so a missing ABI cannot be repaired
for crashes already recorded.

### The navigation route, because it is not guessable

Every future release needs this, and the failure mode presents as "the button
does nothing":

1. NO KINGS → **Test and release → App bundle explorer**.
2. In the version row, the **"View app version" control exists TWICE**. One twin
   is `display:none`; the real one is a ~40px arrow rendered past the viewport
   (x≈1458 at 1271px wide). Clicks land on the hidden twin and silently do
   nothing. `scrollIntoView({inline:'center'})` before the click is the fix —
   hover emulation is a red herring.
3. That lands on `…/app-bundle-explorer?artifactId=<id>`, tabs
   Details | **Downloads** | Delivery | Comparison.
4. **Downloads** → Assets table. `Native debug symbols` is the **second** upload
   control; the first is `ReTrace mapping file`. An unattached row shows no size
   and no download icon.

Direct URL, for reference:
`play.google.com/console/u/0/developers/5660342400699971142/app/4973836996004489929/app-bundle-explorer?artifactId=4860230669253486127&tab=downloads`

Also present and **not to be touched**: a hidden (0×0, `aria-hidden`) "Upload
documents to verify your organization" form, and an unrendered stepper
"1 Confirm version for update / 2 Select targeting criteria". Neither is part of
this task; the second is a release-targeting flow.

### Who performs the upload

**An agent upload is blocked.** On the Aux machine the file-chooser intercept
plus `DOM.setFileInputFiles` on the Upload control was denied by the permission
classifier even with the user's direct approval, and that denial was not routed
around — not on Aux, and not by re-running it from the other machine, since the
denial attaches to the action rather than to the keyboard. Max performed it by
hand.

**Standing route for production-console writes: the agent prepares, verifies and
confirms; Max clicks.** Everything reversible — navigation, reading state,
staging and hash-verifying the file, checking ABI coverage, re-reading the target
row immediately beforehand, and verifying afterwards — is agent work. The
irreversible click is not.
