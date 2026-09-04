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

Repeat with `target=template_release` against the release xcframework when a
release simulator build is ever needed (device builds are unaffected — the
device slices were always correct).
