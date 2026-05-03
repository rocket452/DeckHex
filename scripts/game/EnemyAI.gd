extends RefCounted
class_name EnemyAI


func take_turn(game) -> void:
	if TurnManager.is_game_over():
		return
	await game.pause(0.35)
	await _play_cards(game)
	await _move_and_attack(game)
	await game.pause(0.25)
	if not TurnManager.is_game_over():
		game.log_event("Enemy ends turn.")
		TurnManager.finish_enemy_turn()


func _play_cards(game) -> void:
	var plays := 0
	while plays < 4 and not TurnManager.is_game_over():
		var card: CardData = _choose_playable_card(game)
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


func _choose_playable_card(game) -> CardData:
	var playable: Array[CardData] = []
	for card in game.enemy.hand:
		if not card.is_creature() or card.id != "zombie":
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


func _move_and_attack(game) -> void:
	var actors: Array[Creature] = game.get_enemy_creatures()
	for creature in actors:
		if not is_instance_valid(creature) or TurnManager.is_game_over():
			continue

		if creature.can_move(TurnManager.turn_number):
			var target_cell: Vector2i = game.get_ai_target_cell(creature)
			var best_cell: Vector2i = game.get_best_reachable_cell_toward(creature, target_cell)
			if best_cell != creature.cell:
				game.move_creature(creature, best_cell)
				await game.pause(0.22)

		if creature.can_attack(TurnManager.turn_number):
			var target: Creature = game.find_best_attack_target(creature, "player")
			if target != null:
				await game.creature_attack_creature(creature, target)
				await game.pause(0.28)
			elif game.can_attack_leader(creature, "player"):
				await game.creature_attack_leader(creature, "player")
				await game.pause(0.28)
