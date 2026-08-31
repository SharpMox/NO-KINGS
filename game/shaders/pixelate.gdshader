shader_type canvas_item;

// issue 74 — pixelation as a full-screen POST-EFFECT rather than a SubViewport.
//
// The SubViewport route (render small, upscale nearest-neighbour) gives truer
// pixel art, but it changes the coordinate space input arrives in — and this
// project's windowed click probes drive real input at real coordinates. An
// approach that breaks every probe is a bad approach however it looks, so this
// samples the already-composited screen instead: coordinates are untouched and
// the probes cannot tell it is there.
//
// Godot 4 note: the Godot 3 built-in SCREEN_TEXTURE no longer exists. It has to
// be declared as a uniform with hint_screen_texture, and filter_nearest is what
// actually makes the blocks hard-edged rather than smoothly interpolated.
// Getting this wrong renders a blank white screen with no error.
uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_nearest;

uniform float pixel_size : hint_range(1.0, 8.0) = 3.0;

void fragment() {
    vec2 size = 1.0 / SCREEN_PIXEL_SIZE;
    vec2 blocks = size / pixel_size;
    // sample the centre of each block, not its corner, so the image does not
    // drift half a block up-left
    vec2 snapped = (floor(SCREEN_UV * blocks) + 0.5) / blocks;
    COLOR = texture(screen_tex, snapped);
}
