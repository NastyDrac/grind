extends ThingyCondition
class_name GravityGun

## "Gravity Gun" — pick up the pace. At the end of every turn, all items on the
## field slide one EXTRA range toward you, so scrap (and anything else) arrives
## twice as fast. Combat-only. Items already advance once on their own
## time_passed; this adds a second pull on the same signal.


func setup(who, rm) -> void:
	super(who, rm)
	if not Global.time_passed.is_connected(_on_time_passed):
		Global.time_passed.connect(_on_time_passed)


func teardown() -> void:
	if Global.time_passed.is_connected(_on_time_passed):
		Global.time_passed.disconnect(_on_time_passed)
	super()


func _on_time_passed() -> void:
	if not range_manager:
		return
	# Snapshot first: advance_toward_player() re-buckets items (and frees any that
	# reach you), so we can't iterate items_by_range live.
	var items : Array = []
	for r in range_manager.items_by_range:
		for it in range_manager.items_by_range[r]:
			if is_instance_valid(it):
				items.append(it)
	for it in items:
		if is_instance_valid(it) and it.item and not it.item.auto_pickup:
			it.advance_toward_player()


func get_description_with_values() -> String:
	return "At the end of each turn, items move one extra range toward you."
