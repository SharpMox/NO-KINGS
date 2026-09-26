extends SceneTree
## NO-264 option A: Guide illustrations cropped from real in-game captures.
## Each SHOTS row launches one windowed capture through the existing
## --screenshot seam (tools/capture.md), then crops the PNG to a rect and saves
## it as game/assets/guide/<name>.png at S x the 480x800 canvas.
##
## One command, all rows:
##   tools/godot-lock.sh godot --headless --path game -s tools/guide_captures.gd
## This process only launches the captures and crops, so it may be headless; the
## captures it launches are windowed (no --headless), as the seam requires. They
## run one after another, inside the caller's lock.
##
## A row: name, the flags after `--` (minus --screenshot, added here), the file
## the capture writes (game.png for a scenario, menu.png for a menu screen), and
## ONE crop:
##   "rect":  Rect2 in canvas px (480x800), for anything off the board;
##   "board": Rect2i in board tiles, x/y of the bottom-left tile (y=0 is the
##            player's back row, as in --select) plus width/height in tiles.
##            Converted with game.gd's own board_tile_for, so it tracks layout.
## The uncropped capture stays in CAPTURE_DIR/<name>/ for tuning a rect.

const Game := preload("res://scripts/game.gd")
const Hud := preload("res://scripts/hud.gd")
const Tuning := preload("res://scripts/tuning.gd")

const S := 2
const CANVAS := Vector2(480, 800) # project.godot viewport
const OUT_DIR := "res://assets/guide"
const CAPTURE_DIR := "/tmp/guide-captures" # ponytail: POSIX temp; Aux and CI are macOS/Linux

const SHOTS := [
	# Rules > Merging: a Ferz selected, its twin ringed as a merge partner.
	{"name": "rules-merging", "file": "game.png",
		"flags": ["--scenario-name", "Merge: on the board", "--select", "2,1"],
		"board": Rect2i(0, 0, 7, 3)},
]


func _initialize() -> void:
	var out := ProjectSettings.globalize_path(OUT_DIR)
	DirAccess.make_dir_recursive_absolute(out)
	var fails := 0
	for shot: Dictionary in SHOTS:
		var dir := CAPTURE_DIR.path_join(shot.name)
		var png := dir.path_join(shot.file)
		DirAccess.remove_absolute(png) # never crop a stale capture
		var args := PackedStringArray(["--path", ProjectSettings.globalize_path("res://"), "--"])
		args.append_array(PackedStringArray(shot.flags))
		args.append_array(PackedStringArray(["--screenshot", dir]))
		var code := OS.execute(OS.get_executable_path(), args)
		var img: Image = Image.load_from_file(png) if FileAccess.file_exists(png) else null
		if img == null:
			printerr("FAILED %s: capture exited %d, no %s" % [shot.name, code, png])
			fails += 1
			continue
		var k := img.get_width() / CANVAS.x # capture px per canvas px (1, or 2 on a Retina window)
		var r: Rect2 = shot.rect if shot.has("rect") else _board_rect(shot.board)
		var crop := img.get_region(Rect2i(Rect2(r.position * k, r.size * k)))
		# ponytail: a 1x capture is upscaled nearest-neighbour; the pixel font keeps it honest
		crop.resize(int(r.size.x * S), int(r.size.y * S), Image.INTERPOLATE_NEAREST)
		var path := out.path_join(shot.name + ".png")
		var err := crop.save_png(path)
		print("%s %s (capture scale %.1f)" % ["wrote" if err == OK else "FAILED", path, k])
		fails += int(err != OK)
	quit(1 if fails > 0 else 0)


## Board tiles -> canvas px, solved the way game.gd _layout_board solves it on a
## desktop window (no notch inset).
func _board_rect(t: Rect2i) -> Rect2:
	var top := Hud.HEADER_H + Game.BOARD_TOP_MARGIN
	var tile := Game.board_tile_for(CANVAS, top)
	var left := roundf((CANVAS.x - tile * Tuning.BOARD_W) / 2.0)
	var y_top := Tuning.BOARD_H - (t.position.y + t.size.y) # screen row of the crop's top tile
	return Rect2(Vector2(left + t.position.x * tile, top + y_top * tile), Vector2(t.size) * tile)
