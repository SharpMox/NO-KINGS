## Shared layout-settle helper for every click-probe test that reads a
## control's geometry (get_global_rect/position/size) right after opening,
## building, or changing it.
##
## NO-254 (CI, 2026-09-25): a freshly-built container's get_global_rect()
## isn't usable until the next layout-sort frame (CLAUDE.md's documented
## GridContainer trap), and a FIXED number of extra frames is not a fix —
## it settles on some hosts/some code paths and not others (CI run
## 36130372199 failed on #584's head with zero extra frames; #592 added
## exactly one and it still failed intermittently). Poll instead of
## guessing a frame count.
##
## Every test file `extends SceneTree` on its own, so this lives as a
## standalone script rather than a mixin — call it as
## `await Settle.settle_layout(control)` (const Settle :=
## preload("res://tests/test_settle.gd")).


## Waits until `control`'s global rect (position AND size, not size alone —
## so a control still being moved or scaled by a running tween, e.g. a
## modal's scale/fade-in open animation, is waited out too, not just an
## unsorted container) stops changing between two consecutive frames, and
## fits inside its own viewport (an unsettled container can transiently
## report the whole screen's worth of space — NO-254's original bug).
## Bounded at 10 frames, not wall time: this is a layout-sort/tween race,
## not a host-speed one. Returns the settled rect, viewport size and frames
## spent so a caller's failure detail never has to be re-derived.
static func settle_layout(control: Control) -> Dictionary:
	var viewport: Vector2 = control.get_viewport().get_visible_rect().size
	var prev := Rect2(-1, -1, -1, -1)
	var frames := 0
	# NO-243 S2: a modal opening with UiAnim.modal_in scales its content for
	# 0.15 s, which can outlast the 10-frame poll below at 60 fps. Wait that
	# tween out first (bounded), then poll the layout as before.
	var guard := 0
	while _opening(control) and guard < 120:
		await control.get_tree().process_frame
		guard += 1
		frames += 1
	var rect: Rect2 = control.get_global_rect()
	var polled := 0
	while polled < 10:
		rect = control.get_global_rect()
		var fits: bool = rect.size.x <= viewport.x and rect.size.y <= viewport.y
		if fits and rect.is_equal_approx(prev):
			break
		prev = rect
		await control.get_tree().process_frame
		frames += 1
		polled += 1
	return {"rect": rect, "frames": frames, "viewport": viewport}


## True while `control` or an ancestor is mid UiAnim.modal_in: waiting for
## its first frame (modulate.a still 0) or running its tween (ui_anim.gd
## keeps it in the panel's "ui_anim_tw" meta).
static func _opening(control: Control) -> bool:
	var n: Node = control
	while n != null:
		if n.has_meta("ui_anim_gen"):
			var tw: Variant = n.get_meta("ui_anim_tw") if n.has_meta("ui_anim_tw") else null
			if (tw != null and (tw as Tween).is_valid() and (tw as Tween).is_running()) \
					or (n is CanvasItem and (n as CanvasItem).visible and (n as CanvasItem).modulate.a < 0.01):
				return true
		n = n.get_parent()
	return false


## Detail string for a check()'s third argument — every call site formats
## this the same way, so a failure always reports the same three facts.
static func detail(settled: Dictionary) -> String:
	return "rect=%s viewport=%s frames_waited=%d" % [
		settled.rect, settled.viewport, settled.frames]
