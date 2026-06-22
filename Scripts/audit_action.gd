extends Action
class_name AuditAction

# ══════════════════════════════════════════════════════════════════════════════
#  AUDIT ACTION  —  the "fine print" the Auditor staples onto your cards.
#
#  Appended to an audited card's actions array. Because it's a normal Action, it
#  fires through the standard play path whenever the player plays that card —
#  and heals the Auditor. target_type is SELF so it never asks the player to aim.
#
#  Robustness: `auditor` is a runtime back-reference set at audit time. If the
#  Auditor is dead or freed, the amendment whiffs harmlessly — which is the
#  whole point: kill him and every audit on your deck goes inert.
# ══════════════════════════════════════════════════════════════════════════════

## HP the Auditor recovers when the player plays this audited card.
@export var heal_amount : int = 3

## Back-reference to the boss enemy, set by AuditorData at audit time.
## Runtime only — not serialized, and guarded with is_instance_valid().
var auditor = null


func get_action_type() -> String:
	return "Audit"


func execute(target) -> void:
	# No living beneficiary -> the amendment does nothing.
	if not is_instance_valid(auditor):
		return
	if auditor.current_health <= 0:
		return

	auditor.current_health = min(auditor.max_health, auditor.current_health + heal_amount)
	if auditor.has_method("set_health_bar"):
		auditor.set_health_bar()


func get_description_with_values(character) -> String:
	return "[Audited] The Auditor recovers %d." % heal_amount


# Shown on the card face. § markers get tinted by the card renderer; here we use
# an explicit red so the penalty reads as a malus, not a buff.
func get_card_text(character) -> String:
	return "[color=#d65a5a][Audited][/color] Auditor heals %d" % heal_amount


func get_tooltip_text(character) -> String:
	return "An Auditor's amendment. Playing this card heals the Auditor for %d. Defeating the Auditor voids it." % heal_amount
