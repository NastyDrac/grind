extends Node2D
class_name MapGenerator

# ── Layout ─────────────────────────────────────────────────────────────────────
@export var columns        : int   = 7
@export var rows           : int   = 4
@export var node_spacing_x : float = 190.0
@export var node_spacing_y : float = 110.0
@export var left_margin    : float = 120.0
@export var top_margin     : float = 80.0

# ── Road appearance ────────────────────────────────────────────────────────────
## Width of the main road surface in pixels
@export var road_width     : float = 18.0
## Maximum depth of building strips extending from road edge
@export var building_depth : float = 30.0
## How much roads can bow — fraction of segment length
@export_range(0.0, 0.30) var road_curve_amount : float = 0.14

# ── Node type weights ──────────────────────────────────────────────────────────
@export_group("Node Weights – Early Columns")
@export var early_combat   : int = 4
@export var early_services : int = 2
@export var early_gym      : int = 2
@export var early_shop     : int = 1
@export var early_mystery  : int = 1
@export var early_hospital : int = 1
@export_group("Node Weights – Mid Columns")
@export var mid_combat   : int = 6
@export var mid_services : int = 1
@export var mid_gym      : int = 1
@export var mid_shop     : int = 1
@export var mid_mystery  : int = 1
@export var mid_hospital : int = 1
@export_group("")
@export var map_node_scene : PackedScene

# ── Signals ────────────────────────────────────────────────────────────────────
signal node_chosen(map_node)

# ── Runtime state ──────────────────────────────────────────────────────────────
var _rng          : RandomNumberGenerator
var _grid         : Array  = []
var _current_node : MapNode = null
var _all_nodes    : Array  = []
var _map_size     : Vector2

# ── Art data ───────────────────────────────────────────────────────────────────
var _buildings  : Array = []   # {poly: PackedVector2Array, dark: bool}
var _parks      : Array = []   # {poly: PackedVector2Array, dark: bool}
var _alley_lines: Array = []   # {a: Vector2, b: Vector2}  decorative cross-streets
var _creases    : Array = []
var _stains     : Array = []
var _grain      : Array = []

## {from: MapNode, to: MapNode, pts: Array[Vector2]}
## pts are the sampled cubic-bezier road centreline — ~28 points per edge.
var _path_edges : Array = []

# ── Scroll ─────────────────────────────────────────────────────────────────────
var _drag_active : bool    = false
var _drag_origin : Vector2 = Vector2.ZERO
var _map_origin  : Vector2 = Vector2.ZERO

# ── Palette ────────────────────────────────────────────────────────────────────
const C_PAPER := Color(0.616, 0.518, 0.347, 1.0)

# Road surface — colour baked INTO the map, no overlay
# The state is communicated by the road colour itself.
const C_ROAD_CURB      := Color(0.13, 0.10, 0.07, 1.0)  # kerb / casing ring
const C_ROAD_FUTURE    := Color(0.29, 0.25, 0.19, 1.0)  # locked: dark asphalt
const C_ROAD_REACHABLE := Color(0.73, 0.63, 0.37, 1.0)  # available: warm ochre
const C_ROAD_VISITED   := Color(0.85, 0.81, 0.68, 1.0)  # travelled: pale worn
const C_ROAD_EDGE      := Color(0.08, 0.06, 0.04, 0.55) # edge kerb stripe
const C_ROAD_DASH      := Color(0.70, 0.64, 0.48, 0.42) # centre-line dashes

# Junction pads — small circles where roads meet, always same colour family
const C_JNC_CURB       := Color(0.13, 0.10, 0.07, 1.0)
# Surface colour for junction is derived from the edge state at draw time

# Environment
const C_BLDG_A     := Color(0.80, 0.76, 0.70, 1.0)
const C_BLDG_B     := Color(0.61, 0.57, 0.51, 1.0)
const C_PARK_FILL  := Color(0.64, 0.79, 0.51, 1.0)
const C_PARK_DARK  := Color(0.43, 0.58, 0.32, 1.0)
const C_ALLEY_LINE := Color(0.24, 0.20, 0.15, 0.38)

# Weathering (drawn on top of everything — makes roads feel printed on paper)
const C_STAIN  := Color(0.325, 0.02, 0.0, 0.808)
const C_BORDER := Color(0.12, 0.10, 0.08)

# ─────────────────────────────────────────────────────────────────────────────
#  PUBLIC API
# ─────────────────────────────────────────────────────────────────────────────

func build(rng: RandomNumberGenerator) -> void:
	_rng = rng
	_clear_existing()
	_calculate_map_size()
	_gen_grain()
	# Game nodes first — their positions define the road network
	_generate_nodes()
	_generate_paths()          # bezier curves stored in _path_edges
	# City built outward from the road curves
	_gen_road_buildings()      # rotated building quads flush against each curved road
	_gen_block_fills()         # fill block interiors between adjacent road pairs
	_gen_alley_lines()         # thin decorative cross-streets between same-column nodes
	# Paper weathering on top of everything
	_gen_creases()
	_gen_stains()
	_set_reachable_column(0)
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_drag_active = true
				_drag_origin = get_global_mouse_position()
				_map_origin  = position
			else:
				_drag_active = false
	elif event is InputEventMouseMotion and _drag_active:
		position = _scroll_clamp(_map_origin + (get_global_mouse_position() - _drag_origin))

func _scroll_clamp(p: Vector2) -> Vector2:
	var vp := get_viewport_rect().size
	return Vector2(
		clampf(p.x, -(_map_size.x - vp.x * 0.5), vp.x * 0.5),
		clampf(p.y, -(_map_size.y - vp.y * 0.5), vp.y * 0.5))

func mark_visited_and_advance(chosen: MapNode) -> void:
	if not chosen: return
	_current_node       = chosen
	chosen.is_visited   = true
	chosen.is_reachable = false
	chosen.refresh()
	for node in _grid[chosen.col]:
		if node != chosen:
			node.is_reachable = false
			node.refresh()
	var nc := chosen.col + 1
	if nc < columns:
		for node in _grid[nc]:
			node.is_reachable = chosen.next_nodes.has(node)
			node.refresh()
	queue_redraw()

# ─────────────────────────────────────────────────────────────────────────────
#  DRAWING  — roads are part of the map, not an overlay
#  Order: paper → parks → buildings → roads → markings → junctions
#         → stains → creases → border
# ─────────────────────────────────────────────────────────────────────────────

func _draw() -> void:
	_draw_paper()
	_draw_parks()
	_draw_buildings()
	_draw_alley_lines()
	_draw_road_curbs()      # dark casing ring — drawn under everything road-related
	_draw_road_surfaces()   # state-coloured asphalt surface
	_draw_road_markings()   # edge kerb lines + centre dashes
	_draw_junctions()       # small intersection pads that knit roads together
	_draw_stains()
	_draw_creases()
	_draw_border()

# ── Paper ──────────────────────────────────────────────────────────────────────

func _draw_paper() -> void:
	draw_rect(Rect2(Vector2.ZERO, _map_size), C_PAPER)
	for g in _grain:
		draw_line(Vector2(0, g.y), Vector2(_map_size.x, g.y),
			Color(0, 0, 0, g.a), 1.0)

# ── Environment ────────────────────────────────────────────────────────────────

func _draw_buildings() -> void:
	for b in _buildings:
		var col := C_BLDG_B if b["dark"] else C_BLDG_A
		draw_colored_polygon(b["poly"], col)
		var pts : PackedVector2Array = b["poly"]
		for i in pts.size():
			draw_line(pts[i], pts[(i + 1) % pts.size()], Color(0, 0, 0, 0.20), 1.0)

func _draw_parks() -> void:
	for pk in _parks:
		var col := C_PARK_DARK if pk["dark"] else C_PARK_FILL
		draw_colored_polygon(pk["poly"], col)
		var pts : PackedVector2Array = pk["poly"]
		for i in pts.size():
			draw_line(pts[i], pts[(i + 1) % pts.size()],
				Color(C_PARK_DARK.r, C_PARK_DARK.g, C_PARK_DARK.b, 0.55), 1.0)

func _draw_alley_lines() -> void:
	for al in _alley_lines:
		draw_line(al["a"], al["b"], C_ALLEY_LINE, 1.5)

# ── Road network ───────────────────────────────────────────────────────────────
# Three separate passes so overlapping roads blend cleanly at intersections.

func _draw_road_curbs() -> void:
	## Wide dark casing under every road — forms the kerb ring.
	for e in _path_edges:
		draw_polyline(e["pts_packed"], C_ROAD_CURB, road_width + 7.0, true)

func _draw_road_surfaces() -> void:
	## Asphalt surface, coloured by traversal state.
	for e in _path_edges:
		draw_polyline(e["pts_packed"], _road_surface_colour(e), road_width, true)

func _road_surface_colour(e: Dictionary) -> Color:
	var f : MapNode = e["from"]
	var t : MapNode = e["to"]
	if f.is_visited and t.is_visited:    return C_ROAD_VISITED
	if f.is_visited and t.is_reachable:  return C_ROAD_REACHABLE
	return C_ROAD_FUTURE

func _draw_road_markings() -> void:
	## Thin edge kerb lines on both sides + dashed centre line.
	for e in _path_edges:
		var pts  : Array = e["pts"]
		var half := road_width * 0.5 - 1.5
		var left_pts  := PackedVector2Array()
		var right_pts := PackedVector2Array()
		for i in pts.size():
			var n := _pts_normal(pts, i)
			left_pts.append(pts[i]  + n * half)
			right_pts.append(pts[i] - n * half)
		draw_polyline(left_pts,  C_ROAD_EDGE, 1.2, true)
		draw_polyline(right_pts, C_ROAD_EDGE, 1.2, true)

	## Centre dashes — accumulate arc length across bezier samples.
	for e in _path_edges:
		var pts : Array = e["pts"]
		var arc     := 0.0
		var dash    := 7.0
		var gap     := 11.0
		var cycle   := gap   # start after a gap so dashes don't begin on nodes
		for i in range(pts.size() - 1):
			var seg_len = (pts[i + 1] - pts[i]).length()
			if seg_len < 0.01: continue
			var dir = (pts[i + 1] - pts[i]) / seg_len
			var t   := 0.0
			while t < seg_len:
				var remaining = seg_len - t
				var slot      := fmod(arc + t, dash + gap)
				if slot < dash:
					var dt = min(dash - slot, remaining)
					draw_line(pts[i] + dir * t, pts[i] + dir * (t + dt),
						C_ROAD_DASH, 1.5, true)
					t += dt
				else:
					var dt = min(dash + gap - slot, remaining)
					t += dt
			arc += seg_len

func _draw_junctions() -> void:
	## Small circles at each node centre so roads knit together seamlessly.
	## The fill colour tracks the node's reachability state.
	for node in _all_nodes:
		var c    := _node_centre(node)
		var r    := road_width * 0.5 + 3.5
		var surf := C_ROAD_FUTURE
		if node.is_visited:   surf = C_ROAD_VISITED
		elif node.is_reachable: surf = C_ROAD_REACHABLE
		draw_circle(c, r + 3.5, C_JNC_CURB)
		draw_circle(c, r,       surf)

# ── Weathering — drawn over roads to embed them in the paper ──────────────────

func _draw_stains() -> void:
	for s in _stains:
		for j in range(6):
			var angle := j * TAU / 6.0
			var off   = Vector2(cos(angle), sin(angle)) * s["r"] * s["spread_" + str(j)]
			draw_circle(s["pos"] + off, s["r"] * s["scale_" + str(j)],
				Color(C_STAIN.r, C_STAIN.g, C_STAIN.b, s["a"] * s["alpha_" + str(j)]))

func _draw_creases() -> void:
	for c in _creases:
		var pa : Vector2 = c["a"]; var pb : Vector2 = c["b"]
		var perp  := (pb - pa).normalized().rotated(PI * 0.5)
		var reach := 18.0
		var sc    := Color(0.07, 0.05, 0.03, 0.40)
		var scl   := Color(0.07, 0.05, 0.03, 0.00)
		draw_polygon(PackedVector2Array([pa, pb, pb + perp * reach, pa + perp * reach]),
			PackedColorArray([sc, sc, scl, scl]))
		draw_line(pa, pb, Color(0.88, 0.85, 0.78, 0.65), c["w"] + 1.0)
		draw_line(pa - perp, pb - perp, Color(0.12, 0.10, 0.07, 0.50), 1.0)

func _draw_border() -> void:
	draw_rect(Rect2(Vector2.ZERO, _map_size), C_BORDER, false, 2.5)
	for i in range(6):
		var d := float(i) * 5.0
		draw_rect(Rect2(d, d, _map_size.x - d * 2, _map_size.y - d * 2),
			Color(0, 0, 0, 0.07 - i * 0.011), false, 2.0)

# ─────────────────────────────────────────────────────────────────────────────
#  BACKGROUND GENERATION  — city built from road curves outward
# ─────────────────────────────────────────────────────────────────────────────

func _gen_road_buildings() -> void:
	## For each curved road, generate building quads aligned to the local road
	## direction at each point — so buildings physically follow the curve.
	var clear := road_width * 0.5 + 4.0

	for e in _path_edges:
		var pts : Array = e["pts"]
		if pts.size() < 4: continue

		for side in [-1, 1]:
			var is_park := _rng.randf() < 0.18
			var idx     := 1   # skip the node itself
			while idx < pts.size() - 2:
				# Decide building length in number of bezier samples
				var span := _rng.randi_range(3, 9)
				var end  := mini(idx + span, pts.size() - 2)
				if end <= idx: break

				var bdep := _rng.randf_range(8.0, building_depth)
				var poly := _road_strip_poly(pts, idx, end, side, clear, clear + bdep)
				if poly.size() >= 4:
					if is_park:
						_parks.append({"poly": poly, "dark": _rng.randf() < 0.25})
					else:
						_buildings.append({"poly": poly, "dark": _rng.randf() < 0.28})

				# Gap between buildings (0–2 samples)
				idx = end + _rng.randi_range(0, 2)

func _gen_block_fills() -> void:
	## Fill the interior space between pairs of adjacent parallel roads
	## with small axis-aligned building rectangles (checked for road clearance).
	var clear := road_width * 0.5 + 9.0

	for c in range(columns - 1):
		var cur = _grid[c].duplicate()
		var nxt = _grid[c + 1].duplicate()
		cur.sort_custom(func(a, b): return _node_centre(a).y < _node_centre(b).y)
		nxt.sort_custom(func(a, b): return _node_centre(a).y < _node_centre(b).y)

		for i in range(mini(cur.size(), nxt.size()) - 1):
			var corners := [
				_node_centre(cur[i]),
				_node_centre(nxt[i % nxt.size()]),
				_node_centre(nxt[(i + 1) % nxt.size()]),
				_node_centre(cur[i + 1])
			]
			var min_x = corners[0].x; var max_x = corners[0].x
			var min_y = corners[0].y; var max_y = corners[0].y
			for p in corners:
				min_x = min(min_x, p.x); max_x = max(max_x, p.x)
				min_y = min(min_y, p.y); max_y = max(max_y, p.y)
			min_x += clear; max_x -= clear
			min_y += clear; max_y -= clear
			if max_x - min_x < 18.0 or max_y - min_y < 18.0: continue

			var y = min_y
			while y < max_y:
				var bh := _rng.randf_range(7.0, 18.0)
				var x  = min_x
				while x < max_x:
					var bw  := _rng.randf_range(9.0, 24.0)
					if x + bw > max_x: break
					var ctr := Vector2(x + bw * 0.5, y + bh * 0.5)
					if _clear_of_roads(ctr, clear * 0.72):
						_buildings.append({
							"poly": PackedVector2Array([
								Vector2(x, y), Vector2(x + bw, y),
								Vector2(x + bw, y + bh), Vector2(x, y + bh)]),
							"dark": _rng.randf() < 0.28})
					x += bw + _rng.randf_range(2.0, 5.0)
				y += bh + _rng.randf_range(2.0, 5.0)

func _gen_alley_lines() -> void:
	## Thin cross-street lines connecting same-column nodes.
	## These form the vertical skeleton of the city grid without being player paths.
	_alley_lines = []
	for c in range(columns):
		var col = _grid[c].duplicate()
		col.sort_custom(func(a, b): return _node_centre(a).y < _node_centre(b).y)
		for i in range(col.size() - 1):
			var a := _node_centre(col[i])
			var b := _node_centre(col[i + 1])
			# Gently curved alley using a single quad bezier
			var mid  := (a + b) * 0.5
			var perp := (b - a).normalized().rotated(PI * 0.5)
			var ctrl := mid + perp * _rng.randf_range(-15.0, 15.0)
			var al_pts := _quad_bezier_pts(a, b, ctrl, 14)
			for j in range(al_pts.size() - 1):
				_alley_lines.append({"a": al_pts[j], "b": al_pts[j + 1]})

# ─────────────────────────────────────────────────────────────────────────────
#  CURVE & GEOMETRY HELPERS
# ─────────────────────────────────────────────────────────────────────────────

func _cubic_bezier_pts(a: Vector2, b: Vector2, c1: Vector2, c2: Vector2,
		steps: int = 28) -> Array:
	var pts := []
	for i in range(steps + 1):
		var t  := float(i) / steps
		var mt := 1.0 - t
		pts.append(mt*mt*mt*a + 3.0*mt*mt*t*c1 + 3.0*mt*t*t*c2 + t*t*t*b)
	return pts

func _quad_bezier_pts(a: Vector2, b: Vector2, ctrl: Vector2,
		steps: int = 14) -> Array:
	var pts := []
	for i in range(steps + 1):
		var t  := float(i) / steps
		var mt := 1.0 - t
		pts.append(mt*mt*a + 2.0*mt*t*ctrl + t*t*b)
	return pts

## Outward-facing normal at sample index i along a pts array.
func _pts_normal(pts: Array, i: int) -> Vector2:
	var p0 = pts[max(i - 1, 0)]
	var p1 = pts[mini(i + 1, pts.size() - 1)]
	var t  = p1 - p0
	if t.length_squared() < 0.001: return Vector2(0, 1)
	return t.normalized().rotated(PI * 0.5)

## Build a quad polygon by walking a strip of pts[i_start..i_end], offset to
## near/far on the given side.  Returns near-edge forward then far-edge reversed
## for a correctly wound polygon.
func _road_strip_poly(pts: Array, i_start: int, i_end: int,
		side: int, near: float, far: float) -> PackedVector2Array:
	var near_pts := PackedVector2Array()
	var far_pts  := PackedVector2Array()
	for i in range(i_start, i_end + 1):
		var n := _pts_normal(pts, i)
		near_pts.append(pts[i] + n * (side * near))
		far_pts.append( pts[i] + n * (side * far))
	var poly := PackedVector2Array()
	for p in near_pts: poly.append(p)
	far_pts.reverse()
	for p in far_pts: poly.append(p)
	return poly

## True if point p is further than min_dist from every road centreline.
func _clear_of_roads(p: Vector2, min_dist: float) -> bool:
	for e in _path_edges:
		var pts : Array = e["pts"]
		for i in range(pts.size() - 1):
			if _dist_pt_seg(p, pts[i], pts[i + 1]) < min_dist:
				return false
	return true

func _dist_pt_seg(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab     := b - a
	var len_sq := ab.dot(ab)
	if len_sq < 0.001: return p.distance_to(a)
	return p.distance_to(a + ab * clampf((p - a).dot(ab) / len_sq, 0.0, 1.0))

# ─────────────────────────────────────────────────────────────────────────────
#  NODE & PATH GENERATION
# ─────────────────────────────────────────────────────────────────────────────

func _calculate_map_size() -> void:
	_map_size = Vector2(
		left_margin + (columns - 1) * node_spacing_x + left_margin,
		top_margin  + (rows   - 1) * node_spacing_y  + top_margin)

func _generate_nodes() -> void:
	_grid = []; _all_nodes = []
	var hcol     := node_spacing_x * 0.30  # reduced jitter — columns stay readable
	var boss_col := columns - 1

	for c in range(columns):
		var col_arr : Array = []
		if c == boss_col:
			var boss = _create_node(MapNode.NodeType.BOSS, c, 0)
			var half = MapNode.BOSS_NODE_RADIUS + 4.0
			boss.position = Vector2(
				left_margin + c * node_spacing_x - half,
				_map_size.y * 0.5 - half)
			add_child(boss); col_arr.append(boss); _all_nodes.append(boss)
		else:
			for r in range(rows):
				var node := _create_node(_pick_node_type(c), c, r)
				var pos := Vector2(
					left_margin + c * node_spacing_x
						+ _rng.randf_range(-hcol * 0.4, hcol * 0.4),
					top_margin + r * node_spacing_y
						+ _rng.randf_range(-node_spacing_y * 0.20, node_spacing_y * 0.20))
				node.position = pos - Vector2(MapNode.NODE_RADIUS + 4, MapNode.NODE_RADIUS + 4)
				add_child(node); col_arr.append(node); _all_nodes.append(node)
		_grid.append(col_arr)

func _create_node(ntype: MapNode.NodeType, c: int, r: int) -> MapNode:
	var node : MapNode = map_node_scene.instantiate() if map_node_scene else MapNode.new()
	node.node_type = ntype; node.col = c; node.row = r
	node.next_nodes = []; node.is_visited = false; node.is_reachable = false
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.node_selected.connect(_on_node_selected)
	return node

func _generate_paths() -> void:
	_path_edges = []
	for c in range(columns - 1):
		var cur = _grid[c].duplicate()
		var nxt = _grid[c + 1].duplicate()
		cur.sort_custom(func(a, b): return _node_centre(a).y < _node_centre(b).y)
		nxt.sort_custom(func(a, b): return _node_centre(a).y < _node_centre(b).y)
		for i in range(cur.size()):
			_add_edge(cur[i], nxt[i % nxt.size()])
		for i in range(cur.size()):
			if _rng.randf() < 0.38:
				var offset := 1 if _rng.randf() < 0.5 else -1
				_add_edge(cur[i], nxt[clampi(i + offset, 0, nxt.size() - 1)])

func _add_edge(a: MapNode, b: MapNode) -> void:
	if a.next_nodes.has(b): return
	a.next_nodes.append(b)

	var ca  := _node_centre(a)
	var cb  := _node_centre(b)
	var dir := (cb - ca).normalized()
	var per := dir.rotated(PI * 0.5)
	var d   := ca.distance_to(cb)
	var bow := d * road_curve_amount

	# Two independent control points — mix of C-curves and gentle S-curves
	var c1 := ca + dir * d * 0.30 + per * _rng.randf_range(-bow, bow)
	var c2 := cb - dir * d * 0.30 + per * _rng.randf_range(-bow, bow)

	var pts := _cubic_bezier_pts(ca, cb, c1, c2, 28)
	_path_edges.append({
		"from": a, "to": b,
		"pts": pts,
		"pts_packed": PackedVector2Array(pts)  # pre-packed for draw_polyline
	})

func _pick_node_type(col: int) -> MapNode.NodeType:
	var w := [early_combat, early_services, early_gym, early_shop,
			  early_hospital, early_mystery] if col < columns / 2 else \
			 [mid_combat, mid_services, mid_gym, mid_shop,
			  mid_hospital, mid_mystery]
	var total := 0; for v in w: total += v
	if total == 0: return MapNode.NodeType.COMBAT
	var roll := _rng.randi_range(0, total - 1); var accum := 0
	for i in range(w.size()):
		accum += w[i]
		if roll < accum: return i as MapNode.NodeType
	return MapNode.NodeType.COMBAT

func _set_reachable_column(col: int) -> void:
	if col >= columns: return
	for node in _grid[col]:
		node.is_reachable = true; node.refresh()

func _node_centre(n: MapNode) -> Vector2:
	var r    := MapNode.BOSS_NODE_RADIUS if n.node_type == MapNode.NodeType.BOSS \
			   else MapNode.NODE_RADIUS
	return n.position + Vector2(r + 4.0, r + 4.0)

func _clear_existing() -> void:
	for node in _all_nodes: node.queue_free()
	_all_nodes   = []; _grid       = []
	_buildings   = []; _parks      = []
	_alley_lines = []; _creases    = []
	_stains      = []; _grain      = []
	_path_edges  = []
	_current_node = null

# ─────────────────────────────────────────────────────────────────────────────
#  GRAIN / CREASES / STAINS
# ─────────────────────────────────────────────────────────────────────────────

func _gen_grain() -> void:
	_grain = []
	var y := 0.0
	while y < _map_size.y:
		if _rng.randf() < 0.40:
			_grain.append({"y": y, "a": _rng.randf_range(0.005, 0.018)})
		y += 3.0

func _gen_creases() -> void:
	_creases = []
	for _i in range(_rng.randi_range(1, 3)):
		var fy := _rng.randf_range(0.1, 0.9) * _map_size.y
		_creases.append({"a": Vector2(0, fy + _rng.randf_range(-3, 3)),
						  "b": Vector2(_map_size.x, fy + _rng.randf_range(-3, 3)),
						  "w": _rng.randf_range(1.0, 2.2)})
	for _i in range(_rng.randi_range(0, 2)):
		var fx := _rng.randf_range(0.2, 0.8) * _map_size.x
		_creases.append({"a": Vector2(fx, 0),
						  "b": Vector2(fx + _rng.randf_range(-5, 5), _map_size.y),
						  "w": _rng.randf_range(1.0, 1.8)})

func _gen_stains() -> void:
	_stains = []
	for _i in range(_rng.randi_range(25, 35)):
		var entry := {
			"pos": Vector2(_rng.randf_range(0, _map_size.x),
						   _rng.randf_range(0, _map_size.y)),
			"r": _rng.randf_range(20, 85), "a": _rng.randf_range(0.03, 0.14)}
		for j in range(6):
			entry["spread_" + str(j)] = _rng.randf_range(0.1, 0.5)
			entry["scale_"  + str(j)] = _rng.randf_range(0.4, 1.0)
			entry["alpha_"  + str(j)] = _rng.randf_range(0.3, 1.0)
		_stains.append(entry)

# ─────────────────────────────────────────────────────────────────────────────
#  SIGNAL HANDLER
# ─────────────────────────────────────────────────────────────────────────────

func _on_node_selected(map_node: MapNode) -> void:
	if map_node.is_visited: return
	node_chosen.emit(map_node)
