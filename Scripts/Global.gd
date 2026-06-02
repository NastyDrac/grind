extends Node

# Card actions
signal card_played(card_data: CardData)  # When player plays a card
signal time_passed()
signal apply_condition(target, condition : Condition)
signal request_animation(action: Action, target: Object, anim_type: Action.AnimationType)
# Enemy actions
signal enemy_advanced(enemy : Enemy, old_range : int, new_range : int)  # ANY movement (own turn, push, or pull)
signal enemy_player_moved(enemy : Enemy, old_range : int, new_range : int)  # ONLY player-forced movement (push/pull)
signal enemy_spawned(enemy: Enemy)
signal enemy_attacks_player(enemy: Enemy, damage: int)
signal enemy_dies(enemy : Enemy)
signal enemy_took_damage(enemy : Enemy, amount : int)  # Fired only when the enemy SURVIVES the hit
# Hand actions
signal card_added_to_hand(card: Card)
signal card_removed_from_hand(card: Card)
signal card_added_to_deck(card_data : CardData)  # Run-level: a card joined the run deck
# Player actions
signal player_attacks(attacker: Character, target: Enemy, damage: int)
signal item_dropped(item : Item, location : Vector2)

#items actions
signal item_picked_up(item : Item)
