extends ThingyCondition
class_name CombustibleLemons

## "Combustible Lemons" — when life gives you lemons, burn their house down. Your
## attacks set enemies on fire: every hit applies Burning to the target. Combat-
## only; listens for player_attacks and stacks Burning, which then ticks via its
## own time_passed DoT.

## Burning stacks applied per hit.
@export var burn_per_hit : int = 1


func setup(who, rm) -> void:
	super(who, rm)
	if not Global.player_attacks.is_connected(_on_player_attacks):
		Global.player_attacks.connect(_on_player_attacks)


func teardown() -> void:
	if Global.player_attacks.is_connected(_on_player_attacks):
		Global.player_attacks.disconnect(_on_player_attacks)
	super()


func _on_player_attacks(_attacker, target, _damage) -> void:
	if not is_instance_valid(target):
		return
	var fire := Burning.new()
	fire.stacks = burn_per_hit
	# Routed through apply_condition so the enemy's handler stacks onto any
	# existing Burning instead of creating duplicates.
	Global.apply_condition.emit(target, fire)


func get_description_with_values() -> String:
	return "Your attacks apply %d Burning to the enemy hit." % burn_per_hit
