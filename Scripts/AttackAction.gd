extends Action
class_name AttackAction

# Damage calculation
@export var damage_calculator: ValueCalculator

# Number of enemies to hit (only used for X_ENEMIES_UP_TO_RANGE)
@export var enemy_count_calculator: ValueCalculator

## When true, the player's block is set to 0 after this attack resolves. Pairs
## with a damage formula of "block" (Shield Slam): block is permanent, so
## spending it IS the card's cost.
@export var consume_block: bool = false


func get_action_type() -> String:
	return "Attack"


## Damage is applied AFTER the animation completes.
## The card handler should call play_animation_and_execute() rather than
## execute() directly so the visual stays in sync with the damage.
func execute(target) -> void:
	if not player:
		push_error("AttackAction requires a valid Character")
		return
	if not target:
		push_error("AttackAction.execute: target is null")
		return

	var damage = damage_calculator.calculate(player)

	if target.has_method("take_damgage"):
		# Normal case: hitting an enemy.
		target.take_damgage(damage)
		Global.player_attacks.emit(player, target, damage)
	elif target.has_method("take_hit"):
		# Self-detonation (e.g. Landmine cooking off with no enemy in range):
		# damage the player. take_hit() applies block and plot-armor saves,
		# so the blast is absorbed/survived like any other hit. `who` is unused
		# inside take_hit(), so null is safe here.
		target.take_hit(null, damage)
	else:
		push_error("AttackAction.execute: target %s can't take damage" % target)

	if consume_block and player:
		player.block = 0
		if player.has_method("display_block"):
			player.display_block()


# ============================================================================
# DESCRIPTION
# ============================================================================

func get_description_with_values(character: Character) -> String:
	if not character:
		return ""
	if not damage_calculator:
		return ""

	var damage = damage_calculator.calculate(character)
	var damage_formula = damage_calculator.formula
	var show_damage_formula = not damage_formula.is_valid_int()

	var desc = ""

	match target_type:
		TargetType.SINGLE_ENEMY:
			if show_damage_formula:
				desc = "Deal §%d§ damage (%s)" % [damage, _format_formula_display(damage_formula)]
			else:
				desc = "Deal §%d§ damage" % damage

		TargetType.ALL_ENEMIES:
			if show_damage_formula:
				desc = "Deal §%d§ damage (%s) to all enemies" % [damage, _format_formula_display(damage_formula)]
			else:
				desc = "Deal §%d§ damage to all enemies" % damage

		TargetType.ALL_ENEMIES_AT_RANGE:
			if show_damage_formula:
				desc = "Deal §%d§ damage (%s) to all at range" % [damage, _format_formula_display(damage_formula)]
			else:
				desc = "Deal §%d§ damage to all at range" % damage

		TargetType.X_ENEMIES_UP_TO_RANGE:
			if enemy_count_calculator:
				var count = enemy_count_calculator.calculate(character)
				var count_formula = enemy_count_calculator.formula
				var show_count_formula = not count_formula.is_valid_int()

				if show_damage_formula and show_count_formula:
					desc = "Deal §%d§ damage (%s) to §%d§ enemies (%s)" % [damage, _format_formula_display(damage_formula), count, _format_formula_display(count_formula)]
				elif show_damage_formula:
					desc = "Deal §%d§ damage (%s) to §%d§ enemies" % [damage, _format_formula_display(damage_formula), count]
				elif show_count_formula:
					desc = "Deal §%d§ damage to §%d§ enemies (%s)" % [damage, count, _format_formula_display(count_formula)]
				else:
					desc = "Deal §%d§ damage to §%d§ enemies" % [damage, count]
			else:
				if show_damage_formula:
					desc = "Deal §%d§ damage (%s) to multiple enemies" % [damage, _format_formula_display(damage_formula)]
				else:
					desc = "Deal §%d§ damage to multiple enemies" % damage

		TargetType.SELF:
			if show_damage_formula:
				desc = "Deal §%d§ damage (%s) to self" % [damage, _format_formula_display(damage_formula)]
			else:
				desc = "Deal §%d§ damage to self" % damage

	if max_range > 0:
		desc += " - Range: §%d§" % max_range

	return desc


# ============================================================================
# CARD BODY / TOOLTIP SPLIT
# ============================================================================

## Text shown in the CARD BODY: the computed result only, no formula breakdown.
## The formula moves to the hover tooltip (get_tooltip_text) so the card stays
## readable while the math is still available on hover.
func get_card_text(character) -> String:
	if not character or not damage_calculator:
		return "Attack"

	var damage = damage_calculator.calculate(character)

	var desc = ""

	match target_type:
		TargetType.SINGLE_ENEMY:
			desc = "Deal §%d§ damage" % damage

		TargetType.ALL_ENEMIES:
			desc = "Deal §%d§ damage to all enemies" % damage

		TargetType.ALL_ENEMIES_AT_RANGE:
			desc = "Deal §%d§ damage to all at range" % damage

		TargetType.X_ENEMIES_UP_TO_RANGE:
			if enemy_count_calculator:
				var count = enemy_count_calculator.calculate(character)
				desc = "Deal §%d§ damage to §%d§ enemies" % [damage, count]
			else:
				desc = "Deal §%d§ damage to multiple enemies" % damage

		TargetType.SELF:
			desc = "Deal §%d§ damage to self" % damage

	if max_range > 0:
		desc += " - Range: §%d§" % max_range

	return desc


## Plain-text breakdown shown in the card's HOVER TOOLTIP: the formula behind
## each computed value. Returns "" for plain-literal values (nothing to explain),
## so a flat-damage attack contributes no tooltip line.
func get_tooltip_text(character) -> String:
	if not character or not damage_calculator:
		return ""

	var lines : Array[String] = []

	var dmg_line = _formula_breakdown("damage", damage_calculator.calculate(character), damage_calculator.formula)
	if dmg_line != "":
		lines.append(dmg_line)

	if target_type == TargetType.X_ENEMIES_UP_TO_RANGE and enemy_count_calculator:
		var cnt_line = _formula_breakdown("enemies", enemy_count_calculator.calculate(character), enemy_count_calculator.formula)
		if cnt_line != "":
			lines.append(cnt_line)

	return "\n".join(lines)


# ============================================================================
# INTERNAL HELPERS
# ============================================================================

func _calculate_damage() -> int:
	if damage_calculator and player:
		return damage_calculator.calculate(player)
	return 0


func _calculate_damage_from_character(character: Character) -> int:
	if damage_calculator and character:
		return damage_calculator.calculate(character)
	return 0


func _calculate_enemy_count() -> int:
	if enemy_count_calculator and player:
		return enemy_count_calculator.calculate(player)
	return 1


func _calculate_enemy_count_from_character(character: Character) -> int:
	if enemy_count_calculator and character:
		return enemy_count_calculator.calculate(character)
	return 1


func get_enemy_count(character: Character) -> int:
	if target_type == TargetType.X_ENEMIES_UP_TO_RANGE:
		return _calculate_enemy_count_from_character(character)
	return 1


func get_max_range() -> int:
	return max_range


func get_num_targets(character: Character) -> int:
	return _calculate_enemy_count_from_character(character)
