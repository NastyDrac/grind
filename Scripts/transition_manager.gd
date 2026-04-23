extends Node

## Transition effects: TV Static, Film Burn, Broken Glass.
## Set transition_style in the inspector or at runtime to switch.
## Call:  await TransitionManager.transition(callable)
## The callable fires at peak — swap scenes inside it.

enum TransitionStyle {
	TV_STATIC,
	FILM_BURN,
	BROKEN_GLASS,
	FADE
}

@export var transition_style : TransitionStyle = TransitionStyle.BROKEN_GLASS

@export_group("Timing")
@export var buildup_duration : float = 0.30
@export var hold_duration    : float = 0.12
@export var clear_duration   : float = 0.55

@export_group("Fade")
## Colour the screen fades through. Black is classic; white gives a bleach cut.
@export var fade_color : Color = Color(0.0, 0.0, 0.0, 1.0)

# ── Static palette ─────────────────────────────────────────────────────────────
const STATIC_COLORS := [
	Color(0.08, 0.08, 0.08),
	Color(0.85, 0.85, 0.85),
	Color(0.15, 0.15, 0.15),
	Color(0.60, 0.60, 0.60),
	Color(0.40, 0.40, 0.40),
	Color(0.72, 0.58, 0.30),
	Color(0.20, 0.20, 0.20),
	Color(0.95, 0.95, 0.95),
	Color(0.55, 0.42, 0.18),
]

var _canvas    : CanvasLayer
var _container : Control
var _rng       := RandomNumberGenerator.new()
var _active    : bool = false

func _ready() -> void:
	_rng.randomize()
	_build_canvas()

func _build_canvas() -> void:
	_canvas = CanvasLayer.new()
	_canvas.layer = 200
	add_child(_canvas)
	_container = Control.new()
	_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(_container)
	_canvas.hide()

# ------------------------------------------------------------------------------
#  PUBLIC API
# ------------------------------------------------------------------------------

func transition(on_peak: Callable) -> void:
	if _active:
		on_peak.call()
		return
	_active = true
	_canvas.show()

	match transition_style:
		TransitionStyle.TV_STATIC:
			await _run_static(on_peak)
		TransitionStyle.FILM_BURN:
			await _run_film_burn(on_peak)
		TransitionStyle.BROKEN_GLASS:
			await _run_broken_glass(on_peak)
		TransitionStyle.FADE:
			await _run_fade(on_peak)

	_canvas.hide()
	_active = false

# ------------------------------------------------------------------------------
#  FADE
# ------------------------------------------------------------------------------

func _run_fade(on_peak: Callable) -> void:
	var overlay := ColorRect.new()
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(fade_color.r, fade_color.g, fade_color.b, 0.0)
	_container.add_child(overlay)

	# Fade OUT (to opaque)
	var elapsed := 0.0
	while elapsed < buildup_duration:
		overlay.color.a = elapsed / buildup_duration
		await get_tree().process_frame
		elapsed += get_process_delta_time()
	overlay.color.a = 1.0

	on_peak.call()
	await get_tree().create_timer(hold_duration).timeout

	# Fade IN (back to clear)
	elapsed = 0.0
	while elapsed < clear_duration:
		overlay.color.a = 1.0 - (elapsed / clear_duration)
		await get_tree().process_frame
		elapsed += get_process_delta_time()

	_clear_children()

# ------------------------------------------------------------------------------
#  TV STATIC
# ------------------------------------------------------------------------------

func _run_static(on_peak: Callable) -> void:
	var elapsed := 0.0
	while elapsed < buildup_duration:
		_draw_static(elapsed / buildup_duration)
		await get_tree().process_frame
		elapsed += get_process_delta_time()

	_draw_static(1.0)
	on_peak.call()
	await get_tree().create_timer(hold_duration).timeout

	elapsed = 0.0
	while elapsed < clear_duration:
		_draw_static(1.0 - (elapsed / clear_duration))
		await get_tree().process_frame
		elapsed += get_process_delta_time()

	_clear_children()

func _draw_static(density: float) -> void:
	_clear_children()
	var vp    = get_viewport().size
	var count := int(lerp(0.0, 220.0, density))
	var flick := int(lerp(0.0, 40.0, density))

	for i in count:
		var rect := ColorRect.new()
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rect.size = Vector2(
			_rng.randf_range(8.0,  lerp(20.0, 180.0, density)),
			_rng.randf_range(2.0,  lerp(8.0,  28.0,  density)))
		rect.position = Vector2(
			_rng.randf_range(-10.0, vp.x),
			_rng.randf_range(-5.0,  vp.y))
		rect.color = STATIC_COLORS[_rng.randi() % STATIC_COLORS.size()]
		if density > 0.6 and _rng.randf() < 0.12:
			rect.size.x  = vp.x
			rect.color.a = _rng.randf_range(0.15, 0.45)
		_container.add_child(rect)

	for i in flick:
		var line := ColorRect.new()
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.size = Vector2(vp.x * _rng.randf_range(0.2, 1.0), _rng.randf_range(1.0, 3.0))
		line.position = Vector2(
			_rng.randf_range(0.0, vp.x * 0.4),
			_rng.randf_range(0.0, vp.y))
		line.color = Color(1.0, 1.0, 1.0, _rng.randf_range(0.4, 0.9))
		_container.add_child(line)

# ------------------------------------------------------------------------------
#  FILM BURN
# ------------------------------------------------------------------------------

func _run_film_burn(on_peak: Callable) -> void:
	var elapsed := 0.0
	while elapsed < buildup_duration:
		_draw_film_burn(elapsed / buildup_duration, false)
		await get_tree().process_frame
		elapsed += get_process_delta_time()

	_draw_film_burn(1.0, false)
	on_peak.call()
	await get_tree().create_timer(hold_duration).timeout

	elapsed = 0.0
	while elapsed < clear_duration:
		_draw_film_burn(1.0 - (elapsed / clear_duration), true)
		await get_tree().process_frame
		elapsed += get_process_delta_time()

	_clear_children()

func _draw_film_burn(progress: float, clearing: bool) -> void:
	_clear_children()
	var vp = get_viewport().size

	var base := ColorRect.new()
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	base.set_anchors_preset(Control.PRESET_FULL_RECT)
	base.color = Color(0.04, 0.01, 0.0, minf(progress * 1.5, 1.0))
	_container.add_child(base)

	var blob_count := int(lerp(4.0, 55.0, progress))
	for i in blob_count:
		_rng.seed = i * 7919 + int(progress * 60.0)
		var cx := _rng.randf_range(0.0, vp.x)
		var cy := _rng.randf_range(0.0, vp.y)
		var radius := _rng.randf_range(lerp(10.0, 60.0, progress), lerp(40.0, 260.0, progress))
		var layers := [
			[1.00, Color(0.90, 0.30, 0.0,  clampf(progress * 0.55, 0.0, 0.55))],
			[0.65, Color(1.00, 0.65, 0.1,  clampf(progress * 0.75, 0.0, 0.75))],
			[0.35, Color(1.00, 0.95, 0.80, clampf(progress * 1.10, 0.0, 1.00))],
		]
		for layer in layers:
			var r   : float = radius * layer[0]
			var col : Color = layer[1]
			if clearing:
				r     *= (1.0 - progress * 0.6)
				col.a *= (1.0 - progress * 0.5)
			var blob := ColorRect.new()
			blob.mouse_filter = Control.MOUSE_FILTER_IGNORE
			blob.size     = Vector2(r * 2.0, r * 2.0)
			blob.position = Vector2(cx - r, cy - r)
			blob.color    = col
			_container.add_child(blob)

	if progress > 0.65:
		var white := ColorRect.new()
		white.mouse_filter = Control.MOUSE_FILTER_IGNORE
		white.set_anchors_preset(Control.PRESET_FULL_RECT)
		white.color = Color(1.0, 0.97, 0.90, (progress - 0.65) / 0.35)
		_container.add_child(white)

	var grain_count := int(lerp(0.0, 180.0, minf(progress * 1.5, 1.0)))
	for i in grain_count:
		var grain := ColorRect.new()
		grain.mouse_filter = Control.MOUSE_FILTER_IGNORE
		grain.size     = Vector2(_rng.randf_range(1.0, 4.0), _rng.randf_range(1.0, 4.0))
		grain.position = Vector2(_rng.randf_range(0.0, vp.x), _rng.randf_range(0.0, vp.y))
		grain.color    = Color(1.0, 0.85, 0.50, _rng.randf_range(0.2, 0.7))
		_container.add_child(grain)

# ------------------------------------------------------------------------------
#  BROKEN GLASS
# ------------------------------------------------------------------------------

func _run_broken_glass(on_peak: Callable) -> void:
	var vp = get_viewport().size

	# ── Step 1: Grab screenshot of the CURRENT scene before anything changes ──
	# Wait one frame so the viewport is fully rendered first.
	await get_tree().process_frame
	var screenshot_img := get_viewport().get_texture().get_image()
	var screenshot_tex := ImageTexture.create_from_image(screenshot_img)

	# ── Step 2: Swap the scene NOW — new scene loads underneath while we ───────
	# display the screenshot on top, so the player never sees a pop.
	on_peak.call()

	# ── Step 3: Place a full-screen copy of the screenshot on the canvas ──────
	# This hides the new scene while we draw cracks on top.
	var bg_rect := TextureRect.new()
	bg_rect.texture          = screenshot_tex
	bg_rect.stretch_mode     = TextureRect.STRETCH_SCALE
	bg_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg_rect.mouse_filter     = Control.MOUSE_FILTER_IGNORE
	bg_rect.z_index          = 1
	_container.add_child(bg_rect)

	# Impact point — slightly off-centre for drama
	var impact := Vector2(
		_rng.randf_range(vp.x * 0.30, vp.x * 0.70),
		_rng.randf_range(vp.y * 0.25, vp.y * 0.65))

	# Impact flash
	var flash := ColorRect.new()
	flash.size         = Vector2(28.0, 28.0)
	flash.pivot_offset = Vector2(14.0, 14.0)
	flash.position     = impact - Vector2(14.0, 14.0)
	flash.color        = Color(1.0, 0.95, 0.8, 0.0)
	flash.z_index      = 20
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_container.add_child(flash)

	# Generate crack network
	var crack_data := _glass_gen_cracks(impact, vp)

	# Build Line2D crack overlays (glow + sharp)
	var glow_lines  : Array = []
	var sharp_lines : Array = []
	for cd in crack_data:
		var glow := Line2D.new()
		glow.default_color = Color(0.85, 0.92, 1.0, 0.35)
		glow.width         = 5.0
		glow.z_index       = 8
		_container.add_child(glow)
		glow_lines.append(glow)

		var sharp := Line2D.new()
		sharp.default_color = Color(0.95, 0.98, 1.0, 0.95)
		sharp.width         = float(cd["width"])
		sharp.z_index       = 9
		_container.add_child(sharp)
		sharp_lines.append(sharp)

	# ── Phase 1: cracks grow over the screenshot ───────────────────────────────
	var elapsed := 0.0
	while elapsed < buildup_duration:
		var t := elapsed / buildup_duration
		flash.color.a = maxf(1.0 - t * 3.0, 0.0)

		for i in crack_data.size():
			var cd        = crack_data[i]
			var crack_t   := clampf((t - cd["delay"]) / maxf(1.0 - cd["delay"], 0.001), 0.0, 1.0)
			if crack_t <= 0.0:
				continue
			var pts := _glass_walk_line(cd["points"], crack_t)
			glow_lines[i].points  = pts
			sharp_lines[i].points = pts

		await get_tree().process_frame
		elapsed += get_process_delta_time()

	# All cracks fully drawn
	for i in crack_data.size():
		glow_lines[i].points  = PackedVector2Array(crack_data[i]["points"])
		sharp_lines[i].points = PackedVector2Array(crack_data[i]["points"])
	flash.color.a = 0.0

	await get_tree().create_timer(hold_duration).timeout

	# ── Phase 2: replace screenshot with textured shards, then remove bg ──────
	# Build shard polygons textured from the screenshot.
	var shard_nodes : Array = []
	var shard_vel   : Array = []
	var shard_rot   : Array = []
	_glass_gen_shards(impact, vp, crack_data, screenshot_tex,
					  shard_nodes, shard_vel, shard_rot)

	# Remove the flat screenshot — shards now cover the screen instead.
	bg_rect.queue_free()

	# Also hide cracks — they travel with the shards implicitly via the
	# shard edges, and separate crack lines look wrong once shards move.
	for l in glow_lines:
		l.queue_free()
	for l in sharp_lines:
		l.queue_free()

	# ── Phase 3: shards fall, revealing the new scene underneath ──────────────
	elapsed = 0.0
	while elapsed < clear_duration:
		var t  := elapsed / clear_duration
		var dt := get_process_delta_time()

		for i in shard_nodes.size():
			var sn = shard_nodes[i]
			if not is_instance_valid(sn):
				continue
			shard_vel[i].y    += 1100.0 * dt   # gravity
			sn.position       += shard_vel[i] * dt
			sn.rotation_degrees += shard_rot[i] * dt
			sn.modulate.a      = maxf(1.0 - t * 1.4, 0.0)

		await get_tree().process_frame
		elapsed += get_process_delta_time()

	_clear_children()

# ── Crack generation ───────────────────────────────────────────────────────────

func _glass_gen_cracks(impact: Vector2, vp: Vector2) -> Array:
	var cracks     : Array = []
	var num_primary := _rng.randi_range(7, 11)
	var base_angle  := _rng.randf() * TAU

	for i in num_primary:
		var angle := base_angle + (TAU / num_primary) * i + _rng.randf_range(-0.18, 0.18)
		var edge  := _glass_edge_point(impact, angle, vp)
		var pts   := _glass_jagged(impact, edge, 22.0)
		cracks.append({"points": pts, "delay": 0.0, "width": 2.2})

		var num_sec := _rng.randi_range(1, 3)
		for j in num_sec:
			var branch_t     := _rng.randf_range(0.25, 0.75)
			var branch_start := _glass_lerp_poly(pts, branch_t)
			var branch_angle := angle + _rng.randf_range(0.35, 0.75) * (1.0 if _rng.randf() > 0.5 else -1.0)
			var branch_edge  := _glass_edge_point(branch_start, branch_angle, vp)
			var branch_pts   := _glass_jagged(branch_start, branch_edge, 13.0)
			var delay        := _rng.randf_range(0.08, 0.35)
			cracks.append({"points": branch_pts, "delay": delay, "width": 1.4})

			if _rng.randf() < 0.45:
				var tert_t     := _rng.randf_range(0.3, 0.7)
				var tert_start := _glass_lerp_poly(branch_pts, tert_t)
				var tert_angle := branch_angle + _rng.randf_range(0.4, 0.9) * (1.0 if _rng.randf() > 0.5 else -1.0)
				var tert_edge  := _glass_edge_point(tert_start, tert_angle, vp)
				var tert_pts   := _glass_jagged(tert_start, tert_edge, 7.0)
				var tert_delay := delay + _rng.randf_range(0.05, 0.20)
				cracks.append({"points": tert_pts, "delay": clampf(tert_delay, 0.0, 0.9), "width": 1.0})

	return cracks

func _glass_jagged(a: Vector2, b: Vector2, jitter: float) -> Array:
	var pts  : Array = [a]
	var segs := _rng.randi_range(4, 8)
	var perp := (b - a).normalized().rotated(PI * 0.5)
	for i in range(1, segs):
		var t    := float(i) / segs
		var base := a.lerp(b, t)
		pts.append(base + perp * _rng.randf_range(-jitter, jitter))
	pts.append(b)
	return pts

func _glass_edge_point(origin: Vector2, angle: float, vp: Vector2) -> Vector2:
	var dir  := Vector2(cos(angle), sin(angle))
	var best := 9999.0
	if abs(dir.x) > 0.0001:
		var t := ((vp.x if dir.x > 0 else 0.0) - origin.x) / dir.x
		if t > 0.0:
			best = minf(best, t)
	if abs(dir.y) > 0.0001:
		var t := ((vp.y if dir.y > 0 else 0.0) - origin.y) / dir.y
		if t > 0.0:
			best = minf(best, t)
	return (origin + dir * best).clamp(Vector2.ZERO, vp)

func _glass_lerp_poly(pts: Array, t: float) -> Vector2:
	if pts.size() < 2:
		return pts[0] if not pts.is_empty() else Vector2.ZERO
	var total := 0.0
	for i in range(1, pts.size()):
		total += (pts[i] as Vector2).distance_to(pts[i - 1])
	var target := total * t
	var walked := 0.0
	for i in range(1, pts.size()):
		var d := (pts[i] as Vector2).distance_to(pts[i - 1])
		if walked + d >= target:
			return (pts[i - 1] as Vector2).lerp(pts[i], (target - walked) / maxf(d, 0.001))
		walked += d
	return pts[-1]

func _glass_walk_line(pts: Array, t: float) -> PackedVector2Array:
	if pts.is_empty():
		return PackedVector2Array()
	if t >= 1.0:
		var full := PackedVector2Array()
		for p in pts:
			full.append(p)
		return full
	var total := 0.0
	for i in range(1, pts.size()):
		total += (pts[i] as Vector2).distance_to(pts[i - 1])
	var target := total * t
	var walked := 0.0
	var out    := PackedVector2Array([pts[0]])
	for i in range(1, pts.size()):
		var d := (pts[i] as Vector2).distance_to(pts[i - 1])
		if walked + d >= target:
			var frac := (target - walked) / maxf(d, 0.001)
			out.append((pts[i - 1] as Vector2).lerp(pts[i], frac))
			break
		out.append(pts[i])
		walked += d
	return out

# ── Shard generation ───────────────────────────────────────────────────────────

func _glass_gen_shards(
		impact      : Vector2,
		vp          : Vector2,
		crack_data  : Array,
		screenshot  : ImageTexture,
		out_nodes   : Array,
		out_vel     : Array,
		out_rot     : Array) -> void:

	# Collect terminal points from all crack endpoints
	var terminals : Array = []
	for cd in crack_data:
		var pts = cd["points"]
		if not pts.is_empty():
			terminals.append(pts[-1])

	# Add screen corners so shards tile the full screen
	terminals.append(Vector2(0.0,  0.0))
	terminals.append(Vector2(vp.x, 0.0))
	terminals.append(Vector2(vp.x, vp.y))
	terminals.append(Vector2(0.0,  vp.y))

	# Deduplicate close points
	var unique : Array = []
	for p in terminals:
		var dup := false
		for u in unique:
			if (p as Vector2).distance_to(u) < 12.0:
				dup = true
				break
		if not dup:
			unique.append(p)
	terminals = unique

	# Sort by angle around impact so adjacent terminals form sensible triangles
	terminals.sort_custom(func(a, b):
		return (a - impact).angle() < (b - impact).angle())

	for i in terminals.size():
		var a : Vector2 = terminals[i]
		var b : Vector2 = terminals[(i + 1) % terminals.size()]

		# Skip slivers
		var area := absf((a - impact).cross(b - impact)) * 0.5
		if area < 200.0:
			continue

		# Slight inward offset so thin gaps appear between shards
		var ca := impact + (a - impact) * 0.97
		var cb := impact + (b - impact) * 0.97

		# Polygon2D with the screenshot texture.
		# UVs map each vertex's screen position directly onto the texture.
		var poly          := Polygon2D.new()
		poly.polygon       = PackedVector2Array([impact, ca, cb])
		poly.texture       = screenshot
		poly.uv            = PackedVector2Array([impact, ca, cb])
		poly.z_index       = 5
		_container.add_child(poly)
		out_nodes.append(poly)

		# Physics: outward drift from impact + downward bias
		var dir   := ((ca + cb) * 0.5 - impact).normalized()
		var speed := _rng.randf_range(80.0, 280.0)
		var vel   := Vector2(
			dir.x * speed * _rng.randf_range(0.3, 1.0) + _rng.randf_range(-40.0, 40.0),
			dir.y * speed * _rng.randf_range(0.2, 0.8) + _rng.randf_range(30.0, 140.0))
		out_vel.append(vel)
		out_rot.append(_rng.randf_range(-160.0, 160.0))

# ------------------------------------------------------------------------------
#  SHARED UTILITY
# ------------------------------------------------------------------------------

func _clear_children() -> void:
	for child in _container.get_children():
		child.queue_free()
