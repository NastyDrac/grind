extends Action
class_name DeployTurretAction

## Damage each turret shot deals.
@export var damage: ValueCalculator

## Optional texture forwarded to the spawned turret.
@export var turret_texture: Texture2D


# ─────────────────────────────────────────────
# EXECUTE  (target = the enemy the player clicked)
# ─────────────────────────────────────────────

func execute(target) -> void:
	if not target is Enemy:
		push_warning("DeployTurretAction: expected an Enemy target, got %s" % str(target))
		return

	_deploy(target.get_current_range())


# ─────────────────────────────────────────────
# DEPLOY OR STACK
# ─────────────────────────────────────────────

func _get_existing_turret(range_manager: RangeManager, at_range: int) -> Turret:
	for child in range_manager.get_children():
		if child is Turret and child.assigned_range == at_range:
			return child
	return null


func _deploy(at_range: int) -> void:
	if not player or not player.run_manager:
		push_warning("DeployTurretAction: no run_manager accessible from player.")
		return

	var range_manager: RangeManager = player.run_manager.range_manager
	if not range_manager:
		push_warning("DeployTurretAction: run_manager has no range_manager.")
		return

	var existing := _get_existing_turret(range_manager, at_range)
	if existing:
		# A turret already guards this range — just add to its stack.
		existing.add_stack()
		return

	# No turret here yet — spawn one.
	var turret := Turret.new()
	turret.assigned_range = at_range
	turret.damage = damage
	turret.run_manager = player.run_manager

	if turret_texture:
		turret.texture = turret_texture

	range_manager.add_child(turret)

	var x: float = range_manager._get_x_for_range(at_range) - range_manager.range_spacing * 0.5
	var y: float = range_manager.get_viewport().size.y * range_manager.center_ratio
	turret.global_position = Vector2(x, y)


# ─────────────────────────────────────────────
# UI DESCRIPTION
# ─────────────────────────────────────────────

func get_description_with_values(character = null) -> String:
	var who = character if character else player
	var dmg : int = damage.calculate(who) if (damage and who) else 0
	return "Deploy a turret.\nThe turret deals %d damage to a random enemy there." % dmg


## Hover-tooltip breakdown: explains how each turret's per-shot damage is
## computed, e.g. "8 damage = heat + marbles". Returns "" for flat-literal
## damage (nothing to explain), so a fixed-damage turret adds no tooltip line.
## Mirrors AttackAction's damage tooltip; turret shots use the player's stats at
## fire time, so the breakdown is computed from the same character. Tooltip text
## is plain (the card-hover label renders it without BBCode).
func get_tooltip_text(character) -> String:
	if not damage:
		return ""
	var who = character if character else player
	if not who:
		return ""
	return _formula_breakdown("damage", damage.calculate(who), damage.formula)
