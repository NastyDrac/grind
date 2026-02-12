extends HBoxContainer
class_name ConditionContainer

@export var entity: Node

# Track previous condition state to avoid unnecessary updates
var _previous_conditions: Array = []

func _ready():
	# Initial update
	update_conditions()

func _process(delta: float) -> void:
	# Only update if conditions have changed
	if _conditions_changed():
		update_conditions()

func create_icon(con: Condition):
	var icon = ConditionIcon.new(con)
	add_child(icon)
	# Wait for ready before updating display
	icon.ready.connect(icon.update_display.bind(), CONNECT_ONE_SHOT)

func update_conditions():
	if not entity:
		return
	
	# Clear existing icons
	for child in get_children():
		child.queue_free()
	
	# Get conditions from entity
	var conditions: Array[Condition] = []
	if entity is Character or entity is Enemy:
		conditions = entity.conditions
	
	# Create icons for each condition
	for con in conditions:
		create_icon(con)
	
	# Update previous state
	_previous_conditions = conditions.duplicate()

func _conditions_changed() -> bool:
	if not entity:
		return false
	
	# Get current conditions
	var current_conditions: Array = []
	if entity is Character or entity is Enemy:
		current_conditions = entity.conditions
	
	# Check if the number of conditions changed
	if current_conditions.size() != _previous_conditions.size():
		return true
	
	# Check if any condition changed (by comparing stacks and types)
	for i in range(current_conditions.size()):
		if i >= _previous_conditions.size():
			return true
		
		var current = current_conditions[i]
		var previous = _previous_conditions[i]
		
		# Check if it's a different condition type or different stacks
		if current.get_script() != previous.get_script():
			return true
		if current.stacks != previous.stacks:
			return true
	
	return false
