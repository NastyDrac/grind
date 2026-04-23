extends Control
class_name MapNode

# Matches EventData.Exit_Type plus combat, boss entries.
enum NodeType { COMBAT, SERVICES, GYM, SHOP, HOSPITAL, MYSTERY, BOSS }

# ── Data ──────────────────────────────────────────────────────────────────────
var node_type   : NodeType = NodeType.COMBAT
var col         : int = 0
var row         : int = 0
var next_nodes  : Array
var is_visited  : bool = false
var is_reachable: bool = false

signal node_selected(map_node)

# ── Visual constants ──────────────────────────────────────────────────────────
const NODE_RADIUS      : float = 24.0
const BOSS_NODE_RADIUS : float = 36.0
const BOSS_FONT_SIZE   : int   = 11   # still used for the "BOSS" label beneath

const TYPE_COLOUR : Dictionary = {
	NodeType.COMBAT   : Color(0.85, 0.20, 0.15),
	NodeType.SERVICES : Color(0.20, 0.70, 0.30),
	NodeType.GYM      : Color(0.25, 0.50, 0.90),
	NodeType.HOSPITAL : Color(0.85, 0.70, 0.10),
	NodeType.SHOP     : Color(0.002, 0.66, 0.7, 1.0),
	NodeType.MYSTERY  : Color(0.60, 0.20, 0.80),
	NodeType.BOSS     : Color(0.55, 0.04, 0.04),
}
const TYPE_LABEL : Dictionary = {
	NodeType.COMBAT   : "Combat",
	NodeType.SERVICES : "Services",
	NodeType.GYM      : "Gym",
	NodeType.SHOP     : "Shop",
	NodeType.HOSPITAL : "Hospital",
	NodeType.MYSTERY  : "Mystery",
	NodeType.BOSS     : "BOSS",
}

# ── Icon textures — assign these in the Inspector (or via code before build()) ─
## Assign a Texture2D for each node type. If left null the circle fills with the
## type colour only (no icon drawn), so the map still works without any images.
@export var icon_combat   : Texture2D = preload("res://Art/Icons/FightButton.png")
@export var icon_services : Texture2D = preload("res://Art/Icons/SERVICEIcon.png")
@export var icon_gym      : Texture2D = preload("res://Art/Icons/GYMIcon.png")
@export var icon_shop     : Texture2D = preload("res://Art/Icons/SHOPIcon.png")
@export var icon_hospital : Texture2D = preload("res://Art/Icons/HEALINGIcon.png")
@export var icon_mystery  : Texture2D = preload("res://Art/Icons/NarrativeButton.png")
@export var icon_boss     : Texture2D = preload("res://Art/Icons/FightButton.png")

var _hovered : bool = false

func _ready() -> void:
	var r := _radius()
	custom_minimum_size = Vector2((r + 4) * 2, (r + 4) * 2)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

func _radius() -> float:
	return BOSS_NODE_RADIUS if node_type == NodeType.BOSS else NODE_RADIUS

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if is_reachable:
			node_selected.emit(self)

func _draw() -> void:
	var r      := _radius()
	var centre := Vector2(size.x * 0.5, size.y * 0.5)
	var base   : Color = TYPE_COLOUR[node_type]

	# ── Outer ring ────────────────────────────────────────────────────────────
	var ring_col : Color
	if is_visited:
		ring_col = Color(0.4, 0.4, 0.4)
	elif is_reachable:
		ring_col = Color.WHITE if _hovered else Color(0.9, 0.85, 0.6)
	else:
		ring_col = Color(0.25, 0.25, 0.25)

	# Boss gets an extra dramatic outer glow ring
	if node_type == NodeType.BOSS:
		draw_circle(centre, r + 8.0, Color(0.8, 0.0, 0.0, 0.25))
		draw_circle(centre, r + 5.0, Color(0.6, 0.0, 0.0, 0.50))
	draw_circle(centre, r + 4.0, ring_col)

	# ── Fill ──────────────────────────────────────────────────────────────────
	var fill := base if not is_visited else base.darkened(0.55)
	if is_reachable and _hovered:
		fill = fill.lightened(0.25)
	draw_circle(centre, r, fill)

	# ── Icon image ────────────────────────────────────────────────────────────
	var tex : Texture2D = _get_texture()
	if tex:
		# Scale the icon to fit inside the circle with a small margin.
		var icon_size := (r * 2.0 - 10.0)
		var icon_rect := Rect2(centre - Vector2(icon_size, icon_size) * 0.5,
							   Vector2(icon_size, icon_size))
		# Tint to grey-out visited nodes, keep full colour otherwise.
		var tint := Color(0.6, 0.6, 0.6) if is_visited else Color.WHITE
		draw_texture_rect(tex, icon_rect, false, tint)

	# ── BOSS label beneath the node ───────────────────────────────────────────
	if node_type == NodeType.BOSS:
		var lbl := "BOSS"
		var lf  := ThemeDB.fallback_font
		var lfs := BOSS_FONT_SIZE
		var ls  := lf.get_string_size(lbl, HORIZONTAL_ALIGNMENT_CENTER, -1, lfs)
		draw_string(lf, Vector2(centre.x - ls.x * 0.5, centre.y + r + 14.0),
			lbl, HORIZONTAL_ALIGNMENT_CENTER, -1, lfs, Color(1.0, 0.3, 0.3, 0.90))

	# ── Pulse ring ────────────────────────────────────────────────────────────
	if is_reachable and not is_visited:
		var pulse_a := 0.55 + 0.35 * sin(Time.get_ticks_msec() * 0.004)
		var pulse_c := Color(1.0, 0.3, 0.3, pulse_a) if node_type == NodeType.BOSS \
					  else Color(1.0, 1.0, 0.7, pulse_a)
		draw_arc(centre, r + 7.0, 0, TAU, 40, pulse_c, 2.5)

func _get_texture() -> Texture2D:
	match node_type:
		NodeType.COMBAT:   return icon_combat
		NodeType.SERVICES: return icon_services
		NodeType.GYM:      return icon_gym
		NodeType.SHOP:     return icon_shop
		NodeType.HOSPITAL: return icon_hospital
		NodeType.MYSTERY:  return icon_mystery
		NodeType.BOSS:     return icon_boss
	return null

func _process(_delta: float) -> void:
	if is_reachable:
		queue_redraw()

func _on_mouse_entered() -> void:
	_hovered = true;  queue_redraw()
func _on_mouse_exited() -> void:
	_hovered = false; queue_redraw()

func refresh() -> void:
	mouse_filter = MOUSE_FILTER_STOP if is_reachable else MOUSE_FILTER_IGNORE
	queue_redraw()

func get_type_label() -> String:
	return TYPE_LABEL[node_type]
