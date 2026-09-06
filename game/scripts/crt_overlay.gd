extends CanvasLayer
## CRT TV look over the WHOLE screen (user ask, 2026-09-06): an autoload
## CanvasLayer above every scene — Intro, Menu, Game and every modal — holding
## one full-rect ColorRect whose shader re-reads the finished frame and adds
## scanlines, a slight barrel curve with a vignette, and a touch of colour
## fringing at the edges. It never quantises or blurs a pixel (the effect
## issue 74 rejected), so the painted tokens and the hard-edged text stay
## exactly as drawn; it only shades and warps what is already there.
##
## Opt-out in Settings ("CRT: On/Off", settings.gd), which calls set_enabled.
## MOUSE_FILTER_IGNORE keeps every tap going to whatever is underneath, and
## the click probes drive real input through it. The curvature is kept small
## on purpose: the picture is warped, the hit boxes are not, so a large curve
## would push a corner button visibly away from where it responds.

const Settings := preload("res://scripts/settings.gd")

const SHADER := """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear, repeat_disable;
uniform float curvature = 0.035;   // barrel: 0 = flat, 0.1 = a fishbowl
uniform float scanline = 0.28;     // how dark the gaps between lines get
uniform float line_count = 400.0;  // lines down the screen (native height / 2)
uniform float vignette = 0.32;     // corner darkening
uniform float fringe = 0.0012;     // red/blue split at the edges, in UV
uniform float brightness = 1.06;   // lift, so the lines don't dim the picture

void fragment() {
	// barrel curve around the centre
	vec2 c = SCREEN_UV * 2.0 - 1.0;
	float r2 = dot(c, c);
	c *= 1.0 + curvature * r2;
	vec2 uv = c * 0.5 + 0.5;
	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
		COLOR = vec4(0.0, 0.0, 0.0, 1.0); // the bezel
	} else {
		// colour fringing grows toward the edges, like a misconverged tube
		vec2 shift = c * fringe;
		float rc = texture(screen_tex, uv + shift).r;
		float gc = texture(screen_tex, uv).g;
		float bc = texture(screen_tex, uv - shift).b;
		vec3 rgb = vec3(rc, gc, bc) * brightness;
		// scanlines: a soft dark gap every other line
		float line = 0.5 + 0.5 * sin(uv.y * line_count * 6.2831853);
		rgb *= 1.0 - scanline * line * line;
		// vignette
		rgb *= 1.0 - vignette * r2 * r2;
		COLOR = vec4(rgb, 1.0);
	}
}
"""

var _rect := ColorRect.new()


func _ready() -> void:
	layer = 128 # above every scene layer, including the HUD's own CanvasLayer
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.color = Color.WHITE
	var shader := Shader.new()
	shader.code = SHADER
	var mat := ShaderMaterial.new()
	mat.shader = shader
	_rect.material = mat
	add_child(_rect)
	set_enabled(bool(Settings.load_settings().get("crt_on", true)))


## Settings.apply() routes the toggle here; also read once at boot above.
func set_enabled(on: bool) -> void:
	_rect.visible = on


func enabled() -> bool:
	return _rect.visible
