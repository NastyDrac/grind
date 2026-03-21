extends GridContainer
class_name ConditionContainer

@export var entity: Node

const COLUMNS: int = 5

var _previous_conditions: Array = []

func _ready():
	columns = COLUMNS
	update_conditions()

func _process(delta: float) -> void:
	if _conditions_changed():
		update_conditions()

func create_icon(con: Condition):
	var icon = ConditionIcon.new(con)
	add_child(icon)
	icon.ready.connect(icon.update_display.bind(), CONNECT_ONE_SHOT)

func update_conditions():
	if not entity:
		return

	for child in get_children():
		child.queue_free()

	var conditions: Array[Condition] = []
	if entity is Character or entity is Enemy:
		conditions = entity.conditions

	for con in conditions:
		create_icon(con)

	_previous_conditions = conditions.duplicate()

func _conditions_changed() -> bool:
	if not entity:
		return false

	var current_conditions: Array = []
	if entity is Character or entity is Enemy:
		current_conditions = entity.conditions

	if current_conditions.size() != _previous_conditions.size():
		return true

	for i in range(current_conditions.size()):
		if i >= _previous_conditions.size():
			return true

		var current = current_conditions[i]
		var previous = _previous_conditions[i]

		if current.get_script() != previous.get_script():
			return true
		if current.stacks != previous.stacks:
			return true

	return false
