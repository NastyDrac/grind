extends EventEffect
class_name EffectModStat

@export var stat_to_mod : Stat
@export var modify_value : int
func execute(run_manager: RunManager, _parent: Node, done: Callable) -> void:
	if stat_to_mod == null:
		push_warning("ModifyStatAction: no action assigned.")
	else:
		for each : Stat in run_manager.character.stats:
			if each.stat_type == stat_to_mod.stat_type:
				each.modify_stat(modify_value)
	done.call()

func get_description(run : RunManager) -> String:
	var desc := ""
	
	if modify_value < 0:
		desc += "-%s" % abs(modify_value)
	elif modify_value > 0:
		desc += "+%s" % abs(modify_value)
	else:
		return "" 
	
	match stat_to_mod.stat_type:
		Stat.STAT.SWAG:
			desc += " Swag"
		Stat.STAT.MARBLES:
			desc += " Marbles"
		Stat.STAT.GUTS:
			desc += " Guts"
		Stat.STAT.BANG:
			desc += " Bang"
		Stat.STAT.HUSTLE:
			desc += " Hustle"
		Stat.STAT.MOJO:
			desc += " Mojo"

	return desc
