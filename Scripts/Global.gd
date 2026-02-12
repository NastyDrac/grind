extends Node

# Card actions
signal card_played(card_data: CardData)  # When player plays a card
signal time_passed()
signal apply_condition(target, condition : Condition)
# Enemy actions
signal enemy_advanced(enemy : Enemy, new_range : int)  # All enemies move forward or attack
signal enemy_spawned(enemy: Enemy)
signal enemy_attacks_player(enemy: Enemy, damage: int)
signal enemy_dies(enemy : Enemy)
# Player actions
signal player_attacks(attacker: Character, target: Enemy, damage: int)
signal item_dropped(item : Item, location : Vector2)

#items actions
signal item_picked_up(item : Item)
