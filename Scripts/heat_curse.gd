extends TimedThingy
class_name HeatCurse
## A curse relic: the world runs hotter while you carry it. Each active combat
## opens with extra noise and gains extra passive noise per turn. Because the
## RangeManager is rebuilt every combat, there's nothing to undo on teardown.

## Added to the opening noise meter each combat.
@export var extra_starting_noise: float = 2.0

## Added to passive_noise_per_turn for the duration of each combat.
@export var extra_passive_noise: float = 1.0


func _on_combat_start() -> void:
	if range_manager:
		range_manager.noise_meter += extra_starting_noise
		range_manager.passive_noise_per_turn += extra_passive_noise


func get_description_with_values() -> String:
	if description != "":
		return description
	return "+%s opening noise and +%s noise per turn. Lasts %s." % [
		str(extra_starting_noise), str(extra_passive_noise), _duration_text()
	]
