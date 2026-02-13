extends Line2D
class_name TargetingArrow


@export var arrow_color: Color = Color(0.8, 0.1, 0.1, 0.9)  
@export var outline_color: Color = Color(0.2, 0.0, 0.0, 1.0)  
@export var arrow_width: float = 8.0
@export var outline_width: float = 12.0
@export var arrow_head_size: float = 25.0
@export var curve_amount: float = 100.0  

var start_position: Vector2 = Vector2.ZERO
var end_position: Vector2 = Vector2.ZERO
var arrow_head: Polygon2D
var outline_line: Line2D

func _ready():
	
	outline_line = Line2D.new()
	add_child(outline_line)
	outline_line.width = outline_width
	outline_line.default_color = outline_color
	outline_line.joint_mode = Line2D.LINE_JOINT_ROUND
	outline_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	outline_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	outline_line.z_index = -1
	
	
	width = arrow_width
	default_color = arrow_color
	joint_mode = Line2D.LINE_JOINT_ROUND
	begin_cap_mode = Line2D.LINE_CAP_ROUND
	end_cap_mode = Line2D.LINE_CAP_ROUND
	
	
	arrow_head = Polygon2D.new()
	add_child(arrow_head)
	arrow_head.color = arrow_color
	
	var arrow_head_outline = Polygon2D.new()
	add_child(arrow_head_outline)
	arrow_head_outline.color = outline_color
	arrow_head_outline.z_index = -1
	
	
	visible = false

func show_arrow(from: Vector2, to: Vector2):
	start_position = from
	end_position = to
	visible = true
	_update_arrow()

func hide_arrow():
	visible = false
	clear_points()
	if outline_line:
		outline_line.clear_points()

func _process(_delta: float):
	if visible:
		_update_arrow()

func _update_arrow():
	
	clear_points()
	if outline_line:
		outline_line.clear_points()
	
	
	var direction = (end_position - start_position).normalized()
	var distance = start_position.distance_to(end_position)
	
	
	if distance < 30:
		return
	
	
	var offset_start = start_position + direction * 40
	
	
	var perpendicular = Vector2(-direction.y, direction.x)
	var mid_point = (offset_start + end_position) / 2.0
	var control_point = mid_point + perpendicular * curve_amount
	
	
	var num_points = 30
	for i in range(num_points + 1):
		var t = float(i) / float(num_points)
		var point = _quadratic_bezier(offset_start, control_point, end_position, t)
		add_point(point)
		if outline_line:
			outline_line.add_point(point)
	
	
	_draw_arrow_head()

func _quadratic_bezier(p0: Vector2, p1: Vector2, p2: Vector2, t: float) -> Vector2:
	var q0 = p0.lerp(p1, t)
	var q1 = p1.lerp(p2, t)
	return q0.lerp(q1, t)

func _draw_arrow_head():
	
	var points = get_points()
	if points.size() < 2:
		return
	
	var direction = (points[points.size() - 1] - points[points.size() - 2]).normalized()
	var perpendicular = Vector2(-direction.y, direction.x)
	
	
	var tip = end_position
	var base_left = tip - direction * arrow_head_size + perpendicular * (arrow_head_size * 0.6)
	var base_right = tip - direction * arrow_head_size - perpendicular * (arrow_head_size * 0.6)
	
	
	if arrow_head:
		arrow_head.polygon = PackedVector2Array([tip, base_left, base_right])
	
	
	var outline_size = arrow_head_size * 1.15
	var tip_outline = tip + direction * 2
	var base_left_outline = tip - direction * outline_size + perpendicular * (outline_size * 0.65)
	var base_right_outline = tip - direction * outline_size - perpendicular * (outline_size * 0.65)
	
	
	for child in get_children():
		if child is Polygon2D and child.z_index == -1 and child != arrow_head:
			child.polygon = PackedVector2Array([tip_outline, base_left_outline, base_right_outline])
			break
