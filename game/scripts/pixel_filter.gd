## issue 74 — the pixel-filter SPIKE. Off by default; this exists to be looked
## at and judged, not shipped on.
##
## Attaches a full-screen shader over everything on a high CanvasLayer. It
## deliberately does NOT use a SubViewport: that route pixelates more
## authentically (render small, upscale nearest-neighbour) but moves the
## coordinate space input arrives in, and this project's windowed click probes
## drive real input at real coordinates. Post-effect keeps coordinates intact,
## so the probes cannot tell it is there.
##
## Enable with --pixel <factor> for a screenshot, or Settings once someone
## decides it is worth keeping.
extends CanvasLayer

const SHADER := preload("res://shaders/pixelate.gdshader")

## The menu's factor (user call 2026-08-31: 3x reads well on flat UI).
const MENU_FACTOR := 3.0

## The layer this sits on. ANY ART ADDED TO A FILTERED SCREEN MUST RENDER ABOVE
## THIS to dodge the filter — a full-screen post-effect quantises everything
## composited below it, and hand-drawn art distorts rather than stylises. That
## is why the in-game board is not filtered at all: its UI must sit above the
## board, so "filter the UI, exempt the art" would need art above the filter
## and UI below it, which contradicts the visual stacking. If Artefact art
## later appears in a menu, give it a CanvasLayer above LAYER.
const LAYER := 128

var rect: ColorRect


static func factor_from_args(args: PackedStringArray) -> float:
	if not args.has("--pixel"):
		return 0.0
	var i: int = args.find("--pixel") + 1
	return float(args[i]) if i < args.size() else 3.0


func _ready() -> void:
	layer = LAYER
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	rect = ColorRect.new()
	rect.material = mat
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	# never eat a click — the whole point is that input still reaches the game
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.visible = false
	add_child(rect)


func set_factor(f: float) -> void:
	rect.visible = f > 1.0
	if rect.visible:
		rect.material.set_shader_parameter("pixel_size", f)
