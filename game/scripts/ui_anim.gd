## NO-243 S2: the shared UI animation patterns — one helper per pattern, so
## every modal, grid and fly-to-tab moves the same way (plan rule: "one
## helper per pattern, not per-site copies"). Pure module on `g`, like the
## other scripts here; every tween is bound to the node it moves, so a node
## freed mid-animation takes its tween with it.
##
## Rules every function keeps:
## - Gated on `on(g)` — the same `autoplay`/`animations_on` seam every other
##   animation uses. Off means instant: nothing is created or awaited.
## - Never blocks input. Nothing here touches a mouse filter except
##   `input_dead` (for a panel that is already closing) and the ghosts, which
##   are input-dead from birth. A control mid-animation is clickable wherever
##   it is drawn: GUI picking and get_global_rect() both follow its scale.
## - A Container resets a child's scale on every sort (Container.
##   fit_child_in_rect), and a freshly built modal's first sort is deferred to
##   the end of the frame. So anything inside a Container is hidden with alpha
##   (which no sort touches) at once and scaled one frame later, after that
##   sort. A later re-sort mid-tween can only snap it to its final state.

const MODAL_IN_S := 0.15
const MODAL_FROM := 0.95 # modal content starts at this scale
const DEAL_S := 0.15 # one tile's deal-in
const DEAL_STAGGER := 0.04 # between tiles; 7 tiles end by 0.39 s
const FLY_S := 0.35
const FLY_END_SCALE := 0.35
const GLOW_S := 0.4
const GHOST := &"ui_anim_ghost" # meta on every fly_to ghost (tests count them)


static func on(g) -> bool:
	return not g.autoplay and g.animations_on


## Modal scale/fade-in. `panel` is the full-rect modal, a child of the HUD
## layer (never of a Container, so its alpha and scale are its own);
## `content` is its centred content. `from` is the screen point the content
## grows out of (default: its own centre) and `start` its first scale — the
## preview passes the tapped point and a small scale, so it grows out of the
## tile that was pressed.
static func modal_in(g, panel: Control, content: Control, from := Vector2(-1, -1),
		start := MODAL_FROM) -> void:
	if not on(g):
		return
	var gen: int = panel.get_meta("ui_anim_gen", 0) + 1
	panel.set_meta("ui_anim_gen", gen)
	if panel.has_meta("ui_anim_tw"):
		(panel.get_meta("ui_anim_tw") as Tween).kill()
		panel.remove_meta("ui_anim_tw")
	panel.modulate.a = 0.0
	await g.get_tree().process_frame
	if not is_instance_valid(panel) or panel.get_meta("ui_anim_gen", 0) != gen:
		return
	var tw := panel.create_tween().set_parallel()
	tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(panel, "modulate:a", 1.0, MODAL_IN_S)
	if is_instance_valid(content):
		content.pivot_offset = (from - content.global_position) if from.x >= 0.0 \
			else content.size / 2.0
		content.scale = Vector2(start, start)
		tw.tween_property(content, "scale", Vector2.ONE, MODAL_IN_S)
	panel.set_meta("ui_anim_tw", tw)


## Close with a fade: input-dead at once (the panel stays visible for the
## fade, and a visible Control eats clicks — CLAUDE.md), hidden at the end.
static func fade_out(g, panel: Control) -> void:
	input_dead(panel)
	if not on(g):
		panel.visible = false
		return
	var tw := panel.create_tween()
	tw.tween_property(panel, "modulate:a", 0.0, MODAL_IN_S)
	tw.tween_callback(func() -> void: panel.visible = false)


## IGNORE on `node` and every descendant — Godot does not cascade a parent's
## filter. Only for a node that will never take input again (it is closing,
## or it is a ghost): nothing restores the old filters.
static func input_dead(node: Control) -> void:
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in node.find_children("*", "Control", true, false):
		(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE


## Deal-in: each of `nodes` pops from `from_scale` and alpha 0 to its rest,
## `stagger` apart, after `delay`. The Box and the choice pick deal their
## tiles in; a Shop restock passes a thin x-scale, so its tiles flip over; a
## reroll does the same to the Box's tiles. Each node's own alpha is kept (a
## SOLD Shop tile rests at 0.4).
static func deal_in(g, nodes: Array, from_scale := Vector2(0.6, 0.6),
		stagger := DEAL_STAGGER, delay := 0.0) -> void:
	if not on(g) or nodes.is_empty():
		return
	var rest := {}
	for n in nodes:
		rest[n] = (n as Control).modulate.a
		(n as Control).modulate.a = 0.0
	await g.get_tree().process_frame
	for i in nodes.size():
		var n: Control = nodes[i]
		if not is_instance_valid(n) or not n.is_inside_tree():
			continue
		n.pivot_offset = n.size / 2.0
		n.scale = from_scale
		var d := delay + i * stagger
		var tw := n.create_tween().set_parallel()
		tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(n, "scale", Vector2.ONE, DEAL_S).set_delay(d)
		tw.tween_property(n, "modulate:a", rest[n], DEAL_S).set_delay(d)


## Fly-to-target: a ghost of `icon` (a Texture2D, else its text) leaves the
## screen rect `from` and shrinks into `target`'s centre, then frees. The
## target is re-read every frame, so it may still be laying out or sliding.
## The ghost sits on the HUD layer above every panel and takes no input.
## Returns it (null when animations are off) so tests can watch it land.
static func fly_to(g, icon: Variant, from: Rect2, target: Control) -> Control:
	if not on(g) or not is_instance_valid(target):
		return null
	var ghost: Control
	if icon is Texture2D:
		var tr := TextureRect.new()
		tr.texture = icon
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ghost = tr
	else:
		var l := Label.new()
		l.text = str(icon)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		ghost = l
	ghost.set_meta(GHOST, true)
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ghost.position = from.position
	ghost.size = from.size
	ghost.pivot_offset = from.size / 2.0
	g.hud.add_child(ghost)
	var step := func(t: float) -> void:
		var to := from.position
		if is_instance_valid(target):
			to = target.get_global_rect().get_center() - from.size / 2.0
		ghost.position = from.position.lerp(to, t)
		ghost.scale = Vector2.ONE.lerp(Vector2(FLY_END_SCALE, FLY_END_SCALE), t)
	var tw := ghost.create_tween()
	tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_method(step, 0.0, 1.0, FLY_S)
	tw.tween_callback(ghost.queue_free)
	return ghost


## A grid cell that is gone: lifted onto the HUD layer where it stood,
## input-dead, flashed with `flash` (Color.WHITE = none), then shrunk and
## faded out and freed. Detached from its grid at once, so no lookup finds
## it again. Frees it outright when animations are off.
static func vanish(g, node: Control, flash := Color.WHITE) -> void:
	var at := node.get_global_rect()
	if node.get_parent():
		node.get_parent().remove_child(node)
	if not on(g):
		node.queue_free()
		return
	input_dead(node)
	g.hud.add_child(node)
	node.position = at.position
	node.pivot_offset = at.size / 2.0
	var tw := node.create_tween()
	if flash != Color.WHITE:
		tw.tween_property(node, "modulate", flash, 0.08)
	tw.tween_property(node, "scale", Vector2(0.3, 0.3), 0.2)
	tw.parallel().tween_property(node, "modulate:a", 0.0, 0.2)
	tw.tween_callback(node.queue_free)


## A one-shot glow ring of `color` on `node`, fading out over GLOW_S — an
## Artefact arriving in its rarity's colour. The ring is input-dead.
static func glow(g, node: Control, color: Color) -> void:
	if not on(g):
		return
	var ring := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(color, 0.25)
	sb.border_color = color
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(6)
	ring.add_theme_stylebox_override("panel", sb)
	ring.set_anchors_preset(Control.PRESET_FULL_RECT)
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_child(ring)
	var tw := ring.create_tween()
	tw.tween_property(ring, "modulate:a", 0.0, GLOW_S).set_ease(Tween.EASE_IN)
	tw.tween_callback(ring.queue_free)
