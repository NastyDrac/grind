extends EnemyData
class_name AuditorData

# ══════════════════════════════════════════════════════════════════════════════
#  THE AUDITOR  —  Act 2 boss
#
#  Every few turns the Auditor "audits" one of your cards: it deep-copies that
#  card's data (so your PERMANENT run deck is never touched) and staples a
#  penalty action onto the copy. From then on, every time you PLAY that card it
#  also heals the Auditor. The pressure is a race — the longer the fight drags,
#  the more of your deck is amended against you — and killing him VOIDS every
#  amendment at once, because the penalty has no beneficiary left to heal.
#
#  Models its turn hook on were-ostrich.gd: override_movement() is called by
#  enemy.gd each turn; get_current_intent()/get_display_damage() feed the intent
#  indicator.
# ══════════════════════════════════════════════════════════════════════════════

# ── Audit config ──────────────────────────────────────────────────────────────
## Turns between audits. He staples a penalty onto one of your cards this often.
## First audit lands on turn == audit_interval, giving the player a turn of grace.
@export var audit_interval : int = 2
## HP the Auditor recovers each time you play an audited card.
@export var heal_per_play : int = 3
## How many cards he audits per trigger.
@export var audits_per_trigger : int = 1

# ── Runtime state ─────────────────────────────────────────────────────────────
var _turn_counter : int = 0
var _enemy = null   # cached so the range-aware intent can read current_range


# ── Reset — called by enemy.gd on each new spawn ─────────────────────────────
func reset_movement_state() -> void:
	_turn_counter = 0
	_enemy        = null


# ── EnemyData virtual methods ─────────────────────────────────────────────────

func override_movement(enemy) -> bool:
	_enemy = enemy
	_turn_counter += 1

	# Audit on the interval.
	if _turn_counter % audit_interval == 0:
		for i in audits_per_trigger:
			_audit_a_card(enemy)

	# Otherwise behave like a standard slow melee enemy: attack if in range,
	# else close the distance.
	if enemy.get_current_range() <= enemy.data.attack_range:
		enemy.attack_player()
	else:
		enemy._do_advance()

	return true


## Called by enemy.get_next_intent() so the IntentIndicator stays accurate.
func get_current_intent() -> int:
	if _enemy and _enemy.current_range <= _enemy.data.attack_range:
		return MoveStep.MoveAction.ATTACK
	return MoveStep.MoveAction.ADVANCE


## Called by enemy.get_intent_damage() for the IntentIndicator label.
func get_display_damage(enemy) -> int:
	return enemy.get_attack_damage()


# ── Audit ─────────────────────────────────────────────────────────────────────

func _audit_a_card(enemy) -> void:
	var rm = enemy.range_manager
	if not rm or not rm.run_manager:
		return
	var ch = rm.run_manager.card_handler
	if not ch:
		return

	# The hand is empty on the enemy's turn — the deck lives in the draw and
	# discard piles as Card nodes. Gather every card not already audited.
	var candidates : Array = []
	for pile in [ch.draw_pile, ch.discard_pile]:
		if pile == null:
			continue
		for c in pile.get_children():
			if c is Card and c.data and not _is_audited(c):
				candidates.append(c)

	# Whole deck already amended — nothing left to do.
	if candidates.is_empty():
		return

	var card = candidates[randi() % candidates.size()]

	# CRITICAL: isolate this combat instance. The combat deck shares CardData
	# references with run_manager.deck, so we must duplicate before mutating or
	# the penalty would poison the player's permanent deck for the whole run.
	card.data = card.data.duplicate(true)

	var penalty := AuditAction.new()
	penalty.target_type = Action.TargetType.SELF
	penalty.heal_amount = heal_per_play
	penalty.auditor     = enemy
	card.data.actions.append(penalty)

	# Flag it so the card renders the crimson title + frame wash + "Audited"
	# keyword, then refresh both: _apply_title_style for the tint (refresh_
	# description doesn't touch the title/frame) and refresh_description for the
	# new action line and keyword.
	card.data.audited = true
	if card.has_method("_apply_title_style"):
		card._apply_title_style()
	card.refresh_description()

	_announce(enemy, "Audited", card.data.card_name)


func _is_audited(card) -> bool:
	for a in card.data.actions:
		if a is AuditAction:
			return true
	return false


# ── Helpers ───────────────────────────────────────────────────────────────────

func _announce(enemy, title: String, subtitle: String) -> void:
	if not enemy.range_manager or not enemy.range_manager.run_manager:
		return
	var announcer        := CombatAnnouncer.new()
	announcer.run_manager = enemy.range_manager.run_manager
	enemy.range_manager.run_manager.add_child(announcer)
	announcer.show_announcement(title, subtitle)
