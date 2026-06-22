extends Condition
class_name AuditingCondition

# ══════════════════════════════════════════════════════════════════════════════
#  AUDITING  —  display condition for The Auditor.
#
#  This is purely informational: it gives the boss a condition icon + tooltip so
#  the player can see WHY their cards are turning crimson. The actual audit logic
#  lives in auditor_data.gd's override_movement (boss-turn paced, which the
#  reactive TriggeredCondition triggers can't express). Keep this text in step
#  with that behaviour.
# ══════════════════════════════════════════════════════════════════════════════

func get_description_with_values() -> String:
	if description != "":
		return description
	return "Auditing: each turn, the Auditor amends one of your cards — playing an amended card heals him. Defeat the Auditor to void every amendment."
