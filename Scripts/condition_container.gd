extends GridContainer
class_name ConditionContainer

@export var entity: Node

const COLUMNS: int = 5

var _previous_list: Array = []

func _ready():
	columns = COLUMNS
	update_conditions()

func _process(_delta: float) -> void:
	# Rebuild only when the SET of displayed conditions changes (added/removed).
	# Number changes are handled live by each ConditionIcon, so they don't
	# require a rebuild here.
	if _membership_changed():
		update_conditions()

## The full list to display:
##   Character -> persistent thingies (special_effects) + temporary combat conditions
##   Enemy     -> its conditions
func _get_display_list() -> Array:
	var list: Array = []
	if entity is Character:
		if entity.character_data and entity.character_data.special_effects:
			list.append_array(entity.character_data.special_effects)
		list.append_array(entity.conditions)
	elif entity is Enemy:
		list.append_array(entity.conditions)
	return list

func create_icon(con: Condition):
	var icon = ConditionIcon.new()
	icon.set_condition(con)
	add_child(icon)

func update_conditions():
	if not entity:
		return

	for child in get_children():
		child.queue_free()

	var list := _get_display_list()
	for con in list:
		if con is Condition:
			create_icon(con)

	_previous_list = list.duplicate()

func _membership_changed() -> bool:
	if not entity:
		return false

	var current := _get_display_list()

	if current.size() != _previous_list.size():
		return true

	for i in range(current.size()):
		if current[i] != _previous_list[i]:
			return true

	return false
