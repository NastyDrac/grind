extends TimedThingy
class_name LeakyPurse
## A curse relic: coin slips away after every fight.

## Gold lost at the end of each combat (won't drop you below 0).
@export var gold_lost_per_combat: int = 10


func _on_combat_end() -> void:
	if entity and entity.run_manager:
		var c = entity.run_manager.character
		c.gold = max(0, c.gold - gold_lost_per_combat)
		if entity.run_manager.ui_bar:
			entity.run_manager.ui_bar.set_gold()


func get_description_with_values() -> String:
	if description != "":
		return description
	return "Lose %d gold after every fight. Lasts %s." % [gold_lost_per_combat, _duration_text()]
