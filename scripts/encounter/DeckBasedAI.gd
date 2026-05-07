class_name DeckBasedAI
extends AIController

# Standard PvP AI - uses deck, mana, and cards

func _execute_turn_logic() -> void:
	await _play_cards()
	await _move_and_attack()


func _play_cards() -> void:
	var plays := 0
	while plays < 4 and not TurnManager.is_game_over():
		var card: CardData = _choose_playable_card()
		if card == null:
			break

		var played := false
		if card.is_creature():
			var summon_cell: Vector2i = game.find_enemy_summon_cell()
			if summon_cell != GridManager.INVALID_CELL:
				played = game.enemy_play_creature(card, summon_cell)

		if not played:
			break
		plays += 1
		await game.pause(0.35)


func _choose_playable_card() -> CardData:
	var playable: Array[CardData] = []
	for card in game.enemy.hand:
		if not card.is_creature():
			continue
		if card.cost > game.enemy.current_mana:
			continue
		if card.is_creature() and game.find_enemy_summon_cell() == GridManager.INVALID_CELL:
			continue
		playable.append(card)

	playable.sort_custom(func(a: CardData, b: CardData) -> bool: return a.cost > b.cost)
	if playable.is_empty():
		return null
	return playable[0]


func _move_and_attack() -> void:
	var actors: Array[Creature] = get_enemy_creatures()
	for creature in actors:
		if not is_instance_valid(creature) or TurnManager.is_game_over():
			continue

		if creature.can_move(TurnManager.turn_number):
			var target_cell: Vector2i = game.get_ai_target_cell(creature)
			await move_toward_target(creature, target_cell)

		if creature.can_attack(TurnManager.turn_number):
			await attack_if_possible(creature)
