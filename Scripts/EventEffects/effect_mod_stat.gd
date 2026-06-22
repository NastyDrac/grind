extends EventEffect
class_name EffectModStat

## Modifies a stat by [modify_value]. Normally a fixed stat (stat_to_mod); if
## [random_stat] is on, it picks one of the six stats at random instead, so the
## reward varies run to run. Random picks use the run's seeded RNG, so a given
## seed still replays the same outcome.
@export var stat_to_mod : Stat
@export var modify_value : int
## When true, ignore stat_to_mod and roll a random stat each time this fires.
@export var random_stat : bool = false


func execute(run_manager: RunManager, _parent: Node, done: Callable) -> void:
	var target_type : int = -1
	if random_stat:
		target_type = _roll_stat(run_manager)
	elif stat_to_mod != null:
		target_type = stat_to_mod.stat_type
	else:
		push_warning("EffectModStat: no stat assigned and random_stat is off.")
		done.call()
		return

	for each : Stat in run_manager.character.stats:
		if each.stat_type == target_type:
			each.modify_stat(modify_value)
	done.call()


## Pick a random STAT enum value via the seeded run RNG (falls back to global
## randi only if the run somehow has no rng yet).
func _roll_stat(run_manager: RunManager) -> int:
	var n : int = Stat.STAT.size()
	if run_manager and run_manager.rng:
		return run_manager.rng.randi_range(0, n - 1)
	return randi() % n


func get_description(run : RunManager) -> String:
	var sign_txt := ""
	if modify_value < 0:
		sign_txt = "-%s" % abs(modify_value)
	elif modify_value > 0:
		sign_txt = "+%s" % abs(modify_value)
	else:
		return ""

	if random_stat:
		return "%s to a random stat" % sign_txt

	if stat_to_mod == null:
		return sign_txt

	match stat_to_mod.stat_type:
		Stat.STAT.SWAG:    return sign_txt + " Swag"
		Stat.STAT.MARBLES: return sign_txt + " Marbles"
		Stat.STAT.GUTS:    return sign_txt + " Guts"
		Stat.STAT.HEAT:    return sign_txt + " Heat"
		Stat.STAT.HUSTLE:  return sign_txt + " Hustle"
		Stat.STAT.MOJO:    return sign_txt + " Mojo"
	return sign_txt
