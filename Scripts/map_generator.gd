extends Node2D
class_name MapGenerator

# ── Layout ────────────────────────────────────────────────────────────────────
@export var columns        : int   = 7
@export var rows           : int   = 4
@export var node_spacing_x : float = 190.0
@export var node_spacing_y : float = 110.0
@export var left_margin    : float = 120.0
@export var top_margin     : float = 80.0

# ── Road network ──────────────────────────────────────────────────────────────
@export var road_grid_cols : int = 10
@export var road_grid_rows : int = 8

# ── Urban feel ────────────────────────────────────────────────────────────────
## 0.0 = rural  →  1.0 = dense city
@export_range(0.0, 1.0) var urban_density    : float = 0.75
## How tightly buildings pack to the road edge
@export_range(0.1, 1.0) var building_coverage: float = 0.65 

# ── Node type weights ─────────────────────────────────────────────────────────
@export_group("Node Weights – Early Columns")
@export var early_combat   : int = 4
@export var early_services : int = 2
@export var early_gym : int = 2
@export var early_shop : int = 1
@export var early_mystery  : int = 1
@export var early_hospital : int = 1
@export_group("Node Weights – Mid Columns")
@export var mid_combat   : int = 6
@export var mid_services : int = 1
@export var mid_gym : int = 1
@export var mid_shop : int = 1
@export var mid_mystery  : int = 1
@export var mid_hospital : int = 1
@export_group("")
@export var map_node_scene : PackedScene

# ── Signals ───────────────────────────────────────────────────────────────────
signal node_chosen(map_node)

# ── Runtime state ─────────────────────────────────────────────────────────────
var _rng          : RandomNumberGenerator
var _grid         : Array = []
var _current_node : MapNode = null
var _all_nodes    : Array  = []
var _map_size     : Vector2

# ── Art data  (built once in build(), read every _draw()) ──────────────────────
var _junctions  : Array = []   # [c][r] → Vector2
var _arteries   : Array = []   # {a, b, w}
var _streets    : Array = []   # {a, b}
var _buildings  : Array = []   # {rect, dark}
var _parks      : Array = []   # {poly, dark}
var _lots       : Array = []   # {rect}
var _creases    : Array = []   # {a, b, w}
var _stains     : Array = []   # {pos, r, a}
var _grain      : Array = []   # {y, a}  pre-baked paper grain lines

## Pre-computed game path edges. Each entry: {from: MapNode, to: MapNode, pts: Array[Vector2]}
## pts holds the 4 waypoints of the L-shaped route: start → h-bend → v-bend → end.
var _path_edges : Array = []

# ── Scroll state ──────────────────────────────────────────────────────────────
var _drag_active : bool    = false
var _drag_origin : Vector2 = Vector2.ZERO   # mouse pos when drag started
var _map_origin  : Vector2 = Vector2.ZERO   # map position when drag started

# ── Palette ───────────────────────────────────────────────────────────────────
const C_PAPER        := Color(0.616, 0.518, 0.347, 1.0)
const C_BLDG_A       := Color(0.75, 0.72, 0.68)
const C_BLDG_B       := Color(0.62, 0.59, 0.55)
const C_PARK_FILL    := Color(0.79, 0.87, 0.72)
const C_PARK_DARK    := Color(0.487, 0.586, 0.415, 1.0)
const C_LOT_FILL     := Color(0.88, 0.86, 0.82)
const C_STREET_LINE  := Color(0.30, 0.27, 0.23)
const C_ART_CASE     := Color(0.18, 0.15, 0.12)
const C_ART_FILL     := Color(0.793, 0.702, 0.517, 1.0)
const C_CREASE       := Color(0.50, 0.46, 0.41, 0.80)
const C_STAIN        := Color(0.325, 0.02, 0.0, 0.808)
const C_BORDER       := Color(0.12, 0.10, 0.08)

# Route colours — the game overlay drawn on top of the city map
const C_ROUTE_GLOW    := Color(0.20, 0.55, 1.00, 0.20)  # soft halo
const C_ROUTE_CASE    := Color(0.08, 0.28, 0.65, 1.00)  # dark outline
const C_ROUTE_FILL    := Color(0.502, 0.553, 1.0, 1.0)  # light surface
const C_ROUTE_VISITED := Color(1.0, 1.0, 1.0, 1.0)  # already travelled
const C_ROUTE_OFF     := Color(0.0, 0.0, 0.0, 1.0)  # future / not yet reachable

# ─────────────────────────────────────────────────────────────────────────────
#  PUBLIC API
# ─────────────────────────────────────────────────────────────────────────────

func build(rng: RandomNumberGenerator) -> void:
	_rng = rng
	_clear_existing()
	_calculate_map_size()
	# Background art  (all RNG calls happen here, never inside _draw)
	_gen_grain()
	_gen_junctions()
	_gen_arteries()
	_gen_streets()
	_gen_block_fills()
	_gen_creases()
	_gen_stains()
	# Game layer
	_generate_nodes()
	_generate_paths()        # assigns connections AND pre-bakes path waypoints
	_set_reachable_column(0)
	queue_redraw()

## Drag the map by holding left mouse button.
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
		var delta = get_global_mouse_position() - _drag_origin
		position  = _scroll_clamp(_map_origin + delta)

## Clamp so the map can't be dragged completely off screen.
func _scroll_clamp(p: Vector2) -> Vector2:
	var vp   := get_viewport_rect().size
	# Allow dragging until the far edge of the map just touches the viewport edge.
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
#  DRAWING  — zero RNG calls here; everything reads pre-built data arrays
# ─────────────────────────────────────────────────────────────────────────────

func _draw() -> void:
	_draw_paper()
	_draw_lots()
	_draw_parks()
	_draw_buildings()
	_draw_streets()
	_draw_arteries()
	_draw_stains()
	_draw_creases()
	_draw_border()
	_draw_routes()

# ── Paper ─────────────────────────────────────────────────────────────────────

func _draw_paper() -> void:
	draw_rect(Rect2(Vector2.ZERO, _map_size), C_PAPER)
	for g in _grain:
		draw_line(Vector2(0, g["y"]), Vector2(_map_size.x, g["y"]),
			Color(0, 0, 0, g["a"]), 1.0)

# ── Block content ─────────────────────────────────────────────────────────────

func _draw_lots() -> void:
	for lot in _lots:
		draw_rect(lot["rect"], C_LOT_FILL)
		var r : Rect2 = lot["rect"]
		if r.size.x > 20:
			var sx := r.position.x + 8.0
			while sx < r.end.x - 4:
				draw_line(Vector2(sx, r.position.y), Vector2(sx, r.end.y),
					Color(0.5, 0.48, 0.44, 0.35), 1.0)
				sx += 8.0

func _draw_parks() -> void:
	for pk in _parks:
		draw_colored_polygon(pk["poly"], C_PARK_DARK if pk["dark"] else C_PARK_FILL)
		var pts : PackedVector2Array = pk["poly"]
		for i in range(pts.size()):
			draw_line(pts[i], pts[(i + 1) % pts.size()],
				Color(C_PARK_DARK.r, C_PARK_DARK.g, C_PARK_DARK.b, 0.50), 1.0)

func _draw_buildings() -> void:
	for b in _buildings:
		var r : Rect2 = b["rect"]
		draw_rect(r, C_BLDG_B if b["dark"] else C_BLDG_A)
		draw_line(r.position + Vector2(r.size.x, 1), r.end, Color(0, 0, 0, 0.18), 1.0)
		draw_line(r.position + Vector2(1, r.size.y), r.end, Color(0, 0, 0, 0.18), 1.0)

# ── Road network ──────────────────────────────────────────────────────────────

func _draw_streets() -> void:
	for s in _streets:
		draw_line(s["a"], s["b"], C_STREET_LINE, 1.2)

func _draw_arteries() -> void:
	for a in _arteries:
		draw_line(a["a"], a["b"], C_ART_CASE, a["w"] + 3.0)
	for a in _arteries:
		draw_line(a["a"], a["b"], C_ART_FILL, a["w"])

# ── Weathering ────────────────────────────────────────────────────────────────

func _draw_stains() -> void:
	for s in _stains:
		for j in range(6):
			# Use deterministic offsets based on index rather than live RNG
			var angle := j * TAU / 6.0
			var off   = Vector2(cos(angle), sin(angle)) * s["r"] * s["spread_" + str(j)]
			draw_circle(s["pos"] + off, s["r"] * s["scale_" + str(j)],
				Color(C_STAIN.r, C_STAIN.g, C_STAIN.b, s["a"] * s["alpha_" + str(j)]))

func _draw_creases() -> void:
	for c in _creases:
		var pa : Vector2 = c["a"]
		var pb : Vector2 = c["b"]
		var perp  := (pb - pa).normalized().rotated(PI * 0.5)
		var reach := 18.0   # how many pixels the shadow fans out

		# ── Shadow gradient quad ─────────────────────────────────────────────
		# A polygon whose two vertices at the fold are dark and whose two
		# vertices at the far edge are fully transparent.
		# Godot interpolates vertex colours across the face → true gradient.
		var shadow_col   := Color(0.07, 0.05, 0.03, 0.40)
		var shadow_clear := Color(0.07, 0.05, 0.03, 0.00)

		var quad := PackedVector2Array([
			pa,
			pb,
			pb + perp * reach,
			pa + perp * reach,
		])
		var cols := PackedColorArray([
			shadow_col,    # fold start  – dark
			shadow_col,    # fold end    – dark
			shadow_clear,  # far end     – transparent
			shadow_clear,  # far start   – transparent
		])
		draw_polygon(quad, cols)

		# ── Lit paper edge (fold peak catches light) ─────────────────────────
		draw_line(pa, pb, Color(0.88, 0.85, 0.78, 0.65), c["w"] + 1.0)

		# ── Dark compressed-fibre line just behind the peak ──────────────────
		draw_line(pa - perp * 1.0, pb - perp * 1.0,
			Color(0.12, 0.10, 0.07, 0.50), 1.0)

func _draw_border() -> void:
	draw_rect(Rect2(Vector2.ZERO, _map_size), C_BORDER, false, 2.5)
	for i in range(6):
		var d := float(i) * 5.0
		draw_rect(Rect2(d, d, _map_size.x - d * 2, _map_size.y - d * 2),
			Color(0, 0, 0, 0.07 - i * 0.011), false, 2.0)

# ── Game route overlay ────────────────────────────────────────────────────────
# Three draw passes so casing and fill are consistent regardless of draw order.

func _draw_routes() -> void:
	# Pass 0 – wide soft glow behind active/reachable routes only
	for e in _path_edges:
		if e["from"].is_visited and (e["to"].is_visited or e["to"].is_reachable):
			_draw_route_pts(e["pts"], C_ROUTE_GLOW, 20.0)

	# Pass 1 – dark casing for all edges (future paths at low alpha via C_ROUTE_OFF)
	for e in _path_edges:
		var col := _route_colour(e["from"], e["to"])
		_draw_route_pts(e["pts"], col.darkened(0.5), 9.0)

	# Pass 2 – light surface for all edges
	for e in _path_edges:
		var col := _route_colour(e["from"], e["to"])
		_draw_route_pts(e["pts"], col, 4.0)

## Draw the pre-computed waypoint list as connected line segments.
func _draw_route_pts(pts: Array, col: Color, w: float) -> void:
	for i in range(pts.size() - 1):
		draw_line(pts[i], pts[i + 1], col, w, true)

func _route_colour(a: MapNode, b: MapNode) -> Color:
	if a.is_visited and b.is_visited:    return C_ROUTE_VISITED
	if a.is_visited and b.is_reachable:  return C_ROUTE_FILL
	if a.is_visited:                     return C_ROUTE_VISITED.darkened(0.3)
	return C_ROUTE_OFF

# ─────────────────────────────────────────────────────────────────────────────
#  BACKGROUND ART GENERATION
# ─────────────────────────────────────────────────────────────────────────────

func _gen_grain() -> void:
	_grain = []
	var y := 0.0
	while y < _map_size.y:
		if _rng.randf() < 0.40:
			_grain.append({"y": y, "a": _rng.randf_range(0.005, 0.018)})
		y += 3.0

func _gen_junctions() -> void:
	_junctions = []
	var gc := road_grid_cols
	var gr := road_grid_rows
	var cw := _map_size.x / gc
	var ch := _map_size.y / gr
	var jx := cw * 0.25
	var jy := ch * 0.25
	for c in range(gc + 1):
		var col_arr : Array = []
		for r in range(gr + 1):
			var on_h := (c == 0 or c == gc)
			var on_v := (r == 0 or r == gr)
			col_arr.append(Vector2(
				clampf(c * cw + (0.0 if on_h else _rng.randf_range(-jx, jx)), 2.0, _map_size.x - 2.0),
				clampf(r * ch + (0.0 if on_v else _rng.randf_range(-jy, jy)), 2.0, _map_size.y - 2.0)))
		_junctions.append(col_arr)

func _gen_arteries() -> void:
	_arteries = []
	var gc := road_grid_cols
	var gr := road_grid_rows
	for c in range(gc + 1):
		for r in range(gr + 1):
			var p : Vector2 = _junctions[c][r]
			if c < gc:
				_arteries.append({"a": p, "b": _junctions[c + 1][r], "w": _rng.randf_range(2.5, 6.0)})
			if r < gr:
				_arteries.append({"a": p, "b": _junctions[c][r + 1], "w": _rng.randf_range(2.5, 6.0)})
			if c < gc and r < gr:
				if _rng.randf() < 0.18:
					_arteries.append({"a": p, "b": _junctions[c+1][r+1], "w": _rng.randf_range(1.5, 3.5)})
				if _rng.randf() < 0.10:
					_arteries.append({"a": _junctions[c+1][r], "b": _junctions[c][r+1], "w": _rng.randf_range(1.5, 3.0)})

func _gen_streets() -> void:
	_streets = []
	var gc := road_grid_cols
	var gr := road_grid_rows
	var min_d := 1 if urban_density < 0.3 else (2 if urban_density < 0.6 else 3)
	var max_d := 2 if urban_density < 0.3 else (4 if urban_density < 0.6 else 6)
	for c in range(gc):
		for r in range(gr):
			var tl = _junctions[c    ][r    ]
			var tr = _junctions[c + 1][r    ]
			var br = _junctions[c + 1][r + 1]
			var bl = _junctions[c    ][r + 1]
			for i in range(1, _rng.randi_range(min_d, max_d)):
				var t    := float(i) / _rng.randi_range(min_d, max_d)
				var from = tl.lerp(bl, t)
				var to   = tr.lerp(br, t)
				var mid  = from.lerp(to, 0.5) + Vector2(_rng.randf_range(-4, 4), _rng.randf_range(-3, 3))
				_streets.append({"a": from, "b": mid})
				_streets.append({"a": mid,  "b": to })
			for i in range(1, _rng.randi_range(min_d, max_d)):
				var t    := float(i) / _rng.randi_range(min_d, max_d)
				var from = tl.lerp(tr, t)
				var to   = bl.lerp(br, t)
				var mid  = from.lerp(to, 0.5) + Vector2(_rng.randf_range(-3, 3), _rng.randf_range(-4, 4))
				_streets.append({"a": from, "b": mid})
				_streets.append({"a": mid,  "b": to })

func _gen_block_fills() -> void:
	_buildings = []; _parks = []; _lots = []
	var gc := road_grid_cols
	var gr := road_grid_rows
	for c in range(gc):
		for r in range(gr):
			var tl = _junctions[c    ][r    ]
			var tr = _junctions[c + 1][r    ]
			var br = _junctions[c + 1][r + 1]
			var bl = _junctions[c    ][r + 1]
			var roll := _rng.randf()
			if roll < urban_density * 0.80:
				_gen_buildings_in_cell(tl, tr, br, bl)
			elif roll < urban_density * 0.80 + (1.0 - urban_density) * 0.55:
				_gen_park_in_cell(tl, tr, br, bl)
			else:
				_gen_lot_in_cell(tl, tr, br, bl)

func _gen_buildings_in_cell(tl: Vector2, tr: Vector2, br: Vector2, bl: Vector2) -> void:
	var min_x = min(tl.x, min(tr.x, min(br.x, bl.x)))
	var min_y = min(tl.y, min(tr.y, min(br.y, bl.y)))
	var max_x = max(tl.x, max(tr.x, max(br.x, bl.x)))
	var max_y = max(tl.y, max(tr.y, max(br.y, bl.y)))
	var cw = max_x - min_x; var ch = max_y - min_y
	if cw < 24 or ch < 24: return
	var margin := 7.0 + (1.0 - building_coverage) * 10.0
	var x0 = min_x + margin; var y0 = min_y + margin
	var x1 = max_x - margin; var y1 = max_y - margin
	if x1 - x0 < 8 or y1 - y0 < 8: return
	var max_bw := clampf(cw * 0.38, 8.0, 35.0)
	var max_bh := clampf(ch * 0.42, 8.0, 30.0)
	var y = y0
	while y + 5 < y1:
		var bh := _rng.randf_range(6.0, max_bh)
		var x  = x0
		while x + 4 < x1:
			var bw  := _rng.randf_range(6.0, max_bw)
			var gap := _rng.randf_range(2.0, 5.0)
			if x + bw <= x1:
				_buildings.append({"rect": Rect2(x, y, bw, bh), "dark": _rng.randf() < 0.30})
			x += bw + gap
		y += bh + _rng.randf_range(2.5, 6.0)

func _gen_park_in_cell(tl: Vector2, tr: Vector2, br: Vector2, bl: Vector2) -> void:
	var min_x = min(tl.x, min(tr.x, min(br.x, bl.x)))
	var min_y = min(tl.y, min(tr.y, min(br.y, bl.y)))
	var max_x = max(tl.x, max(tr.x, max(br.x, bl.x)))
	var max_y = max(tl.y, max(tr.y, max(br.y, bl.y)))
	if max_x - min_x < 18 or max_y - min_y < 18: return
	var inset := 6.0
	var cen   := Vector2((min_x + max_x) * 0.5, (min_y + max_y) * 0.5)
	var corners := [
		Vector2(min_x + inset, min_y + inset), Vector2(max_x - inset, min_y + inset),
		Vector2(max_x - inset, max_y - inset), Vector2(min_x + inset, max_y - inset),
	]
	var pts := PackedVector2Array()
	for i in range(corners.size()):
		pts.append(corners[i])
		var next = corners[(i + 1) % corners.size()]
		var mid  = (corners[i] + next) * 0.5
		pts.append(mid + (mid - cen).normalized() * _rng.randf_range(-8.0, 8.0))
	_parks.append({"poly": pts, "dark": _rng.randf() < 0.25})

func _gen_lot_in_cell(tl: Vector2, tr: Vector2, br: Vector2, bl: Vector2) -> void:
	var min_x = min(tl.x, min(tr.x, min(br.x, bl.x)))
	var min_y = min(tl.y, min(tr.y, min(br.y, bl.y)))
	var max_x = max(tl.x, max(tr.x, max(br.x, bl.x)))
	var max_y = max(tl.y, max(tr.y, max(br.y, bl.y)))
	var m := 7.0
	if max_x - min_x < 16 or max_y - min_y < 16: return
	_lots.append({"rect": Rect2(min_x + m, min_y + m, max_x - min_x - m * 2, max_y - min_y - m * 2)})

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
	for _i in range(_rng.randi_range(15, 25)):
		var entry := {
			"pos": Vector2(_rng.randf_range(0, _map_size.x), _rng.randf_range(0, _map_size.y)),
			"r":   _rng.randf_range(20, 85),
			"a":   _rng.randf_range(0.03, 0.14)
		}
		# Pre-bake per-blob randomness so _draw_stains needs no RNG
		for j in range(6):
			entry["spread_" + str(j)] = _rng.randf_range(0.1, 0.5)
			entry["scale_"  + str(j)] = _rng.randf_range(0.4, 1.0)
			entry["alpha_"  + str(j)] = _rng.randf_range(0.3, 1.0)
		_stains.append(entry)

# ─────────────────────────────────────────────────────────────────────────────
#  NODE & PATH GENERATION
# ─────────────────────────────────────────────────────────────────────────────

func _calculate_map_size() -> void:
	_map_size = Vector2(
		left_margin + (columns - 1) * node_spacing_x + left_margin,
		top_margin  + (rows   - 1) * node_spacing_y  + top_margin)

func _generate_nodes() -> void:
	_grid = []; _all_nodes = []
	var tw   := left_margin + (columns - 1) * node_spacing_x + left_margin
	var th   := top_margin  + (rows    - 1) * node_spacing_y  + top_margin
	var ox   := (_map_size.x - tw) * 0.5
	var oy   := (_map_size.y - th) * 0.5
	var hcol := node_spacing_x * 0.36
	var boss_col := columns - 1

	for c in range(columns):
		var col_arr : Array = []
		if c == boss_col:
			# Boss column: single centred node, no jitter
			var boss = _create_node(MapNode.NodeType.BOSS, c, 0)
			var half = MapNode.BOSS_NODE_RADIUS + 4.0
			var bx   := ox + left_margin + c * node_spacing_x
			var by   := _map_size.y * 0.5
			boss.position = Vector2(bx - half, by - half)
			add_child(boss)
			col_arr.append(boss)
			_all_nodes.append(boss)
		else:
			for r in range(rows):
				var node := _create_node(_pick_node_type(c), c, r)
				var pos := Vector2(
					ox + left_margin + c * node_spacing_x + _rng.randf_range(-hcol * 0.5, hcol * 0.5),
					oy + top_margin  + r * node_spacing_y + _rng.randf_range(-node_spacing_y * 0.35, node_spacing_y * 0.35))
				node.position = pos - Vector2(MapNode.NODE_RADIUS + 4, MapNode.NODE_RADIUS + 4)
				add_child(node)
				col_arr.append(node)
				_all_nodes.append(node)
		_grid.append(col_arr)

func _create_node(ntype: MapNode.NodeType, c: int, r: int) -> MapNode:
	var node : MapNode = map_node_scene.instantiate() if map_node_scene else MapNode.new()
	node.node_type = ntype; node.col = c; node.row = r
	node.next_nodes = []; node.is_visited = false; node.is_reachable = false
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.node_selected.connect(_on_node_selected)
	return node

## Assign paths using a Y-sorted non-crossing algorithm, then pre-bake waypoints.
func _generate_paths() -> void:
	_path_edges = []

	for c in range(columns - 1):
		var cur = _grid[c].duplicate()
		var nxt = _grid[c + 1].duplicate()

		# Sort both columns by their actual screen Y so connections stay ordered.
		cur.sort_custom(func(a, b): return _node_centre(a).y < _node_centre(b).y)
		nxt.sort_custom(func(a, b): return _node_centre(a).y < _node_centre(b).y)

		# Primary edges: cur[i] → nxt[i], guaranteed non-crossing.
		for i in range(cur.size()):
			var t : MapNode = nxt[i % nxt.size()]
			_add_edge(cur[i], t)

		# Optional extra edges: only connect to the immediately adjacent index
		# in the sorted next column (±1), which can only produce a single crossing
		# at worst and adds the branching feel.
		for i in range(cur.size()):
			if _rng.randf() < 0.38:
				var offset := 1 if _rng.randf() < 0.5 else -1
				var ni     := clampi(i + offset, 0, nxt.size() - 1)
				_add_edge(cur[i], nxt[ni])

## Register a connection and route its waypoints along the artery junction grid.
func _add_edge(a: MapNode, b: MapNode) -> void:
	if a.next_nodes.has(b): return
	a.next_nodes.append(b)
	var pts := _route_on_arteries(_node_centre(a), _node_centre(b))
	_path_edges.append({"from": a, "to": b, "pts": pts})

## Find the grid index [c, r] of the junction closest to world position pos.
func _nearest_junction_idx(pos: Vector2) -> Vector2i:
	var best_sq := INF
	var best    := Vector2i(0, 0)
	for c in range(road_grid_cols + 1):
		for r in range(road_grid_rows + 1):
			var d := pos.distance_squared_to(_junctions[c][r])
			if d < best_sq:
				best_sq = d
				best    = Vector2i(c, r)
	return best

## Build a waypoint list that travels from world pos `from` to world pos `to`
## by snapping to the nearest junction, walking along the grid (horizontal then
## vertical), and snapping out to the destination.  Every segment of the walk
## is an existing artery, so the highlighted path rides exactly on the roads.
func _route_on_arteries(from: Vector2, to: Vector2) -> Array:
	var ji := _nearest_junction_idx(from)
	var jt := _nearest_junction_idx(to)

	var pts : Array = [from]

	# Entry: straight shot from node centre to nearest junction
	pts.append(_junctions[ji.x][ji.y])

	# Walk horizontally along the junction grid first (keep row, advance column)
	var cc := ji.x
	var cr := ji.y
	while cc != jt.x:
		cc += int(sign(jt.x - cc))
		pts.append(_junctions[cc][cr])

	# Then walk vertically (keep column, advance row)
	while cr != jt.y:
		cr += int(sign(jt.y - cr))
		pts.append(_junctions[cc][cr])

	# Exit: straight shot from final junction to destination node centre
	pts.append(to)
	return pts

func _pick_node_type(col: int) -> MapNode.NodeType:
	# Boss column is handled separately in _generate_nodes; this is never called for it.
	var w := [early_combat, early_services, early_gym, early_shop,early_hospital, early_mystery] 		if col < columns / 2 else 		[mid_combat, mid_services, mid_gym, mid_shop,mid_hospital, mid_mystery]
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
	# n.size is Vector2.ZERO at generation time (Control layout hasn't run yet).
	# Node is positioned so centre = position + half the known fixed node diameter.
	var r    = MapNode.BOSS_NODE_RADIUS if n.node_type == MapNode.NodeType.BOSS else MapNode.NODE_RADIUS
	var half = r + 4.0
	return n.position + Vector2(half, half)

func _clear_existing() -> void:
	for node in _all_nodes: node.queue_free()
	_all_nodes  = []; _grid       = []; _junctions  = []
	_arteries   = []; _streets    = []; _buildings  = []
	_parks      = []; _lots       = []; _creases    = []
	_stains     = []; _grain      = []; _path_edges = []
	_current_node = null

# ─────────────────────────────────────────────────────────────────────────────
#  SIGNAL HANDLER
# ─────────────────────────────────────────────────────────────────────────────

func _on_node_selected(map_node: MapNode) -> void:
	if map_node.is_visited: return
	node_chosen.emit(map_node)
