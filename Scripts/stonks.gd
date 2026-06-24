extends ThingyCondition
class_name Stonks

## "Stonks" — number go up. Win a fight, permanently gain stat. A slow,
## compounding investment that pays off over a long run. RUN-level: wins happen
## between combats, so it hooks fight_ended in activate() and unhooks in
## deactivate() (mirrors Training Montage's permanent-stat pattern).

## How much to grow per win.
@export var amount : int = 1
## Which stat grows. Pick the one that defines the build you're investing in.
@export var stat_type : Stat.STAT = Stat.STAT.MOJO

var _run


func activate(run) -> void:
	_run = run
	if not Global.fight_ended.is_connected(_on_fight_ended):
		Global.fight_ended.connect(_on_fight_ended)


func deactivate() -> void:
	if Global.fight_ended.is_connected(_on_fight_ended):
		Global.fight_ended.disconnect(_on_fight_ended)
	_run = null


func _on_fight_ended(won: bool) -> void:
	if not won or _run == null or _run.character == null:
		return
	for stat in _run.character.stats:
		if stat.stat_type == stat_type:
			stat.modify_stat(amount)
			break
	# Push the permanent gain into the live combat copy for the next fight.
	if _run.player and _run.player.has_method("sync_from_data"):
		_run.player.sync_from_data()


func get_description_with_values() -> String:
	return "Each fight you win, permanently gain +%d %s." % [amount, Stat.STAT.keys()[stat_type].capitalize()]
