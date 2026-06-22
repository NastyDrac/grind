extends Action
class_name PushPullAction


@export var distance_calculator: ValueCalculator


@export var enemy_count_calculator: ValueCalculator

func get_action_type() -> String:
	return "Push/Pull"


## A push/pull slides the enemy to a new range, which takes a moment. Always make
## the card handler wait for it before the next action (e.g. the attack), so the
## target has arrived before the hit lands — no .tres flag required.
func blocks_until_resolved() -> bool:
	return true

func execute(target: Enemy) -> void:
	if not player:
		push_error("PushPullAction requires valid Character")
		return

	if not target:
		push_error("PushPullAction requires valid Enemy target")
		return

	var distance = _calculate_distance()

	# Enemy.push() owns the range bounds: it clamps to [1, range manager max] so
	# an enemy can never reach range 0 (the player's slot) or exceed the
	# playfield, and it emits enemy_advanced + enemy_player_moved for both
	# directions. Positive distance pushes away; negative pulls toward.
	target.push(distance)

func get_description_with_values(character: Character) -> String:
	if not character or not distance_calculator:
		return "Push/Pull enemy"


	var distance = distance_calculator.calculate(character)


	var formula_display = _format_formula_display(distance_calculator.formula)


	var action_word = "Push" if distance > 0 else "Pull"
	var abs_distance = abs(distance)


	var desc = ""

	match target_type:
		TargetType.SINGLE_ENEMY:
			desc = "%s: §%d§ (%s)" % [action_word, abs_distance, formula_display]

		TargetType.ALL_ENEMIES:
			desc = "%s: §%d§ (%s) all enemies" % [action_word, abs_distance, formula_display]

		TargetType.ALL_ENEMIES_AT_RANGE:
			desc = "%s: §%d§ (%s) all at range" % [action_word, abs_distance, formula_display]

		TargetType.X_ENEMIES_UP_TO_RANGE:
			if enemy_count_calculator:
				var count = enemy_count_calculator.calculate(character)
				var count_formula = _format_formula_display(enemy_count_calculator.formula)
				desc = "%s: §%d§ (%s) on §%d§ (%s) enemies" % [action_word, abs_distance, formula_display, count, count_formula]
			else:
				desc = "%s: §%d§ (%s) multiple enemies" % [action_word, abs_distance, formula_display]

		TargetType.SELF:
			desc = "%s: Cannot target self" % action_word

	return desc


# ============================================================================
# CARD BODY / TOOLTIP SPLIT
# ============================================================================

## Card body: the clean computed distance only (green when it comes from a
## formula, white when it's a flat literal). The "(formula)" breakdown moves to
## the hover tooltip so the card face stays uncluttered — mirrors AttackAction.
func get_card_text(character) -> String:
	if not character or not distance_calculator:
		return "Push/Pull enemy"

	var distance = distance_calculator.calculate(character)
	var action_word = "Push" if distance > 0 else "Pull"
	var dist_str = _cv(abs(distance), distance_calculator.formula)

	match target_type:
		TargetType.SINGLE_ENEMY:
			return "%s: %s" % [action_word, dist_str]
		TargetType.ALL_ENEMIES:
			return "%s: %s all enemies" % [action_word, dist_str]
		TargetType.ALL_ENEMIES_AT_RANGE:
			return "%s: %s all at range" % [action_word, dist_str]
		TargetType.X_ENEMIES_UP_TO_RANGE:
			if enemy_count_calculator:
				var count = enemy_count_calculator.calculate(character)
				return "%s: %s on %s enemies" % [action_word, dist_str, _cv(count, enemy_count_calculator.formula)]
			return "%s: %s multiple enemies" % [action_word, dist_str]
		TargetType.SELF:
			return "%s: Cannot target self" % action_word

	return "%s: %s" % [action_word, dist_str]


## Hover tooltip: the formula behind the distance (and the enemy count, when the
## action hits multiple). Returns "" for flat-literal values (nothing to
## explain). Tooltip text is plain — no BBCode.
func get_tooltip_text(character) -> String:
	if not character or not distance_calculator:
		return ""

	var lines : Array[String] = []

	var dist_line = _formula_breakdown("distance", abs(distance_calculator.calculate(character)), distance_calculator.formula)
	if dist_line != "":
		lines.append(dist_line)

	if target_type == TargetType.X_ENEMIES_UP_TO_RANGE and enemy_count_calculator:
		var cnt_line = _formula_breakdown("enemies", enemy_count_calculator.calculate(character), enemy_count_calculator.formula)
		if cnt_line != "":
			lines.append(cnt_line)

	return "\n".join(lines)

func _calculate_distance() -> int:
	if distance_calculator and player:
		return distance_calculator.calculate(player)
	return 1


func get_num_targets(character: Character) -> int:
	if target_type == TargetType.X_ENEMIES_UP_TO_RANGE and enemy_count_calculator:
		return enemy_count_calculator.calculate(character)
	return 1
