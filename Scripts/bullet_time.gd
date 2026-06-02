extends ThingyCondition
class_name ThingyBulletTime

## "Bullet Time" — ignore ALL damage from every Nth incoming attack, with a
## live countdown to the next free dodge.
##
## One instance: it lives in special_effects, take_hit runs modify_damage on it,
## AND both displays (character sheet + combat HUD) render this same object. So
## updating `stacks` here shows up everywhere, no syncing. The number shown is
## "hits remaining until the next dodge" — when it reads 1, the next hit is free.

@export var every_n : int = 10

var _hits : int = 0

func setup(who, rm) -> void:
	super(who, rm)
	show_stacks = true
	stacks = _remaining()

func modify_damage(damage : int) -> int:
	_hits += 1
	var dodged := every_n > 0 and _hits % every_n == 0
	stacks = _remaining()      # ConditionIcon polls this and shows it live
	if dodged:
		return 0
	return damage

## Hits remaining until the next free dodge (reads every_n right after a dodge).
func _remaining() -> int:
	if every_n <= 0:
		return 0
	var into_cycle := _hits % every_n
	return every_n if into_cycle == 0 else every_n - into_cycle

func get_description_with_values() -> String:
	return "Ignore all damage from every %d%s attack. (%d until next.)" % [
		every_n, _ordinal(every_n), _remaining()
	]

func _ordinal(n : int) -> String:
	var teens := n % 100
	if teens >= 11 and teens <= 13:
		return "th"
	match n % 10:
		1: return "st"
		2: return "nd"
		3: return "rd"
		_: return "th"
